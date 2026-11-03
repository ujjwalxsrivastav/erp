import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing temporary student admissions
class TempAdmissionService {
  static final TempAdmissionService _instance =
      TempAdmissionService._internal();
  factory TempAdmissionService() => _instance;
  TempAdmissionService._internal();

  final _supabase = Supabase.instance.client;

  // ============================================================================
  // TEMPORARY STUDENT OPERATIONS
  // ============================================================================

  /// Get temp student details by temp_id
  Future<Map<String, dynamic>?> getTempStudentDetails(String tempId) async {
    try {
      final response = await _supabase
          .from('temporary_students')
          .select()
          .eq('temp_id', tempId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting temp student: $e');
      return null;
    }
  }

  /// Get offer letter data for a temp student
  Future<Map<String, dynamic>?> getOfferLetterData(String tempId) async {
    try {
      final tempStudent = await getTempStudentDetails(tempId);
      if (tempStudent == null) return null;

      // Get programme details
      final courseCode = await _supabase
          .from('course_codes')
          .select('*, programme_codes(*)')
          .ilike('course_name', '%${tempStudent['course']}%')
          .maybeSingle();

      return {
        ...tempStudent,
        'programme_details': courseCode?['programme_codes'],
        'course_details': courseCode,
        'offer_date': DateTime.now().toIso8601String(),
        'college_name': 'Shivalik College',
        'college_address': 'Dehradun, Uttarakhand',
      };
    } catch (e) {
      print('Error getting offer letter data: $e');
      return null;
    }
  }

  /// Accept offer - triggers payment and migration
  Future<Map<String, dynamic>> acceptOffer({
    required String tempId,
    required String paymentId,
    double paymentAmount = 25000,
  }) async {
    try {
      final response = await _supabase.rpc('accept_offer', params: {
        'p_temp_id': tempId,
        'p_payment_id': paymentId,
        'p_payment_amount': paymentAmount,
      });

      if (response != null && response.isNotEmpty) {
        final result = response[0];
        return {
          'success': result['success'] ?? false,
          'permanentId': result['permanent_id'],
          'message': result['message'] ?? 'Unknown error',
        };
      }

      return {
        'success': false,
        'message': 'No response from server',
      };
    } catch (e) {
      print('Error accepting offer: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  /// Reject offer - moves to dead admissions
  Future<bool> rejectOffer(String tempId, {String? reason}) async {
    try {
      final response = await _supabase.rpc('reject_offer', params: {
        'p_temp_id': tempId,
        'p_reason': reason ?? 'Student rejected the offer',
      });
      return response == true;
    } catch (e) {
      print('Error rejecting offer: $e');
      return false;
    }
  }

  // ============================================================================
  // DEAD ADMISSIONS OPERATIONS
  // ============================================================================

  /// Get all dead admissions (for dean)
  Future<List<Map<String, dynamic>>> getAllDeadAdmissions() async {
    try {
      final response = await _supabase
          .from('dead_admissions')
          .select()
          .order('rejected_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting dead admissions: $e');
      return [];
    }
  }

  /// Get dead admissions for a specific counsellor
  Future<List<Map<String, dynamic>>> getDeadAdmissionsForCounsellor(
      String counsellor) async {
    try {
      final response = await _supabase
          .from('dead_admissions')
          .select()
          .eq('assigned_counsellor', counsellor)
          .order('rejected_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting dead admissions for counsellor: $e');
      return [];
    }
  }

  // ============================================================================
  // PROGRAMME & COURSE CODE OPERATIONS
  // ============================================================================

  /// Get all programmes
  Future<List<Map<String, dynamic>>> getProgrammes() async {
    try {
      final response =
          await _supabase.from('programme_codes').select().order('code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting programmes: $e');
      return [];
    }
  }

  /// Get all courses
  Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final response = await _supabase
          .from('course_codes')
          .select('*, programme_codes(*)')
          .order('code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting courses: $e');
      return [];
    }
  }

  /// Get courses by programme
  Future<List<Map<String, dynamic>>> getCoursesByProgramme(
      int programmeId) async {
    try {
      final response = await _supabase
          .from('course_codes')
          .select()
          .eq('programme_id', programmeId)
          .order('code');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting courses by programme: $e');
      return [];
    }
  }
}
