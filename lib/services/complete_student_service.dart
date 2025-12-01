// FIXED Student Service - Using roll_number (username) as primary key
import 'package:supabase_flutter/supabase_flutter.dart';

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get student profile by roll number (username)
  Future<Map<String, dynamic>?> getStudentProfile(String rollNumber) async {
    try {
      final response = await _supabase.from('students').select('''
            *,
            departments(dept_name, dept_code)
          ''').eq('roll_number', rollNumber).single();

      return response;
    } catch (e) {
      print('Error fetching student profile: $e');
      return null;
    }
  }

  /// Get attendance percentage by roll number
  Future<Map<int, double>> getAttendancePercentage(String rollNumber) async {
    try {
      final Map<int, double> percentages = {};

      // Get all enrollments for this student
      final enrollments = await _supabase
          .from('enrollments')
          .select('enroll_id, course_id, courses(course_code, course_name)')
          .eq('roll_number', rollNumber);

      for (var enrollment in enrollments) {
        final enrollId = enrollment['enroll_id'];
        final courseId = enrollment['course_id'];

        // Get total attendance records
        final totalData = await _supabase
            .from('attendance')
            .select('attendance_id')
            .eq('enroll_id', enrollId);
        final totalClasses = totalData.length;

        // Get present attendance records
        final presentData = await _supabase
            .from('attendance')
            .select('attendance_id')
            .eq('enroll_id', enrollId)
            .eq('status', 'present');
        final presentClasses = presentData.length;

        if (totalClasses > 0) {
          percentages[courseId] = (presentClasses / totalClasses) * 100;
        }
      }

      return percentages;
    } catch (e) {
      print('Error calculating attendance: $e');
      return {};
    }
  }

  /// Calculate CGPA for a student
  Future<double> calculateCGPA(String rollNumber) async {
    try {
      // Get all results for this student
      final results = await _supabase.from('results').select('''
            marks_obtained,
            exams(max_marks, courses(credits))
          ''').eq('roll_number', rollNumber);

      if (results.isEmpty) return 0.0;

      double totalGradePoints = 0.0;
      int totalCredits = 0;

      for (var result in results) {
        final marksObtained = (result['marks_obtained'] as num).toDouble();
        final maxMarks = (result['exams']['max_marks'] as num).toDouble();
        final credits = result['exams']['courses']['credits'] as int;

        final percentage = (marksObtained / maxMarks) * 100;
        final gradePoint = _getGradePoint(percentage);

        totalGradePoints += gradePoint * credits;
        totalCredits += credits;
      }

      return totalCredits > 0 ? totalGradePoints / totalCredits : 0.0;
    } catch (e) {
      print('Error calculating CGPA: $e');
      return 0.0;
    }
  }

  /// Get upcoming exams for a student
  Future<List<Map<String, dynamic>>> getUpcomingExams(String rollNumber) async {
    try {
      // Get enrolled courses
      final enrollments = await _supabase
          .from('enrollments')
          .select('course_id')
          .eq('roll_number', rollNumber);

      if (enrollments.isEmpty) return [];

      final courseIds = enrollments.map((e) => e['course_id']).toList();

      // Get upcoming exams for these courses
      final exams = await _supabase
          .from('exams')
          .select('''
            *,
            courses(course_code, course_name)
          ''')
          .inFilter('course_id', courseIds)
          .gte('exam_date', DateTime.now().toIso8601String())
          .order('exam_date');

      return List<Map<String, dynamic>>.from(exams);
    } catch (e) {
      print('Error fetching upcoming exams: $e');
      return [];
    }
  }

  /// Get enrolled courses
  Future<List<Map<String, dynamic>>> getEnrolledCourses(
      String rollNumber) async {
    try {
      final enrollments = await _supabase.from('enrollments').select('''
            *,
            courses(*)
          ''').eq('roll_number', rollNumber);

      return List<Map<String, dynamic>>.from(enrollments);
    } catch (e) {
      print('Error fetching enrolled courses: $e');
      return [];
    }
  }

  /// Get attendance records
  Future<List<Map<String, dynamic>>> getAttendance(String rollNumber) async {
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('enroll_id')
          .eq('roll_number', rollNumber);

      if (enrollments.isEmpty) return [];

      final enrollIds = enrollments.map((e) => e['enroll_id']).toList();

      final attendance = await _supabase
          .from('attendance')
          .select('''
            *,
            enrollments(courses(course_code, course_name))
          ''')
          .inFilter('enroll_id', enrollIds)
          .order('attendance_date', ascending: false);

      return List<Map<String, dynamic>>.from(attendance);
    } catch (e) {
      print('Error fetching attendance: $e');
      return [];
    }
  }

  /// Get exam results
  Future<List<Map<String, dynamic>>> getResults(String rollNumber) async {
    try {
      final results = await _supabase
          .from('results')
          .select('''
            *,
            exams(exam_name, max_marks, courses(course_code, course_name))
          ''')
          .eq('roll_number', rollNumber)
          .order('result_id', ascending: false);

      return List<Map<String, dynamic>>.from(results);
    } catch (e) {
      print('Error fetching results: $e');
      return [];
    }
  }

  /// Get timetable
  Future<List<Map<String, dynamic>>> getTimetable(String rollNumber) async {
    try {
      final enrollments = await _supabase
          .from('enrollments')
          .select('course_id')
          .eq('roll_number', rollNumber);

      if (enrollments.isEmpty) return [];

      final courseIds = enrollments.map((e) => e['course_id']).toList();

      final timetable = await _supabase.from('timetable').select('''
            *,
            courses(course_code, course_name)
          ''').inFilter('course_id', courseIds).order('day_of_week');

      return List<Map<String, dynamic>>.from(timetable);
    } catch (e) {
      print('Error fetching timetable: $e');
      return [];
    }
  }

  /// Get issued library books
  Future<List<Map<String, dynamic>>> getIssuedBooks(String rollNumber) async {
    try {
      final books = await _supabase.from('book_issues').select('''
            *,
            library_books(title, author, isbn)
          ''').eq('roll_number', rollNumber).eq('status', 'issued');

      return List<Map<String, dynamic>>.from(books);
    } catch (e) {
      print('Error fetching issued books: $e');
      return [];
    }
  }

  /// Get hostel allocation
  Future<Map<String, dynamic>?> getHostelAllocation(String rollNumber) async {
    try {
      final allocation = await _supabase
          .from('hostel_allocations')
          .select('''
            *,
            hostel_rooms(room_number, hostel_name, room_type)
          ''')
          .eq('roll_number', rollNumber)
          .eq('status', 'active')
          .maybeSingle();

      return allocation;
    } catch (e) {
      print('Error fetching hostel allocation: $e');
      return null;
    }
  }

  /// Get transport allocation
  Future<Map<String, dynamic>?> getTransportAllocation(
      String rollNumber) async {
    try {
      final allocation = await _supabase
          .from('transport_allocations')
          .select('''
            *,
            transport_routes(route_name, route_number, driver_name, vehicle_number)
          ''')
          .eq('roll_number', rollNumber)
          .eq('status', 'active')
          .maybeSingle();

      return allocation;
    } catch (e) {
      print('Error fetching transport allocation: $e');
      return null;
    }
  }

  /// Get fees
  Future<List<Map<String, dynamic>>> getFees(String rollNumber,
      {String? status}) async {
    try {
      var query =
          _supabase.from('fees').select('*').eq('roll_number', rollNumber);

      if (status != null) {
        query = query.eq('status', status);
      }

      final fees = await query.order('due_date', ascending: false);
      return List<Map<String, dynamic>>.from(fees);
    } catch (e) {
      print('Error fetching fees: $e');
      return [];
    }
  }

  /// Get total pending fees
  Future<double> getTotalPendingFees(String rollNumber) async {
    try {
      final fees = await getFees(rollNumber, status: 'pending');
      final total = fees.fold<double>(
        0.0,
        (sum, fee) => sum + (fee['amount'] as num).toDouble(),
      );
      return total;
    } catch (e) {
      print('Error calculating pending fees: $e');
      return 0.0;
    }
  }

  /// Convert percentage to grade point
  double _getGradePoint(double percentage) {
    if (percentage >= 90) return 10.0;
    if (percentage >= 80) return 9.0;
    if (percentage >= 70) return 8.0;
    if (percentage >= 60) return 7.0;
    if (percentage >= 50) return 6.0;
    if (percentage >= 40) return 5.0;
    return 0.0;
  }

  /// Get grade from percentage
  String getGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    if (percentage >= 40) return 'D';
    return 'F';
  }
}
