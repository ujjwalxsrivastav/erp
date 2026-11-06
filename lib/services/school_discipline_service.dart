import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';
import 'auth_service.dart';
import 'school_permission_service.dart';

class SchoolDisciplineService {
  static final SchoolDisciplineService _instance = SchoolDisciplineService._internal();
  factory SchoolDisciplineService() => _instance;
  SchoolDisciplineService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolPayrollService _payroll = SchoolPayrollService();
  final SchoolPermissionService _permissions = SchoolPermissionService();

  Future<(String, String)> _actor(String permission) async {
    final username = await AuthService().getCurrentUsername() ?? '';
    if (username.isEmpty) throw Exception('Sign in to use discipline tools.');
    final role = (await _permissions.getLiveUserRole(username) ?? '').toLowerCase();
    await _permissions.enforce(feature: 'discipline', requiredPermission: permission, username: username);
    return (username, role);
  }

  Future<List<Map<String, dynamic>>> _assignedClassRows(String username) async {
    final rows = <String, Map<String, dynamic>>{};
    final ownClasses = await _supabase.from('school_classes').select('id,name,section').eq('class_teacher_id', username);
    for (final row in List<Map<String, dynamic>>.from(ownClasses)) {
      rows[row['id']?.toString() ?? ''] = row;
    }
    final mappings = await _supabase.from('school_teacher_classes').select('class_id').eq('teacher_username', username);
    final ids = List<Map<String, dynamic>>.from(mappings).map((m) => m['class_id']?.toString() ?? '').where((v) => v.isNotEmpty).toSet().where((id) => !rows.containsKey(id)).toList();
    if (ids.isNotEmpty) {
      final mapped = await _supabase.from('school_classes').select('id,name,section').inFilter('id', ids);
      for (final row in List<Map<String, dynamic>>.from(mapped)) {
        rows[row['id']?.toString() ?? ''] = row;
      }
    }
    rows.remove('');
    return rows.values.toList();
  }

  // ==========================================
  // 1. INCIDENT REPORTING & CASE REGISTER
  // ==========================================

  Future<List<Map<String, dynamic>>> getIncidents({
    String? category,
    String? severity,
    String? status,
    String? studentId,
  }) async {
    final (actor, role) = await _actor('view');
    if (role == 'student' || role == 'sstudent') {
      final student = await _supabase.from('school_students').select('id').eq('username', actor).maybeSingle();
      studentId = student?['id']?.toString() ?? actor;
    }
    if (role == 'parent' || role == 'sparent') throw Exception('Use the linked-child discipline view.');
    try {
      var query = _supabase.from('school_discipline_incidents').select();
      if (role == 'teacher' || role == 'steacher' || role == 'class_teacher') {
        final rows = await _assignedClassRows(actor);
        if (rows.isEmpty) return [];
        final sections = rows.map((c) {
          final name = c['name']?.toString() ?? '';
          final section = c['section']?.toString() ?? '';
          if (section.isEmpty || name.toLowerCase().endsWith('-${section.toLowerCase()}')) return name;
          return '$name-$section';
        }).where((v) => v.isNotEmpty).toSet().toList();
        if (sections.isEmpty) return [];
        query = query.inFilter('class_section', sections);
      } else if (role == 'warden') {
        final allocations = await _supabase.from('school_hostel_allocations').select('student_id').eq('status', 'Active');
        final studentKeys = List<Map<String, dynamic>>.from(allocations).map((s) => s['student_id']?.toString() ?? '').where((v) => v.isNotEmpty).toSet().toList();
        final students = studentKeys.isEmpty ? <Map<String, dynamic>>[] : List<Map<String, dynamic>>.from(await _supabase.from('school_students').select('id').inFilter('username', studentKeys));
        final ids = {...studentKeys, ...students.map((s) => s['id']?.toString() ?? '').where((v) => v.isNotEmpty)}.toList();
        if (ids.isEmpty) return [];
        query = query.inFilter('student_id', ids);
      }
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
      rethrow;
    }
  }

  Future<Map<String, dynamic>> reportIncident(Map<String, dynamic> data) async {
    final (actor, role) = await _actor('edit');
    if (!{'teacher', 'steacher', 'class_teacher', 'warden', 'admin', 'sadmin', 'principal', 'superadmin'}.contains(role)) throw Exception('This role cannot report incidents.');
    final studentId = data['student_id']?.toString() ?? '';
    if (studentId.isEmpty || (data['description']?.toString() ?? '').trim().isEmpty) throw Exception('Student identity and factual incident description are required.');
    final student = await _supabase.from('school_students').select().or('id.eq.$studentId,username.eq.$studentId').maybeSingle();
    if (student == null) throw Exception('Select a student record that exists in this school.');
    final studentClassId = student['class_id']?.toString() ?? '';
    if (role == 'teacher' || role == 'steacher' || role == 'class_teacher') {
      final assigned = await _assignedClassRows(actor);
      final assignedIds = assigned.map((c) => c['id']?.toString() ?? '').toSet();
      final assignedNames = assigned.map((c) => c['name']?.toString().toLowerCase() ?? '').toSet();
      if (!assignedIds.contains(studentClassId) && !assignedNames.contains((student['class_name']?.toString() ?? '').toLowerCase())) throw Exception('You can report incidents only for students in your assigned classes.');
    }
    if (role == 'warden') {
      final allocation = await _supabase.from('school_hostel_allocations').select('student_id').eq('status', 'Active').eq('student_id', student['username']?.toString() ?? studentId).maybeSingle();
      if (allocation == null) throw Exception('Wardens can report incidents only for currently allocated hostel students.');
    }
    final payload = {
      'institute_id': 'SHIV-SCH',
      'incident_number': 'INC-2026-${(100 + (DateTime.now().millisecondsSinceEpoch % 900))}',
      'student_id': student['id']?.toString() ?? studentId,
      'student_name': student['name'] ?? data['student_name'],
      'class_section': student['class_section'] ?? student['class_name'] ?? data['class_section'] ?? '',
      'incident_date': data['incident_date'] ?? DateTime.now().toIso8601String(),
      'location': data['location'] ?? '',
      'category': data['category'] ?? 'Classroom Disruption',
      'severity': data['severity'] ?? 'Medium',
      'description': data['description'],
      'reported_by_id': actor,
      'reported_by_name': actor,
      'reported_by_role': role,
      if ((data['witnesses']?.toString() ?? '').trim().isNotEmpty) 'witnesses': data['witnesses'],
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
      rethrow;
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
  }) async {
    final (actor, role) = await _actor('edit');
    if (!{'teacher', 'steacher', 'class_teacher', 'admin', 'sadmin', 'principal', 'superadmin'}.contains(role)) throw Exception('This role cannot record an inquiry.');
    if (findings.trim().isEmpty || (studentStatement ?? '').trim().isEmpty || (teacherStatement ?? '').trim().isEmpty) throw Exception('Type the findings and both statements before saving.');
    final incident = await _supabase.from('school_discipline_incidents').select('class_section').eq('id', incidentId).maybeSingle();
    if (incident == null) throw Exception('Incident record not found.');
    if (role == 'teacher' || role == 'steacher' || role == 'class_teacher') {
      final own = await getIncidentsForClassTeacher(teacherUsername: actor);
      if (!own.any((row) => row['id']?.toString() == incidentId)) throw Exception('This incident is outside your assigned classes.');
    } else if (!{'admin', 'sadmin', 'principal', 'superadmin'}.contains(role)) {
      throw Exception('This role cannot investigate discipline incidents.');
    }
    final payload = {
      'institute_id': 'SHIV-SCH',
      'incident_id': incidentId,
      'inquiry_date': DateTime.now().toIso8601String(),
      'officer_name': actor,
      'officer_role': role,
      'student_statement': studentStatement,
      'teacher_statement': teacherStatement,
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
      rethrow;
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
    int durationDays = 0,
  }) async {
    final (actor, liveRole) = await _actor('approve');
    final authorizedById = actor;
    final authorizedRole = liveRole;
    if (!{'admin', 'sadmin', 'principal', 'superadmin'}.contains(liveRole)) throw Exception('Only school leadership can take disciplinary action.');
    final incident = await _supabase.from('school_discipline_incidents').select('student_id').eq('id', incidentId).maybeSingle();
    if (incident == null || incident['student_id']?.toString() != studentId) throw Exception('The action student must match the incident record.');
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
      rethrow;
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
    final (actor, role) = await _actor('approve');
    if (!{'admin', 'sadmin', 'principal', 'superadmin'}.contains(role)) throw Exception('Only school leadership can send parent discipline notices.');
    final incident = await _supabase.from('school_discipline_incidents').select('student_id').eq('id', incidentId).maybeSingle();
    if (incident == null || incident['student_id']?.toString() != studentId) throw Exception('Notice recipient must match the incident student.');
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
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getParentDisciplineNotices(String studentId) async {
    final current = await AuthService().getCurrentUsername() ?? '';
    final role = (await _permissions.getLiveUserRole(current) ?? '').toLowerCase();
    if (role == 'student' || role == 'sstudent') {
      final student = await _supabase.from('school_students').select('id').eq('username', current).maybeSingle();
      if ((student?['id']?.toString() ?? current) != studentId) throw Exception('Students can only read their own notices.');
    } else if (role == 'parent' || role == 'sparent') {
      final student = await _supabase.from('school_students').select('username').eq('id', studentId).maybeSingle();
      final childUsername = student?['username']?.toString() ?? studentId;
      final link = await _supabase.from('parent_student_links').select('student_username').eq('parent_username', current).eq('student_username', childUsername).maybeSingle();
      if (link == null) throw Exception('This notice is outside your linked child.');
    } else {
      throw Exception('Only a student or linked parent may read discipline notices.');
    }
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

  Future<List<Map<String, dynamic>>> getIncidentsForClassTeacher({required String teacherUsername}) async {
    final current = await AuthService().getCurrentUsername() ?? '';
    if (current != teacherUsername) throw Exception('Teacher identity must match the signed-in account.');
    final role = (await _permissions.getLiveUserRole(current) ?? '').toLowerCase();
    if (!{'teacher', 'steacher', 'class_teacher'}.contains(role)) throw Exception('Teacher role required.');
    final classes = await _assignedClassRows(current);
    final sections = classes.map((c) {
      final name = c['name']?.toString() ?? '';
      final section = c['section']?.toString() ?? '';
      if (section.isEmpty || name.toLowerCase().endsWith('-${section.toLowerCase()}')) return name;
      return '$name-$section';
    }).where((v) => v.isNotEmpty).toList();
    if (sections.isEmpty) return [];
    final rows = await _supabase.from('school_discipline_incidents').select().inFilter('class_section', sections).order('incident_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getMyDisciplineNotices({required String username, required String role, String? studentUsername}) async {
    final current = await AuthService().getCurrentUsername() ?? '';
    if (current != username) throw Exception('Discipline view identity must match the signed-in user.');
    final liveRole = (await _permissions.getLiveUserRole(current) ?? '').toLowerCase();
    final isStudent = liveRole == 'student' || liveRole == 'sstudent';
    final isParent = liveRole == 'parent' || liveRole == 'sparent';
    if (!isStudent && !isParent) throw Exception('This role cannot view student discipline notices.');
    final target = isStudent ? current : (studentUsername ?? '');
    if (target.isEmpty) return [];
    if (isStudent && target != current) throw Exception('Students can only view their own notices.');
    if (isParent) {
      final link = await _supabase.from('parent_student_links').select('student_username').eq('parent_username', current).eq('student_username', target).maybeSingle();
      if (link == null) throw Exception('This student is not linked to your account.');
    }
    final student = await _supabase.from('school_students').select('id,username').eq('username', target).maybeSingle();
    if (student == null) return [];
    return getParentDisciplineNotices(student['id']?.toString() ?? target);
  }

  Future<List<Map<String, dynamic>>> getMyDisciplineIncidents({required String username, String? studentUsername}) async {
    final current = await AuthService().getCurrentUsername() ?? '';
    if (current != username) throw Exception('Discipline view identity must match the signed-in user.');
    final role = (await _permissions.getLiveUserRole(current) ?? '').toLowerCase();
    final target = (role == 'student' || role == 'sstudent') ? current : (studentUsername ?? '');
    if (role != 'student' && role != 'sstudent' && role != 'parent' && role != 'sparent') throw Exception('This role cannot view student incident summaries.');
    if (target.isEmpty) return [];
    if (role == 'parent' || role == 'sparent') {
      final link = await _supabase.from('parent_student_links').select('student_username').eq('parent_username', current).eq('student_username', target).maybeSingle();
      if (link == null) throw Exception('This student is not linked to your account.');
    }
    final student = await _supabase.from('school_students').select('id,username').eq('username', target).maybeSingle();
    if (student == null) return [];
    final id = student['id']?.toString() ?? target;
    final rows = await _supabase.from('school_discipline_incidents').select('id,incident_number,incident_date,category,severity,status,description').eq('student_id', id).order('incident_date', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> acknowledgeDisciplineNotice({required String noticeId}) async {
    final (actor, role) = await _actor('view');
    if (!{'student', 'sstudent', 'parent', 'sparent'}.contains(role)) throw Exception('Only a student or linked parent can acknowledge a notice.');
    final notice = await _supabase.from('school_discipline_parent_notices').select('student_id').eq('id', noticeId).maybeSingle();
    if (notice == null) throw Exception('Notice not found.');
    final studentId = notice['student_id']?.toString() ?? '';
    if (role == 'parent' || role == 'sparent') {
      final linked = await _supabase.from('parent_student_links').select('student_username').eq('parent_username', actor).eq('student_username', studentId).maybeSingle();
      if (linked == null) {
        final student = await _supabase.from('school_students').select('username').eq('id', studentId).maybeSingle();
        final username = student?['username']?.toString() ?? '';
        final actualLink = await _supabase.from('parent_student_links').select('student_username').eq('parent_username', actor).eq('student_username', username).maybeSingle();
        if (actualLink == null) throw Exception('This notice is outside your linked child.');
      }
    } else {
      final student = await _supabase.from('school_students').select('username').eq('id', studentId).maybeSingle();
      if (student?['username']?.toString() != actor) throw Exception('This notice belongs to another student.');
    }
    await _supabase.from('school_discipline_parent_notices').update({'parent_read': true, 'parent_read_at': DateTime.now().toIso8601String()}).eq('id', noticeId);
  }
}
