/// Secure Logging Utility
///
/// This utility ensures sensitive information is not logged in production.
/// - Debug mode: Full logging with timestamps
/// - Release mode: No logging (or PII-redacted logging)
///
/// Security Features:
/// 1. Automatically disables in release mode
/// 2. Redacts sensitive data patterns (IDs, emails, phone numbers)
/// 3. Truncates long strings to prevent log flooding
/// 4. Provides structured logging with severity levels

import 'package:flutter/foundation.dart';

/// Log levels for categorizing messages
enum LogLevel {
  debug,
  info,
  warning,
  error,
  security, // For security-related events
}

/// Secure Logger that automatically handles production vs debug logging
class SecureLogger {
  static final SecureLogger _instance = SecureLogger._internal();

  factory SecureLogger() => _instance;

  SecureLogger._internal();

  /// Whether to enable logging (only in debug mode)
  static bool get _isLoggingEnabled => kDebugMode;

  /// Maximum length for logged strings (prevents log flooding)
  static const int _maxLogLength = 200;

  /// Patterns to redact from logs
  static final List<RegExp> _sensitivePatterns = [
    // Email addresses
    RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
    // Phone numbers (Indian format)
    RegExp(r'\b[6-9]\d{9}\b'),
    // Password-like fields
    RegExp(r'(password|passwd|pwd|secret|token)\s*[:=]\s*\S+',
        caseSensitive: false),
    // Aadhaar numbers (12 digits)
    RegExp(r'\b\d{4}\s?\d{4}\s?\d{4}\b'),
    // PAN numbers
    RegExp(r'\b[A-Z]{5}\d{4}[A-Z]\b'),
    // Credit card numbers
    RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
    // API keys (common patterns)
    RegExp(r'(api[_-]?key|apikey|access[_-]?token)\s*[:=]\s*\S+',
        caseSensitive: false),
  ];

  /// Patterns that should never be logged (completely removed)
  static final List<RegExp> _blockedPatterns = [
    // JWT tokens
    RegExp(r'eyJ[A-Za-z0-9_-]*\.eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*'),
    // Base64 encoded strings that look like secrets (long alphanumeric)
    RegExp(r'(?:password|secret|key)\s*[:=]\s*[A-Za-z0-9+/=]{20,}',
        caseSensitive: false),
  ];

  /// Redact sensitive information from a string
  String _redactSensitiveData(String message) {
    String redacted = message;

    // Completely block certain patterns
    for (final pattern in _blockedPatterns) {
      redacted = redacted.replaceAll(pattern, '[BLOCKED]');
    }

    // Partially redact other sensitive patterns
    for (final pattern in _sensitivePatterns) {
      redacted = redacted.replaceAllMapped(pattern, (match) {
        final original = match.group(0) ?? '';
        if (original.length <= 4) {
          return '[REDACTED]';
        }
        // Show first 2 and last 2 characters
        return '${original.substring(0, 2)}***${original.substring(original.length - 2)}';
      });
    }

    return redacted;
  }

  /// Truncate long messages
  String _truncate(String message) {
    if (message.length <= _maxLogLength) {
      return message;
    }
    return '${message.substring(0, _maxLogLength)}... [truncated ${message.length - _maxLogLength} chars]';
  }

  /// Format log message with timestamp and level
  String _formatMessage(LogLevel level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    return '[$timestamp] [$levelStr] [$tag] $message';
  }

  /// Core logging method
  void _log(LogLevel level, String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    if (!_isLoggingEnabled) return;

    // Redact and truncate the message
    final safeMessage = _truncate(_redactSensitiveData(message));
    final formattedMessage = _formatMessage(level, tag, safeMessage);

    // Use debugPrint for controlled output
    debugPrint(formattedMessage);

    // Log error details if provided (also redacted)
    if (error != null) {
      final safeError = _redactSensitiveData(error.toString());
      debugPrint('  Error: $safeError');
    }

    // Only log stack traces for errors (and truncate them)
    if (stackTrace != null && level == LogLevel.error) {
      final stackLines = stackTrace.toString().split('\n').take(5);
      debugPrint('  Stack: ${stackLines.join('\n          ')}');
    }
  }

  // Public logging methods

  /// Debug log - general debugging info
  static void debug(String tag, String message) {
    _instance._log(LogLevel.debug, tag, message);
  }

  /// Info log - informational messages
  static void info(String tag, String message) {
    _instance._log(LogLevel.info, tag, message);
  }

  /// Warning log - potential issues
  static void warning(String tag, String message) {
    _instance._log(LogLevel.warning, tag, message);
  }

  /// Error log - errors and exceptions
  static void error(String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    _instance._log(LogLevel.error, tag, message,
        error: error, stackTrace: stackTrace);
  }

  /// Security log - security-related events (always logged, even in production for audit trail)
  /// Note: In production, this should be sent to a secure logging service instead
  static void security(String tag, String message) {
    // Security logs are special - we might want to keep these even in production
    // For now, they follow the same rules but are marked differently
    _instance._log(LogLevel.security, tag, message);

    // TODO: In production, send to secure audit log service
    // await _sendToAuditService(tag, message);
  }

  /// Log API call (with automatic redaction of sensitive params)
  static void apiCall(String endpoint, Map<String, dynamic>? params) {
    if (!_isLoggingEnabled) return;

    // Redact known sensitive fields
    final safeParams = params != null ? _instance._redactParams(params) : {};
    _instance._log(LogLevel.info, 'API', '$endpoint -> $safeParams');
  }

  /// Redact sensitive fields from parameter maps
  Map<String, dynamic> _redactParams(Map<String, dynamic> params) {
    const sensitiveKeys = [
      'password',
      'p_password',
      'old_password',
      'new_password',
      'token',
      'secret',
      'api_key',
      'apikey',
      'access_token',
      'authorization',
      'auth',
      'cookie',
      'session',
    ];

    return params.map((key, value) {
      if (sensitiveKeys.any((k) => key.toLowerCase().contains(k))) {
        return MapEntry(key, '[REDACTED]');
      }
      if (value is String) {
        return MapEntry(key, _redactSensitiveData(value));
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _redactParams(value));
      }
      return MapEntry(key, value);
    });
  }
}

/// Shorthand logger instance for convenience
final log = SecureLogger();

/// Extension for easy logging from any class
extension SecureLogging on Object {
  void logDebug(String message) =>
      SecureLogger.debug(runtimeType.toString(), message);
  void logInfo(String message) =>
      SecureLogger.info(runtimeType.toString(), message);
  void logWarning(String message) =>
      SecureLogger.warning(runtimeType.toString(), message);
  void logError(String message, {Object? error, StackTrace? stack}) =>
      SecureLogger.error(runtimeType.toString(), message,
          error: error, stackTrace: stack);
  void logSecurity(String message) =>
      SecureLogger.security(runtimeType.toString(), message);
}
