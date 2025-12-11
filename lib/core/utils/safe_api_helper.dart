import 'dart:async';

/// Simple API helper for safe query execution
///
/// Features:
/// - Automatic error handling
/// - Optional retry logic
/// - Timeout support
/// - No startup initialization required
class SafeApiHelper {
  static final SafeApiHelper _instance = SafeApiHelper._internal();
  factory SafeApiHelper() => _instance;
  SafeApiHelper._internal();

  /// Execute a query with error handling
  /// Returns null on error instead of throwing
  Future<T?> safeExecute<T>(
    Future<T> Function() queryFn, {
    String? operationName,
    T? defaultValue,
    Duration? timeout,
  }) async {
    try {
      if (timeout != null) {
        return await queryFn().timeout(timeout);
      }
      return await queryFn();
    } on TimeoutException {
      print('⏱️ Timeout: ${operationName ?? 'query'}');
      return defaultValue;
    } catch (e) {
      print('❌ Error in ${operationName ?? 'query'}: $e');
      return defaultValue;
    }
  }

  /// Execute a query with simple retry logic
  /// Retries up to maxRetries times on failure
  Future<T?> executeWithRetry<T>(
    Future<T> Function() queryFn, {
    String? operationName,
    int maxRetries = 2,
    T? defaultValue,
  }) async {
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        return await queryFn();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          print(
              '❌ Failed after $maxRetries attempts: ${operationName ?? 'query'}');
          return defaultValue;
        }
        print('⚠️ Retry $attempt/$maxRetries for ${operationName ?? 'query'}');
        // Simple delay between retries
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    return defaultValue;
  }

  /// Execute a list query, returns empty list on error
  Future<List<Map<String, dynamic>>> safeListQuery(
    Future<List<dynamic>> Function() queryFn, {
    String? operationName,
  }) async {
    try {
      final result = await queryFn();
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('❌ Error in ${operationName ?? 'list query'}: $e');
      return [];
    }
  }

  /// Execute a single-item query, returns null on error
  Future<Map<String, dynamic>?> safeSingleQuery(
    Future<Map<String, dynamic>?> Function() queryFn, {
    String? operationName,
  }) async {
    try {
      return await queryFn();
    } catch (e) {
      print('❌ Error in ${operationName ?? 'single query'}: $e');
      return null;
    }
  }
}
