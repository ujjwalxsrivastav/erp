class AppConfig {
  // Supabase Configuration
  // IMPORTANT: Do NOT hardcode credentials here!
  // Credentials are passed via --dart-define during build
  // See deploy.sh for how credentials are injected

  // These are placeholders - actual values come from build-time environment variables
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // App Configuration
  static const String appName = 'Shivalik College ERP';
  static const String appVersion = '1.0.0';

  // Feature Flags
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
}
