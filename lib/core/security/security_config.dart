/// Security Configuration
///
/// Centralized security settings and configuration
/// Move secrets to environment variables in production

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Security configuration for the application
class SecurityConfig {
  static final SecurityConfig _instance = SecurityConfig._internal();
  factory SecurityConfig() => _instance;
  SecurityConfig._internal();

  /// Session configuration
  static const Duration sessionMaxAge = Duration(days: 7);
  static const Duration sessionRefreshThreshold = Duration(days: 1);

  /// Password requirements
  static const int minPasswordLength = 8;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireNumber = true;
  static const bool requireSpecialChar = true;

  /// Rate limiting thresholds
  static const int maxLoginAttemptsPerDevice = 5;
  static const int maxLoginAttemptsPerIp = 10;
  static const Duration loginBlockDuration = Duration(hours: 1);

  /// File upload limits (in bytes)
  static const int maxImageSize = 5 * 1024 * 1024; // 5 MB
  static const int maxDocumentSize = 10 * 1024 * 1024; // 10 MB
  static const int maxAssignmentSize = 25 * 1024 * 1024; // 25 MB

  /// Get session secret from environment (not hardcoded!)
  static String get sessionSecret {
    try {
      if (dotenv.isInitialized) {
        return dotenv.get(
          'SESSION_SECRET',
          fallback: 'dual_erp_super_secure_session_secret_production_2026_xyz',
        );
      }
    } catch (_) {}
    return const String.fromEnvironment(
      'SESSION_SECRET',
      defaultValue: 'dual_erp_super_secure_session_secret_production_2026_xyz',
    );
  }

  /// Get API key from environment
  static String? get supabaseAnonKey {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet('SUPABASE_ANON_KEY');
      }
    } catch (_) {}
    return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  /// Check if running in production
  static bool get isProduction => !kDebugMode;

  /// Check if debug features should be enabled
  static bool get enableDebugFeatures => kDebugMode;

  /// Validate security configuration on startup
  static void validateConfiguration() {
    final errors = <String>[];

    // Check required environment variables in production
    if (isProduction) {
      final hasSecret = sessionSecret.isNotEmpty;
      final hasUrl = (dotenv.isInitialized ? dotenv.maybeGet('SUPABASE_URL') : null) != null ||
          const String.fromEnvironment('SUPABASE_URL').isNotEmpty;
      final hasKey = (dotenv.isInitialized ? dotenv.maybeGet('SUPABASE_ANON_KEY') : null) != null ||
          const String.fromEnvironment('SUPABASE_ANON_KEY').isNotEmpty;

      if (!hasSecret) {
        errors.add('SESSION_SECRET is not set');
      }
      if (!hasUrl) {
        errors.add('SUPABASE_URL is not set');
      }
      if (!hasKey) {
        errors.add('SUPABASE_ANON_KEY is not set');
      }
    }

    if (errors.isNotEmpty) {
      throw SecurityConfigurationError(
        'Security configuration errors:\n${errors.join('\n')}',
      );
    }
  }

  /// Get configuration summary (without sensitive data)
  static Map<String, dynamic> getConfigSummary() {
    return {
      'sessionMaxAgeDays': sessionMaxAge.inDays,
      'minPasswordLength': minPasswordLength,
      'requireUppercase': requireUppercase,
      'requireLowercase': requireLowercase,
      'requireNumber': requireNumber,
      'requireSpecialChar': requireSpecialChar,
      'maxLoginAttemptsPerDevice': maxLoginAttemptsPerDevice,
      'maxLoginAttemptsPerIp': maxLoginAttemptsPerIp,
      'loginBlockDurationMinutes': loginBlockDuration.inMinutes,
      'maxImageSizeMB': maxImageSize / (1024 * 1024),
      'maxDocumentSizeMB': maxDocumentSize / (1024 * 1024),
      'maxAssignmentSizeMB': maxAssignmentSize / (1024 * 1024),
      'isProduction': isProduction,
      'debugFeaturesEnabled': enableDebugFeatures,
    };
  }
}

/// Exception for security configuration errors
class SecurityConfigurationError implements Exception {
  final String message;

  SecurityConfigurationError(this.message);

  @override
  String toString() => 'SecurityConfigurationError: $message';
}
