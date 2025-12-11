import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/performance_config.dart';

/// Real-time Subscription Manager
///
/// Optimizes real-time connections by:
/// 1. Limiting max concurrent subscriptions
/// 2. Deduplicating same subscriptions
/// 3. Auto-cleanup of inactive subscriptions
/// 4. Connection health monitoring

class RealtimeManager {
  static final RealtimeManager _instance = RealtimeManager._internal();
  factory RealtimeManager() => _instance;
  RealtimeManager._internal();

  // Lazy access to Supabase client - prevents crash if accessed before initialization
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _initialized = false;

  // Active subscriptions tracker
  final Map<String, _SubscriptionEntry> _activeSubscriptions = {};

  // Subscription reference counts (for shared subscriptions)
  final Map<String, int> _subscriptionRefCounts = {};

  // Health check timer
  Timer? _healthCheckTimer;

  /// Initialize realtime manager
  void initialize() {
    if (_initialized) return;
    if (!PerformanceConfig.enableRealtime) return;

    try {
      // Start health check timer
      _healthCheckTimer = Timer.periodic(
        Duration(seconds: PerformanceConfig.realtimeHeartbeatSeconds),
        (_) => _checkHealth(),
      );
      _initialized = true;
      print('✅ RealtimeManager initialized');
    } catch (e) {
      print('⚠️ RealtimeManager initialization error: $e');
    }
  }

  /// Subscribe to a table with automatic deduplication
  Stream<List<Map<String, dynamic>>> subscribe({
    required String table,
    required List<String> primaryKey,
    Map<String, dynamic>? filter,
    String? subscriptionKey,
  }) {
    if (!PerformanceConfig.enableRealtime) {
      return const Stream.empty();
    }

    final key = subscriptionKey ?? _generateKey(table, filter);

    // Check if subscription already exists
    if (_activeSubscriptions.containsKey(key)) {
      _subscriptionRefCounts[key] = (_subscriptionRefCounts[key] ?? 1) + 1;
      return _activeSubscriptions[key]!.controller.stream;
    }

    // Check max subscription limit
    if (_activeSubscriptions.length >=
        PerformanceConfig.maxRealtimeSubscriptions) {
      print('⚠️ Max realtime subscriptions reached, cleaning up...');
      _cleanupLeastUsed();
    }

    // Create new subscription
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    var queryBuilder = _supabase.from(table).stream(primaryKey: primaryKey);

    // Apply filter using the builder pattern
    late Stream<List<Map<String, dynamic>>> stream;
    if (filter != null && filter.isNotEmpty) {
      // For single filter, use eq
      final entry = filter.entries.first;
      stream = queryBuilder.eq(entry.key, entry.value);
    } else {
      stream = queryBuilder;
    }

    final subscription = stream.listen(
      (data) {
        controller.add(List<Map<String, dynamic>>.from(data));
        _activeSubscriptions[key]?.lastActivity = DateTime.now();
      },
      onError: (error) {
        print('❌ Realtime error for $key: $error');
        controller.addError(error);
      },
    );

    _activeSubscriptions[key] = _SubscriptionEntry(
      subscription: subscription,
      controller: controller,
      table: table,
      createdAt: DateTime.now(),
      lastActivity: DateTime.now(),
    );
    _subscriptionRefCounts[key] = 1;

    print('✅ Created realtime subscription: $key');

    return controller.stream;
  }

  /// Unsubscribe from a stream
  void unsubscribe(String key) {
    final refCount = _subscriptionRefCounts[key] ?? 0;

    if (refCount <= 1) {
      // Actually unsubscribe
      _activeSubscriptions[key]?.subscription.cancel();
      _activeSubscriptions[key]?.controller.close();
      _activeSubscriptions.remove(key);
      _subscriptionRefCounts.remove(key);
      print('🔌 Unsubscribed: $key');
    } else {
      // Just decrease ref count
      _subscriptionRefCounts[key] = refCount - 1;
    }
  }

  /// Unsubscribe from table subscriptions by table name
  void unsubscribeTable(String table) {
    final keysToRemove = _activeSubscriptions.entries
        .where((e) => e.value.table == table)
        .map((e) => e.key)
        .toList();

    for (final key in keysToRemove) {
      _activeSubscriptions[key]?.subscription.cancel();
      _activeSubscriptions[key]?.controller.close();
      _activeSubscriptions.remove(key);
      _subscriptionRefCounts.remove(key);
    }

    print('🔌 Unsubscribed all $table subscriptions');
  }

  /// Pause all subscriptions (for background/inactive state)
  void pauseAll() {
    for (final entry in _activeSubscriptions.values) {
      entry.subscription.pause();
    }
    print('⏸️ Paused all realtime subscriptions');
  }

  /// Resume all subscriptions
  void resumeAll() {
    for (final entry in _activeSubscriptions.values) {
      entry.subscription.resume();
    }
    print('▶️ Resumed all realtime subscriptions');
  }

  /// Cleanup all subscriptions
  void dispose() {
    _healthCheckTimer?.cancel();

    for (final entry in _activeSubscriptions.values) {
      entry.subscription.cancel();
      entry.controller.close();
    }

    _activeSubscriptions.clear();
    _subscriptionRefCounts.clear();

    print('🧹 Disposed all realtime subscriptions');
  }

  // Generate unique key for subscription
  String _generateKey(String table, Map<String, dynamic>? filter) {
    final filterStr =
        filter?.entries.map((e) => '${e.key}=${e.value}').join('_') ?? '';
    return '${table}_$filterStr';
  }

  // Cleanup least used subscriptions when limit reached
  void _cleanupLeastUsed() {
    if (_activeSubscriptions.isEmpty) return;

    // Sort by last activity and remove oldest
    final sorted = _activeSubscriptions.entries.toList()
      ..sort((a, b) => a.value.lastActivity.compareTo(b.value.lastActivity));

    // Remove oldest 20%
    final toRemove = (sorted.length * 0.2).ceil().clamp(1, sorted.length);

    for (var i = 0; i < toRemove; i++) {
      final key = sorted[i].key;
      unsubscribe(key);
    }
  }

  // Health check for stale subscriptions
  void _checkHealth() {
    final now = DateTime.now();
    final staleThreshold = Duration(minutes: 30);

    final staleKeys = _activeSubscriptions.entries
        .where((e) => now.difference(e.value.lastActivity) > staleThreshold)
        .map((e) => e.key)
        .toList();

    for (final key in staleKeys) {
      print('🧹 Cleaning up stale subscription: $key');
      unsubscribe(key);
    }
  }

  /// Get subscription stats
  Map<String, dynamic> getStats() {
    return {
      'active_subscriptions': _activeSubscriptions.length,
      'max_subscriptions': PerformanceConfig.maxRealtimeSubscriptions,
      'subscriptions': _activeSubscriptions.entries
          .map((e) => {
                'key': e.key,
                'table': e.value.table,
                'age_minutes':
                    DateTime.now().difference(e.value.createdAt).inMinutes,
                'ref_count': _subscriptionRefCounts[e.key] ?? 0,
              })
          .toList(),
    };
  }
}

class _SubscriptionEntry {
  final StreamSubscription subscription;
  final StreamController<List<Map<String, dynamic>>> controller;
  final String table;
  final DateTime createdAt;
  DateTime lastActivity;

  _SubscriptionEntry({
    required this.subscription,
    required this.controller,
    required this.table,
    required this.createdAt,
    required this.lastActivity,
  });
}
