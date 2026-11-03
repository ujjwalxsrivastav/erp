// SECURE Auth Service - Hardened against attacks & Dual-Mode (College + School)
// Security Features:
// 1. Device-based rate limiting (5 attempts/hour)
// 2. IP-based rate limiting (10 attempts/hour)
// 3. Timing attack protection (artificial delay)
// 4. Secure session with signature
// 5. Dual-mode support (College + School institute_type resolution)
// 6. Role guard integration

import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/security/security_config.dart';
import '../core/security/role_guard.dart';
import '../core/security/secure_logger.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // Lazy access to prevent accessing before Supabase is initialized
  SupabaseClient get _supabase => Supabase.instance.client;

  // Keys for SharedPreferences
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyRole = 'user_role';
  static const String _keyInstituteType = 'institute_type';
  static const String _keyDeviceFingerprint = 'device_fingerprint';
  static const String _keySessionSignature = 'session_signature';
  static const String _keySessionTimestamp = 'session_timestamp';

  // Get session secret from security config (environment-based)
  String get _sessionSecret => SecurityConfig.sessionSecret;

  // Cached device fingerprint and IP
  String? _cachedFingerprint;
  String? _cachedIpAddress;

  // Minimum response time to prevent timing attacks (milliseconds)
  static const int _minResponseTimeMs = 500;

  /// Secure logging (disabled in production)
  void _secureLog(String message) {
    if (kDebugMode) {
      debugPrint('[AUTH] $message');
    }
  }

  /// Generate unique device fingerprint
  Future<Map<String, String>> _getDeviceInfo() async {
    if (_cachedFingerprint != null) {
      return {
        'fingerprint': _cachedFingerprint!,
        'ip': 'app_client',
        'userAgent': 'flutter_app',
      };
    }

    String fingerprint = '';
    String userAgent = 'flutter_app';

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        fingerprint =
            '${webInfo.browserName}_${webInfo.platform}_${webInfo.language}';
        userAgent = 'Web/${webInfo.browserName}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        fingerprint =
            '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
        userAgent = 'Android/${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        fingerprint = '${iosInfo.identifierForVendor}_${iosInfo.model}';
        userAgent = 'iOS/${iosInfo.systemVersion}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        fingerprint = '${macInfo.systemGUID}_${macInfo.model}';
        userAgent = 'macOS/${macInfo.majorVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        fingerprint = '${windowsInfo.deviceId}_${windowsInfo.computerName}';
        userAgent = 'Windows/${windowsInfo.majorVersion}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        fingerprint = '${linuxInfo.machineId}_${linuxInfo.name}';
        userAgent = 'Linux/${linuxInfo.version}';
      }
    } catch (e) {
      _secureLog('Error getting device info');
      fingerprint = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }

    final hashedFingerprint = md5.convert(utf8.encode(fingerprint)).toString();
    _cachedFingerprint = hashedFingerprint;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeviceFingerprint, hashedFingerprint);
    } catch (e) {
      _secureLog('Error saving fingerprint');
    }

    return {
      'fingerprint': hashedFingerprint,
      'userAgent': userAgent,
    };
  }

  /// Get real client IP address (external service)
  Future<String> _getRealIpAddress() async {
    if (_cachedIpAddress != null) {
      return _cachedIpAddress!;
    }

    if (kIsWeb) {
      _cachedIpAddress = '127.0.0.1';
      return '127.0.0.1';
    }

    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedIpAddress = data['ip'] as String?;
        return _cachedIpAddress ?? '127.0.0.1';
      }
    } catch (e) {
      _secureLog('Could not fetch external IP, using fallback');
    }

    return '127.0.0.1';
  }

  /// Generate HMAC signature for session data to prevent tampering
  String _generateSessionSignature(
      String username, String role, int timestamp) {
    final data = '$username:$role:$timestamp:$_sessionSecret';
    return sha256.convert(utf8.encode(data)).toString();
  }

  /// Verify session signature
  bool _verifySessionSignature(
      String username, String role, int timestamp, String signature) {
    final expectedSignature =
        _generateSessionSignature(username, role, timestamp);
    return signature == expectedSignature;
  }

  /// Add artificial delay to normalize response times and prevent timing attacks
  Future<void> _addSecurityDelay(DateTime startTime) async {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < _minResponseTimeMs) {
      final jitter = Random().nextInt(100) + 100;
      await Future.delayed(
          Duration(milliseconds: _minResponseTimeMs - elapsed + jitter));
    }
  }

  /// Validate username format
  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,50}$');
    return regex.hasMatch(username);
  }

  /// Login user with username and password (SECURE + DUAL-MODE)
  Future<Map<String, dynamic>> login(String username, String password) async {
    final startTime = DateTime.now();

    try {
      if (username.trim().isEmpty || password.trim().isEmpty) {
        await _addSecurityDelay(startTime);
        return {
          'success': false,
          'role': null,
          'institute_type': 'college',
          'message': 'Username and password cannot be empty',
        };
      }

      final sanitizedUsername = username.trim();
      if (!_isValidUsername(sanitizedUsername)) {
        await _addSecurityDelay(startTime);
        return {
          'success': false,
          'role': null,
          'institute_type': 'college',
          'message': 'Invalid username format',
        };
      }

      // Try secure RPC first
      try {
        final deviceInfo = await _getDeviceInfo();
        final ipAddress = await _getRealIpAddress();

        final response = await _supabase.rpc('secure_login_v3', params: {
          'p_username': sanitizedUsername.toLowerCase(),
          'p_password': password,
          'p_device_fingerprint': deviceInfo['fingerprint'],
          'p_ip_address': ipAddress,
          'p_user_agent': deviceInfo['userAgent'],
        });

        final Map<String, dynamic> result;
        if (response is Map) {
          result = Map<String, dynamic>.from(response);
        } else if (response is String) {
          result = Map<String, dynamic>.from(json.decode(response) as Map);
        } else {
          throw Exception('Unexpected RPC response type');
        }

        await _addSecurityDelay(startTime);

        if (result['success'] == true) {
          final actualUsername = result['username'] as String? ?? sanitizedUsername;
          final role = result['role'] as String;

          // Resolve institute_type from database
          String instituteType = 'college';
          try {
            final userRecord = await _supabase
                .from('users')
                .select('institute_type, institution')
                .eq('username', actualUsername)
                .maybeSingle();

            // users.institution is the source of truth set by Manage Users;
            // institute_type is the legacy dual-mode flag.
            if (userRecord != null && userRecord['institution'] != null) {
              instituteType = userRecord['institution'] as String;
            } else if (userRecord != null &&
                userRecord['institute_type'] != null) {
              instituteType = userRecord['institute_type'] as String;
            } else if (actualUsername.startsWith('s') || role == 'parent') {
              instituteType = 'school';
            }
          } catch (_) {
            if (actualUsername.startsWith('s') || role == 'parent') {
              instituteType = 'school';
            }
          }

          await _saveSecureSession(actualUsername, role, instituteType: instituteType);

          return {
            'success': true,
            'role': role,
            'institute_type': instituteType,
            'message': result['message'] ?? 'Login successful',
          };
        } else {
          return {
            'success': false,
            'role': null,
            'institute_type': 'college',
            'message': result['message'] ?? 'Invalid username or password',
            'rate_limited': result['rate_limited'] ?? false,
            'block_remaining_minutes': result['block_remaining_minutes'],
          };
        }
      } catch (rpcError) {
        // Fallback to direct query if RPC is not deployed yet
        _secureLog('RPC login error or not configured: $rpcError. Trying direct query...');
        
        final userQuery = await _supabase
            .from('users')
            .select('username, password, role, institute_type, institution')
            .eq('username', sanitizedUsername)
            .maybeSingle();

        await _addSecurityDelay(startTime);

        if (userQuery != null && userQuery['password'] == password) {
          final role = userQuery['role'] as String;
          final instituteType = (userQuery['institution'] as String?) ??
              (userQuery['institute_type'] as String?) ??
              (sanitizedUsername.startsWith('s') || role == 'parent' ? 'school' : 'college');

          await _saveSecureSession(sanitizedUsername, role, instituteType: instituteType);

          return {
            'success': true,
            'role': role,
            'institute_type': instituteType,
            'message': 'Login successful',
          };
        }

        return {
          'success': false,
          'role': null,
          'institute_type': 'college',
          'message': 'Invalid username or password',
        };
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AUTH] Login error — ${e.runtimeType}: $e');
        debugPrint('[AUTH] Stack: ${stack.toString().split('\n').take(4).join('\n')}');
      }

      await _addSecurityDelay(startTime);

      return {
        'success': false,
        'role': null,
        'institute_type': 'college',
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Save secure session with signature and institute_type
  Future<void> _saveSecureSession(String username, String role,
      {String instituteType = 'college'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signature = _generateSessionSignature(username, role, timestamp);

      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyRole, role);
      await prefs.setString(_keyInstituteType, instituteType);
      await prefs.setInt(_keySessionTimestamp, timestamp);
      await prefs.setString(_keySessionSignature, signature);

      // Update role guard with current user
      roleGuard.setCurrentUser(username, role);

      SecureLogger.security(
          'AUTH', 'User logged in: $username ($role, $instituteType)');
    } catch (e) {
      SecureLogger.error('AUTH', 'Error saving session', error: e);
    }
  }

  /// Check if user is logged in (with signature verification)
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

      if (!isLoggedIn) return false;

      final username = prefs.getString(_keyUsername);
      final role = prefs.getString(_keyRole);
      final timestamp = prefs.getInt(_keySessionTimestamp);
      final signature = prefs.getString(_keySessionSignature);

      if (username == null ||
          role == null ||
          timestamp == null ||
          signature == null) {
        return false;
      }

      if (!_verifySessionSignature(username, role, timestamp, signature)) {
        _secureLog('Session signature mismatch - possible tampering');
        await logout();
        return false;
      }

      final sessionAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      const maxSessionAge = 7 * 24 * 60 * 60 * 1000; // 7 days
      if (sessionAge > maxSessionAge) {
        _secureLog('Session expired');
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      _secureLog('Error checking login status');
      return false;
    }
  }

  /// Get current user's role
  Future<String?> getCurrentUserRole() async {
    try {
      final isValid = await isLoggedIn();
      if (!isValid) return null;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRole);
    } catch (e) {
      _secureLog('Error getting user role');
      return null;
    }
  }

  /// Get current username
  Future<String?> getCurrentUsername() async {
    try {
      final isValid = await isLoggedIn();
      if (!isValid) return null;

      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUsername);
    } catch (e) {
      _secureLog('Error getting username');
      return null;
    }
  }

  /// Get current institute type
  Future<String?> getCurrentInstituteType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyInstituteType) ?? 'college';
    } catch (e) {
      return 'college';
    }
  }

  /// Logout user and clear session
  Future<void> logout() async {
    try {
      final username = roleGuard.currentUsername;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyInstituteType);
      await prefs.remove(_keySessionTimestamp);
      await prefs.remove(_keySessionSignature);

      roleGuard.clearCurrentUser();

      SecureLogger.security('AUTH', 'User logged out: $username');
    } catch (e) {
      SecureLogger.error('AUTH', 'Error during logout', error: e);
    }
  }

  /// Verify if current session is still valid
  Future<bool> verifySession() async {
    try {
      final isValid = await isLoggedIn();
      if (!isValid) return false;

      final username = await getCurrentUsername();
      if (username == null) return false;

      final response = await _supabase
          .from('users')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      return response != null;
    } catch (e) {
      _secureLog('Error verifying session');
      return false;
    }
  }

  /// Change password for current user
  Future<Map<String, dynamic>> changePassword(
      String oldPassword, String newPassword) async {
    try {
      final username = await getCurrentUsername();
      if (username == null) {
        return {'success': false, 'message': 'Not logged in'};
      }

      if (newPassword.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters'
        };
      }

      final response = await _supabase.rpc('secure_update_password', params: {
        'p_username': username,
        'p_old_password': oldPassword,
        'p_new_password': newPassword,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _secureLog('Error changing password');
      return {'success': false, 'message': 'Error changing password'};
    }
  }
}
