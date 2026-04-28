import 'package:supabase_flutter/supabase_flutter.dart';

class TransportService {
  final _db = Supabase.instance.client;

  // ─── STATS ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final buses = await _db.from('transport_buses').select();
      final routes = await _db.from('transport_routes').select();
      final requests = await _db.from('student_transport_requests').select();

      final activeBuses =
          (buses as List).where((v) => v['is_active'] == true).length;
      final pendingRequests =
          (requests as List).where((s) => s['status'] == 'pending').length;
      final approvedRequests =
          requests.where((s) => s['status'] == 'approved').length;

      return {
        'total_buses': buses.length,
        'active_buses': activeBuses,
        'total_routes': (routes as List).length,
        'pending_requests': pendingRequests,
        'approved_requests': approvedRequests,
        'total_requests': requests.length,
      };
    } catch (_) {
      return {
        'total_buses': 0,
        'active_buses': 0,
        'total_routes': 0,
        'pending_requests': 0,
        'approved_requests': 0,
        'total_requests': 0,
      };
    }
  }

  // ─── ROUTES ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRoutes() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('transport_routes').select().order('route_name'));
    } catch (_) {
      return [];
    }
  }

  // ─── BUSES ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBuses() async {
    try {
      return List<Map<String, dynamic>>.from(
          await _db.from('transport_buses').select().order('bus_number'));
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBusesByRoute(String routeId) async {
    try {
      return List<Map<String, dynamic>>.from(await _db
          .from('transport_buses')
          .select()
          .eq('route_id', routeId)
          .order('bus_number'));
    } catch (_) {
      return [];
    }
  }

  // ─── STUDENT REQUESTS ─────────────────────────────────────

  /// Get transport request for a specific student
  Future<Map<String, dynamic>?> getStudentRequest(String studentId) async {
    try {
      final result = await _db
          .from('student_transport_requests')
          .select()
          .eq('student_id', studentId)
          .eq('is_active', true)
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Student submits a route request and auto-allocates bus
  Future<Map<String, dynamic>> submitRouteRequest({
    required String studentId,
    required String studentName,
    required String routeId,
    required String stopName,
    required double feeAmount,
  }) async {
    try {
      // Find available bus
      final buses = List<Map<String, dynamic>>.from(await _db
          .from('transport_buses')
          .select()
          .eq('route_id', routeId)
          .order('bus_number', ascending: true));
      
      String? allocatedBusId;
      for (var bus in buses) {
        final currentOcc = (bus['current_occupancy'] ?? 0) as int;
        final capacity = (bus['capacity'] ?? 40) as int;
        if (currentOcc < capacity) {
          allocatedBusId = bus['id'];
          // increment occupancy
          await _db.from('transport_buses').update({'current_occupancy': currentOcc + 1}).eq('id', bus['id']);
          break;
        }
      }

      if (allocatedBusId == null) {
        return {'success': false, 'message': 'No seats available on this route. Max 80 seats filled.'};
      }

      // Check if student already has an active request
      final existing = await _db
          .from('student_transport_requests')
          .select()
          .eq('student_id', studentId)
          .eq('is_active', true)
          .maybeSingle();

      if (existing != null) {
        if (existing['bus_id'] != null) {
          final oldBusId = existing['bus_id'];
          final oldBus = await _db.from('transport_buses').select('current_occupancy').eq('id', oldBusId).maybeSingle();
          if (oldBus != null) {
            final oldOcc = (oldBus['current_occupancy'] ?? 1) as int;
            if (oldOcc > 0) {
              await _db.from('transport_buses').update({'current_occupancy': oldOcc - 1}).eq('id', oldBusId);
            }
          }
        }
        await _db
            .from('student_transport_requests')
            .update({
              'route_id': routeId,
              'status': 'approved',
              'bus_id': allocatedBusId,
              'stop_name': stopName,
              'fee_amount': feeAmount,
              'fee_status': 'not_paid',
              'requested_at': DateTime.now().toIso8601String(),
              'processed_at': DateTime.now().toIso8601String(),
              'processed_by': 'system_auto',
              'remarks': 'Auto-assigned on first come basis',
            })
            .eq('id', existing['id']);
      } else {
        // Insert new request
        await _db.from('student_transport_requests').insert({
          'student_id': studentId,
          'student_name': studentName,
          'route_id': routeId,
          'status': 'approved',
          'bus_id': allocatedBusId,
          'stop_name': stopName,
          'fee_amount': feeAmount,
          'fee_status': 'not_paid',
          'processed_at': DateTime.now().toIso8601String(),
          'processed_by': 'system_auto',
          'remarks': 'Auto-assigned on first come basis',
        });
      }

      // Upsert into bus_fee_enrollment for fees module
      final feeExisting = await _db.from('bus_fee_enrollment').select().eq('student_id', studentId).maybeSingle();
      if (feeExisting != null) {
        await _db.from('bus_fee_enrollment').update({'bus_fee': feeAmount}).eq('student_id', studentId);
      } else {
        await _db.from('bus_fee_enrollment').insert({'student_id': studentId, 'bus_fee': feeAmount});
      }

      return {'success': true, 'message': 'Transport allocated successfully! Stop: $stopName, Fee: ₹$feeAmount'};
    } catch (e) {
      print('Error submitting transport request: $e');
      return {'success': false, 'message': 'An internal error occurred.'};
    }
  }

  // ─── OFFICER FUNCTIONS ────────────────────────────────────

  /// Get all pending requests (for transport officer)
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      return List<Map<String, dynamic>>.from(await _db
          .from('student_transport_requests')
          .select()
          .eq('status', 'pending')
          .eq('is_active', true)
          .order('requested_at'));
    } catch (_) {
      return [];
    }
  }

  /// Get all requests (for transport officer)
  Future<List<Map<String, dynamic>>> getAllRequests() async {
    try {
      return List<Map<String, dynamic>>.from(await _db
          .from('student_transport_requests')
          .select()
          .eq('is_active', true)
          .order('requested_at', ascending: false));
    } catch (_) {
      return [];
    }
  }

  /// Officer allocates a bus to a student
  Future<bool> allocateBus({
    required String requestId,
    required String busId,
    required String officerUsername,
    String? remarks,
  }) async {
    try {
      await _db.from('student_transport_requests').update({
        'bus_id': busId,
        'status': 'approved',
        'processed_at': DateTime.now().toIso8601String(),
        'processed_by': officerUsername,
        'remarks': remarks,
      }).eq('id', requestId);

      // Increment bus occupancy
      final bus = await _db
          .from('transport_buses')
          .select()
          .eq('id', busId)
          .single();
      final currentOcc = (bus['current_occupancy'] ?? 0) as int;
      await _db
          .from('transport_buses')
          .update({'current_occupancy': currentOcc + 1}).eq('id', busId);

      return true;
    } catch (e) {
      print('Error allocating bus: $e');
      return false;
    }
  }

  /// Officer rejects a request
  Future<bool> rejectRequest({
    required String requestId,
    required String officerUsername,
    String? remarks,
  }) async {
    try {
      await _db.from('student_transport_requests').update({
        'status': 'rejected',
        'processed_at': DateTime.now().toIso8601String(),
        'processed_by': officerUsername,
        'remarks': remarks ?? 'Request rejected by transport officer',
      }).eq('id', requestId);
      return true;
    } catch (e) {
      print('Error rejecting request: $e');
      return false;
    }
  }

  /// Get route details by ID
  Future<Map<String, dynamic>?> getRouteById(String routeId) async {
    try {
      return await _db
          .from('transport_routes')
          .select()
          .eq('id', routeId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Get bus details by ID
  Future<Map<String, dynamic>?> getBusById(String busId) async {
    try {
      return await _db
          .from('transport_buses')
          .select()
          .eq('id', busId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
  // ─── CONDUCTOR FUNCTIONS ──────────────────────────────────

  /// Get the bus assigned to a conductor
  Future<Map<String, dynamic>?> getConductorBus(String username) async {
    try {
      return await _db
          .from('transport_buses')
          .select('*, transport_routes(*)')
          .eq('conductor_username', username)
          .maybeSingle();
    } catch (e) {
      print('Error getting conductor bus: $e');
      return null;
    }
  }

  /// Get all students assigned to a specific bus
  Future<List<Map<String, dynamic>>> getBusStudents(String busId) async {
    try {
      return List<Map<String, dynamic>>.from(await _db
          .from('student_transport_requests')
          .select()
          .eq('bus_id', busId)
          .eq('status', 'approved')
          .eq('is_active', true)
          .order('student_name'));
    } catch (e) {
      print('Error getting bus students: $e');
      return [];
    }
  }

  /// Get attendance records for a specific bus and date
  Future<List<Map<String, dynamic>>> getAttendanceForDate(String busId, String dateStr) async {
    try {
      return List<Map<String, dynamic>>.from(await _db
          .from('transport_attendance')
          .select()
          .eq('bus_id', busId)
          .eq('attendance_date', dateStr));
    } catch (e) {
      print('Error getting attendance: $e');
      return [];
    }
  }

  /// Mark attendance for a student
  Future<bool> markAttendance({
    required String busId,
    required String dateStr,
    required String studentId,
    required String studentName,
    required bool isPresent,
    required String conductorUsername,
  }) async {
    try {
      // Upsert attendance record
      final existing = await _db
          .from('transport_attendance')
          .select()
          .eq('bus_id', busId)
          .eq('attendance_date', dateStr)
          .eq('student_id', studentId)
          .maybeSingle();

      if (existing != null) {
        await _db.from('transport_attendance').update({
          'is_present': isPresent,
          'marked_by': conductorUsername,
        }).eq('id', existing['id']);
      } else {
        await _db.from('transport_attendance').insert({
          'bus_id': busId,
          'attendance_date': dateStr,
          'student_id': studentId,
          'student_name': studentName,
          'is_present': isPresent,
          'marked_by': conductorUsername,
        });
      }
      return true;
    } catch (e) {
      print('Error marking attendance: $e');
      return false;
    }
  }

  /// Bulk mark attendance
  Future<bool> markBulkAttendance({
    required String busId,
    required String dateStr,
    required List<String> presentStudentIds,
    required List<String> absentStudentIds,
    required String conductorUsername,
  }) async {
    try {
      for (final id in presentStudentIds) {
        await markAttendance(
          busId: busId, dateStr: dateStr, studentId: id, studentName: 'Bulk', isPresent: true, conductorUsername: conductorUsername);
      }
      for (final id in absentStudentIds) {
        await markAttendance(
          busId: busId, dateStr: dateStr, studentId: id, studentName: 'Bulk', isPresent: false, conductorUsername: conductorUsername);
      }
      return true;
    } catch (e) {
      print('Error in bulk attendance: $e');
      return false;
    }
  }

  // ─── ADVANCED CONDUCTOR FEATURES ──────────────────────────

  /// Update bus trip status
  Future<bool> updateBusStatus(String busId, String status) async {
    try {
      final updates = <String, dynamic>{'trip_status': status};
      if (status == 'In Transit') {
        updates['last_trip_start'] = DateTime.now().toIso8601String();
      } else if (status == 'At Depot') {
        updates['last_trip_end'] = DateTime.now().toIso8601String();
      }
      
      await _db.from('transport_buses').update(updates).eq('id', busId);
      return true;
    } catch (e) {
      print('Error updating bus status: $e');
      return false;
    }
  }

  /// Report an issue (delay/breakdown)
  Future<bool> reportIssue({
    required String busId,
    required String conductorUsername,
    required String alertType,
    required String description,
  }) async {
    try {
      await _db.from('transport_alerts').insert({
        'bus_id': busId,
        'reported_by': conductorUsername,
        'alert_type': alertType,
        'description': description,
      });
      return true;
    } catch (e) {
      print('Error reporting issue: $e');
      return false;
    }
  }

  /// Get active alerts for transport officer
  Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db.from('transport_alerts')
                 .select('*, transport_buses(*)')
                 .eq('status', 'Active')
                 .order('created_at', ascending: false)
      );
    } catch (_) {
      return [];
    }
  }

  /// Resolve an alert
  Future<bool> resolveAlert(String alertId, String officerUsername) async {
    try {
      await _db.from('transport_alerts').update({
        'status': 'Resolved',
        'resolved_at': DateTime.now().toIso8601String(),
        'resolved_by': officerUsername,
      }).eq('id', alertId);
      return true;
    } catch (e) {
      print('Error resolving alert: $e');
      return false;
    }
  }
}

