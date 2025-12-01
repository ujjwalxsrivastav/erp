import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class StudentService {
  static final StudentService _instance = StudentService._internal();

  factory StudentService() {
    return _instance;
  }

  StudentService._internal();

  final supabase = Supabase.instance.client;

  /// Get student details by student ID
  Future<Map<String, dynamic>?> getStudentDetails(String studentId) async {
    try {
      final response = await supabase
          .from('student_details')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

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

  /// Get student marks from all exam type tables
  Future<List<Map<String, dynamic>>> getStudentMarks(String studentId) async {
    try {
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
      return allMarks;
    } catch (e, stackTrace) {
      print('❌ Error fetching student marks: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get student assignments
  Future<List<Map<String, dynamic>>> getStudentAssignments(
      String studentId) async {
    try {
      // First get subjects for the student
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

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching student assignments: $e');
      return [];
    }
  }

  /// Get student timetable
  Future<List<Map<String, dynamic>>> getTimetable(String studentId) async {
    try {
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

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching student timetable: $e');
      return [];
    }
  }
}
