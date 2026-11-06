import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';

class SchoolActivitiesService {
  static final SchoolActivitiesService _instance = SchoolActivitiesService._internal();
  factory SchoolActivitiesService() => _instance;
  SchoolActivitiesService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolPayrollService _payroll = SchoolPayrollService();

  // ==========================================
  // 1. SCHOOL EVENTS & MEETS
  // ==========================================

  Future<List<Map<String, dynamic>>> getActivityEvents({
    String? category,
    bool? upcomingOnly,
  }) async {
    try {
      var query = _supabase.from('school_activity_events').select();
      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }
      final res = await query.order('event_date', ascending: true);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) {
        if (upcomingOnly == true) {
          final now = DateTime.now().toIso8601String().split('T')[0];
          return list.where((e) => (e['event_date']?.toString() ?? '').compareTo(now) >= 0).toList();
        }
        return list;
      }
    } catch (_) {}

    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'ActivityEvent')
          .order('published_at', ascending: false);
      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          c['id'] = r['id'];
          list.add(c);
        } catch (_) {}
      }
      if (list.isNotEmpty) {
        var filtered = list;
        if (category != null && category != 'All') {
          filtered = filtered.where((e) => e['category'] == category).toList();
        }
        return filtered;
      }
    } catch (_) {}

    return [];
  }

  Future<Map<String, dynamic>> createActivityEvent(Map<String, dynamic> event) async {
    final payload = {
      'institute_id': 'SHIV-SCH',
      'title': event['title'],
      'category': event['category'] ?? 'Cultural',
      'event_date': event['event_date'] ?? DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0],
      'venue': event['venue'] ?? 'School Main Grounds',
      'coordinator_teacher_id': event['coordinator_teacher_id'] ?? 'steacher1',
      'coordinator_teacher_name': event['coordinator_teacher_name'] ?? 'Ms. Sunita Sharma',
      'eligibility_classes': event['eligibility_classes'] ?? ['All'],
      'max_participants': event['max_participants'] ?? 100,
      'status': 'Upcoming',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_activity_events').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'create_event',
        entity: 'school_activity_events',
        entityId: res['id']?.toString() ?? 'evt',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Activity Event: ${payload['title']}',
        'content': jsonEncode(payload),
        'category': 'ActivityEvent',
        'target_audience': 'Students',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'act-evt-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  // ==========================================
  // 2. CLUBS & SOCIETIES
  // ==========================================

  Future<List<Map<String, dynamic>>> getClubs() async {
    try {
      final res = await _supabase.from('school_clubs').select().order('name', ascending: true);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'SchoolClub')
          .order('published_at', ascending: false);
      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          c['id'] = r['id'];
          list.add(c);
        } catch (_) {}
      }
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return [];
  }

  Future<Map<String, dynamic>> joinClub({
    required String clubId,
    required String studentId,
    required String studentName,
    required String classSection,
    String role = 'Member',
  }) async {
    final payload = {
      'institute_id': 'SHIV-SCH',
      'club_id': clubId,
      'student_id': studentId,
      'student_name': studentName,
      'class_section': classSection,
      'role': role,
      'joined_date': DateTime.now().toIso8601String().split('T')[0],
      'approval_status': 'Approved',
      'approved_by': 'sadmin1',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_club_memberships').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'join_club',
        entity: 'school_club_memberships',
        entityId: res['id']?.toString() ?? 'member',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Club Membership: $studentName in Club $clubId',
        'content': jsonEncode(payload),
        'category': 'ClubMembership',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'mem-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  // ==========================================
  // 3. SPORTS TEAMS & ATHLETICS
  // ==========================================

  Future<List<Map<String, dynamic>>> getSportsTeams() async {
    try {
      final res = await _supabase.from('school_sports_teams').select().order('sport_name', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // 4. PARTICIPATIONS & ACCREDITED CERTIFICATES
  // ==========================================

  Future<Map<String, dynamic>> recordParticipation({
    required String eventId,
    required String studentId,
    required String studentName,
    required String classSection,
    required String activityType,
    String roleOrItem = 'Contestant',
    String positionAward = 'Participant',
  }) async {
    final payload = {
      'institute_id': 'SHIV-SCH',
      'event_id': eventId,
      'student_id': studentId,
      'student_name': studentName,
      'class_section': classSection,
      'activity_type': activityType,
      'role_or_item': roleOrItem,
      'position_award': positionAward,
      'certificate_serial': 'CERT-ACT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 10000}',
      'certificate_issued': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_activity_participations').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'record_participation',
        entity: 'school_activity_participations',
        entityId: res['id']?.toString() ?? 'part',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Activity Participation: $studentName ($positionAward)',
        'content': jsonEncode(payload),
        'category': 'ActivityParticipation',
        'target_audience': 'Students',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'part-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  Future<List<Map<String, dynamic>>> getParticipations({
    String? studentId,
    String? eventId,
  }) async {
    try {
      var query = _supabase.from('school_activity_participations').select();
      if (studentId != null) {
        query = query.eq('student_id', studentId);
      }
      if (eventId != null) {
        query = query.eq('event_id', eventId);
      }
      final res = await query.order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'ActivityParticipation')
          .order('published_at', ascending: false);
      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          c['id'] = r['id'];
          list.add(c);
        } catch (_) {}
      }
      if (list.isNotEmpty) {
        var filtered = list;
        if (studentId != null) {
          filtered = filtered.where((p) => p['student_id'] == studentId).toList();
        }
        return filtered;
      }
    } catch (_) {}

    return [];
  }
}
