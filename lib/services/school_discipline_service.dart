import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';
import 'auth_service.dart';

class SchoolDisciplineService {
  static final SchoolDisciplineService _instance = SchoolDisciplineService._internal();
  factory SchoolDisciplineService() => _instance;
  SchoolDisciplineService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolPayrollService _payroll = SchoolPayrollService();

  // ==========================================
  // 1. INCIDENT REPORTING & CASE REGISTER
  // ==========================================

  Future<List<Map<String, dynamic>>> getIncidents({
    String? category,
    String? severity,
    String? status,
    String? studentId,
  }) async {
    try {
      var query = _supabase.from('school_discipline_incidents').select();
      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }
      if (severity != null && severity != 'All') {
        query = query.eq('severity', severity);
      }
      if (status != null && status != 'All') {
        query = query.eq('status', status);
      }
      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }
      final res = await query.order('incident_date', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> reportIncident(Map<String, dynamic> data) async {
    final actor = await AuthService().getCurrentUsername() ?? 'faculty';
    final payload = {
      'institute_id': 'SHIV-SCH',
      'incident_number': 'INC-2026-${(100 + (DateTime.now().millisecondsSinceEpoch % 900))}',
      'student_id': data['student_id'] ?? 'student',
      'student_name': data['student_name'] ?? 'Student',
      'class_section': data['class_section'] ?? '10-A',
      'incident_date': data['incident_date'] ?? DateTime.now().toIso8601String(),
      'location': data['location'] ?? 'Classroom',
      'category': data['category'] ?? 'Classroom Disruption',
      'severity': data['severity'] ?? 'Medium',
      'description': data['description'] ?? 'Incident reported by faculty.',
      'reported_by_id': data['reported_by_id'] ?? actor,
      'reported_by_name': data['reported_by_name'] ?? 'Reporting Faculty',
      'reported_by_role': data['reported_by_role'] ?? 'teacher',
      'witnesses': data['witnesses'] ?? 'Prefect / Staff',
      'status': 'Reported',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_discipline_incidents').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: actor,
        action: 'report_incident',
        entity: 'school_discipline_incidents',
        entityId: res['id']?.toString() ?? 'incident',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      payload['id'] = 'inc-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  // ==========================================
  // 2. INQUIRY & INVESTIGATION DESK
  // ==========================================

  Future<Map<String, dynamic>> recordInquiry({
    required String incidentId,
    required String findings,
    String? studentStatement,
    String? teacherStatement,
    String officerName = 'Principal / Disciplinary Committee',
  }) async {
    final actor = await AuthService().getCurrentUsername() ?? 'sadmin';
    final payload = {
      'institute_id': 'SHIV-SCH',
      'incident_id': incidentId,
      'inquiry_date': DateTime.now().toIso8601String(),
      'officer_name': officerName,
      'officer_role': 'Discipline Officer',
      'student_statement': studentStatement ?? 'Student cooperated and provided clarification.',
      'teacher_statement': teacherStatement ?? 'Teacher confirmed incident sequence.',
      'findings': findings,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_discipline_inquiries').insert(payload).select().single();
      await _supabase
          .from('school_discipline_incidents')
          .update({'status': 'Inquiring'})
          .eq('id', incidentId);

      await _payroll.logAudit(
        actorUsername: actor,
        action: 'record_inquiry',
        entity: 'school_discipline_inquiries',
        entityId: res['id']?.toString() ?? 'inq',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      payload['id'] = 'inq-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  // ==========================================
  // 3. ADMINISTRATIVE ACTIONS & SUSPENSION GATE
  // ==========================================

  Future<Map<String, dynamic>> recordDisciplinaryAction({
    required String incidentId,
    required String studentId,
    required String studentName,
    required String actionType,
    required String actionNotes,
    String authorizedById = 'sadmin1',
    String authorizedRole = 'principal',
    int durationDays = 0,
  }) async {
    // Role-gating standard S7.3: Suspension strictly restricted to 'principal' or 'sadmin'
    if (actionType.toLowerCase().contains('suspension')) {
      if (authorizedRole != 'principal' && authorizedRole != 'sadmin') {
        throw Exception('Role Unauthorized: Student suspension can ONLY be authorized by Principal or Superadmin.');
      }
    }

    final payload = {
      'institute_id': 'SHIV-SCH',
      'incident_id': incidentId,
      'student_id': studentId,
      'student_name': studentName,
      'action_type': actionType,
      'action_date': DateTime.now().toIso8601String().split('T')[0],
      'authorized_by_id': authorizedById,
      'authorized_by_role': authorizedRole,
      'duration_days': durationDays,
      'action_notes': actionNotes,
      'status': 'Active',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_discipline_actions').insert(payload).select().single();
      await _supabase
          .from('school_discipline_incidents')
          .update({'status': 'Resolved'})
          .eq('id', incidentId);

      await _payroll.logAudit(
        actorUsername: authorizedById,
        actorRole: authorizedRole,
        action: 'discipline_action',
        entity: 'school_discipline_actions',
        entityId: res['id']?.toString() ?? 'act',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      payload['id'] = 'act-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  // ==========================================
  // 4. PARENT DISCIPLINE NOTICES & AUDIT
  // ==========================================

  Future<Map<String, dynamic>> sendDisciplineParentNotice({
    required String incidentId,
    required String studentId,
    required String noticeTitle,
    required String noticeBody,
    DateTime? scheduledMeetingDate,
  }) async {
    final actor = await AuthService().getCurrentUsername() ?? 'admin';
    final payload = {
      'institute_id': 'SHIV-SCH',
      'incident_id': incidentId,
      'student_id': studentId,
      'notice_title': noticeTitle,
      'notice_body': noticeBody,
      'scheduled_meeting_date': scheduledMeetingDate?.toIso8601String(),
      'parent_read': false,
      'sent_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_discipline_parent_notices').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: actor,
        action: 'send_parent_discipline_notice',
        entity: 'school_discipline_parent_notices',
        entityId: res['id']?.toString() ?? 'notice',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      payload['id'] = 'pn-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  Future<List<Map<String, dynamic>>> getParentDisciplineNotices(String studentId) async {
    try {
      final res = await _supabase
          .from('school_discipline_parent_notices')
          .select()
          .eq('student_id', studentId)
          .order('sent_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }
}
