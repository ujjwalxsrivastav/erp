// FIXED Auth Service - Dual Mode (College + School)
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final _supabase = Supabase.instance.client;

  // Keys for SharedPreferences
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyRole = 'user_role';
  static const String _keyInstituteType = 'institute_type';

  /// Login user with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      if (username.trim().isEmpty || password.trim().isEmpty) {
        return {
          'success': false,
          'role': null,
          'institute_type': 'college',
          'message': 'Username and password cannot be empty',
        };
      }

      final response = await _supabase.from('users').select('''
            username,
            password,
            role,
            institute_type
          ''').eq('username', username.trim()).maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'role': null,
          'institute_type': 'college',
          'message': 'Invalid username or password',
        };
      }

      final storedPassword = response['password'] as String;
      if (storedPassword != password) {
        return {
          'success': false,
          'role': null,
          'institute_type': 'college',
          'message': 'Invalid username or password',
        };
      }

      final role = response['role'] as String;
      final instituteType = (response['institute_type'] as String?) ?? 'college';

      await _saveSession(username.trim(), role, instituteType);

      return {
        'success': true,
        'role': role,
        'institute_type': instituteType,
        'message': 'Login successful',
      };
    } on PostgrestException catch (e) {
      print('Supabase error: ${e.message}');
      return {
        'success': false,
        'role': null,
        'institute_type': 'college',
        'message': 'Database error: ${e.message}',
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'role': null,
        'institute_type': 'college',
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Save user session to SharedPreferences
  Future<void> _saveSession(String username, String role, String instituteType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyRole, role);
      await prefs.setString(_keyInstituteType, instituteType);
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's role
  Future<String?> getCurrentUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRole);
    } catch (e) {
      return null;
    }
  }

  /// Get current username
  Future<String?> getCurrentUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUsername);
    } catch (e) {
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  /// Verify if current session is still valid
  Future<bool> verifySession() async {
    try {
      final loggedIn = await isLoggedIn();
      if (!loggedIn) return false;

      final username = await getCurrentUsername();
      if (username == null) return false;

      final response = await _supabase
          .from('users')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error verifying session: $e');
      return false;
    }
  }
}
