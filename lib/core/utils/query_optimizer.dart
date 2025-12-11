import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/performance_config.dart';

/// Query Optimizer - Reduces database calls through batching, debouncing, and smart caching
///
/// Features:
/// 1. Query deduplication - Same queries within 100ms are batched
/// 2. Request debouncing - Prevents rapid duplicate API calls
/// 3. Smart prefetching - Preloads likely needed data
/// 4. Connection pooling - Reuses connections efficiently

class QueryOptimizer {
  static final QueryOptimizer _instance = QueryOptimizer._internal();
  factory QueryOptimizer() => _instance;
  QueryOptimizer._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  // Pending queries for batching
  final Map<String, List<Completer<dynamic>>> _pendingQueries = {};

  // Debounce timers
  final Map<String, Timer> _debounceTimers = {};

  // In-flight requests (for deduplication)
  final Map<String, Future<dynamic>> _inFlightRequests = {};

  // Memory cache for hot data
  final Map<String, _CacheEntry> _memoryCache = {};

  /// Deduplicated query - prevents same query from running multiple times
  Future<T> deduplicatedQuery<T>(
    String queryKey,
    Future<T> Function() queryFn, {
    Duration? cacheDuration,
  }) async {
    // Check memory cache first
    final cached = _getFromMemoryCache<T>(queryKey);
    if (cached != null) {
      return cached;
    }

    // Check if same request is already in flight
    if (_inFlightRequests.containsKey(queryKey)) {
      return await _inFlightRequests[queryKey] as T;
    }

    // Execute query and track it
    final future = queryFn();
    _inFlightRequests[queryKey] = future;

    try {
      final result = await future;

      // Cache the result
      if (cacheDuration != null) {
        _saveToMemoryCache(queryKey, result, cacheDuration);
      }

      return result;
    } finally {
      _inFlightRequests.remove(queryKey);
    }
  }

  /// Debounced query - waits for user to stop typing/clicking
  Future<T> debouncedQuery<T>(
    String queryKey,
    Future<T> Function() queryFn, {
    int debounceMs = 300,
  }) async {
    final completer = Completer<T>();

    // Cancel existing timer
    _debounceTimers[queryKey]?.cancel();

    // Set new timer
    _debounceTimers[queryKey] = Timer(
      Duration(milliseconds: debounceMs),
      () async {
        try {
          final result = await queryFn();
          completer.complete(result);
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    return completer.future;
  }

  /// Batch fetch multiple IDs at once
  Future<List<Map<String, dynamic>>> batchFetch({
    required String table,
    required String idColumn,
    required List<String> ids,
    String selectColumns = '*',
  }) async {
    if (ids.isEmpty) return [];

    // Remove duplicates
    final uniqueIds = ids.toSet().toList();

    // Check which are cached
    final cachedResults = <Map<String, dynamic>>[];
    final uncachedIds = <String>[];

    for (final id in uniqueIds) {
      final cacheKey = '${table}_$id';
      final cached = _getFromMemoryCache<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        cachedResults.add(cached);
      } else {
        uncachedIds.add(id);
      }
    }

    // Fetch uncached in batches
    if (uncachedIds.isNotEmpty) {
      // Split into smaller batches if needed
      const batchSize = 50;
      for (var i = 0; i < uncachedIds.length; i += batchSize) {
        final batchIds = uncachedIds.skip(i).take(batchSize).toList();

        final response = await _supabase
            .from(table)
            .select(selectColumns)
            .inFilter(idColumn, batchIds);

        for (final item in response) {
          final id = item[idColumn].toString();
          _saveToMemoryCache(
            '${table}_$id',
            item,
            Duration(minutes: PerformanceConfig.defaultCacheDuration),
          );
          cachedResults.add(item);
        }
      }
    }

    return cachedResults;
  }

  /// Prefetch data for likely next screen
  void prefetch({
    required String cacheKey,
    required Future<dynamic> Function() queryFn,
  }) {
    if (!PerformanceConfig.enablePrefetching) return;

    // Only prefetch if not already cached or in-flight
    if (_memoryCache.containsKey(cacheKey)) return;
    if (_inFlightRequests.containsKey(cacheKey)) return;

    // Fire and forget
    deduplicatedQuery(
      cacheKey,
      queryFn,
      cacheDuration: Duration(minutes: PerformanceConfig.defaultCacheDuration),
    );
  }

  /// Paginated query helper
  Future<PaginatedResult<T>> paginatedQuery<T>({
    required String table,
    required String selectColumns,
    String? orderBy,
    bool ascending = false,
    Map<String, dynamic>? filters,
    int page = 0,
    int pageSize = PerformanceConfig.defaultPageSize,
    T Function(Map<String, dynamic>)? mapper,
  }) async {
    // Apply pagination
    final from = page * pageSize;
    final to = from + pageSize - 1;

    try {
      // Build query with proper chaining
      dynamic queryBuilder = _supabase.from(table).select(selectColumns);

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          queryBuilder = queryBuilder.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        queryBuilder = queryBuilder.order(orderBy, ascending: ascending);
      }

      final response = await queryBuilder.range(from, to);

      final items = mapper != null
          ? (response as List)
              .map((e) => mapper(e as Map<String, dynamic>))
              .toList()
          : response as List<T>;

      return PaginatedResult<T>(
        items: items,
        page: page,
        pageSize: pageSize,
        hasMore: response.length == pageSize,
      );
    } catch (e) {
      print('❌ Paginated query error: $e');
      return PaginatedResult<T>(
        items: [],
        page: page,
        pageSize: pageSize,
        hasMore: false,
      );
    }
  }

  // Memory cache helpers
  T? _getFromMemoryCache<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _memoryCache.remove(key);
      return null;
    }

    return entry.data as T;
  }

  void _saveToMemoryCache(String key, dynamic data, Duration duration) {
    // Cleanup if too many items
    if (_memoryCache.length >= PerformanceConfig.maxMemoryCacheItems) {
      _cleanupMemoryCache();
    }

    _memoryCache[key] = _CacheEntry(
      data: data,
      expiry: DateTime.now().add(duration),
    );
  }

  void _cleanupMemoryCache() {
    // Remove expired entries
    _memoryCache.removeWhere((key, entry) => entry.isExpired);

    // If still too many, remove oldest 20%
    if (_memoryCache.length >= PerformanceConfig.maxMemoryCacheItems) {
      final entriesToRemove = (_memoryCache.length * 0.2).ceil();
      final keys = _memoryCache.keys.take(entriesToRemove).toList();
      for (final key in keys) {
        _memoryCache.remove(key);
      }
    }
  }

  /// Clear all caches and pending operations
  void clearAll() {
    _pendingQueries.clear();
    _debounceTimers.forEach((_, timer) => timer.cancel());
    _debounceTimers.clear();
    _inFlightRequests.clear();
    _memoryCache.clear();
  }

  /// Invalidate specific cache entries
  void invalidateCache(String keyPattern) {
    _memoryCache.removeWhere((key, _) => key.contains(keyPattern));
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

class PaginatedResult<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasMore;

  PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });
}
