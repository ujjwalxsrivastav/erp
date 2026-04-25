import 'package:supabase_flutter/supabase_flutter.dart';

class HostelService {
  final _supabase = Supabase.instance.client;

  // ─── HOSTELS & ROOMS ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHostels() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _supabase.from('hostels').select().order('name'));
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRoomsByHostel(String hostelId) async {
    try {
      return List<Map<String, dynamic>>.from(await _supabase
          .from('room_occupancy_view')
          .select()
          .eq('hostel_id', hostelId)
          .order('room_number'));
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUnallottedStudents() async {
    try {
      return List<Map<String, dynamic>>.from(await _supabase
          .from('hostel_students')
          .select()
          .isFilter('room_id', null)
          .order('student_name'));
    } catch (e) {
      return [];
    }
  }

  Future<bool> allotRoom(String studentId, String roomId, String hostelId,
      {String? bedNumber}) async {
    try {
      await _supabase.from('hostel_students').update({
        'room_id': roomId,
        'hostel_id': hostelId,
        if (bedNumber != null) 'bed_number': bedNumber,
      }).eq('student_id', studentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unallotRoom(String studentId, String roomId) async {
    try {
      // Trigger `sync_room_occupancy` will auto-decrement current_occupancy
      await _supabase.from('hostel_students').update({
        'room_id': null,
        'hostel_id': null,
        'bed_number': null,
        'room_number': null,
        'block_name': null,
      }).eq('student_id', studentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Transfer an already-allocated student to a new room/bed.
  /// The existing `sync_room_occupancy` trigger handles updating
  /// current_occupancy on both the old and new rooms automatically.
  Future<bool> reassignRoom({
    required String studentId,
    required String newRoomId,
    required String newHostelId,
    required String newRoomNumber,
    required String newBedNumber,
    String? newBlockName,
  }) async {
    try {
      await _supabase.from('hostel_students').update({
        'room_id': newRoomId,
        'hostel_id': newHostelId,
        'room_number': newRoomNumber,
        'bed_number': newBedNumber,
        if (newBlockName != null) 'block_name': newBlockName,
      }).eq('student_id', studentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get rooms with available capacity in a hostel (for transfer picker).
  Future<List<Map<String, dynamic>>> getAvailableRooms(String hostelId) async {
    try {
      final rooms = await _supabase
          .from('room_occupancy_view')
          .select()
          .eq('hostel_id', hostelId)
          .order('room_number');
      // Return rooms that still have at least 1 free bed
      return List<Map<String, dynamic>>.from(rooms).where((r) {
        final cap = r['capacity'] as int? ?? 0;
        final occ = r['current_occupancy'] as int? ?? 0;
        return occ < cap;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStudentRoomDetails(String studentId) async {
    try {
      final studentRecord = await _supabase
          .from('hostel_students')
          .select('room_id, hostel_id, student_name')
          .eq('student_id', studentId)
          .maybeSingle();
      if (studentRecord == null || studentRecord['room_id'] == null) return null;
      return await _supabase
          .from('room_occupancy_view')
          .select()
          .eq('room_id', studentRecord['room_id'])
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  // ─── STUDENT DIRECTORY ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllHostelStudents(
      {String? state, String? city}) async {
    try {
      var query = _supabase.from('hostel_students').select();
      if (state != null && state.isNotEmpty) query = query.eq('state', state);
      if (city != null && city.isNotEmpty) query = query.eq('city', city);
      return List<Map<String, dynamic>>.from(
          await query.order('student_name'));
    } catch (e) {
      return [];
    }
  }

  // ─── AUTO ALLOCATION ───────────────────────────────────────

  Future<Map<String, dynamic>> autoAllocateRooms() async {
    try {
      final response = await _supabase.rpc('auto_allocate_hostel_rooms');
      if (response is Map) return Map<String, dynamic>.from(response);
      return {'success': true, 'allocated': 0, 'total_unallocated_before': 0};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── GATEPASSES ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGatepasses({String? status}) async {
    try {
      var query = _supabase.from('hostel_gatepasses').select();
      if (status != null && status != 'all') query = query.eq('status', status);
      return List<Map<String, dynamic>>.from(
          await query.order('created_at', ascending: false));
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateGatepassStatus(
      String id, String status, String wardenName) async {
    try {
      await _supabase.from('hostel_gatepasses').update({
        'status': status,
        'reviewed_by': wardenName,
        'reviewed_at': DateTime.now().toIso8601String(),
        if (status == 'completed')
          'actual_in_time': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> createGatepass({
    required String studentId,
    required String studentName,
    required String reason,
    required DateTime outTime,
    required DateTime expectedInTime,
  }) async {
    try {
      await _supabase.from('hostel_gatepasses').insert({
        'student_id': studentId,
        'student_name': studentName,
        'reason': reason,
        'out_time': outTime.toIso8601String(),
        'expected_in_time': expectedInTime.toIso8601String(),
        'status': 'pending',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── NIGHT ATTENDANCE ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRoomsForAttendance(
      String hostelId) async {
    try {
      return List<Map<String, dynamic>>.from(await _supabase
          .from('room_occupancy_view')
          .select()
          .eq('hostel_id', hostelId)
          .gt('current_occupancy', 0)
          .order('room_number'));
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAttendanceForDate(
      String roomId, String date) async {
    try {
      return await _supabase
          .from('hostel_attendance')
          .select()
          .eq('room_id', roomId)
          .eq('attendance_date', date)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveAttendance({
    required String roomId,
    required String date,
    required List<String> absentStudentIds,
    required String markedBy,
  }) async {
    try {
      await _supabase.from('hostel_attendance').upsert({
        'room_id': roomId,
        'attendance_date': date,
        'absent_students': absentStudentIds,
        'marked_by': markedBy,
      }, onConflict: 'room_id,attendance_date');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── INCIDENTS / DISCIPLINARY ─────────────────────────────

  Future<List<Map<String, dynamic>>> getIncidents({String? studentId}) async {
    try {
      var query = _supabase.from('hostel_incidents').select();
      if (studentId != null) query = query.eq('student_id', studentId);
      return List<Map<String, dynamic>>.from(
          await query.order('incident_date', ascending: false));
    } catch (e) {
      return [];
    }
  }

  Future<bool> logIncident({
    required String studentId,
    required String studentName,
    required String title,
    required String description,
    required String severity,
    required String reporter,
  }) async {
    try {
      await _supabase.from('hostel_incidents').insert({
        'student_id': studentId,
        'student_name': studentName,
        'title': title,
        'description': description,
        'severity': severity,
        'reported_by': reporter,
        'incident_date': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteIncident(String id) async {
    try {
      await _supabase.from('hostel_incidents').delete().eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }
}
