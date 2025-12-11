import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_manager.dart';

/// Service to handle offline/online state detection and management
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  final _cache = CacheManager();

  /// Stream controller for connectivity changes
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool _isOnline = true;
  Timer? _connectivityCheckTimer;

  /// Check if currently online
  bool get isOnline => _isOnline;

  /// Initialize the offline service
  void initialize() {
    // Start periodic connectivity checks
    _startConnectivityMonitor();
    // Do an initial check
    checkConnectivity();
  }

  /// Start periodic connectivity monitoring
  void _startConnectivityMonitor() {
    _connectivityCheckTimer?.cancel();
    _connectivityCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnectivity(),
    );
  }

  /// Stop connectivity monitoring
  void dispose() {
    _connectivityCheckTimer?.cancel();
    _connectivityController.close();
  }

  /// Check if we can reach Supabase
  Future<bool> checkConnectivity() async {
    try {
      // Try a simple query to check connectivity
      await Supabase.instance.client
          .from('users')
          .select('username')
          .limit(1)
          .timeout(const Duration(seconds: 5));

      if (!_isOnline) {
        print('📶 Back online!');
        _isOnline = true;
        _cache.setOfflineMode(false);
        _connectivityController.add(true);
      }
      return true;
    } catch (e) {
      if (_isOnline) {
        print('📴 Gone offline: $e');
        _isOnline = false;
        _cache.setOfflineMode(true);
        _connectivityController.add(false);
      }
      return false;
    }
  }

  /// Execute a query with offline fallback
  /// If online: fetches fresh data and caches it
  /// If offline: returns cached data
  Future<T?> executeWithOfflineFallback<T>({
    required Future<T> Function() onlineQuery,
    required String cacheKey,
    T Function(dynamic cached)? fromCache,
    T? defaultValue,
  }) async {
    // Check if we're online
    final online = await checkConnectivity();

    if (online) {
      try {
        // Try to fetch fresh data
        final result = await onlineQuery();
        // Cache the result
        await _cache.saveToCache(cacheKey, result);
        return result;
      } catch (e) {
        print('⚠️ Online query failed, trying cache: $e');
        // Fall through to offline fallback
      }
    }

    // Try to get cached data
    final cached = await _cache.getOfflineFallback(cacheKey);
    if (cached != null) {
      if (fromCache != null) {
        return fromCache(cached);
      }
      return cached as T?;
    }

    return defaultValue;
  }

  /// Execute a list query with offline fallback
  Future<List<Map<String, dynamic>>> executeListWithOfflineFallback({
    required Future<List<dynamic>> Function() onlineQuery,
    required String cacheKey,
  }) async {
    final result = await executeWithOfflineFallback<List<dynamic>>(
      onlineQuery: onlineQuery,
      cacheKey: cacheKey,
      fromCache: (cached) => List<dynamic>.from(cached),
    );

    if (result == null) return [];
    return List<Map<String, dynamic>>.from(result);
  }
}

/// Widget to show offline indicator banner
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineService().connectivityStream,
      initialData: OfflineService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        return Column(
          children: [
            // Offline banner
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isOnline ? 0 : 36,
              child: isOnline
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      color: Colors.orange[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'You\'re offline - showing cached data',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Mixin for stateful widgets that need offline support
mixin OfflineAwareMixin<T extends StatefulWidget> on State<T> {
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOffline = false;

  bool get isOffline => _isOffline;

  @override
  void initState() {
    super.initState();
    _isOffline = !OfflineService().isOnline;
    _connectivitySubscription = OfflineService().connectivityStream.listen(
      (isOnline) {
        if (mounted) {
          setState(() {
            _isOffline = !isOnline;
          });
          if (isOnline) {
            onBackOnline();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  /// Called when connectivity is restored - override to refresh data
  void onBackOnline() {
    // Override in subclass to refresh data
  }
}
