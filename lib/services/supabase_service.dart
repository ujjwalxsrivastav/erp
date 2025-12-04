import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  static Future<void> initialize() async {
    try {
      // Try to get from AppConfig first (for web), then fallback to dotenv (for mobile)
      String url = '';
      String anonKey = '';

      // Import AppConfig
      try {
        // For web builds, use AppConfig
        const configUrl =
            String.fromEnvironment('SUPABASE_URL', defaultValue: '');
        const configKey =
            String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

        if (configUrl.isNotEmpty && configKey.isNotEmpty) {
          url = configUrl;
          anonKey = configKey;
        } else {
          // Fallback to dotenv for mobile
          url = dotenv.get('SUPABASE_URL', fallback: '');
          anonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');
        }
      } catch (e) {
        // If dotenv fails, try environment variables
        url = dotenv.get('SUPABASE_URL', fallback: '');
        anonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');
      }

      if (url.isEmpty || anonKey.isEmpty) {
        print('Warning: Supabase credentials not found in environment');
        print('Please set SUPABASE_URL and SUPABASE_ANON_KEY');
        return;
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
