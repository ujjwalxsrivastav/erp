import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/performance_config.dart';
import '../core/utils/query_optimizer.dart';
import '../core/utils/realtime_manager.dart';
import 'cache_manager.dart';

/// Optimized Student Service
///
/// Improvements over original:
/// 1. Batch fetching for related data (eliminates N+1 queries)
/// 2. Query deduplication
/// 3. Smarter caching with configurable TTLs
/// 4. Pagination support for large lists
/// 5. Prefetching for anticipated data needs

class OptimizedStudentService {
  static final OptimizedStudentService _instance =
      OptimizedStudentService._internal();
  factory OptimizedStudentService() => _instance;
  OptimizedStudentService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final _cache = CacheManager();
  final _queryOptimizer = QueryOptimizer();
  final _realtimeManager = RealtimeManager();

  // ============================================
  // STUDENT DETAILS
  // ============================================

  /// Get student details with caching and deduplication
  Future<Map<String, dynamic>?> getStudentDetails(String studentId) async {
    final cacheKey = '${CacheKeyPrefixes.student}details_$studentId';

    return await _queryOptimizer.deduplicatedQuery<Map<String, dynamic>?>(
      cacheKey,
      () async {
        // Check persistent cache first
        final cachedData = await _cache.getFromCache(
          cacheKey,
          durationMinutes: PerformanceConfig.profileCacheDuration,
        );

        if (cachedData != null) {
          return Map<String, dynamic>.from(cachedData);
        }

        final response = await _supabase
            .from('student_details')
            .select()
            .eq('student_id', studentId)
            .maybeSingle();

        if (response != null) {
          await _cache.saveToCache(cacheKey, response);
        }

        return response;
      },
      cacheDuration: Duration(minutes: PerformanceConfig.profileCacheDuration),
    );
  }

  // ============================================
  // MARKS - OPTIMIZED (Fixed N+1 Query Problem)
  // ============================================

  /// Get student marks with batch subject fetching
  Future<List<Map<String, dynamic>>> getStudentMarks(String studentId) async {
    final cacheKey = '${CacheKeyPrefixes.marks}$studentId';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        // Check cache
        final cachedData = await _cache.getFromCache(
          cacheKey,
          durationMinutes: PerformanceConfig.marksCacheDuration,
        );

        if (cachedData != null) {
          return List<Map<String, dynamic>>.from(cachedData);
        }

        // Get student details for year/section
        final studentDetails = await getStudentDetails(studentId);
        if (studentDetails == null) return [];

        final year = studentDetails['year'];
        final section = studentDetails['section'];

        final examTypes = ['Mid Term', 'End Semester', 'Quiz', 'Assignment'];
        List<Map<String, dynamic>> allMarks = [];
        Set<String> subjectIds = {};

        // Fetch marks from all exam tables
        for (final examType in examTypes) {
          try {
            final tableName =
                _getMarksTableName(year.toString(), section, examType);

            final response = await _supabase
                .from(tableName)
                .select('*')
                .eq('student_id', studentId)
                .order('uploaded_at', ascending: false);

            for (var mark in response) {
              mark['exam_type'] = examType;
              if (mark['subject_id'] != null) {
                subjectIds.add(mark['subject_id'].toString());
              }
              allMarks.add(Map<String, dynamic>.from(mark));
            }
          } catch (e) {
            // Table might not exist, continue
          }
        }

        // BATCH FETCH all subjects at once (fixes N+1 problem)
        if (subjectIds.isNotEmpty) {
          final subjects = await _queryOptimizer.batchFetch(
            table: 'subjects',
            idColumn: 'subject_id',
            ids: subjectIds.toList(),
            selectColumns: 'subject_id, subject_name',
          );

          // Create lookup map
          final subjectMap = {
            for (var s in subjects) s['subject_id'].toString(): s
          };

          // Enrich marks with subject data
          for (var mark in allMarks) {
            final subjectId = mark['subject_id']?.toString();
            if (subjectId != null && subjectMap.containsKey(subjectId)) {
              mark['subjects'] = subjectMap[subjectId];
            }
          }
        }

        // Cache result
        await _cache.saveToCache(cacheKey, allMarks);

        return allMarks;
      },
      cacheDuration: Duration(minutes: PerformanceConfig.marksCacheDuration),
    );
  }

  // ============================================
  // ASSIGNMENTS - OPTIMIZED
  // ============================================

  /// Get assignments with pagination
  Future<List<Map<String, dynamic>>> getStudentAssignments(
    String studentId, {
    int page = 0,
    int pageSize = PerformanceConfig.defaultPageSize,
  }) async {
    final cacheKey =
        '${CacheKeyPrefixes.assignments}student_${studentId}_$page';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        // Get enrolled subjects first
        final subjects = await _supabase
            .from('student_subjects')
            .select('subject_id')
            .eq('student_id', studentId);

        final subjectIds =
            (subjects as List).map((s) => s['subject_id']).toList();
        if (subjectIds.isEmpty) return [];

        // Fetch assignments with pagination
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final response = await _supabase
            .from('assignments')
            .select('*, subjects(subject_name), teacher_details(name)')
            .inFilter('subject_id', subjectIds)
            .order('created_at', ascending: false)
            .range(from, to);

        return List<Map<String, dynamic>>.from(response);
      },
      cacheDuration: Duration(minutes: PerformanceConfig.defaultCacheDuration),
    );
  }

  // ============================================
  // TIMETABLE - OPTIMIZED
  // ============================================

  /// Get timetable with longer cache (static data)
  Future<List<Map<String, dynamic>>> getTimetable(String studentId) async {
    final cacheKey = '${CacheKeyPrefixes.timetable}$studentId';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        // Check cache with longer TTL
        final cachedData = await _cache.getFromCache(
          cacheKey,
          durationMinutes: PerformanceConfig.staticDataCacheDuration,
        );

        if (cachedData != null) {
          return List<Map<String, dynamic>>.from(cachedData);
        }

        // Get enrolled subjects
        final subjects = await _supabase
            .from('student_subjects')
            .select('subject_id')
            .eq('student_id', studentId);

        if (subjects.isEmpty) return [];

        final subjectIds =
            (subjects as List).map((s) => s['subject_id']).toList();

        // Fetch timetable with all related data in single query
        final response = await _supabase
            .from('timetable')
            .select('*, subjects(subject_name), teacher_details(name)')
            .inFilter('subject_id', subjectIds)
            .order('day_of_week')
            .order('start_time');

        final timetable = List<Map<String, dynamic>>.from(response);

        // Cache with longer TTL
        await _cache.saveToCache(cacheKey, timetable);

        return timetable;
      },
      cacheDuration:
          Duration(minutes: PerformanceConfig.staticDataCacheDuration),
    );
  }

  // ============================================
  // STUDY MATERIALS - OPTIMIZED WITH BATCH FETCH
  // ============================================

  /// Get study materials with batch enrichment
  Future<List<Map<String, dynamic>>> getStudyMaterials(
    String studentId, {
    int page = 0,
    int pageSize = PerformanceConfig.defaultPageSize,
  }) async {
    final cacheKey = '${CacheKeyPrefixes.materials}$studentId\_$page';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final studentDetails = await getStudentDetails(studentId);
        if (studentDetails == null) return [];

        final year = studentDetails['year'].toString();
        final section = studentDetails['section'];

        // Get student subjects
        final subjects = await _supabase
            .from('student_subjects')
            .select('subject_id')
            .eq('student_id', studentId);

        final subjectIds =
            (subjects as List).map((s) => s['subject_id']).toList();
        if (subjectIds.isEmpty) return [];

        // Fetch materials with pagination
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final materials = await _supabase
            .from('study_materials')
            .select()
            .inFilter('subject_id', subjectIds)
            .eq('year', year)
            .eq('section', section)
            .order('created_at', ascending: false)
            .range(from, to);

        if (materials.isEmpty) return [];

        // Collect IDs for batch fetching
        final materialSubjectIds = <String>{};
        final teacherIds = <String>{};

        for (var m in materials) {
          if (m['subject_id'] != null)
            materialSubjectIds.add(m['subject_id'].toString());
          if (m['teacher_id'] != null)
            teacherIds.add(m['teacher_id'].toString());
        }

        // BATCH FETCH subjects and teachers
        final [subjectData, teacherData] = await Future.wait([
          _queryOptimizer.batchFetch(
            table: 'subjects',
            idColumn: 'subject_id',
            ids: materialSubjectIds.toList(),
            selectColumns: 'subject_id, subject_name',
          ),
          _queryOptimizer.batchFetch(
            table: 'teacher_details',
            idColumn: 'teacher_id',
            ids: teacherIds.toList(),
            selectColumns: 'teacher_id, name',
          ),
        ]);

        // Create lookup maps
        final subjectMap = {
          for (var s in subjectData) s['subject_id'].toString(): s
        };
        final teacherMap = {
          for (var t in teacherData) t['teacher_id'].toString(): t
        };

        // Enrich materials
        final enriched = <Map<String, dynamic>>[];
        for (var material in materials) {
          final enrichedMaterial = Map<String, dynamic>.from(material);

          final subjectId = material['subject_id']?.toString();
          final teacherId = material['teacher_id']?.toString();

          if (subjectId != null && subjectMap.containsKey(subjectId)) {
            enrichedMaterial['subjects'] = subjectMap[subjectId];
          }
          if (teacherId != null && teacherMap.containsKey(teacherId)) {
            enrichedMaterial['teacher_details'] = teacherMap[teacherId];
          }

          enriched.add(enrichedMaterial);
        }

        return enriched;
      },
      cacheDuration: Duration(minutes: PerformanceConfig.defaultCacheDuration),
    );
  }

  // ============================================
  // ANNOUNCEMENTS - OPTIMIZED
  // ============================================

  /// Get announcements with short cache (time-sensitive)
  Future<List<Map<String, dynamic>>> getAnnouncements(
    String studentId, {
    int page = 0,
    int pageSize = PerformanceConfig.defaultPageSize,
  }) async {
    final cacheKey = '${CacheKeyPrefixes.announcements}$studentId\_$page';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final studentDetails = await getStudentDetails(studentId);
        if (studentDetails == null) return [];

        final year = studentDetails['year'].toString();
        final section = studentDetails['section'];

        // Get student subjects
        final subjects = await _supabase
            .from('student_subjects')
            .select('subject_id')
            .eq('student_id', studentId);

        final subjectIds =
            (subjects as List).map((s) => s['subject_id']).toList();
        if (subjectIds.isEmpty) return [];

        // Fetch with pagination
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final announcements = await _supabase
            .from('announcements')
            .select()
            .inFilter('subject_id', subjectIds)
            .eq('year', year)
            .eq('section', section)
            .order('created_at', ascending: false)
            .range(from, to);

        if (announcements.isEmpty) return [];

        // Batch fetch related data
        final announcementSubjectIds = <String>{};
        final teacherIds = <String>{};

        for (var a in announcements) {
          if (a['subject_id'] != null)
            announcementSubjectIds.add(a['subject_id'].toString());
          if (a['teacher_id'] != null)
            teacherIds.add(a['teacher_id'].toString());
        }

        final [subjectData, teacherData] = await Future.wait([
          _queryOptimizer.batchFetch(
            table: 'subjects',
            idColumn: 'subject_id',
            ids: announcementSubjectIds.toList(),
            selectColumns: 'subject_id, subject_name',
          ),
          _queryOptimizer.batchFetch(
            table: 'teacher_details',
            idColumn: 'teacher_id',
            ids: teacherIds.toList(),
            selectColumns: 'teacher_id, name',
          ),
        ]);

        final subjectMap = {
          for (var s in subjectData) s['subject_id'].toString(): s
        };
        final teacherMap = {
          for (var t in teacherData) t['teacher_id'].toString(): t
        };

        final enriched = <Map<String, dynamic>>[];
        for (var announcement in announcements) {
          final enrichedAnnouncement = Map<String, dynamic>.from(announcement);

          final subjectId = announcement['subject_id']?.toString();
          final teacherId = announcement['teacher_id']?.toString();

          if (subjectId != null && subjectMap.containsKey(subjectId)) {
            enrichedAnnouncement['subjects'] = subjectMap[subjectId];
          }
          if (teacherId != null && teacherMap.containsKey(teacherId)) {
            enrichedAnnouncement['teacher_details'] = teacherMap[teacherId];
          }

          enriched.add(enrichedAnnouncement);
        }

        return enriched;
      },
      cacheDuration:
          Duration(minutes: PerformanceConfig.announcementsCacheDuration),
    );
  }

  // ============================================
  // REAL-TIME STREAMS (Optimized)
  // ============================================

  /// Stream student details with managed subscription
  Stream<Map<String, dynamic>?> streamStudentDetails(String studentId) {
    return _realtimeManager
        .subscribe(
          table: 'student_details',
          primaryKey: ['student_id'],
          filter: {'student_id': studentId},
          subscriptionKey: 'student_$studentId',
        )
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  /// Stream announcements with managed subscription
  Stream<List<Map<String, dynamic>>> streamAnnouncements(
      String studentId) async* {
    final studentDetails = await getStudentDetails(studentId);
    if (studentDetails == null) return;

    final year = studentDetails['year'].toString();
    final section = studentDetails['section'];

    yield* _realtimeManager
        .subscribe(
          table: 'announcements',
          primaryKey: ['id'],
          subscriptionKey: 'announcements_${year}_$section',
        )
        .map((data) => data
            .where((item) =>
                item['year'].toString() == year && item['section'] == section)
            .toList());
  }

  // ============================================
  // PREFETCHING
  // ============================================

  /// Prefetch common student data for faster navigation
  void prefetchStudentData(String studentId) {
    // Prefetch timetable (likely next view)
    _queryOptimizer.prefetch(
      cacheKey: '${CacheKeyPrefixes.timetable}$studentId',
      queryFn: () => getTimetable(studentId),
    );

    // Prefetch assignments
    _queryOptimizer.prefetch(
      cacheKey: '${CacheKeyPrefixes.assignments}student_${studentId}_0',
      queryFn: () => getStudentAssignments(studentId),
    );
  }

  // ============================================
  // CACHE INVALIDATION
  // ============================================

  /// Invalidate all student-related caches
  Future<void> invalidateStudentCache(String studentId) async {
    _queryOptimizer.invalidateCache(studentId);
    await _cache.clearCache('${CacheKeyPrefixes.student}details_$studentId');
    await _cache.clearCache('${CacheKeyPrefixes.marks}$studentId');
    await _cache.clearCache('${CacheKeyPrefixes.timetable}$studentId');
  }

  // ============================================
  // FILE UPLOADS (Same as before)
  // ============================================

  Future<bool> submitAssignment({
    required String assignmentId,
    required String studentId,
    required File file,
  }) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();
      final fileName =
          'submission_${studentId}_${assignmentId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = 'submissions/$fileName';

      await _supabase.storage.from('assignment-submissions').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final fileUrl =
          _supabase.storage.from('assignment-submissions').getPublicUrl(path);

      await _supabase.from('assignment_submissions').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'file_url': fileUrl,
        'status': 'submitted',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      // Invalidate assignments cache
      _queryOptimizer
          .invalidateCache('${CacheKeyPrefixes.assignments}student_$studentId');

      return true;
    } catch (e) {
      print('❌ Error submitting assignment: $e');
      return false;
    }
  }

  // ============================================
  // HELPER FUNCTIONS
  // ============================================

  String _getMarksTableName(String year, String section, String examType) {
    final normalizedExamType = examType.toLowerCase().replaceAll(' ', '');
    final normalizedSection = section.toLowerCase();

    final examTypeMap = {
      'midterm': 'midterm',
      'mid term': 'midterm',
      'endsemester': 'endsem',
      'end semester': 'endsem',
      'quiz': 'quiz',
      'assignment': 'assignment',
    };

    final tableSuffix = examTypeMap[normalizedExamType] ?? normalizedExamType;
    return 'marks_year${year}_section${normalizedSection}_$tableSuffix';
  }
}
