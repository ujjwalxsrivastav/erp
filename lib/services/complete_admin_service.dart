// FIXED Admin Service - Using username as primary key
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get system overview
  Future<Map<String, dynamic>> getSystemOverview() async {
    try {
      // Get total students
      final students = await _supabase.from('students').select('roll_number');
      final totalStudents = students.length;

      // Get active students (current semester > 0)
      final activeStudents = await _supabase
          .from('students')
          .select('roll_number')
          .gt('current_semester', 0);
      final activeStudentsCount = activeStudents.length;

      // Get total staff
      final staff = await _supabase.from('staff').select('staff_code');
      final totalStaff = staff.length;

      // Get total courses
      final courses = await _supabase.from('courses').select('course_id');
      final totalCourses = courses.length;

      // Get total departments
      final departments = await _supabase.from('departments').select('dept_id');
      final totalDepartments = departments.length;

      // Get pending fees
      final fees =
          await _supabase.from('fees').select('amount').eq('status', 'pending');

      double pendingFees = 0.0;
      for (var fee in fees) {
        pendingFees += (fee['amount'] as num).toDouble();
      }

      return {
        'total_students': totalStudents,
        'active_students': activeStudentsCount,
        'total_staff': totalStaff,
        'total_courses': totalCourses,
        'total_departments': totalDepartments,
        'pending_fees': pendingFees,
      };
    } catch (e) {
      print('Error fetching system overview: $e');
      return {
        'total_students': 0,
        'active_students': 0,
        'total_staff': 0,
        'total_courses': 0,
        'total_departments': 0,
        'pending_fees': 0.0,
      };
    }
  }

  /// Get all students
  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      final students = await _supabase.from('students').select('''
            *,
            departments(dept_name, dept_code)
          ''').order('roll_number');

      return List<Map<String, dynamic>>.from(students);
    } catch (e) {
      print('Error fetching students: $e');
      return [];
    }
  }

  /// Get all staff
  Future<List<Map<String, dynamic>>> getAllStaff() async {
    try {
      final staff = await _supabase.from('staff').select('''
            *,
            departments(dept_name, dept_code)
          ''').order('staff_code');

      return List<Map<String, dynamic>>.from(staff);
    } catch (e) {
      print('Error fetching staff: $e');
      return [];
    }
  }

  /// Get all courses
  Future<List<Map<String, dynamic>>> getAllCourses() async {
    try {
      final courses = await _supabase.from('courses').select('''
            *,
            departments(dept_name),
            staff(name)
          ''').order('course_code');

      return List<Map<String, dynamic>>.from(courses);
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }

  /// Get all departments
  Future<List<Map<String, dynamic>>> getAllDepartments() async {
    try {
      final departments =
          await _supabase.from('departments').select('*').order('dept_code');

      return List<Map<String, dynamic>>.from(departments);
    } catch (e) {
      print('Error fetching departments: $e');
      return [];
    }
  }

  /// Create new student
  Future<bool> createStudent(Map<String, dynamic> studentData) async {
    try {
      await _supabase.from('students').insert(studentData);
      return true;
    } catch (e) {
      print('Error creating student: $e');
      return false;
    }
  }

  /// Create new staff
  Future<bool> createStaff(Map<String, dynamic> staffData) async {
    try {
      await _supabase.from('staff').insert(staffData);
      return true;
    } catch (e) {
      print('Error creating staff: $e');
      return false;
    }
  }

  /// Create new course
  Future<bool> createCourse(Map<String, dynamic> courseData) async {
    try {
      await _supabase.from('courses').insert(courseData);
      return true;
    } catch (e) {
      print('Error creating course: $e');
      return false;
    }
  }

  /// Get fee defaulters
  Future<List<Map<String, dynamic>>> getFeeDefaulters() async {
    try {
      final defaulters = await _supabase
          .from('fees')
          .select('''
            *,
            students(roll_number, name, email)
          ''')
          .eq('status', 'pending')
          .lt('due_date', DateTime.now().toIso8601String())
          .order('due_date');

      return List<Map<String, dynamic>>.from(defaulters);
    } catch (e) {
      print('Error fetching fee defaulters: $e');
      return [];
    }
  }
}
