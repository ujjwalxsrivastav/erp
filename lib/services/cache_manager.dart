import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Cache Manager for storing and retrieving data locally
/// Reduces backend load and improves app performance
/// Note: Caching is disabled for web to ensure real-time data
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Clear all cache on web platform to ensure fresh data
    if (kIsWeb) {
      await clearAllCache();
      print('🌐 Web platform: All cache cleared for fresh data');
    }
  }

  /// Cache duration in minutes
  static const int _cacheDuration = 5; // 5 minutes default

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

  /// Get data from cache if not expired
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
      final duration = durationMinutes ?? _cacheDuration;

      // Check if cache is still valid
      if (now - timestamp < duration * 60 * 1000) {
        print(
            '✅ Cache hit: $key (${((now - timestamp) / 1000 / 60).toStringAsFixed(1)} min old)');
        return cacheData['data'];
      } else {
        print('⏰ Cache expired: $key');
        await clearCache(key);
        return null;
      }
    } catch (e) {
      print('❌ Cache error: $e');
      await clearCache(key);
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
}
