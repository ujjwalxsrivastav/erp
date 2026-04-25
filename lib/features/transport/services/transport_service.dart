import 'package:supabase_flutter/supabase_flutter.dart';

class TransportService {
  final _db = Supabase.instance.client;

  // ─── STATS ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final vehicles = await _db.from('transport_vehicles').select();
      final routes   = await _db.from('transport_routes').select();
      final students = await _db.from('student_transport').select();

      final activeVehicles = (vehicles as List)
          .where((v) => v['is_active'] == true).length;
      final allocatedStudents = (students as List)
          .where((s) => s['is_active'] == true && s['route_id'] != null).length;

      return {
        'total_vehicles'     : vehicles.length,
        'active_vehicles'    : activeVehicles,
        'total_routes'       : routes.length,
        'allocated_students' : allocatedStudents,
        'total_students'     : students.length,
      };
    } catch (_) {
      return {
        'total_vehicles': 0, 'active_vehicles': 0,
        'total_routes': 0, 'allocated_students': 0, 'total_students': 0,
      };
    }
  }

  // ─── VEHICLES ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('transport_vehicles').select().order('vehicle_no'));
    } catch (_) { return []; }
  }

  // ─── ROUTES ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRoutes() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('transport_routes').select().order('route_name'));
    } catch (_) { return []; }
  }

  // ─── STUDENTS ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllocatedStudents() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('student_transport').select().order('student_name'));
    } catch (_) { return []; }
  }
}
