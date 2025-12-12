// SECURE Auth Service - Hardened against attacks
// Security Features:
// 1. Device-based rate limiting (5 attempts/hour)
// 2. IP-based rate limiting (10 attempts/hour)
// 3. No fallback that bypasses rate limiting
// 4. Timing attack protection (artificial delay)
// 5. Secure session with signature
// 6. No console logging in production
// 7. Environment-based secrets
// 8. Role guard integration

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
    // Return cached fingerprint if available
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

    // Hash the fingerprint for privacy
    final hashedFingerprint = md5.convert(utf8.encode(fingerprint)).toString();
    _cachedFingerprint = hashedFingerprint;

    // Save fingerprint for future use
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

  /// Fetch real IP address for IP-based rate limiting
  Future<String> _getRealIpAddress() async {
    // Return cached IP if available
    if (_cachedIpAddress != null) {
      return _cachedIpAddress!;
    }

    try {
      // Use ipify API to get public IP (free, no API key needed)
      final response = await http
          .get(
            Uri.parse('https://api.ipify.org?format=json'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedIpAddress = data['ip'] as String;
        return _cachedIpAddress!;
      }
    } catch (e) {
      _secureLog('Error fetching IP address');
    }

    // Fallback: generate a hash from device info
    final deviceInfo = await _getDeviceInfo();
    _cachedIpAddress =
        'mobile_${deviceInfo['fingerprint']?.substring(0, 8) ?? 'unknown'}';
    return _cachedIpAddress!;
  }

  /// Get IP status (remaining attempts, blocked state)
  Future<Map<String, dynamic>> getIpStatus() async {
    try {
      final ipAddress = await _getRealIpAddress();

      final response = await _supabase.rpc('get_ip_status', params: {
        'p_ip_address': ipAddress,
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _secureLog('Error checking IP status');
      return {
        'is_blocked': false,
        'remaining_attempts': 10,
        'message': 'Unable to check IP status',
      };
    }
  }

  /// Generate session signature for tamper detection
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

  /// Check remaining login attempts for this device
  Future<Map<String, dynamic>> getRemainingAttempts() async {
    try {
      final deviceInfo = await _getDeviceInfo();

      final response =
          await _supabase.rpc('get_remaining_login_attempts', params: {
        'p_device_fingerprint': deviceInfo['fingerprint'],
      });

      return Map<String, dynamic>.from(response);
    } catch (e) {
      _secureLog('Error checking remaining attempts');
      return {
        'remaining_attempts': 5,
        'is_blocked': false,
        'message': 'Unable to check rate limit',
      };
    }
  }

  /// Add artificial delay to prevent timing attacks
  Future<void> _addSecurityDelay(DateTime startTime) async {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < _minResponseTimeMs) {
      // Add random jitter (100-200ms) to prevent fingerprinting
      final jitter = Random().nextInt(100) + 100;
      await Future.delayed(
          Duration(milliseconds: _minResponseTimeMs - elapsed + jitter));
    }
  }

  /// Login user with username and password (SECURE with rate limiting)
  Future<Map<String, dynamic>> login(String username, String password) async {
    final startTime = DateTime.now();

    try {
      // Validate input locally first
      if (username.trim().isEmpty || password.trim().isEmpty) {
        await _addSecurityDelay(startTime);
        return {
          'success': false,
          'role': null,
          'message': 'Username and password cannot be empty',
        };
      }

      // Basic input sanitization (prevent injection)
      final sanitizedUsername = username.trim().toLowerCase();
      if (!_isValidUsername(sanitizedUsername)) {
        await _addSecurityDelay(startTime);
        return {
          'success': false,
          'role': null,
          'message': 'Invalid username format',
        };
      }

      // Get device fingerprint and real IP
      final deviceInfo = await _getDeviceInfo();
      final ipAddress = await _getRealIpAddress();

      // Call secure login V3 with IP-based rate limiting
      final response = await _supabase.rpc('secure_login_v3', params: {
        'p_username': sanitizedUsername,
        'p_password': password,
        'p_device_fingerprint': deviceInfo['fingerprint'],
        'p_ip_address': ipAddress,
        'p_user_agent': deviceInfo['userAgent'],
      });

      final result = Map<String, dynamic>.from(response);

      // Add security delay before responding
      await _addSecurityDelay(startTime);

      // Check if login was successful
      if (result['success'] == true) {
        // Save secure session
        await _saveSecureSession(sanitizedUsername, result['role'] as String);

        return {
          'success': true,
          'role': result['role'],
          'message': result['message'] ?? 'Login successful',
        };
      } else {
        // Login failed
        return {
          'success': false,
          'role': null,
          'message': result['message'] ?? 'Invalid username or password',
          'rate_limited': result['rate_limited'] ?? false,
          'block_remaining_minutes': result['block_remaining_minutes'],
        };
      }
    } on PostgrestException {
      _secureLog('Database error during login');

      // Add security delay
      await _addSecurityDelay(startTime);

      // ❌ NO FALLBACK - This prevents bypassing rate limiting
      // If secure_login_v2 fails, login is denied
      return {
        'success': false,
        'role': null,
        'message': 'Authentication service unavailable. Please try again.',
      };
    } catch (_) {
      _secureLog('Login error');

      // Add security delay
      await _addSecurityDelay(startTime);

      // ❌ NO FALLBACK - Security first
      return {
        'success': false,
        'role': null,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Validate username format (prevent injection)
  bool _isValidUsername(String username) {
    // Allow only alphanumeric, underscore, and minimum 3 chars
    final regex = RegExp(r'^[a-z0-9_]{3,50}$');
    return regex.hasMatch(username);
  }

  /// Save secure session with signature
  Future<void> _saveSecureSession(String username, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final signature = _generateSessionSignature(username, role, timestamp);

      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyRole, role);
      await prefs.setInt(_keySessionTimestamp, timestamp);
      await prefs.setString(_keySessionSignature, signature);

      // Update role guard with current user
      roleGuard.setCurrentUser(username, role);

      SecureLogger.security(
          'AUTH', 'User logged in: $username with role: $role');
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

      // Verify session hasn't been tampered
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

      // Verify signature
      if (!_verifySessionSignature(username, role, timestamp, signature)) {
        _secureLog('Session signature mismatch - possible tampering');
        await logout(); // Clear tampered session
        return false;
      }

      // Check session age (max 7 days)
      final sessionAge = DateTime.now().millisecondsSinceEpoch - timestamp;
      const maxSessionAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
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

  /// Logout user and clear session
  Future<void> logout() async {
    try {
      final username = roleGuard.currentUsername;

      final prefs = await SharedPreferences.getInstance();
      // Only clear auth-related keys, not all preferences
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyRole);
      await prefs.remove(_keySessionTimestamp);
      await prefs.remove(_keySessionSignature);
      // Keep device fingerprint for rate limiting

      // Clear role guard
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

      // Verify user still exists in database (minimal query)
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

      // Validate new password strength
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
