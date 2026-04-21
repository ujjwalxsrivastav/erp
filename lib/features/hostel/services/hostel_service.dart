import 'package:supabase_flutter/supabase_flutter.dart';

class HostelService {
  final _supabase = Supabase.instance.client;

  /// Get all hostels
  Future<List<Map<String, dynamic>>> getHostels() async {
    try {
      final response = await _supabase.from('hostels').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching hostels: $e');
      return [];
    }
  }

  /// Get rooms for a hostel by hostel_id with occupancy details
  /// Uses room_occupancy_view which includes hostel_id column
  Future<List<Map<String, dynamic>>> getRoomsByHostel(String hostelId) async {
    try {
      final response = await _supabase
          .from('room_occupancy_view')
          .select()
          .eq('hostel_id', hostelId)
          .order('room_number');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }

  /// Get students who opted for hostel but are not yet allotted a room
  Future<List<Map<String, dynamic>>> getUnallottedStudents() async {
    try {
      final response = await _supabase
          .from('hostel_students')
          .select()
          .isFilter('room_id', null);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching unallotted students: $e');
      return [];
    }
  }

  /// Allot a room to a student
  Future<bool> allotRoom(
      String studentId, String roomId, String hostelId) async {
    try {
      await _supabase.from('hostel_students').update({
        'room_id': roomId,
        'hostel_id': hostelId,
      }).eq('student_id', studentId);
      return true;
    } catch (e) {
      print('Error allotting room: $e');
      return false;
    }
  }

  /// Get student's room details — queries hostel_students joined with room view
  /// Returns null if not allotted yet.
  Future<Map<String, dynamic>?> getStudentRoomDetails(String studentId) async {
    try {
      // First get the student's room_id from hostel_students
      final studentRecord = await _supabase
          .from('hostel_students')
          .select('room_id, hostel_id, student_name')
          .eq('student_id', studentId)
          .maybeSingle();

      if (studentRecord == null || studentRecord['room_id'] == null) {
        return null; // Not yet allotted
      }

      final roomId = studentRecord['room_id'];

      // Fetch the room occupancy view row for that room
      final roomDetails = await _supabase
          .from('room_occupancy_view')
          .select()
          .eq('room_id', roomId)
          .maybeSingle();

      return roomDetails;
    } catch (e) {
      print('Error fetching student room details: $e');
      return null;
    }
  }
}
