import 'dart:async';

/// Pagination configuration and utilities
class PaginationConfig {
  /// Default page size
  static const int defaultPageSize = 25;

  /// Large list page size (for admin views)
  static const int largePageSize = 50;

  /// Maximum items per page
  static const int maxPageSize = 100;
}

/// Pagination state for UI
class PaginationState<T> {
  final List<T> items;
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  PaginationState({
    this.items = const [],
    this.currentPage = 0,
    this.totalItems = 0,
    this.pageSize = PaginationConfig.defaultPageSize,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  int get totalPages => (totalItems / pageSize).ceil();
  bool get isEmpty => items.isEmpty && !isLoading;
  bool get isFirstPage => currentPage == 0;
  bool get isLastPage => !hasMore;

  PaginationState<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalItems,
    int? pageSize,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalItems: totalItems ?? this.totalItems,
      pageSize: pageSize ?? this.pageSize,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// Debouncer for rate limiting user actions
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttler for preventing rapid repeated calls
class Throttler {
  final Duration cooldown;
  DateTime? _lastCall;

  Throttler({this.cooldown = const Duration(seconds: 1)});

  bool canCall() {
    final now = DateTime.now();
    if (_lastCall == null || now.difference(_lastCall!) > cooldown) {
      _lastCall = now;
      return true;
    }
    return false;
  }

  Future<T?> throttle<T>(Future<T> Function() action) async {
    if (canCall()) {
      return await action();
    }
    print('⏳ Throttled: Please wait before trying again');
    return null;
  }
}

/// Request Rate Limiter - limits requests per time window
class RateLimiter {
  final int maxRequests;
  final Duration window;
  final List<DateTime> _requestTimes = [];

  RateLimiter({
    this.maxRequests = 30,
    this.window = const Duration(minutes: 1),
  });

  bool canMakeRequest() {
    final now = DateTime.now();
    // Remove old requests outside the window
    _requestTimes.removeWhere((time) => now.difference(time) > window);

    if (_requestTimes.length < maxRequests) {
      _requestTimes.add(now);
      return true;
    }
    return false;
  }

  Future<T?> execute<T>(Future<T> Function() action) async {
    if (canMakeRequest()) {
      return await action();
    }
    print(
        '🚫 Rate limit exceeded. Max $maxRequests requests per ${window.inSeconds}s');
    return null;
  }

  int get remainingRequests => maxRequests - _requestTimes.length;

  Duration? get timeUntilNextSlot {
    if (_requestTimes.isEmpty) return null;
    final oldest = _requestTimes.first;
    final resetTime = oldest.add(window);
    final now = DateTime.now();
    if (resetTime.isAfter(now)) {
      return resetTime.difference(now);
    }
    return null;
  }
}
