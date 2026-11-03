import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin workflow service — No-Dues clearance, Certificate issuance and
/// the central Grievance centre.
///
/// Follows the same pattern as FinanceService: a plain class over
/// `Supabase.instance.client`, try/catch with print, and safe defaults
/// (empty list / false / null / zeroed map) so screens never crash on a
/// backend error. Tables are created by
/// `run karwade/02_admin_nodues_certificates.sql`.
class AdminWorkflowService {
  final _supabase = Supabase.instance.client;

  /// Departments that must clear every No-Dues request, in display order.
  static const List<String> noDuesDepartments = [
    'library',
    'hostel',
    'transport',
    'laboratory',
    'examination',
    'finance',
    'store',
    'it',
    'sports',
  ];

  static const List<String> noDuesReasons = [
    'completion',
    'tc',
    'withdrawal',
    'degree',
  ];

  static const List<String> certificateTypes = [
    'bonafide',
    'character',
    'transfer',
    'migration',
    'course_completion',
    'provisional',
    'transcript',
  ];

  static const List<String> deliveryModes = ['collect', 'post', 'digilocker'];

  static const List<String> grievanceCategories = [
    'academic',
    'admission',
    'examination',
    'hostel',
    'transport',
    'ragging',
    'icc',
    'sc_st',
    'fee',
    'infrastructure',
    'other',
  ];

  // ============================================================
  // NO-DUES
  // ============================================================

  /// Opens a No-Dues case for [studentId] and creates one pending
  /// clearance row for each of the 9 departments. Returns the created
  /// request row, or null on failure.
  Future<Map<String, dynamic>?> initiateNoDues(
      String studentId, String reason) async {
    try {
      final request = await _supabase
          .from('nodues_requests')
          .insert({
            'student_id': studentId,
            'reason': reason,
            'status': 'pending',
          })
          .select()
          .single();

      final rows = noDuesDepartments
          .map((dept) => {
                'request_id': request['id'],
                'department': dept,
                'status': 'pending',
                'due_amount': 0,
              })
          .toList();
      await _supabase.from('nodues_clearances').insert(rows);
      return Map<String, dynamic>.from(request);
    } catch (e) {
      print('Initiate No-Dues error: $e');
      return null;
    }
  }

  /// All No-Dues requests, newest first. Pass [status] to filter.
  Future<List<Map<String, dynamic>>> getNoDuesRequests({String? status}) async {
    try {
      var query = _supabase.from('nodues_requests').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get No-Dues requests error: $e');
      return [];
    }
  }

  /// Department clearance rows for one No-Dues request.
  Future<List<Map<String, dynamic>>> getClearances(String requestId) async {
    try {
      final r = await _supabase
          .from('nodues_clearances')
          .select()
          .eq('request_id', requestId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get clearances error: $e');
      return [];
    }
  }

  /// Updates one department clearance. When every department of the
  /// parent request is 'clear', the request is automatically marked
  /// 'cleared' with completed_at set.
  Future<bool> updateClearance({
    required String id,
    required String status,
    double? dueAmount,
    String? remarks,
    String? clearedBy,
  }) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (dueAmount != null) update['due_amount'] = dueAmount;
      if (status == 'clear') {
        update['due_amount'] = dueAmount ?? 0;
        update['cleared_at'] = DateTime.now().toIso8601String();
        if (clearedBy != null) update['cleared_by'] = clearedBy;
      } else {
        update['cleared_at'] = null;
      }
      if (remarks != null) update['remarks'] = remarks;

      final row = await _supabase
          .from('nodues_clearances')
          .update(update)
          .eq('id', id)
          .select('request_id')
          .single();
      final requestId = row['request_id'] as String;

      // Re-evaluate the parent request.
      final clearances = await getClearances(requestId);
      final allClear =
          clearances.isNotEmpty && clearances.every((c) => c['status'] == 'clear');
      if (allClear) {
        await _supabase.from('nodues_requests').update({
          'status': 'cleared',
          'completed_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', requestId);
      } else {
        // Any departmental action moves a fresh request to in_progress.
        await _supabase
            .from('nodues_requests')
            .update({
              'status': 'in_progress',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', requestId)
            .eq('status', 'pending');
      }
      return true;
    } catch (e) {
      print('Update clearance error: $e');
      return false;
    }
  }

  /// Latest No-Dues position for a student: the most recent request, its
  /// department clearances and summary counts / total due.
  Future<Map<String, dynamic>> getStudentNoDuesStatus(String studentId) async {
    try {
      final requests = await _supabase
          .from('nodues_requests')
          .select()
          .eq('student_id', studentId)
          .order('requested_at', ascending: false)
          .limit(1);
      if (requests.isEmpty) {
        return {
          'hasActiveRequest': false,
          'isCleared': false,
          'request': null,
          'clearances': <Map<String, dynamic>>[],
          'clearedCount': 0,
          'totalCount': 0,
          'totalDue': 0.0,
        };
      }
      final request = Map<String, dynamic>.from(requests.first);
      final clearances = await getClearances(request['id'] as String);
      double totalDue = 0;
      int clearedCount = 0;
      for (var c in clearances) {
        totalDue += (c['due_amount'] as num?)?.toDouble() ?? 0;
        if (c['status'] == 'clear') clearedCount++;
      }
      final status = request['status'] as String? ?? 'pending';
      return {
        'hasActiveRequest': status == 'pending' || status == 'in_progress',
        'isCleared': status == 'cleared',
        'request': request,
        'clearances': clearances,
        'clearedCount': clearedCount,
        'totalCount': clearances.length,
        'totalDue': totalDue,
      };
    } catch (e) {
      print('Student No-Dues status error: $e');
      return {
        'hasActiveRequest': false,
        'isCleared': false,
        'request': null,
        'clearances': <Map<String, dynamic>>[],
        'clearedCount': 0,
        'totalCount': 0,
        'totalDue': 0.0,
      };
    }
  }

  // ============================================================
  // CERTIFICATES
  // ============================================================

  /// Creates a certificate request. Returns the created row or null.
  Future<Map<String, dynamic>?> createCertificateRequest({
    required String studentId,
    required String certificateType,
    int copies = 1,
    String deliveryMode = 'collect',
    double feeAmount = 0,
    String? requestedBy,
    String? remarks,
  }) async {
    try {
      final res = await _supabase
          .from('certificate_requests')
          .insert({
            'student_id': studentId,
            'certificate_type': certificateType,
            'copies': copies,
            'delivery_mode': deliveryMode,
            'fee_amount': feeAmount,
            'status': 'requested',
            'requested_by': requestedBy,
            'remarks': remarks,
          })
          .select()
          .single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('Create certificate request error: $e');
      return null;
    }
  }

  /// All certificate requests, newest first. Pass [status] to filter.
  Future<List<Map<String, dynamic>>> getCertificateRequests(
      {String? status}) async {
    try {
      var query = _supabase.from('certificate_requests').select();
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get certificate requests error: $e');
      return [];
    }
  }

  /// Moves a certificate request to [status]. When the new status is
  /// 'issued' and the request has no serial number yet, one is generated
  /// in the format CERT-YYYY-#### (running count of issued certificates
  /// for the current year, checked for uniqueness).
  Future<bool> updateCertificateStatus({
    required String id,
    required String status,
    String? approvedBy,
  }) async {
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (approvedBy != null) update['approved_by'] = approvedBy;

      if (status == 'issued') {
        final row = await _supabase
            .from('certificate_requests')
            .select('serial_no')
            .eq('id', id)
            .single();
        if (row['serial_no'] == null) {
          update['serial_no'] = await _generateCertificateSerial();
        }
        update['issued_at'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('certificate_requests').update(update).eq('id', id);
      return true;
    } catch (e) {
      print('Update certificate status error: $e');
      return false;
    }
  }

  Future<String> _generateCertificateSerial() async {
    final year = DateTime.now().year;
    final prefix = 'CERT-$year-';
    final existing = await _supabase
        .from('certificate_requests')
        .select('serial_no')
        .like('serial_no', '$prefix%');
    final used = existing
        .map((r) => r['serial_no'] as String?)
        .where((s) => s != null)
        .toSet();
    int next = used.length + 1;
    var candidate = '$prefix${next.toString().padLeft(4, '0')}';
    while (used.contains(candidate)) {
      next++;
      candidate = '$prefix${next.toString().padLeft(4, '0')}';
    }
    return candidate;
  }

  /// All certificate requests of one student, newest first.
  Future<List<Map<String, dynamic>>> getCertificatesForStudent(
      String studentId) async {
    try {
      final r = await _supabase
          .from('certificate_requests')
          .select()
          .eq('student_id', studentId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get student certificates error: $e');
      return [];
    }
  }

  // ============================================================
  // GRIEVANCES
  // ============================================================

  /// Raises a grievance ticket. When [slaDueAt] is not given, the SLA
  /// defaults to 7 days from now (UGC SGRC acknowledgement/resolution
  /// window used by the admin centre). Returns the created row or null.
  Future<Map<String, dynamic>?> createGrievance({
    required String raisedBy,
    required String raisedByRole,
    required String category,
    required String subject,
    String? description,
    DateTime? slaDueAt,
  }) async {
    try {
      final res = await _supabase
          .from('grievance_tickets')
          .insert({
            'raised_by': raisedBy,
            'raised_by_role': raisedByRole,
            'category': category,
            'subject': subject,
            'description': description,
            'status': 'open',
            'sla_due_at': (slaDueAt ?? DateTime.now().add(const Duration(days: 7)))
                .toIso8601String(),
          })
          .select()
          .single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('Create grievance error: $e');
      return null;
    }
  }

  /// Grievance tickets, newest first. Filter by [category] and/or [status].
  Future<List<Map<String, dynamic>>> getGrievances({
    String? category,
    String? status,
  }) async {
    try {
      var query = _supabase.from('grievance_tickets').select();
      if (category != null) query = query.eq('category', category);
      if (status != null) query = query.eq('status', status);
      final r = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) {
      print('Get grievances error: $e');
      return [];
    }
  }

  /// Updates assignment / status / resolution of a ticket. Moving to
  /// 'resolved' or 'closed' stamps resolved_at.
  Future<bool> updateGrievance({
    required String id,
    String? status,
    String? assignedTo,
    String? resolution,
  }) async {
    try {
      final update = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status != null) {
        update['status'] = status;
        if (status == 'resolved' || status == 'closed') {
          update['resolved_at'] = DateTime.now().toIso8601String();
        }
      }
      if (assignedTo != null) update['assigned_to'] = assignedTo;
      if (resolution != null) update['resolution'] = resolution;
      await _supabase.from('grievance_tickets').update(update).eq('id', id);
      return true;
    } catch (e) {
      print('Update grievance error: $e');
      return false;
    }
  }

  // ============================================================
  // DASHBOARD STATS
  // ============================================================

  /// Counters for the Admin workflow centre: pending No-Dues requests,
  /// pending certificate requests, open grievances and SLA-overdue
  /// grievances (past sla_due_at and not resolved/closed).
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final nodues = await _supabase
          .from('nodues_requests')
          .select('id')
          .inFilter('status', ['pending', 'in_progress']);
      final certs = await _supabase
          .from('certificate_requests')
          .select('id')
          .inFilter('status', ['requested', 'processing']);
      final grievances = await _supabase
          .from('grievance_tickets')
          .select('status, sla_due_at')
          .inFilter('status', ['open', 'in_progress', 'escalated']);

      final now = DateTime.now();
      int overdue = 0;
      for (var g in grievances) {
        final sla = g['sla_due_at'] as String?;
        if (sla != null) {
          final due = DateTime.tryParse(sla);
          if (due != null && due.isBefore(now)) overdue++;
        }
      }

      return {
        'pendingNoDues': nodues.length,
        'pendingCertificates': certs.length,
        'openGrievances': grievances.length,
        'overdueGrievances': overdue,
      };
    } catch (e) {
      print('Admin workflow stats error: $e');
      return {
        'pendingNoDues': 0,
        'pendingCertificates': 0,
        'openGrievances': 0,
        'overdueGrievances': 0,
      };
    }
  }
}
