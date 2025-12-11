// FIXED Auth Service - Using username as primary key
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Login user with username and password
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // Validate input
      if (username.trim().isEmpty || password.trim().isEmpty) {
        return {
          'success': false,
          'role': null,
          'message': 'Username and password cannot be empty',
        };
      }

      // Query Supabase for user
      // Query Supabase for user
      final response = await _supabase.from('users').select('''
            username,
            password,
            role
          ''').eq('username', username.trim()).maybeSingle();

      // Check if user exists
      if (response == null) {
        return {
          'success': false,
          'role': null,
          'message': 'Invalid username or password',
        };
      }

      // Verify password
      final storedPassword = response['password'] as String;
      if (storedPassword != password) {
        return {
          'success': false,
          'role': null,
          'message': 'Invalid username or password',
        };
      }

      // Get user role
      final role = response['role'] as String;

      // Save session
      await _saveSession(username.trim(), role);

      return {
        'success': true,
        'role': role,
        'message': 'Login successful',
      };
    } on PostgrestException catch (e) {
      print('Supabase error: ${e.message}');
      return {
        'success': false,
        'role': null,
        'message': 'Database error: ${e.message}',
      };
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'role': null,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  /// Save user session to SharedPreferences
  Future<void> _saveSession(String username, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, username);
      await prefs.setString(_keyRole, role);
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
      print('Error checking login status: $e');
      return false;
    }
  }

  /// Get current user's role
  Future<String?> getCurrentUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRole);
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Get current username
  Future<String?> getCurrentUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUsername);
    } catch (e) {
      print('Error getting username: $e');
      return null;
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
      final isLoggedIn = await this.isLoggedIn();
      if (!isLoggedIn) return false;

      final username = await getCurrentUsername();
      if (username == null) return false;

      // Verify user still exists in database
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
