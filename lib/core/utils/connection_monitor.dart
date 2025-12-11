import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection monitor for checking Supabase connectivity
class ConnectionMonitor {
  static final ConnectionMonitor _instance = ConnectionMonitor._internal();
  factory ConnectionMonitor() => _instance;
  ConnectionMonitor._internal();

  bool _isOnline = true;
  DateTime? _lastCheck;
  static const Duration _checkCooldown = Duration(seconds: 30);

  /// Check if we can connect to Supabase
  Future<bool> checkConnection() async {
    // Don't check too frequently
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _checkCooldown) {
      return _isOnline;
    }

    try {
      // Simple health check - try to access Supabase
      await Supabase.instance.client
          .from('users')
          .select('username')
          .limit(1)
          .timeout(const Duration(seconds: 5));

      _isOnline = true;
      _lastCheck = DateTime.now();
      return true;
    } catch (e) {
      print('⚠️ Connection check failed: $e');
      _isOnline = false;
      _lastCheck = DateTime.now();
      return false;
    }
  }

  /// Get cached connection status
  bool get isOnline => _isOnline;

  /// Force a fresh connection check
  Future<bool> forceCheck() async {
    _lastCheck = null;
    return await checkConnection();
  }
}

/// Wrapper for API calls with automatic retry and connection handling
class ResilientApiWrapper {
  static final ResilientApiWrapper _instance = ResilientApiWrapper._internal();
  factory ResilientApiWrapper() => _instance;
  ResilientApiWrapper._internal();

  final _connectionMonitor = ConnectionMonitor();

  /// Execute an API call with retry logic
  Future<T?> execute<T>(
    Future<T> Function() apiCall, {
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 1),
    T? defaultValue,
    String? operationName,
  }) async {
    // Check connection first
    if (!_connectionMonitor.isOnline) {
      final connected = await _connectionMonitor.checkConnection();
      if (!connected) {
        print('❌ No connection for: ${operationName ?? 'API call'}');
        return defaultValue;
      }
    }

    int attempts = 0;
    Object? lastError;

    while (attempts < maxRetries) {
      try {
        return await apiCall();
      } on TimeoutException {
        lastError = TimeoutException('Request timed out');
        attempts++;
        print(
            '⏱️ Timeout (attempt $attempts/$maxRetries): ${operationName ?? 'API call'}');
      } catch (e) {
        lastError = e;
        attempts++;

        // Check if error is retryable
        if (!_isRetryableError(e)) {
          print('❌ Non-retryable error: $e');
          return defaultValue;
        }

        print(
            '⚠️ Retrying (attempt $attempts/$maxRetries): ${operationName ?? 'API call'}');
      }

      if (attempts < maxRetries) {
        await Future.delayed(retryDelay * attempts); // Exponential backoff
      }
    }

    print('❌ Failed after $maxRetries attempts: $lastError');
    return defaultValue;
  }

  /// Check if an error should be retried
  bool _isRetryableError(Object error) {
    final errorStr = error.toString().toLowerCase();

    // Retry on network/connection errors
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504')) {
      return true;
    }

    // Don't retry on client errors
    if (errorStr.contains('400') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('404') ||
        errorStr.contains('422')) {
      return false;
    }

    // Default to retry
    return true;
  }

  /// Execute a list query with fallback to empty list
  Future<List<Map<String, dynamic>>> executeListQuery(
    Future<List<dynamic>> Function() query, {
    String? operationName,
  }) async {
    final result = await execute<List<dynamic>>(
      query,
      defaultValue: [],
      operationName: operationName,
    );

    if (result == null) return [];
    return List<Map<String, dynamic>>.from(result);
  }
}
