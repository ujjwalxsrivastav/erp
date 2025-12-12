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
    if (kDebugMode) {
      // In debug mode, use a default for local testing
      return dotenv.get(
        'SESSION_SECRET',
        fallback: 'debug_session_secret_not_for_production',
      );
    }

    // In production, require the environment variable to be set
    final secret = dotenv.maybeGet('SESSION_SECRET');
    if (secret == null || secret.isEmpty) {
      throw SecurityConfigurationError(
        'SESSION_SECRET environment variable must be set in production',
      );
    }

    if (secret.length < 32) {
      throw SecurityConfigurationError(
        'SESSION_SECRET must be at least 32 characters',
      );
    }

    return secret;
  }

  /// Get API key from environment
  static String? get supabaseAnonKey {
    return dotenv.maybeGet('SUPABASE_ANON_KEY');
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
      if (dotenv.maybeGet('SESSION_SECRET') == null) {
        errors.add('SESSION_SECRET is not set');
      }
      if (dotenv.maybeGet('SUPABASE_URL') == null) {
        errors.add('SUPABASE_URL is not set');
      }
      if (dotenv.maybeGet('SUPABASE_ANON_KEY') == null) {
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
