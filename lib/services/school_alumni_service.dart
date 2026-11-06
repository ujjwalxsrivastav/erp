import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'school_payroll_service.dart';

class SchoolAlumniService {
  static final SchoolAlumniService _instance = SchoolAlumniService._internal();
  factory SchoolAlumniService() => _instance;
  SchoolAlumniService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final SchoolPayrollService _payroll = SchoolPayrollService();

  // ==========================================
  // 1. ALUMNI DIRECTORY & PROFILES
  // ==========================================

  Future<List<Map<String, dynamic>>> getAlumniProfiles({
    int? passingYear,
    String? batch,
    String? search,
  }) async {
    try {
      var query = _supabase.from('school_alumni_profiles').select();
      if (passingYear != null) {
        query = query.eq('passing_year', passingYear);
      }
      if (batch != null && batch.isNotEmpty) {
        query = query.eq('batch_name', batch);
      }
      final res = await query.order('passing_year', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) {
        if (search != null && search.trim().isNotEmpty) {
          final s = search.toLowerCase();
          return list.where((a) =>
              (a['full_name']?.toString().toLowerCase().contains(s) ?? false) ||
              (a['organization_college']?.toString().toLowerCase().contains(s) ?? false) ||
              (a['designation_degree']?.toString().toLowerCase().contains(s) ?? false) ||
              (a['batch_name']?.toString().toLowerCase().contains(s) ?? false)
          ).toList();
        }
        return list;
      }
    } catch (_) {}

    // Resilient fallback to school_circulars
    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'AlumniProfile')
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
        if (search != null && search.trim().isNotEmpty) {
          final s = search.toLowerCase();
          return list.where((a) =>
              (a['full_name']?.toString().toLowerCase().contains(s) ?? false) ||
              (a['organization_college']?.toString().toLowerCase().contains(s) ?? false)
          ).toList();
        }
        return list;
      }
    } catch (_) {}

    // Return empty list if no profiles found
    return [];
  }

  Future<Map<String, dynamic>> registerAlumniProfile(Map<String, dynamic> data) async {
    final payload = {
      'institute_id': data['institute_id'] ?? 'SHIV-SCH',
      'student_id': data['student_id'],
      'full_name': data['full_name'],
      'passing_year': data['passing_year'] ?? DateTime.now().year,
      'batch_name': data['batch_name'] ?? 'Class of ${data['passing_year'] ?? DateTime.now().year}',
      'last_class_section': data['last_class_section'] ?? '12-A',
      'current_status': data['current_status'] ?? 'Higher Education',
      'organization_college': data['organization_college'] ?? '',
      'designation_degree': data['designation_degree'] ?? '',
      'city': data['city'] ?? 'Dehradun',
      'country': data['country'] ?? 'India',
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'linkedin_url': data['linkedin_url'] ?? '',
      'is_verified': true,
      'willing_to_mentor': data['willing_to_mentor'] == true,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_alumni_profiles').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'create',
        entity: 'school_alumni_profiles',
        entityId: res['id']?.toString() ?? 'alumni',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Alumni Profile: ${payload['full_name']}',
        'content': jsonEncode(payload),
        'category': 'AlumniProfile',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'alumni-${DateTime.now().millisecondsSinceEpoch}';
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'create',
        entity: 'school_alumni_profiles',
        entityId: payload['id'].toString(),
        newValue: payload,
      );
      return payload;
    }
  }

  // ==========================================
  // 2. ALUMNI EVENTS & REUNIONS
  // ==========================================

  Future<List<Map<String, dynamic>>> getAlumniEvents({bool activeOnly = true}) async {
    try {
      var query = _supabase.from('school_alumni_events').select();
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final res = await query.order('event_date', ascending: true);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'AlumniEvent')
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

  Future<Map<String, dynamic>> createAlumniEvent(Map<String, dynamic> event) async {
    final payload = {
      'institute_id': event['institute_id'] ?? 'SHIV-SCH',
      'title': event['title'],
      'event_type': event['event_type'] ?? 'Reunion',
      'event_date': event['event_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'venue': event['venue'] ?? 'School Main Auditorium',
      'mode': event['mode'] ?? 'In-Person',
      'meeting_link': event['meeting_link'],
      'description': event['description'] ?? '',
      'target_batches': event['target_batches'] ?? ['All'],
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_alumni_events').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'create',
        entity: 'school_alumni_events',
        entityId: res['id']?.toString() ?? 'event',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Alumni Event: ${payload['title']}',
        'content': jsonEncode(payload),
        'category': 'AlumniEvent',
        'target_audience': 'Alumni',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'event-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  // ==========================================
  // 3. RSVPs & PARTICIPATION
  // ==========================================

  Future<Map<String, dynamic>> submitAlumniRsvp({
    required String eventId,
    required String alumniName,
    required String alumniEmail,
    String status = 'Attending',
    int guestCount = 0,
    String notes = '',
  }) async {
    final payload = {
      'institute_id': 'SHIV-SCH',
      'event_id': eventId,
      'alumni_name': alumniName,
      'alumni_email': alumniEmail,
      'status': status,
      'guest_count': guestCount,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_alumni_rsvps').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'rsvp',
        entity: 'school_alumni_rsvps',
        entityId: res['id']?.toString() ?? 'rsvp',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Alumni RSVP: $alumniName ($status)',
        'content': jsonEncode(payload),
        'category': 'AlumniRsvp',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'rsvp-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  Future<List<Map<String, dynamic>>> getEventRsvps(String eventId) async {
    try {
      final res = await _supabase
          .from('school_alumni_rsvps')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'AlumniRsvp')
          .order('published_at', ascending: false);
      final list = <Map<String, dynamic>>[];
      for (final r in res) {
        try {
          final c = jsonDecode(r['content']?.toString() ?? '{}') as Map<String, dynamic>;
          if (c['event_id'] == eventId) {
            c['id'] = r['id'];
            list.add(c);
          }
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // 4. INSTITUTIONAL GIVING & CAUSES (INTEREST FORM ONLY)
  // Strictly interest form — NO MONEY COLLECTION
  // ==========================================

  Future<Map<String, dynamic>> submitDonationInterest({
    required String alumniName,
    required String alumniEmail,
    required String causeArea,
    required double pledgeAmountEstimate,
    String message = '',
  }) async {
    final payload = {
      'institute_id': 'SHIV-SCH',
      'alumni_name': alumniName,
      'alumni_email': alumniEmail,
      'cause_area': causeArea,
      'pledge_amount_estimate': pledgeAmountEstimate,
      'message': message,
      'status': 'Expressed Interest',
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase.from('school_alumni_donation_interests').insert(payload).select().single();
      await _payroll.logAudit(
        actorUsername: 'sadmin1',
        action: 'pledge_interest',
        entity: 'school_alumni_donation_interests',
        entityId: res['id']?.toString() ?? 'donation',
        newValue: payload,
      );
      return Map<String, dynamic>.from(res);
    } catch (_) {
      final circ = await _supabase.from('school_circulars').insert({
        'title': 'Donation Interest: $alumniName ($causeArea)',
        'content': jsonEncode(payload),
        'category': 'AlumniDonationInterest',
        'target_audience': 'Admin',
        'published_at': DateTime.now().toIso8601String(),
      }).select().maybeSingle();

      payload['id'] = circ?['id'] ?? 'pledge-${DateTime.now().millisecondsSinceEpoch}';
      return payload;
    }
  }

  Future<List<Map<String, dynamic>>> getDonationInterests() async {
    try {
      final res = await _supabase
          .from('school_alumni_donation_interests')
          .select()
          .order('created_at', ascending: false);
      final list = List<Map<String, dynamic>>.from(res);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final res = await _supabase
          .from('school_circulars')
          .select()
          .eq('category', 'AlumniDonationInterest')
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

  // ==========================================
  // 5. ALUMNI BROADCASTS & CIRCULARS
  // ==========================================

  Future<Map<String, dynamic>> sendAlumniCircular({
    required String title,
    required String content,
    String priority = 'Normal',
  }) async {
    final payload = {
      'title': title,
      'content': content,
      'category': 'Event',
      'target_audience': 'Alumni',
      'priority': priority,
      'published_by': 'Alumni Relations Officer',
      'published_at': DateTime.now().toIso8601String(),
      'is_active': true,
      'school_id': 'SCH001',
    };

    final res = await _supabase.from('school_circulars').insert(payload).select().maybeSingle();
    await _payroll.logAudit(
      actorUsername: 'sadmin1',
      action: 'broadcast_alumni',
      entity: 'school_circulars',
      entityId: res?['id']?.toString() ?? 'circ-alumni',
      newValue: payload,
    );
    return res ?? payload;
  }
}
