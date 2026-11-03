import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class SchoolService {
  static final SchoolService _instance = SchoolService._internal();
  factory SchoolService() => _instance;
  SchoolService._internal();

  final SupabaseClient _supabase = SupabaseService.client;

  // ===== STUDENT DETAILS =====
  Future<Map<String, dynamic>?> getSchoolStudentDetails(String username) async {
    try {
      final response = await _supabase
          .from('school_students')
          .select()
          .eq('username', username)
          .maybeSingle();
      return response;
    } catch (e) {
      print('SchoolService getSchoolStudentDetails: $e');
      return null;
    }
  }

  // ===== HOMEWORK =====
  Future<List<Map<String, dynamic>>> getHomework({String? classId}) async {
    try {
      var query = _supabase.from('school_homework').select();
      if (classId != null) {
        query = query.eq('class_id', classId);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SchoolService getHomework: $e');
      return [];
    }
  }

  Future<bool> createHomework(Map<String, dynamic> data) async {
    try {
      await _supabase.from('school_homework').insert(data);
      return true;
    } catch (e) {
      print('SchoolService createHomework: $e');
      return false;
    }
  }

  // ===== ATTENDANCE =====
  Future<List<Map<String, dynamic>>> getAttendance({
    required String classId,
    required DateTime date,
  }) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final response = await _supabase
          .from('school_attendance')
          .select()
          .eq('class_id', classId)
          .eq('date', dateStr);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SchoolService getAttendance: $e');
      return [];
    }
  }

  Future<bool> markAttendance(List<Map<String, dynamic>> records) async {
    try {
      await _supabase.from('school_attendance').upsert(records);
      return true;
    } catch (e) {
      print('SchoolService markAttendance: $e');
      return false;
    }
  }

  // ===== MARKS & REPORT CARDS =====
  Future<List<Map<String, dynamic>>> getStudentMarks(String studentId, {String? examType}) async {
    try {
      var query = _supabase.from('school_marks').select().eq('student_id', studentId);
      if (examType != null) {
        query = query.eq('exam_type', examType);
      }
      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SchoolService getStudentMarks: $e');
      return [];
    }
  }

  Future<bool> saveMarks(List<Map<String, dynamic>> marksList) async {
    try {
      await _supabase.from('school_marks').upsert(marksList);
      return true;
    } catch (e) {
      print('SchoolService saveMarks: $e');
      return false;
    }
  }

  // ===== CIRCULARS =====
  Future<List<Map<String, dynamic>>> getCirculars({String? category}) async {
    try {
      var query = _supabase.from('school_circulars').select();
      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }
      final response = await query.order('published_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SchoolService getCirculars: $e');
      return [];
    }
  }

  // ===== TRANSPORT =====
  Future<List<Map<String, dynamic>>> getTransportRoutes() async {
    try {
      final response = await _supabase.from('school_transport').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SchoolService getTransportRoutes: $e');
      return [];
    }
  }

  // ===== ADMISSIONS =====
  Future<List<Map<String, dynamic>>> getAdmissions({String? status}) async {
    try {
      var query = _supabase.from('school_admissions').select();
      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }
      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('SchoolService getAdmissions: $e');
      return [];
    }
  }

  Future<bool> submitAdmission(Map<String, dynamic> data) async {
    try {
      await _supabase.from('school_admissions').insert(data);
      return true;
    } catch (e) {
      print('SchoolService submitAdmission: $e');
      return false;
    }
  }
}

