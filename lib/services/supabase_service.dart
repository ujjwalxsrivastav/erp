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
      final url = dotenv.get('SUPABASE_URL', fallback: '');
      final anonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');

      if (url.isEmpty || anonKey.isEmpty) {
        print('Warning: Supabase credentials not found in environment');
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
