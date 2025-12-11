import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'cache_manager.dart';

class StudentService {
  static final StudentService _instance = StudentService._internal();

  factory StudentService() {
    return _instance;
  }

  StudentService._internal();

  final supabase = Supabase.instance.client;
  final _cache = CacheManager();

  /// Get student details by student ID with caching and offline fallback
  Future<Map<String, dynamic>?> getStudentDetails(String studentId) async {
    final cacheKey = CacheKeys.studentDetails(studentId);

    try {
      // Check cache first
      final cachedData = await _cache.getFromCache(cacheKey);

      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }

      final response = await supabase
          .from('student_details')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      if (response != null) {
        // Cache the result
        await _cache.saveToCache(cacheKey, response);
      }

      return response;
    } catch (e) {
      print('⚠️ Error fetching student details: $e');

      // Try offline fallback
      final offlineData = await _cache.getOfflineFallback(cacheKey);
      if (offlineData != null) {
        print('📴 Using offline data for student: $studentId');
        return Map<String, dynamic>.from(offlineData);
      }

      return null;
    }
  }

  /// Update student name
  Future<bool> updateStudentName(String studentId, String newName) async {
    try {
      await supabase
          .from('student_details')
          .update({'name': newName}).eq('student_id', studentId);
      return true;
    } catch (e) {
      print('Error updating student name: $e');
      return false;
    }
  }

  /// Update father's name
  Future<bool> updateFatherName(String studentId, String newFatherName) async {
    try {
      await supabase
          .from('student_details')
          .update({'father_name': newFatherName}).eq('student_id', studentId);
      return true;
    } catch (e) {
      print('Error updating father name: $e');
      return false;
    }
  }

  /// Upload profile photo to Supabase Storage
  Future<String?> uploadProfilePhoto(String studentId, File imageFile) async {
    try {
      final fileName =
          '$studentId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'profile_photos/$fileName';

      // Upload to Supabase Storage
      await supabase.storage.from('student-profiles').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl =
          supabase.storage.from('student-profiles').getPublicUrl(path);

      // Update database with new photo URL
      await supabase
          .from('student_details')
          .update({'profile_photo_url': publicUrl}).eq('student_id', studentId);

      return publicUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      return null;
    }
  }

  /// Delete old profile photo from storage
  Future<void> deleteProfilePhoto(String photoUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(photoUrl);
      final path = uri.pathSegments.last;

      await supabase.storage
          .from('student-profiles')
          .remove(['profile_photos/$path']);
    } catch (e) {
      print('Error deleting profile photo: $e');
    }
  }

  /// Get all students (for admin/teacher) with pagination
  /// [page] starts from 0, [limit] defaults to 25
  Future<List<Map<String, dynamic>>> getAllStudents({
    int page = 0,
    int limit = 25,
  }) async {
    try {
      final offset = page * limit;
      final response = await supabase
          .from('student_details')
          .select()
          .order('student_id')
          .range(offset, offset + limit - 1);

      print('📄 Fetched students page $page (${response.length} items)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all students: $e');
      return [];
    }
  }

  /// Get total count of students (for pagination)
  Future<int> getStudentsCount() async {
    try {
      final response = await supabase
          .from('student_details')
          .select('student_id')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      print('Error counting students: $e');
      return 0;
    }
  }

  /// Stream student details for real-time updates
  Stream<Map<String, dynamic>?> streamStudentDetails(String studentId) {
    return supabase
        .from('student_details')
        .stream(primaryKey: ['student_id'])
        .eq('student_id', studentId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  /// Helper function to get table name
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

  /// Get student marks from all exam type tables with caching
  /// OPTIMIZED: Uses batch query for subjects instead of N+1 pattern
  Future<List<Map<String, dynamic>>> getStudentMarks(String studentId) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.studentMarks(studentId);
      final cachedData = await _cache.getFromCache(cacheKey);

      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      print('🎯 getStudentMarks called for: $studentId');

      // First get student's year and section
      final studentDetails = await getStudentDetails(studentId);
      if (studentDetails == null) {
        print('❌ No student details found for: $studentId');
        return [];
      }

      final year = studentDetails['year'];
      final section = studentDetails['section'];

      print('📚 Student Year: $year, Section: $section');

      // Define all exam types
      final examTypes = ['Mid Term', 'End Semester', 'Quiz', 'Assignment'];

      List<Map<String, dynamic>> allMarks = [];
      Set<String> allSubjectIds = {};

      // Step 1: Fetch marks from each exam type table and collect subject IDs
      for (final examType in examTypes) {
        try {
          final tableName =
              _getMarksTableName(year.toString(), section, examType);

          final response = await supabase
              .from(tableName)
              .select('*')
              .eq('student_id', studentId)
              .order('uploaded_at', ascending: false);

          print('✅ Table $tableName returned ${response.length} records');

          // Add exam_type to each record and collect subject IDs
          for (var mark in response) {
            mark['exam_type'] = examType;
            if (mark['subject_id'] != null) {
              allSubjectIds.add(mark['subject_id'].toString());
            }
            allMarks.add(Map<String, dynamic>.from(mark));
          }
        } catch (e) {
          print('⚠️ Error fetching from $examType table: $e');
          // Continue to next exam type even if one fails
        }
      }

      // Step 2: Batch fetch all subjects in ONE query (optimization)
      Map<String, String> subjectMap = {};
      if (allSubjectIds.isNotEmpty) {
        try {
          final subjectsData = await supabase
              .from('subjects')
              .select('subject_id, subject_name')
              .filter('subject_id', 'in', allSubjectIds.toList());

          for (var s in subjectsData) {
            subjectMap[s['subject_id'].toString()] = s['subject_name'] ?? '';
          }
          print('✅ Batch fetched ${subjectMap.length} subjects');
        } catch (e) {
          print('⚠️ Could not batch fetch subjects: $e');
        }
      }

      // Step 3: Enrich marks with subject names using map (O(1) lookups)
      for (var mark in allMarks) {
        final subjectId = mark['subject_id']?.toString();
        if (subjectId != null && subjectMap.containsKey(subjectId)) {
          mark['subjects'] = {'subject_name': subjectMap[subjectId]};
        }
      }

      print('✅ Total marks fetched: ${allMarks.length} (optimized)');

      // Cache the result
      await _cache.saveToCache(cacheKey, allMarks);

      return allMarks;
    } catch (e, stackTrace) {
      print('❌ Error fetching student marks: $e');
      print('Stack trace: $stackTrace');

      // Try offline fallback
      final cacheKey = CacheKeys.studentMarks(studentId);
      final offlineData = await _cache.getOfflineFallback(cacheKey);
      if (offlineData != null) {
        print('📴 Using offline marks data for: $studentId');
        return List<Map<String, dynamic>>.from(offlineData);
      }

      return [];
    }
  }

  /// Get assignments for student with caching
  Future<List<Map<String, dynamic>>> getStudentAssignments(
      String studentId) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.studentAssignments(studentId);
      final cachedData = await _cache.getFromCache(cacheKey);

      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      print('🔄 Fetching assignments from API...');

      // Get enrolled subjects
      final subjects = await supabase
          .from('student_subjects')
          .select('subject_id')
          .eq('student_id', studentId);

      final subjectIds =
          (subjects as List).map((s) => s['subject_id']).toList();

      if (subjectIds.isEmpty) return [];

      // Then fetch assignments for these subjects
      final response = await supabase
          .from('assignments')
          .select('*, subjects(subject_name), teacher_details(name)')
          .filter('subject_id', 'in', subjectIds)
          .order('created_at', ascending: false);

      final assignments = List<Map<String, dynamic>>.from(response);

      // Cache the result
      await _cache.saveToCache(cacheKey, assignments);

      return assignments;
    } catch (e) {
      print('Error fetching student assignments: $e');
      return [];
    }
  }

  /// Get student timetable with caching
  Future<List<Map<String, dynamic>>> getTimetable(String studentId) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.timetable(studentId);
      final cachedData = await _cache.getFromCache(cacheKey);

      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      // 1. Get enrolled subjects
      final subjects = await supabase
          .from('student_subjects')
          .select('subject_id')
          .eq('student_id', studentId);

      if (subjects.isEmpty) return [];

      final subjectIds =
          (subjects as List).map((s) => s['subject_id']).toList();

      // 2. Get timetable for these subjects
      final response = await supabase
          .from('timetable')
          .select('*, subjects(subject_name), teacher_details(name)')
          .filter('subject_id', 'in', subjectIds)
          .order('day_of_week')
          .order('start_time');

      final timetable = List<Map<String, dynamic>>.from(response);

      // Cache the result
      await _cache.saveToCache(cacheKey, timetable);

      return timetable;
    } catch (e) {
      print('Error fetching student timetable: $e');
      return [];
    }
  }

  /// Get study materials for student with caching
  /// OPTIMIZED: Uses batch queries instead of N+1 pattern
  Future<List<Map<String, dynamic>>> getStudyMaterials(String studentId) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.studyMaterials(studentId);
      final cachedData = await _cache.getFromCache(cacheKey);

      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      // First get student's year and section
      final studentDetails = await getStudentDetails(studentId);
      if (studentDetails == null) {
        print('❌ No student details found for: $studentId');
        return [];
      }

      final year = studentDetails['year'].toString();
      final section = studentDetails['section'];

      // Get subjects for the student
      final subjects = await supabase
          .from('student_subjects')
          .select('subject_id')
          .eq('student_id', studentId);

      final subjectIds =
          (subjects as List).map((s) => s['subject_id']).toList();

      if (subjectIds.isEmpty) return [];

      // Fetch study materials for these subjects matching year and section
      final materials = await supabase
          .from('study_materials')
          .select()
          .filter('subject_id', 'in', subjectIds)
          .eq('year', year)
          .eq('section', section)
          .order('created_at', ascending: false);

      if (materials.isEmpty) return [];

      // OPTIMIZATION: Batch fetch all subjects and teachers in 2 queries instead of 2*N
      final materialSubjectIds = (materials as List)
          .map((m) => m['subject_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      final materialTeacherIds = materials
          .map((m) => m['teacher_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Batch fetch subjects
      Map<String, Map<String, dynamic>> subjectMap = {};
      if (materialSubjectIds.isNotEmpty) {
        final subjectsData = await supabase
            .from('subjects')
            .select('subject_id, subject_name')
            .filter('subject_id', 'in', materialSubjectIds);

        for (var s in subjectsData) {
          subjectMap[s['subject_id'].toString()] = {
            'subject_name': s['subject_name']
          };
        }
      }

      // Batch fetch teachers
      Map<String, Map<String, dynamic>> teacherMap = {};
      if (materialTeacherIds.isNotEmpty) {
        final teachersData = await supabase
            .from('teacher_details')
            .select('teacher_id, name')
            .filter('teacher_id', 'in', materialTeacherIds);

        for (var t in teachersData) {
          teacherMap[t['teacher_id'].toString()] = {'name': t['name']};
        }
      }

      // Enrich materials using maps (O(1) lookups instead of queries)
      final enrichedMaterials = <Map<String, dynamic>>[];
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

        enrichedMaterials.add(enrichedMaterial);
      }

      // Cache the result
      await _cache.saveToCache(cacheKey, enrichedMaterials);

      print(
          '✅ Fetched ${enrichedMaterials.length} study materials (optimized)');
      return enrichedMaterials;
    } catch (e) {
      print('Error fetching study materials: $e');
      return [];
    }
  }

  /// Get announcements for student with caching
  /// OPTIMIZED: Uses batch queries instead of N+1 pattern
  Future<List<Map<String, dynamic>>> getAnnouncements(String studentId) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.studentAnnouncements(studentId);
      final cachedData = await _cache.getFromCache(cacheKey);

      if (cachedData != null) {
        return List<Map<String, dynamic>>.from(cachedData);
      }

      // First get student's year and section
      final studentDetails = await getStudentDetails(studentId);
      if (studentDetails == null) {
        print('❌ No student details found for: $studentId');
        return [];
      }

      final year = studentDetails['year'].toString();
      final section = studentDetails['section'];

      // Get subjects for the student
      final subjects = await supabase
          .from('student_subjects')
          .select('subject_id')
          .eq('student_id', studentId);

      final subjectIds =
          (subjects as List).map((s) => s['subject_id']).toList();

      if (subjectIds.isEmpty) return [];

      // Fetch announcements for these subjects matching year and section
      final announcementsData = await supabase
          .from('announcements')
          .select()
          .filter('subject_id', 'in', subjectIds)
          .eq('year', year)
          .eq('section', section)
          .order('created_at', ascending: false);

      if (announcementsData.isEmpty) return [];

      // OPTIMIZATION: Batch fetch all subjects and teachers in 2 queries instead of 2*N
      final announcementSubjectIds = (announcementsData as List)
          .map((a) => a['subject_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      final announcementTeacherIds = announcementsData
          .map((a) => a['teacher_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      // Batch fetch subjects
      Map<String, Map<String, dynamic>> subjectMap = {};
      if (announcementSubjectIds.isNotEmpty) {
        final subjectsData = await supabase
            .from('subjects')
            .select('subject_id, subject_name')
            .filter('subject_id', 'in', announcementSubjectIds);

        for (var s in subjectsData) {
          subjectMap[s['subject_id'].toString()] = {
            'subject_name': s['subject_name']
          };
        }
      }

      // Batch fetch teachers
      Map<String, Map<String, dynamic>> teacherMap = {};
      if (announcementTeacherIds.isNotEmpty) {
        final teachersData = await supabase
            .from('teacher_details')
            .select('teacher_id, name')
            .filter('teacher_id', 'in', announcementTeacherIds);

        for (var t in teachersData) {
          teacherMap[t['teacher_id'].toString()] = {'name': t['name']};
        }
      }

      // Enrich announcements using maps (O(1) lookups instead of queries)
      final enrichedAnnouncements = <Map<String, dynamic>>[];
      for (var announcement in announcementsData) {
        final enrichedAnnouncement = Map<String, dynamic>.from(announcement);

        final subjectId = announcement['subject_id']?.toString();
        final teacherId = announcement['teacher_id']?.toString();

        if (subjectId != null && subjectMap.containsKey(subjectId)) {
          enrichedAnnouncement['subjects'] = subjectMap[subjectId];
        }
        if (teacherId != null && teacherMap.containsKey(teacherId)) {
          enrichedAnnouncement['teacher_details'] = teacherMap[teacherId];
        }

        enrichedAnnouncements.add(enrichedAnnouncement);
      }

      // Cache the result
      await _cache.saveToCache(cacheKey, enrichedAnnouncements);

      print(
          '✅ Fetched ${enrichedAnnouncements.length} announcements (optimized)');
      return enrichedAnnouncements;
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }

  /// Stream study materials for real-time updates
  Stream<List<Map<String, dynamic>>> streamStudyMaterials(
      String studentId) async* {
    try {
      final studentDetails = await getStudentDetails(studentId);
      if (studentDetails == null) return;

      final year = studentDetails['year'].toString();
      final section = studentDetails['section'];

      yield* supabase
          .from('study_materials')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) {
            // Filter by year and section in the map
            return data
                .where((item) =>
                    item['year'].toString() == year &&
                    item['section'] == section)
                .toList()
                .cast<Map<String, dynamic>>();
          });
    } catch (e) {
      print('Error streaming study materials: $e');
    }
  }

  /// Stream announcements for real-time updates
  Stream<List<Map<String, dynamic>>> streamAnnouncements(
      String studentId) async* {
    try {
      final studentDetails = await getStudentDetails(studentId);
      if (studentDetails == null) return;

      final year = studentDetails['year'].toString();
      final section = studentDetails['section'];

      yield* supabase
          .from('announcements')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((data) {
            // Filter by year and section in the map
            return data
                .where((item) =>
                    item['year'].toString() == year &&
                    item['section'] == section)
                .toList()
                .cast<Map<String, dynamic>>();
          });
    } catch (e) {
      print('Error streaming announcements: $e');
    }
  }

  /// Submit assignment solution
  Future<bool> submitAssignment({
    required String assignmentId,
    required String studentId,
    required File file,
  }) async {
    try {
      print('📤 Starting assignment submission...');

      // Compress file if it's a PDF or image
      File fileToUpload = file;
      final extension = file.path.split('.').last.toLowerCase();

      if (extension == 'pdf' || ['jpg', 'jpeg', 'png'].contains(extension)) {
        print('🗜️ Compressing file...');
        fileToUpload = await _compressFile(file);
        print('✅ File compressed successfully');
      }

      // Upload to storage
      final fileName =
          'submission_${studentId}_${assignmentId}_${DateTime.now().millisecondsSinceEpoch}.${extension}';
      final path = 'submissions/$fileName';

      print('📁 Uploading to storage...');
      await supabase.storage.from('assignment-submissions').upload(
            path,
            fileToUpload,
            fileOptions: const FileOptions(upsert: true),
          );

      final fileUrl =
          supabase.storage.from('assignment-submissions').getPublicUrl(path);

      print('💾 Saving submission record...');
      // Insert submission record
      await supabase.from('assignment_submissions').insert({
        'assignment_id': assignmentId,
        'student_id': studentId,
        'file_url': fileUrl,
        'status': 'submitted',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      print('✅ Assignment submitted successfully!');
      return true;
    } catch (e) {
      print('❌ Error submitting assignment: $e');
      return false;
    }
  }

  /// Compress file to save storage
  Future<File> _compressFile(File file) async {
    try {
      final extension = file.path.split('.').last.toLowerCase();

      // For images, we can use flutter's image compression
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
        // For now, just return the original file
        // In production, you'd use image compression package
        // like flutter_image_compress
        return file;
      }

      // For PDFs, return as is (PDF compression requires native libraries)
      // In production, you'd use a package like pdf_compressor
      return file;
    } catch (e) {
      print('⚠️ Compression failed, using original file: $e');
      return file;
    }
  }

  /// Check if student has submitted an assignment
  Future<Map<String, dynamic>?> getSubmissionStatus(
    String assignmentId,
    String studentId,
  ) async {
    try {
      final response = await supabase
          .from('assignment_submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .eq('student_id', studentId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error checking submission status: $e');
      return null;
    }
  }

  /// Get all submissions for a student
  Future<List<Map<String, dynamic>>> getStudentSubmissions(
      String studentId) async {
    try {
      final response = await supabase
          .from('assignment_submissions')
          .select('*, assignments(*)')
          .eq('student_id', studentId)
          .order('submitted_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching submissions: $e');
      return [];
    }
  }
}
