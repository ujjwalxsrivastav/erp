import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class TeacherService {
  final SupabaseClient _supabase = SupabaseService.client;

  // Get teacher details by teacher_id
  Future<Map<String, dynamic>?> getTeacherDetails(String teacherId) async {
    try {
      final response = await _supabase
          .from('teacher_details')
          .select()
          .eq('teacher_id', teacherId)
          .single();

      return response;
    } catch (e) {
      print('Error fetching teacher details: $e');
      return null;
    }
  }

  // Update teacher details
  Future<bool> updateTeacherDetails(
    String teacherId,
    Map<String, dynamic> updates,
  ) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('teacher_details')
          .update(updates)
          .eq('teacher_id', teacherId);

      return true;
    } catch (e) {
      print('Error updating teacher details: $e');
      return false;
    }
  }

  // Upload profile photo
  Future<String?> uploadProfilePhoto(String teacherId, File imageFile) async {
    try {
      final fileName =
          '$teacherId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'teacher-profiles/$fileName';

      await _supabase.storage.from('teacher-profiles').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          _supabase.storage.from('teacher-profiles').getPublicUrl(path);

      // Update teacher_details with new photo URL
      await updateTeacherDetails(teacherId, {'profile_photo_url': publicUrl});

      return publicUrl;
    } catch (e) {
      print('Error uploading profile photo: $e');
      return null;
    }
  }

  // Stream teacher details for real-time updates
  Stream<Map<String, dynamic>?> streamTeacherDetails(String teacherId) {
    return _supabase
        .from('teacher_details')
        .stream(primaryKey: ['teacher_id'])
        .eq('teacher_id', teacherId)
        .map((data) => data.isNotEmpty ? data.first : null);
  }

  // 1. Get unique subjects taught by teacher
  Future<List<Map<String, dynamic>>> getTeacherSubjects(
      String teacherId) async {
    try {
      print('Fetching subjects for teacher: $teacherId');
      final response =
          await _supabase.from('subjects').select().eq('teacher_id', teacherId);

      print('Subjects found: ${response.length}');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teacher subjects: $e');
      return [];
    }
  }

  // 2. Get classes (Year/Section) for a specific subject
  Future<List<Map<String, dynamic>>> getClassesForSubject(
      String subjectId) async {
    try {
      // Get students enrolled in this subject
      final response = await _supabase
          .from('student_subjects')
          .select('student_details(year, section)')
          .eq('subject_id', subjectId);

      // Group by Year/Section
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
            classes.add({
              'year': year,
              'section': section,
            });
          }
        }
      }

      // Sort classes
      classes.sort((a, b) {
        int cmp = a['year'].compareTo(b['year']);
        if (cmp != 0) return cmp;
        return a['section'].compareTo(b['section']);
      });

      return classes;
    } catch (e) {
      print('Error fetching classes for subject: $e');
      return [];
    }
  }

  // 3. Get students for a specific class (Subject + Year + Section)
  Future<List<Map<String, dynamic>>> getStudentsForClass({
    required String subjectId,
    required String year,
    required String section,
  }) async {
    try {
      // Fetch students who have this subject AND match year/section
      final response = await _supabase
          .from('student_subjects')
          .select('student_details(*)')
          .eq('subject_id', subjectId);

      // Filter manually
      final List<Map<String, dynamic>> students = [];

      for (var item in response) {
        final student = item['student_details'] as Map<String, dynamic>;
        // Convert to string for safe comparison
        if (student['year'].toString() == year.toString() &&
            student['section'] == section) {
          students.add(student);
        }
      }

      return students;
    } catch (e) {
      print('Error fetching students for class: $e');
      return [];
    }
  }

  // Legacy method for backward compatibility (optional)
  Future<List<Map<String, dynamic>>> getStudentsForSubject(
      String subjectId) async {
    try {
      final response = await _supabase
          .from('student_subjects')
          .select('*, student_details(*)')
          .eq('subject_id', subjectId);

      return response
          .map((item) => item['student_details'] as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Error fetching students for subject: $e');
      return [];
    }
  }

  // Upload Assignment with Year/Section targeting
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

      return true;
    } catch (e) {
      print('Error uploading assignment: $e');
      return false;
    }
  }

  // Upload Marks
  /// Helper function to get table name based on year, section, and exam type
  String _getMarksTableName(String year, String section, String examType) {
    // Normalize exam type: remove spaces and convert to lowercase
    final normalizedExamType = examType.toLowerCase().replaceAll(' ', '');
    final normalizedSection = section.toLowerCase();

    // Map exam types to table suffixes
    final examTypeMap = {
      'midterm': 'midterm',
      'endsemester': 'endsem',
      'quiz': 'quiz',
      'assignment': 'assignment',
    };

    final tableSuffix = examTypeMap[normalizedExamType] ?? normalizedExamType;

    return 'marks_year${year}_section${normalizedSection}_$tableSuffix';
  }

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
      // Get the appropriate table name
      final tableName = _getMarksTableName(year, section, examType);

      print('📊 Uploading marks to table: $tableName');

      // Insert or update marks in the specific table
      await _supabase.from(tableName).upsert({
        'student_id': studentId,
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'marks_obtained': marks,
        'total_marks': totalMarks,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id, subject_id');

      print('✅ Marks uploaded successfully to $tableName');
      return true;
    } catch (e) {
      print('❌ Error uploading marks: $e');
      return false;
    }
  }

  // Upload Study Material
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
      // Upload file to storage
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

      // Insert record into database
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

      print('✅ Study material uploaded successfully');
      return true;
    } catch (e) {
      print('❌ Error uploading study material: $e');
      return false;
    }
  }

  // Make Announcement
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

      print('✅ Announcement created successfully');
      return true;
    } catch (e) {
      print('❌ Error creating announcement: $e');
      return false;
    }
  }

  /// Get teacher's assignments for a specific class
  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
    String year,
    String section,
  ) async {
    try {
      final response = await _supabase
          .from('assignments')
          .select()
          .eq('teacher_id', teacherId)
          .eq('year', year)
          .eq('section', section)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teacher assignments: $e');
      return [];
    }
  }

  /// Get submissions for a specific assignment
  Future<List<Map<String, dynamic>>> getAssignmentSubmissions(
    String assignmentId,
  ) async {
    try {
      // First, get all submissions for this assignment
      final submissions = await _supabase
          .from('assignment_submissions')
          .select()
          .eq('assignment_id', assignmentId)
          .order('submitted_at', ascending: false);

      // Then fetch student details for each submission
      final enrichedSubmissions = <Map<String, dynamic>>[];

      for (var submission in submissions) {
        final studentId = submission['student_id'];

        // Fetch student details
        final studentDetails = await _supabase
            .from('student_details')
            .select('name, student_id')
            .eq('student_id', studentId)
            .maybeSingle();

        // Add student details to submission
        final enrichedSubmission = Map<String, dynamic>.from(submission);
        enrichedSubmission['student_details'] = studentDetails;
        enrichedSubmissions.add(enrichedSubmission);
      }

      return enrichedSubmissions;
    } catch (e) {
      print('Error fetching submissions: $e');
      return [];
    }
  }
}
