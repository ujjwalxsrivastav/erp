import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Get total count of all users
  Future<int> getTotalUsers() async {
    try {
      final response = await _supabase.from('users').select('username');
      return response.length;
    } catch (e) {
      print('Error getting total users: $e');
      return 0;
    }
  }

  // Get count of students
  Future<int> getStudentCount() async {
    try {
      final response = await _supabase
          .from('users')
          .select('username')
          .eq('role', 'student');
      return response.length;
    } catch (e) {
      print('Error getting student count: $e');
      return 0;
    }
  }

  // Get count of teachers
  Future<int> getTeacherCount() async {
    try {
      final response = await _supabase
          .from('users')
          .select('username')
          .eq('role', 'teacher');
      return response.length;
    } catch (e) {
      print('Error getting teacher count: $e');
      return 0;
    }
  }

  // Get count of staff
  Future<int> getStaffCount() async {
    try {
      final response =
          await _supabase.from('users').select('username').eq('role', 'staff');
      return response.length;
    } catch (e) {
      print('Error getting staff count: $e');
      return 0;
    }
  }

  // Get count of admins
  Future<int> getAdminCount() async {
    try {
      final response =
          await _supabase.from('users').select('username').eq('role', 'admin');
      return response.length;
    } catch (e) {
      print('Error getting admin count: $e');
      return 0;
    }
  }

  // Get next available teacher ID
  Future<String> getNextTeacherId() async {
    try {
      final response = await _supabase
          .from('users')
          .select('username')
          .eq('role', 'teacher')
          .order('username', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return 'teacher1';
      }

      final lastTeacherId = response[0]['username'] as String;
      // Extract number from teacher ID (e.g., "teacher10" -> 10)
      final numberPart = lastTeacherId.replaceAll('teacher', '');
      final nextNumber = int.parse(numberPart) + 1;
      return 'teacher$nextNumber';
    } catch (e) {
      print('Error getting next teacher ID: $e');
      return 'teacher1';
    }
  }

  // Add a new teacher
  Future<bool> addTeacher({
    required String teacherId,
    required String password,
    required String name,
    required String employeeId,
    required String subject,
    required String department,
    required String phone,
    required String email,
    required String qualification,
    String? teacherRole,
  }) async {
    try {
      // 1. Add to users table for authentication
      await _supabase.from('users').insert({
        'username': teacherId,
        'password': password,
        'role': 'teacher',
      });

      // 2. Add to teacher_details table
      await _supabase.from('teacher_details').insert({
        'teacher_id': teacherId,
        'name': name,
        'employee_id': employeeId,
        'subject': subject,
        'department': department,
        'phone': phone,
        'email': email,
        'qualification': qualification,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error adding teacher: $e');
      return false;
    }
  }

  // Get user distribution for analytics
  Future<Map<String, int>> getUserDistribution() async {
    try {
      final studentCount = await getStudentCount();
      final teacherCount = await getTeacherCount();
      final staffCount = await getStaffCount();
      final adminCount = await getAdminCount();

      return {
        'students': studentCount,
        'teachers': teacherCount,
        'staff': staffCount,
        'admins': adminCount,
      };
    } catch (e) {
      print('Error getting user distribution: $e');
      return {
        'students': 0,
        'teachers': 0,
        'staff': 0,
        'admins': 0,
      };
    }
  }

  // Get next available student ID for a department
  Future<String> getNextStudentId(String department) async {
    try {
      final currentYear = DateTime.now().year;
      final yearSuffix = currentYear.toString().substring(2); // "2025" -> "25"
      final prefix = 'BT$yearSuffix$department'; // e.g., "BT25CSE"

      // Get all students with this prefix
      final response = await _supabase
          .from('student_details')
          .select('student_id')
          .like('student_id', '$prefix%')
          .order('student_id', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        return '${prefix}001'; // First student: BT25CSE001
      }

      final lastStudentId = response[0]['student_id'] as String;
      // Extract number from student ID (e.g., "BT25CSE010" -> "010")
      final numberPart = lastStudentId.replaceAll(prefix, '');
      final nextNumber = int.parse(numberPart) + 1;
      final paddedNumber = nextNumber.toString().padLeft(3, '0');
      return '$prefix$paddedNumber';
    } catch (e) {
      print('Error getting next student ID: $e');
      final currentYear = DateTime.now().year;
      final yearSuffix = currentYear.toString().substring(2);
      return 'BT$yearSuffix${department}001';
    }
  }

  // Add a new student
  Future<bool> addStudent({
    required String studentId,
    required String password,
    required String name,
    required String fatherName,
    required String year,
    required String semester,
    required String department,
    required String section,
  }) async {
    try {
      // 1. Add to users table for authentication
      await _supabase.from('users').insert({
        'username': studentId,
        'password': password,
        'role': 'student',
      });

      // 2. Add to student_details table
      await _supabase.from('student_details').insert({
        'student_id': studentId,
        'name': name,
        'father_name': fatherName,
        'year': year,
        'semester': semester,
        'department': department,
        'section': section,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error adding student: $e');
      return false;
    }
  }

  // Create database backup
  Future<String?> createBackup() async {
    try {
      print('📦 Creating database backup...');

      // Fetch all data from all tables
      final users = await _supabase.from('users').select('*');
      final students = await _supabase.from('student_details').select('*');
      final teachers = await _supabase.from('teacher_details').select('*');

      // Create backup content
      final timestamp = DateTime.now().toIso8601String();
      final buffer = StringBuffer();

      buffer.writeln('-- Database Backup');
      buffer.writeln('-- Generated: $timestamp');
      buffer.writeln('-- Tables: users, student_details, teacher_details');
      buffer.writeln();

      // Users table backup
      buffer.writeln('-- USERS TABLE');
      buffer.writeln('DELETE FROM users;');
      for (var user in users) {
        buffer.writeln(
          "INSERT INTO users (username, password, role) VALUES ('${user['username']}', '${user['password']}', '${user['role']}');",
        );
      }
      buffer.writeln();

      // Student details backup
      buffer.writeln('-- STUDENT DETAILS TABLE');
      buffer.writeln('DELETE FROM student_details;');
      for (var student in students) {
        buffer.writeln(
          "INSERT INTO student_details (student_id, name, father_name, year, semester, department, section, created_at, updated_at) VALUES ('${student['student_id']}', '${student['name']}', '${student['father_name']}', '${student['year']}', '${student['semester']}', '${student['department']}', '${student['section']}', '${student['created_at']}', '${student['updated_at']}');",
        );
      }
      buffer.writeln();

      // Teacher details backup
      buffer.writeln('-- TEACHER DETAILS TABLE');
      buffer.writeln('DELETE FROM teacher_details;');
      for (var teacher in teachers) {
        buffer.writeln(
          "INSERT INTO teacher_details (teacher_id, name, employee_id, subject, department, phone, email, qualification, created_at, updated_at) VALUES ('${teacher['teacher_id']}', '${teacher['name']}', '${teacher['employee_id']}', '${teacher['subject']}', '${teacher['department']}', '${teacher['phone']}', '${teacher['email']}', '${teacher['qualification']}', '${teacher['created_at']}', '${teacher['updated_at']}');",
        );
      }

      print('✅ Backup created successfully!');
      print(
          '   Users: ${users.length}, Students: ${students.length}, Teachers: ${teachers.length}');

      return buffer.toString();
    } catch (e) {
      print('❌ Error creating backup: $e');
      return null;
    }
  }
}
