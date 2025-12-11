import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-capable Cache Manager for storing and retrieving data locally
/// - Works offline: Returns cached data even when expired if no network
/// - Reduces backend load and improves app performance
/// - Note: Caching is disabled for web to ensure real-time data
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;

  /// Offline mode flag - when true, returns expired cache data
  bool _isOffline = false;

  /// Set offline mode
  void setOfflineMode(bool offline) {
    _isOffline = offline;
    print(_isOffline ? '📴 Offline mode enabled' : '📶 Online mode enabled');
  }

  /// Check if in offline mode
  bool get isOffline => _isOffline;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Clear all cache on web platform to ensure fresh data
    if (kIsWeb) {
      await clearAllCache();
      print('🌐 Web platform: All cache cleared for fresh data');
    }
  }

  /// Cache duration in minutes (online mode)
  static const int _cacheDuration = 5; // 5 minutes default

  /// Offline cache duration in hours
  static const int _offlineCacheDurationHours = 24; // 24 hours for offline

  /// Save data to cache with timestamp
  Future<void> saveToCache(String key, dynamic data) async {
    // Disable caching for web
    if (kIsWeb) {
      print('ℹ️ Caching disabled for web platform');
      return;
    }

    await initialize();
    final cacheData = {
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _prefs?.setString(key, jsonEncode(cacheData));
    print('✅ Cached: $key');
  }

  /// Get data from cache
  /// - In online mode: Returns data only if not expired (5 min default)
  /// - In offline mode: Returns data even if expired (up to 24 hours)
  Future<dynamic> getFromCache(String key, {int? durationMinutes}) async {
    // Disable caching for web - always return null to fetch fresh data
    if (kIsWeb) {
      print('ℹ️ Web platform: Fetching fresh data (cache disabled)');
      return null;
    }

    await initialize();
    final cachedString = _prefs?.getString(key);

    if (cachedString == null) {
      print('❌ Cache miss: $key');
      return null;
    }

    try {
      final cacheData = jsonDecode(cachedString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ageInMinutes = (now - timestamp) / 1000 / 60;

      // Online mode: Use normal duration
      if (!_isOffline) {
        final duration = durationMinutes ?? _cacheDuration;
        if (ageInMinutes < duration) {
          print(
              '✅ Cache hit: $key (${ageInMinutes.toStringAsFixed(1)} min old)');
          return cacheData['data'];
        } else {
          print('⏰ Cache expired: $key');
          // Don't clear - keep for offline use
          return null;
        }
      }

      // Offline mode: Accept older cached data
      final maxOfflineMinutes = _offlineCacheDurationHours * 60;
      if (ageInMinutes < maxOfflineMinutes) {
        print(
            '📴 Offline cache hit: $key (${ageInMinutes.toStringAsFixed(1)} min old)');
        return cacheData['data'];
      } else {
        print(
            '⏰ Offline cache too old: $key (${(ageInMinutes / 60).toStringAsFixed(1)} hours)');
        return null;
      }
    } catch (e) {
      print('❌ Cache error: $e');
      return null;
    }
  }

  /// Get data from cache ignoring expiry (for offline fallback)
  /// Use this when online fetch fails
  Future<dynamic> getOfflineFallback(String key) async {
    if (kIsWeb) return null;

    await initialize();
    final cachedString = _prefs?.getString(key);

    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      final ageInMinutes = (now - timestamp) / 1000 / 60;

      // Accept any cached data up to 24 hours old
      if (ageInMinutes < _offlineCacheDurationHours * 60) {
        print(
            '📴 Using offline fallback: $key (${ageInMinutes.toStringAsFixed(1)} min old)');
        return cacheData['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Clear specific cache
  Future<void> clearCache(String key) async {
    await initialize();
    await _prefs?.remove(key);
    print('🗑️ Cleared cache: $key');
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    await initialize();
    final keys = _prefs?.getKeys() ?? {};
    for (var key in keys) {
      if (key.startsWith('cache_')) {
        await _prefs?.remove(key);
      }
    }
    print('🗑️ Cleared all cache');
  }

  /// Check if cache exists and is valid
  Future<bool> isCacheValid(String key, {int? durationMinutes}) async {
    final data = await getFromCache(key, durationMinutes: durationMinutes);
    return data != null;
  }

  /// Check if any cached data exists (even expired)
  Future<bool> hasCachedData(String key) async {
    await initialize();
    return _prefs?.containsKey(key) ?? false;
  }

  /// Get cache age in minutes
  Future<double?> getCacheAge(String key) async {
    await initialize();
    final cachedString = _prefs?.getString(key);

    if (cachedString == null) return null;

    try {
      final cacheData = jsonDecode(cachedString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      return (now - timestamp) / 1000 / 60; // Return age in minutes
    } catch (e) {
      return null;
    }
  }

  /// Get all cached keys
  Future<List<String>> getAllCacheKeys() async {
    await initialize();
    final keys = _prefs?.getKeys() ?? {};
    return keys.where((key) => key.startsWith('cache_')).toList();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await initialize();
    final keys = await getAllCacheKeys();
    int validCount = 0;
    int expiredCount = 0;

    for (var key in keys) {
      final age = await getCacheAge(key);
      if (age != null && age < _cacheDuration) {
        validCount++;
      } else {
        expiredCount++;
      }
    }

    return {
      'totalKeys': keys.length,
      'validKeys': validCount,
      'expiredKeys': expiredCount,
    };
  }
}

/// Cache keys for different data types
class CacheKeys {
  static String studentDetails(String studentId) => 'cache_student_$studentId';
  static String studentMarks(String studentId) => 'cache_marks_$studentId';
  static String studentAssignments(String studentId) =>
      'cache_assignments_$studentId';
  static String studentAnnouncements(String studentId) =>
      'cache_announcements_$studentId';
  static String studyMaterials(String studentId) =>
      'cache_materials_$studentId';
  static String timetable(String studentId) => 'cache_timetable_$studentId';
  static String upcomingClasses(String studentId) => 'cache_classes_$studentId';
  static String teacherAssignments(String teacherId) =>
      'cache_teacher_assignments_$teacherId';
  static String submissions(String assignmentId) =>
      'cache_submissions_$assignmentId';
  static String teacherDetails(String teacherId) => 'cache_teacher_$teacherId';
  static String staffList() => 'cache_staff_list';
  static String studentList() => 'cache_student_list';
}
