import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/performance_config.dart';
import '../core/utils/query_optimizer.dart';
import 'cache_manager.dart';

/// Optimized Teacher Service
///
/// Improvements:
/// 1. Batch fetching for student data
/// 2. Query deduplication
/// 3. Efficient class/subject resolution
/// 4. Pagination for large data sets

class OptimizedTeacherService {
  static final OptimizedTeacherService _instance =
      OptimizedTeacherService._internal();
  factory OptimizedTeacherService() => _instance;
  OptimizedTeacherService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final _cache = CacheManager();
  final _queryOptimizer = QueryOptimizer();

  // ============================================
  // TEACHER DETAILS
  // ============================================

  Future<Map<String, dynamic>?> getTeacherDetails(String teacherId) async {
    final cacheKey = '${CacheKeyPrefixes.teacher}details_$teacherId';

    return await _queryOptimizer.deduplicatedQuery<Map<String, dynamic>?>(
      cacheKey,
      () async {
        final cachedData = await _cache.getFromCache(
          cacheKey,
          durationMinutes: PerformanceConfig.profileCacheDuration,
        );

        if (cachedData != null) {
          return Map<String, dynamic>.from(cachedData);
        }

        final response = await _supabase
            .from('teacher_details')
            .select()
            .eq('teacher_id', teacherId)
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
  // SUBJECTS - CACHED
  // ============================================

  Future<List<Map<String, dynamic>>> getTeacherSubjects(
      String teacherId) async {
    final cacheKey = '${CacheKeyPrefixes.subjects}teacher_$teacherId';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final cachedData = await _cache.getFromCache(
          cacheKey,
          durationMinutes: PerformanceConfig.staticDataCacheDuration,
        );

        if (cachedData != null) {
          return List<Map<String, dynamic>>.from(cachedData);
        }

        final response = await _supabase
            .from('subjects')
            .select()
            .eq('teacher_id', teacherId);

        await _cache.saveToCache(cacheKey, response);

        return List<Map<String, dynamic>>.from(response);
      },
      cacheDuration:
          Duration(minutes: PerformanceConfig.staticDataCacheDuration),
    );
  }

  // ============================================
  // CLASSES FOR SUBJECT - OPTIMIZED
  // ============================================

  Future<List<Map<String, dynamic>>> getClassesForSubject(
      String subjectId) async {
    final cacheKey = '${CacheKeyPrefixes.subjects}classes_$subjectId';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final response = await _supabase
            .from('student_subjects')
            .select('student_details(year, section)')
            .eq('subject_id', subjectId);

        // Deduplicate year/section combinations
        final uniqueKeys = <String>{};
        final List<Map<String, dynamic>> classes = [];

        for (var item in response) {
          final student = item['student_details'];
          if (student != null) {
            final year = student['year'];
            final section = student['section'];
            final key = '$year-$section';

            if (!uniqueKeys.contains(key)) {
              uniqueKeys.add(key);
              classes.add({'year': year, 'section': section});
            }
          }
        }

        classes.sort((a, b) {
          int cmp = a['year'].compareTo(b['year']);
          if (cmp != 0) return cmp;
          return a['section'].compareTo(b['section']);
        });

        return classes;
      },
      cacheDuration:
          Duration(minutes: PerformanceConfig.staticDataCacheDuration),
    );
  }

  // ============================================
  // STUDENTS FOR CLASS - PAGINATED
  // ============================================

  Future<List<Map<String, dynamic>>> getStudentsForClass({
    required String subjectId,
    required String year,
    required String section,
    int page = 0,
    int pageSize = PerformanceConfig.largePageSize,
  }) async {
    final cacheKey =
        '${CacheKeyPrefixes.student}class_${subjectId}_${year}_${section}_$page';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final response = await _supabase
            .from('student_subjects')
            .select('student_details(*)')
            .eq('subject_id', subjectId);

        // Filter by year/section
        final students = <Map<String, dynamic>>[];
        for (var item in response) {
          final student = item['student_details'] as Map<String, dynamic>;
          if (student['year'].toString() == year.toString() &&
              student['section'] == section) {
            students.add(student);
          }
        }

        // Apply pagination
        final start = page * pageSize;
        final end = (start + pageSize).clamp(0, students.length);

        return students.sublist(start, end);
      },
      cacheDuration: Duration(minutes: PerformanceConfig.defaultCacheDuration),
    );
  }

  // ============================================
  // ASSIGNMENTS - PAGINATED
  // ============================================

  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
    String year,
    String section, {
    int page = 0,
    int pageSize = PerformanceConfig.defaultPageSize,
  }) async {
    final cacheKey =
        '${CacheKeyPrefixes.assignments}teacher_${teacherId}_${year}_${section}_$page';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final response = await _supabase
            .from('assignments')
            .select()
            .eq('teacher_id', teacherId)
            .eq('year', year)
            .eq('section', section)
            .order('created_at', ascending: false)
            .range(from, to);

        return List<Map<String, dynamic>>.from(response);
      },
      cacheDuration: Duration(minutes: PerformanceConfig.defaultCacheDuration),
    );
  }

  // ============================================
  // SUBMISSIONS - BATCH FETCH OPTIMIZED
  // ============================================

  Future<List<Map<String, dynamic>>> getAssignmentSubmissions(
    String assignmentId, {
    int page = 0,
    int pageSize = PerformanceConfig.defaultPageSize,
  }) async {
    final cacheKey =
        '${CacheKeyPrefixes.assignments}submissions_${assignmentId}_$page';

    return await _queryOptimizer.deduplicatedQuery<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        // Fetch submissions
        final submissions = await _supabase
            .from('assignment_submissions')
            .select()
            .eq('assignment_id', assignmentId)
            .order('submitted_at', ascending: false)
            .range(from, to);

        if (submissions.isEmpty) return [];

        // Collect student IDs for batch fetch
        final studentIds = <String>{};
        for (var s in submissions) {
          if (s['student_id'] != null) {
            studentIds.add(s['student_id'].toString());
          }
        }

        // Batch fetch student details
        final studentData = await _queryOptimizer.batchFetch(
          table: 'student_details',
          idColumn: 'student_id',
          ids: studentIds.toList(),
          selectColumns: 'student_id, name',
        );

        final studentMap = {
          for (var s in studentData) s['student_id'].toString(): s
        };

        // Enrich submissions
        final enriched = <Map<String, dynamic>>[];
        for (var submission in submissions) {
          final enrichedSubmission = Map<String, dynamic>.from(submission);
          final studentId = submission['student_id']?.toString();

          if (studentId != null && studentMap.containsKey(studentId)) {
            enrichedSubmission['student_details'] = studentMap[studentId];
          }

          enriched.add(enrichedSubmission);
        }

        return enriched;
      },
      cacheDuration: Duration(minutes: PerformanceConfig.defaultCacheDuration),
    );
  }

  // ============================================
  // UPLOAD OPERATIONS (Same logic, with cache invalidation)
  // ============================================

  Future<bool> uploadAssignment({
    required String title,
    required String description,
    required String subjectId,
    required String teacherId,
    required DateTime dueDate,
    required String year,
    required String section,
    File? file,
  }) async {
    try {
      String? fileUrl;

      if (file != null) {
        final fileName =
            'assignment_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final path = 'assignments/$fileName';

        await _supabase.storage.from('Assignments').upload(path, file);
        fileUrl = _supabase.storage.from('Assignments').getPublicUrl(path);
      }

      await _supabase.from('assignments').insert({
        'title': title,
        'description': description,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'due_date': dueDate.toIso8601String(),
        'file_url': fileUrl,
        'year': year,
        'section': section,
      });

      // Invalidate assignment caches
      _queryOptimizer
          .invalidateCache('${CacheKeyPrefixes.assignments}teacher_$teacherId');

      return true;
    } catch (e) {
      print('❌ Error uploading assignment: $e');
      return false;
    }
  }

  /// Upload marks to unified student_marks table
  Future<bool> uploadMarks({
    required String studentId,
    required String subjectId,
    required String teacherId,
    required String examType,
    required double marks,
    required double totalMarks,
    required String year,
    required String section,
  }) async {
    try {
      // Normalize exam type for storage
      final normalizedExamType = examType.toLowerCase().replaceAll(' ', '');
      final examTypeMap = {
        'midterm': 'midterm',
        'mid term': 'midterm',
        'endsemester': 'endsem',
        'end semester': 'endsem',
        'quiz': 'quiz',
        'assignment': 'assignment',
      };
      final dbExamType = examTypeMap[normalizedExamType] ?? normalizedExamType;

      await _supabase.from('student_marks').upsert({
        'student_id': studentId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'year': int.parse(year),
        'section': section.toUpperCase(),
        'exam_type': dbExamType,
        'marks_obtained': marks,
        'total_marks': totalMarks,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id, subject_id, exam_type');

      // Invalidate marks cache
      _queryOptimizer.invalidateCache('${CacheKeyPrefixes.marks}$studentId');

      return true;
    } catch (e) {
      print('❌ Error uploading marks: $e');
      return false;
    }
  }

  Future<bool> uploadStudyMaterial({
    required String title,
    required String description,
    required String materialType,
    required String subjectId,
    required String teacherId,
    required String year,
    required String section,
    required File file,
  }) async {
    try {
      final fileName =
          'study_material_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final path = 'study-materials/$fileName';

      await _supabase.storage.from('study-materials').upload(
            path,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      final fileUrl =
          _supabase.storage.from('study-materials').getPublicUrl(path);

      await _supabase.from('study_materials').insert({
        'title': title,
        'description': description,
        'material_type': materialType,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'file_url': fileUrl,
        'year': year,
        'section': section,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Invalidate materials cache
      _queryOptimizer.invalidateCache(CacheKeyPrefixes.materials);

      return true;
    } catch (e) {
      print('❌ Error uploading study material: $e');
      return false;
    }
  }

  Future<bool> makeAnnouncement({
    required String title,
    required String message,
    required String priority,
    required String subjectId,
    required String teacherId,
    required String year,
    required String section,
  }) async {
    try {
      await _supabase.from('announcements').insert({
        'title': title,
        'message': message,
        'priority': priority,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'year': year,
        'section': section,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Invalidate announcements cache
      _queryOptimizer.invalidateCache(CacheKeyPrefixes.announcements);

      return true;
    } catch (e) {
      print('❌ Error creating announcement: $e');
      return false;
    }
  }

  // ============================================
  // CACHE MANAGEMENT
  // ============================================

  Future<void> invalidateTeacherCache(String teacherId) async {
    _queryOptimizer.invalidateCache(teacherId);
    await _cache.clearCache('${CacheKeyPrefixes.teacher}details_$teacherId');
    await _cache.clearCache('${CacheKeyPrefixes.subjects}teacher_$teacherId');
  }
}
