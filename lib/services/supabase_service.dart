import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static const String _defaultUrl = 'https://rvyzfqffjgwadxtbiuvr.supabase.co';
  static const String _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2eXpmcWZmamd3YWR4dGJpdXZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NDkwMzAsImV4cCI6MjA3OTEyNTAzMH0.focrBupRcbCiPgSCRvRpBpzZnvte9hNkWmsD4LSTBN0';

  static Future<void> initialize() async {
    try {
      String url = '';
      String anonKey = '';

      // 1. Check dart-define
      const configUrl =
          String.fromEnvironment('SUPABASE_URL', defaultValue: '');
      const configKey =
          String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

      if (configUrl.isNotEmpty && configKey.isNotEmpty) {
        url = configUrl;
        anonKey = configKey;
      } else {
        // 2. Check dotenv
        try {
          url = dotenv.get('SUPABASE_URL', fallback: '');
          anonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');
        } catch (_) {}
      }

      // 3. Fallback to legitimate anon JWT key
      if (url.isEmpty || anonKey.isEmpty) {
        url = _defaultUrl;
        anonKey = _defaultAnonKey;
      }

      await Supabase.initialize(url: url, anonKey: anonKey);
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  static bool get isAuthenticated => currentUser != null;
}
