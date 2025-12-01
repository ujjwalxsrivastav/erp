// FIXED Teacher Service - Using staff_code (username) as primary key
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get teacher profile by staff code (username)
  Future<Map<String, dynamic>?> getTeacherProfile(String staffCode) async {
    try {
      final response = await _supabase.from('staff').select('''
            *,
            departments(dept_name, dept_code)
          ''').eq('staff_code', staffCode).single();

      return response;
    } catch (e) {
      print('Error fetching teacher profile: $e');
      return null;
    }
  }

  /// Get assigned courses for a teacher
  Future<List<Map<String, dynamic>>> getAssignedCourses(
      String staffCode) async {
    try {
      final courses = await _supabase
          .from('courses')
          .select('*')
          .eq('instructor_code', staffCode);

      return List<Map<String, dynamic>>.from(courses);
    } catch (e) {
      print('Error fetching assigned courses: $e');
      return [];
    }
  }

  /// Get students enrolled in a course
  Future<List<Map<String, dynamic>>> getCourseStudents(int courseId) async {
    try {
      final enrollments = await _supabase.from('enrollments').select('''
            *,
            students(roll_number, name, email, current_semester)
          ''').eq('course_id', courseId).eq('status', 'active');

      return List<Map<String, dynamic>>.from(enrollments);
    } catch (e) {
      print('Error fetching course students: $e');
      return [];
    }
  }

  /// Mark attendance for a student
  Future<bool> markAttendance(
    int enrollId,
    DateTime date,
    String status,
    String markedBy,
  ) async {
    try {
      await _supabase.from('attendance').insert({
        'enroll_id': enrollId,
        'attendance_date': date.toIso8601String().split('T')[0],
        'status': status,
        'marked_by': markedBy,
      });
      return true;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  /// Get attendance for a course on a specific date
  Future<List<Map<String, dynamic>>> getCourseAttendance(
    int courseId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      final attendance = await _supabase.from('attendance').select('''
            *,
            enrollments(
              roll_number,
              students(roll_number, name)
            )
          ''').eq('attendance_date', dateStr);

      return List<Map<String, dynamic>>.from(attendance);
    } catch (e) {
      print('Error fetching course attendance: $e');
      return [];
    }
  }

  /// Enter marks for an exam
  Future<bool> enterMarks(
    int examId,
    String rollNumber,
    double marks, {
    String? grade,
    String? remarks,
  }) async {
    try {
      await _supabase.from('results').insert({
        'exam_id': examId,
        'roll_number': rollNumber,
        'marks_obtained': marks,
        'grade': grade,
        'remarks': remarks,
      });
      return true;
    } catch (e) {
      print('Error entering marks: $e');
      return false;
    }
  }

  /// Get exam results for a course
  Future<List<Map<String, dynamic>>> getExamResults(int examId) async {
    try {
      final results = await _supabase.from('results').select('''
            *,
            students(roll_number, name)
          ''').eq('exam_id', examId).order('marks_obtained', ascending: false);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print('Error fetching exam results: $e');
      return [];
    }
  }

  /// Create exam
  Future<bool> createExam(Map<String, dynamic> examData) async {
    try {
      await _supabase.from('exams').insert(examData);
      return true;
    } catch (e) {
      print('Error creating exam: $e');
      return false;
    }
  }

  /// Get exams for a course
  Future<List<Map<String, dynamic>>> getCourseExams(int courseId) async {
    try {
      final exams = await _supabase
          .from('exams')
          .select('*')
          .eq('course_id', courseId)
          .order('exam_date', ascending: false);

      return List<Map<String, dynamic>>.from(exams);
    } catch (e) {
      print('Error fetching course exams: $e');
      return [];
    }
  }

  /// Get teaching schedule
  Future<List<Map<String, dynamic>>> getTeachingSchedule(
      String staffCode) async {
    try {
      // Get courses taught by this teacher
      final courses = await getAssignedCourses(staffCode);
      if (courses.isEmpty) return [];

      final courseIds = courses.map((c) => c['course_id']).toList();

      final schedule = await _supabase.from('timetable').select('''
            *,
            courses(course_code, course_name)
          ''').inFilter('course_id', courseIds).order('day_of_week');

      return List<Map<String, dynamic>>.from(schedule);
    } catch (e) {
      print('Error fetching teaching schedule: $e');
      return [];
    }
  }

  /// Get class performance analytics
  Future<Map<String, dynamic>> getClassPerformance(int courseId) async {
    try {
      // Get all results for this course's exams
      final exams = await getCourseExams(courseId);
      if (exams.isEmpty) {
        return {
          'average_marks': 0.0,
          'highest_marks': 0.0,
          'lowest_marks': 0.0,
          'pass_percentage': 0.0,
        };
      }

      final examIds = exams.map((e) => e['exam_id']).toList();

      final results = await _supabase
          .from('results')
          .select('marks_obtained, exams(max_marks)')
          .inFilter('exam_id', examIds);

      if (results.isEmpty) {
        return {
          'average_marks': 0.0,
          'highest_marks': 0.0,
          'lowest_marks': 0.0,
          'pass_percentage': 0.0,
        };
      }

      final marks =
          results.map((r) => (r['marks_obtained'] as num).toDouble()).toList();
      final average = marks.reduce((a, b) => a + b) / marks.length;
      final highest = marks.reduce((a, b) => a > b ? a : b);
      final lowest = marks.reduce((a, b) => a < b ? a : b);

      int passCount = 0;
      for (var result in results) {
        final obtained = (result['marks_obtained'] as num).toDouble();
        final maxMarks = (result['exams']['max_marks'] as num).toDouble();
        final percentage = (obtained / maxMarks) * 100;
        if (percentage >= 40) passCount++;
      }

      final passPercentage = (passCount / results.length) * 100;

      return {
        'average_marks': average,
        'highest_marks': highest,
        'lowest_marks': lowest,
        'pass_percentage': passPercentage,
      };
    } catch (e) {
      print('Error calculating class performance: $e');
      return {
        'average_marks': 0.0,
        'highest_marks': 0.0,
        'lowest_marks': 0.0,
        'pass_percentage': 0.0,
      };
    }
  }
}
