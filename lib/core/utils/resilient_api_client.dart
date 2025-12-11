import 'dart:async';
import 'dart:math';
import '../config/performance_config.dart';

/// API Client with retry logic, rate limiting, and connection management
///
/// Features:
/// 1. Exponential backoff for retries
/// 2. Rate limiting to prevent quota exhaustion
/// 3. Request queuing during high load
/// 4. Connection health monitoring
/// 5. Automatic error recovery

class ResilientApiClient {
  static final ResilientApiClient _instance = ResilientApiClient._internal();
  factory ResilientApiClient() => _instance;
  ResilientApiClient._internal();

  // Rate limiting
  final Map<String, List<DateTime>> _requestLog = {};
  static const int _maxRequestsPerMinute = 100;

  // Request queue during high load
  final List<_QueuedRequest> _requestQueue = [];
  bool _isProcessingQueue = false;

  // Circuit breaker state
  _CircuitState _circuitState = _CircuitState.closed;
  DateTime? _circuitOpenTime;
  int _consecutiveFailures = 0;
  static const int _failureThreshold = 5;
  static const Duration _circuitResetDuration = Duration(seconds: 30);

  /// Execute query with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() queryFn, {
    String? operationName,
    int? maxRetries,
    bool shouldRetry = true,
  }) async {
    final retries = maxRetries ?? PerformanceConfig.maxRetryAttempts;

    // Check circuit breaker
    if (_circuitState == _CircuitState.open) {
      if (_shouldResetCircuit()) {
        _circuitState = _CircuitState.halfOpen;
      } else {
        throw Exception('Service temporarily unavailable (circuit open)');
      }
    }

    // Rate limiting check
    await _waitForRateLimit();

    int attempt = 0;
    Exception? lastException;

    while (attempt < retries) {
      try {
        _logRequest(operationName ?? 'query');

        final result = await queryFn();

        // Success - reset circuit breaker
        _onSuccess();

        return result;
      } catch (e) {
        lastException = e as Exception;
        attempt++;

        _onFailure();

        if (!shouldRetry || attempt >= retries) {
          break;
        }

        // Check if error is retryable
        if (!_isRetryableError(e)) {
          break;
        }

        // Exponential backoff
        final delay = _calculateBackoff(attempt);
        print(
            '⚠️ Retry $attempt/$retries for ${operationName ?? 'query'} in ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }

    throw lastException ?? Exception('Unknown error');
  }

  /// Execute query with rate limiting only (no retry)
  Future<T> executeWithRateLimit<T>(
    Future<T> Function() queryFn, {
    String? operationName,
  }) async {
    await _waitForRateLimit();
    _logRequest(operationName ?? 'query');
    return await queryFn();
  }

  /// Queue a request for later execution (during high load)
  Future<T> queueRequest<T>(
    Future<T> Function() queryFn, {
    String? operationName,
    int priority = 0,
  }) async {
    final completer = Completer<T>();

    _requestQueue.add(_QueuedRequest(
      execute: () async {
        try {
          final result =
              await executeWithRetry(queryFn, operationName: operationName);
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      },
      priority: priority,
    ));

    // Sort by priority
    _requestQueue.sort((a, b) => b.priority.compareTo(a.priority));

    // Start processing if not already
    _processQueue();

    return completer.future;
  }

  // Rate limiting helpers
  void _logRequest(String operation) {
    final now = DateTime.now();
    _requestLog.putIfAbsent(operation, () => []);
    _requestLog[operation]!.add(now);

    // Cleanup old entries
    final cutoff = now.subtract(Duration(minutes: 1));
    _requestLog[operation]!.removeWhere((t) => t.isBefore(cutoff));
  }

  Future<void> _waitForRateLimit() async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: 1));

    int totalRequests = 0;
    for (var times in _requestLog.values) {
      totalRequests += times.where((t) => t.isAfter(cutoff)).length;
    }

    if (totalRequests >= _maxRequestsPerMinute) {
      // Calculate wait time
      final oldestRequest = _requestLog.values
          .expand((x) => x)
          .where((t) => t.isAfter(cutoff))
          .reduce((a, b) => a.isBefore(b) ? a : b);

      final waitTime = oldestRequest.add(Duration(minutes: 1)).difference(now);

      if (waitTime.isNegative == false) {
        print('⏳ Rate limit reached, waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }
  }

  // Circuit breaker helpers
  void _onSuccess() {
    _consecutiveFailures = 0;
    if (_circuitState == _CircuitState.halfOpen) {
      _circuitState = _CircuitState.closed;
      print('✅ Circuit breaker closed');
    }
  }

  void _onFailure() {
    _consecutiveFailures++;

    if (_consecutiveFailures >= _failureThreshold) {
      _circuitState = _CircuitState.open;
      _circuitOpenTime = DateTime.now();
      print('🔴 Circuit breaker opened');
    }
  }

  bool _shouldResetCircuit() {
    if (_circuitOpenTime == null) return true;
    return DateTime.now().difference(_circuitOpenTime!) > _circuitResetDuration;
  }

  // Retry helpers
  Duration _calculateBackoff(int attempt) {
    final baseDelay = PerformanceConfig.initialRetryDelayMs;
    final multiplier = PerformanceConfig.retryDelayMultiplier;

    // Exponential backoff with jitter
    final delay = baseDelay * pow(multiplier, attempt - 1);
    final jitter = Random().nextInt(500); // Add 0-500ms jitter

    return Duration(milliseconds: delay.toInt() + jitter);
  }

  bool _isRetryableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Retry on network/server errors
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504') ||
        errorStr.contains('network')) {
      return true;
    }

    // Don't retry auth errors or client errors
    if (errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('400') ||
        errorStr.contains('404')) {
      return false;
    }

    return true;
  }

  // Queue processing
  void _processQueue() async {
    if (_isProcessingQueue || _requestQueue.isEmpty) return;

    _isProcessingQueue = true;

    while (_requestQueue.isNotEmpty) {
      final request = _requestQueue.removeAt(0);

      // Wait briefly between requests
      await Future.delayed(Duration(milliseconds: 50));

      await request.execute();
    }

    _isProcessingQueue = false;
  }

  /// Get API client status
  Map<String, dynamic> getStatus() {
    return {
      'circuit_state': _circuitState.toString(),
      'consecutive_failures': _consecutiveFailures,
      'queue_length': _requestQueue.length,
      'requests_last_minute': _requestLog.values
          .expand((x) => x)
          .where(
              (t) => t.isAfter(DateTime.now().subtract(Duration(minutes: 1))))
          .length,
    };
  }

  /// Reset client state
  void reset() {
    _requestLog.clear();
    _requestQueue.clear();
    _circuitState = _CircuitState.closed;
    _circuitOpenTime = null;
    _consecutiveFailures = 0;
    print('🔄 API client reset');
  }
}

enum _CircuitState { closed, open, halfOpen }

class _QueuedRequest {
  final Future<void> Function() execute;
  final int priority;

  _QueuedRequest({required this.execute, required this.priority});
}
