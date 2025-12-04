class AppConfig {
  // Supabase Configuration
  // IMPORTANT: Replace these with your actual Supabase credentials
  static const String supabaseUrl = 'https://rvyzfqffjgwadxtbiuvr.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ2eXpmcWZmamd3YWR4dGJpdXZyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NDkwMzAsImV4cCI6MjA3OTEyNTAzMH0.focrBupRcbCiPgSCRvRpBpzZnvte9hNkWmsD4LSTBN0';

  // App Configuration
  static const String appName = 'Shivalik College ERP';
  static const String appVersion = '1.0.0';

  // Feature Flags
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
}
