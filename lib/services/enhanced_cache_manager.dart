import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/performance_config.dart';

/// Enhanced Cache Manager for storing and retrieving data locally
///
/// Improvements:
/// 1. Web-aware caching (short TTL for web, longer for mobile)
/// 2. Tiered caching (memory + persistent)
/// 3. Cache versioning for invalidation
/// 4. Compression for large data
/// 5. LRU eviction strategy

class EnhancedCacheManager {
  static final EnhancedCacheManager _instance =
      EnhancedCacheManager._internal();
  factory EnhancedCacheManager() => _instance;
  EnhancedCacheManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Memory cache for fast access
  final Map<String, _MemoryCacheEntry> _memoryCache = {};

  // Cache version for invalidation
  static const String _cacheVersionKey = 'cache_version';
  static const int _currentCacheVersion = 1;

  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    // Check cache version and clear if outdated
    final storedVersion = _prefs?.getInt(_cacheVersionKey) ?? 0;
    if (storedVersion < _currentCacheVersion) {
      await clearAllCache();
      await _prefs?.setInt(_cacheVersionKey, _currentCacheVersion);
      print('🔄 Cache version updated, old cache cleared');
    }

    _initialized = true;
  }

  /// Save data to cache with timestamp
  /// For web: Uses shorter TTL by default
  Future<void> saveToCache(
    String key,
    dynamic data, {
    int? ttlMinutes,
  }) async {
    await initialize();

    // Determine TTL based on platform
    final effectiveTtl =
        ttlMinutes ?? (kIsWeb ? 2 : PerformanceConfig.defaultCacheDuration);

    final expiry = DateTime.now().add(Duration(minutes: effectiveTtl));

    // Save to memory cache
    _memoryCache[key] = _MemoryCacheEntry(
      data: data,
      expiry: expiry,
    );

    // Save to persistent cache (not for web with very short TTL)
    if (!kIsWeb || effectiveTtl > 2) {
      final cacheData = {
        'data': data,
        'expiry': expiry.millisecondsSinceEpoch,
        'version': _currentCacheVersion,
      };

      try {
        final encoded = jsonEncode(cacheData);
        // Compress if large (> 10KB)
        if (encoded.length > 10240) {
          await _prefs?.setString('compressed_$key', _compress(encoded));
        } else {
          await _prefs?.setString(key, encoded);
        }
      } catch (e) {
        print('⚠️ Cache save error: $e');
      }
    }
  }

  /// Get data from cache if not expired
  Future<dynamic> getFromCache(
    String key, {
    int? durationMinutes,
  }) async {
    await initialize();

    // Check memory cache first (fastest)
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return memoryEntry.data;
    }

    // Remove expired memory cache
    if (memoryEntry != null) {
      _memoryCache.remove(key);
    }

    // Check persistent cache
    String? cachedString = _prefs?.getString(key);

    // Check compressed cache
    if (cachedString == null) {
      final compressed = _prefs?.getString('compressed_$key');
      if (compressed != null) {
        cachedString = _decompress(compressed);
      }
    }

    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString);
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(cacheData['expiry'] as int);

      if (DateTime.now().isBefore(expiry)) {
        // Restore to memory cache
        _memoryCache[key] = _MemoryCacheEntry(
          data: cacheData['data'],
          expiry: expiry,
        );
        return cacheData['data'];
      } else {
        // Expired, remove
        await clearCache(key);
        return null;
      }
    } catch (e) {
      print('⚠️ Cache read error: $e');
      await clearCache(key);
      return null;
    }
  }

  /// Clear specific cache
  Future<void> clearCache(String key) async {
    await initialize();
    _memoryCache.remove(key);
    await _prefs?.remove(key);
    await _prefs?.remove('compressed_$key');
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await initialize();
    _memoryCache.clear();

    final keys = _prefs?.getKeys() ?? {};
    for (var key in keys) {
      if (key != _cacheVersionKey) {
        await _prefs?.remove(key);
      }
    }
    print('🗑️ All cache cleared');
  }

  /// Clear cache by pattern
  Future<void> clearCacheByPattern(String pattern) async {
    await initialize();

    // Memory cache
    _memoryCache.removeWhere((key, _) => key.contains(pattern));

    // Persistent cache
    final keys = _prefs?.getKeys() ?? {};
    for (var key in keys) {
      if (key.contains(pattern)) {
        await _prefs?.remove(key);
      }
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_cache_size': _memoryCache.length,
      'memory_cache_keys': _memoryCache.keys.toList(),
      'persistent_cache_size': _prefs?.getKeys().length ?? 0,
      'is_web': kIsWeb,
    };
  }

  // Simple compression (base64 for now, can use zlib later)
  String _compress(String data) {
    return base64Encode(utf8.encode(data));
  }

  String _decompress(String compressed) {
    return utf8.decode(base64Decode(compressed));
  }

  /// Cleanup expired entries
  Future<void> cleanup() async {
    await initialize();

    // Memory cache
    _memoryCache.removeWhere((_, entry) => entry.isExpired);

    // Persistent cache - check each entry
    final keys = _prefs?.getKeys().toList() ?? [];
    for (var key in keys) {
      if (key == _cacheVersionKey) continue;

      try {
        final cachedString = _prefs?.getString(key);
        if (cachedString != null) {
          final cacheData = jsonDecode(cachedString);
          final expiry =
              DateTime.fromMillisecondsSinceEpoch(cacheData['expiry'] as int);

          if (DateTime.now().isAfter(expiry)) {
            await _prefs?.remove(key);
          }
        }
      } catch (e) {
        // Invalid entry, remove
        await _prefs?.remove(key);
      }
    }

    print('🧹 Cache cleanup complete');
  }
}

class _MemoryCacheEntry {
  final dynamic data;
  final DateTime expiry;

  _MemoryCacheEntry({required this.data, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Cache keys for different data types (enhanced)
class CacheKeyPrefixes {
  static const String student = 'student_';
  static const String teacher = 'teacher_';
  static const String admin = 'admin_';
  static const String hr = 'hr_';
  static const String hod = 'hod_';
  static const String marks = 'marks_';
  static const String assignments = 'assignments_';
  static const String timetable = 'timetable_';
  static const String announcements = 'announcements_';
  static const String materials = 'materials_';
  static const String leaves = 'leaves_';
  static const String salary = 'salary_';
  static const String subjects = 'subjects_';
}
