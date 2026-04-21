import 'package:supabase_flutter/supabase_flutter.dart';

class GrievanceService {
  final _db = Supabase.instance.client;

  // ── Student: Submit a new grievance ─────────────────────────────────────
  Future<bool> submitGrievance({
    required String studentId,
    required String studentName,
    required String category,
    required String title,
    required String description,
    required bool isAnonymous,
    String priority = 'medium',
    String? roomNumber,
    String? hostelName,
  }) async {
    try {
      await _db.from('hostel_grievances').insert({
        'student_id': studentId,
        'student_name': studentName,
        'category': category,
        'title': title,
        'description': description,
        'is_anonymous': isAnonymous,
        'priority': priority,
        'room_number': roomNumber,
        'hostel_name': hostelName,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      print('Error submitting grievance: $e');
      return false;
    }
  }

  // ── Student: Get own grievances ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStudentGrievances(
      String studentId) async {
    try {
      final res = await _db
          .from('hostel_grievances')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error fetching student grievances: $e');
      return [];
    }
  }

  // ── Warden: Get all grievances (masks anonymous ones) ───────────────────
  Future<List<Map<String, dynamic>>> getAllGrievances({
    String? statusFilter,
  }) async {
    try {
      var query = _db
          .from('hostel_grievances')
          .select()
          .order('created_at', ascending: false);

      final res = statusFilter != null && statusFilter != 'all'
          ? await _db
              .from('hostel_grievances')
              .select()
              .eq('status', statusFilter)
              .order('created_at', ascending: false)
          : await query;

      // Mask identity for anonymous grievances
      return List<Map<String, dynamic>>.from(res).map((g) {
        if (g['is_anonymous'] == true) {
          return {
            ...g,
            'student_name': 'Anonymous Student',
            'student_id': '••••••',
            'room_number': g['room_number'] != null ? '••••' : null,
          };
        }
        return g;
      }).toList();
    } catch (e) {
      print('Error fetching all grievances: $e');
      return [];
    }
  }

  // ── Warden: Respond to / update status of a grievance ──────────────────
  Future<bool> respondToGrievance({
    required String grievanceId,
    required String status,
    String? response,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (response != null && response.isNotEmpty) {
        updates['warden_response'] = response;
        updates['responded_at'] = DateTime.now().toIso8601String();
      }
      if (status == 'resolved') {
        updates['resolved_at'] = DateTime.now().toIso8601String();
      }
      await _db.from('hostel_grievances').update(updates).eq('id', grievanceId);
      return true;
    } catch (e) {
      print('Error responding to grievance: $e');
      return false;
    }
  }

  // ── Stats for warden ────────────────────────────────────────────────────
  Future<Map<String, int>> getGrievanceStats() async {
    try {
      final res = await _db.from('hostel_grievances').select('status');
      final all = List<Map<String, dynamic>>.from(res);
      return {
        'total': all.length,
        'pending': all.where((g) => g['status'] == 'pending').length,
        'in_progress': all.where((g) => g['status'] == 'in_progress').length,
        'resolved': all.where((g) => g['status'] == 'resolved').length,
        'acknowledged': all.where((g) => g['status'] == 'acknowledged').length,
      };
    } catch (e) {
      return {'total': 0, 'pending': 0, 'in_progress': 0, 'resolved': 0, 'acknowledged': 0};
    }
  }
}
