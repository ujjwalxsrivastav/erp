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

  /// Get student details by student ID with caching
  Future<Map<String, dynamic>?> getStudentDetails(String studentId) async {
    try {
      // Check cache first
      final cacheKey = CacheKeys.studentDetails(studentId);
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
      print('Error fetching student details: $e');
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

  /// Get all students (for admin/teacher)
  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final response =
          await supabase.from('student_details').select().order('student_id');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all students: $e');
      return [];
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

      // Fetch marks from each exam type table
      for (final examType in examTypes) {
        try {
          final tableName =
              _getMarksTableName(year.toString(), section, examType);

          print('🔍 Querying table: $tableName for student: $studentId');

          final response = await supabase
              .from(tableName)
              .select('*')
              .eq('student_id', studentId)
              .order('uploaded_at', ascending: false);

          print('✅ Table $tableName returned ${response.length} records');

          // Add exam_type to each record for filtering
          for (var mark in response) {
            mark['exam_type'] = examType;

            // Try to fetch subject name separately if needed
            try {
              if (mark['subject_id'] != null) {
                final subjectData = await supabase
                    .from('subjects')
                    .select('subject_name')
                    .eq('subject_id', mark['subject_id'])
                    .maybeSingle();

                if (subjectData != null) {
                  mark['subjects'] = {
                    'subject_name': subjectData['subject_name']
                  };
                }
              }
            } catch (e) {
              print('⚠️ Could not fetch subject name: $e');
            }

            allMarks.add(Map<String, dynamic>.from(mark));
          }
        } catch (e) {
          print('⚠️ Error fetching from $examType table: $e');
          // Continue to next exam type even if one fails
        }
      }

      print('✅ Total marks fetched: ${allMarks.length}');

      // Cache the result
      await _cache.saveToCache(cacheKey, allMarks);

      return allMarks;
    } catch (e, stackTrace) {
      print('❌ Error fetching student marks: $e');
      print('Stack trace: $stackTrace');
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

      // Enrich with subject and teacher details
      final enrichedMaterials = <Map<String, dynamic>>[];

      for (var material in materials) {
        final enrichedMaterial = Map<String, dynamic>.from(material);

        // Fetch subject details
        if (material['subject_id'] != null) {
          final subjectData = await supabase
              .from('subjects')
              .select('subject_name')
              .eq('subject_id', material['subject_id'])
              .maybeSingle();

          if (subjectData != null) {
            enrichedMaterial['subjects'] = subjectData;
          }
        }

        // Fetch teacher details
        if (material['teacher_id'] != null) {
          final teacherData = await supabase
              .from('teacher_details')
              .select('name')
              .eq('teacher_id', material['teacher_id'])
              .maybeSingle();

          if (teacherData != null) {
            enrichedMaterial['teacher_details'] = teacherData;
          }
        }

        enrichedMaterials.add(enrichedMaterial);
      }

      // Cache the result
      await _cache.saveToCache(cacheKey, enrichedMaterials);

      return enrichedMaterials;
    } catch (e) {
      print('Error fetching study materials: $e');
      return [];
    }
  }

  /// Get announcements for student with caching
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

      // Enrich with subject and teacher details
      final enrichedAnnouncements = <Map<String, dynamic>>[];

      for (var announcement in announcementsData) {
        final enrichedAnnouncement = Map<String, dynamic>.from(announcement);

        // Fetch subject details
        if (announcement['subject_id'] != null) {
          final subjectData = await supabase
              .from('subjects')
              .select('subject_name')
              .eq('subject_id', announcement['subject_id'])
              .maybeSingle();

          if (subjectData != null) {
            enrichedAnnouncement['subjects'] = subjectData;
          }
        }

        // Fetch teacher details
        if (announcement['teacher_id'] != null) {
          final teacherData = await supabase
              .from('teacher_details')
              .select('name')
              .eq('teacher_id', announcement['teacher_id'])
              .maybeSingle();

          if (teacherData != null) {
            enrichedAnnouncement['teacher_details'] = teacherData;
          }
        }

        enrichedAnnouncements.add(enrichedAnnouncement);
      }

      // Cache the result
      await _cache.saveToCache(cacheKey, enrichedAnnouncements);

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
