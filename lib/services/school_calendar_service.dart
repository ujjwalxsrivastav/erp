import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';
import 'school_service.dart';
import 'auth_service.dart';

class SchoolCalendarService {
  static final SchoolCalendarService _instance = SchoolCalendarService._internal();
  factory SchoolCalendarService() => _instance;
  SchoolCalendarService._internal();

  final SupabaseClient _supabase = SupabaseService.client;
  final _auth = AuthService();

  Future<(String, String)> _verifiedCalendarActor() async {
    final username = await _auth.getCurrentUsername() ?? '';
    if (username.isEmpty) throw Exception('Sign in to manage the academic calendar.');
    final role = (await _auth.getLiveUserRole(username) ?? '').toLowerCase();
    final normalized = role == 'sadmin' ? 'admin' : role;
    if (!{'admin', 'sadmin', 'principal', 'superadmin'}.contains(normalized)) {
      throw Exception('Only school leadership can manage academic calendar events.');
    }
    return (username, normalized);
  }

  /// Read only the calendar events this signed-in role and learner scope may see.
  Future<List<Map<String, dynamic>>> getEventsForScope({
    String academicYear = '2026-2027',
    String? category,
    String? targetAudience,
    String? studentUsername,
  }) async {
    final username = await _auth.getCurrentUsername() ?? '';
    if (username.isEmpty) throw Exception('Sign in to view the school calendar.');
    final live = (await _auth.getLiveUserRole(username) ?? '').toLowerCase();
    final role = live == 'sstudent' ? 'student' : live == 'sparent' ? 'parent' : live == 'steacher' ? 'teacher' : live == 'sadmin' ? 'admin' : live;
    const allowed = {'student', 'parent', 'teacher', 'class_teacher', 'admin', 'principal', 'superadmin', 'librarian', 'warden', 'nurse', 'accountant'};
    if (!allowed.contains(role)) throw Exception('This role cannot view the school calendar.');
    if ({'admin', 'principal', 'superadmin'}.contains(role)) {
      return getAcademicEvents(academicYear: academicYear, category: category, targetAudience: targetAudience);
    }

    final classes = <String>{};
    if (role == 'student' || role == 'parent') {
      final target = role == 'student' ? username : (studentUsername ?? '');
      if (target.isEmpty) return [];
      if (role == 'student' && target != username) throw Exception('Students can only view their own class calendar.');
      if (role == 'parent') {
        final link = await _supabase.from('parent_student_links').select('student_username').eq('parent_username', username).eq('student_username', target).maybeSingle();
        if (link == null) throw Exception('This student is not linked to your account.');
      }
      final student = await _supabase.from('school_students').select('class_id,class_name,section').eq('username', target).maybeSingle();
      if (student != null) {
        for (final key in [student['class_id'], student['class_name'], student['section']]) {
          final value = key?.toString().trim() ?? '';
          if (value.isNotEmpty) classes.add(value);
        }
        final name = student['class_name']?.toString() ?? '';
        final section = student['section']?.toString() ?? '';
        if (name.isNotEmpty && section.isNotEmpty) classes.add('$name-$section');
      }
    } else if (role == 'teacher' || role == 'class_teacher') {
      final own = await _supabase.from('school_classes').select('id,name,section').eq('class_teacher_id', username);
      for (final row in List<Map<String, dynamic>>.from(own)) {
        for (final key in [row['id'], row['name']]) {
          final value = key?.toString().trim() ?? '';
          if (value.isNotEmpty) classes.add(value);
        }
        final name = row['name']?.toString() ?? '';
        final section = row['section']?.toString() ?? '';
        if (name.isNotEmpty && section.isNotEmpty) classes.add('$name-$section');
      }
      final mappings = await _supabase.from('school_teacher_classes').select('class_id').eq('teacher_username', username);
      for (final mapping in List<Map<String, dynamic>>.from(mappings)) {
        final id = mapping['class_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        classes.add(id);
        final row = await _supabase.from('school_classes').select('name,section').eq('id', id).maybeSingle();
        if (row != null) {
          final name = row['name']?.toString() ?? '';
          final section = row['section']?.toString() ?? '';
          if (name.isNotEmpty) classes.add(name);
          if (name.isNotEmpty && section.isNotEmpty) classes.add('$name-$section');
        }
      }
    }

    final audience = role == 'student' ? 'students' : role == 'parent' ? 'parents' : (role == 'teacher' || role == 'class_teacher') ? 'teachers' : '';
    final allowedAudiences = audience.isEmpty ? const ['all'] : const ['all'];
    final requestedAudience = targetAudience ?? 'all';
    final targets = requestedAudience == 'all' ? (audience.isEmpty ? allowedAudiences : ['all', audience]) : (requestedAudience == audience ? [requestedAudience] : const <String>[]);
    if (targets.isEmpty) return [];

    final rows = <String, Map<String, dynamic>>{};
    Future<void> addQuery({List<String>? classValues}) async {
      var query = _supabase.from('school_academic_calendar').select()
          .eq('academic_year', academicYear).eq('is_published', true).inFilter('target_audience', targets);
      if (category != null && category.isNotEmpty && category != 'All') query = query.eq('category', category);
      if (classValues != null) query = query.contains('applicable_classes', classValues);
      final response = await query.order('start_date', ascending: true);
      for (final row in List<Map<String, dynamic>>.from(response)) {
        rows[row['id']?.toString() ?? '${row['title']}|${row['start_date']}'] = row;
      }
    }

    if (!SchoolService.isTableMissing('school_academic_calendar')) {
      try {
        await addQuery(classValues: ['All']);
        for (final classValue in classes) {
          await addQuery(classValues: [classValue]);
        }
      } catch (e) {
        if (e.toString().contains('404') || e.toString().contains('does not exist')) SchoolService.markTableMissing('school_academic_calendar');
        else rethrow;
      }
    }
    if (SchoolService.isTableMissing('school_academic_calendar') || rows.isEmpty) {
      final fallback = await _supabase.from('school_circulars').select()
          .eq('category', 'AcademicCalendarEvent').inFilter('target_audience', targets)
          .order('published_at', ascending: true);
      for (final circular in List<Map<String, dynamic>>.from(fallback)) {
        try {
          final decoded = jsonDecode(circular['content']?.toString() ?? '{}');
          if (decoded is! Map<String, dynamic> || decoded['academic_year'] != academicYear) continue;
          if (category != null && category.isNotEmpty && category != 'All' && decoded['category'] != category) continue;
          final applicable = List<String>.from(decoded['applicable_classes'] ?? const ['All']);
          if (!applicable.contains('All') && !applicable.any(classes.contains)) continue;
          final id = circular['id']?.toString() ?? '';
          rows[id.isEmpty ? '${decoded['title']}|${decoded['start_date']}' : id] = {'id': circular['id'], ...decoded};
        } catch (_) {}
      }
    }
    return rows.values.toList()..sort((a, b) => (a['start_date']?.toString() ?? '').compareTo(b['start_date']?.toString() ?? ''));
  }

  static const List<String> categories = [
    'Academic',
    'Examination',
    'Holiday',
    'PTM',
    'Co-Curricular',
    'Administrative',
  ];

  static const List<String> audiences = [
    'all',
    'students',
    'teachers',
    'parents',
  ];

  static const List<String> terms = [
    'Term 1',
    'Term 2',
    'Annual',
  ];

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'Holiday':
        return const Color(0xFFEF4444); // Red
      case 'Examination':
        return const Color(0xFF8B5CF6); // Purple
      case 'PTM':
        return const Color(0xFFEC4899); // Pink
      case 'Co-Curricular':
        return const Color(0xFF3B82F6); // Blue
      case 'Administrative':
        return const Color(0xFFF59E0B); // Amber
      case 'Academic':
      default:
        return const Color(0xFF10B981); // Emerald Green
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Holiday':
        return Icons.beach_access_rounded;
      case 'Examination':
        return Icons.quiz_outlined;
      case 'PTM':
        return Icons.groups_outlined;
      case 'Co-Curricular':
        return Icons.emoji_events_outlined;
      case 'Administrative':
        return Icons.admin_panel_settings_outlined;
      case 'Academic':
      default:
        return Icons.menu_book_outlined;
    }
  }

  /// Get academic events with filtering & resilient fallbacks
  Future<List<Map<String, dynamic>>> getAcademicEvents({
    String academicYear = '2026-2027',
    String? category,
    String? targetAudience,
    String? term,
  }) async {
    await _verifiedCalendarActor();
    if (!SchoolService.isTableMissing('school_academic_calendar')) {
      try {
        var query = _supabase.from('school_academic_calendar').select().eq('academic_year', academicYear);
        if (category != null && category.isNotEmpty && category != 'All') query = query.eq('category', category);
        if (targetAudience != null && targetAudience.isNotEmpty && targetAudience != 'all') {
          query = query.or('target_audience.eq.$targetAudience,target_audience.eq.all');
        }
        if (term != null && term.isNotEmpty && term != 'All') query = query.eq('term', term);
        final response = await query.order('start_date', ascending: true);
        if ((response as List).isNotEmpty) return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        if (e.toString().contains('404') || e.toString().contains('does not exist')) {
          SchoolService.markTableMissing('school_academic_calendar');
        } else {
          rethrow;
        }
      }
    }
    try {
      final response = await _supabase.from('school_circulars').select()
          .eq('category', 'AcademicCalendarEvent').order('published_at', ascending: true);
      final list = <Map<String, dynamic>>[];
      for (final row in response) {
        try {
          final decoded = jsonDecode(row['content']?.toString() ?? '{}');
          if (decoded is! Map<String, dynamic>) continue;
          if (decoded['academic_year'] != academicYear) continue;
          if (category != null && category != 'All' && decoded['category'] != category) continue;
          if (targetAudience != null && targetAudience != 'all' && decoded['target_audience'] != 'all' && decoded['target_audience'] != targetAudience) continue;
          if (term != null && term != 'All' && decoded['term'] != term) continue;
          list.add({'id': row['id'], ...decoded});
        } catch (_) {}
      }
      return list;
    } catch (_) {
      return [];
    }
  }
  /// Create a new academic calendar event
  Future<bool> createAcademicEvent({
    required String title,
    String? description,
    required String category,
    required String term,
    required String startDate,
    required String endDate,
    String? startTime,
    String? endTime,
    bool isAllDay = true,
    bool isHoliday = false,
    String targetAudience = 'all',
    List<String> applicableClasses = const ['All'],
    String venue = 'Main Campus',
    String? colorCode,
    String? createdBy,
    String academicYear = '2026-2027',
  }) async {
    final (actor, _) = await _verifiedCalendarActor();
    final payload = {
      'academic_year': academicYear,
      'term': term,
      'title': title,
      'description': description ?? '',
      'category': category,
      'start_date': startDate,
      'end_date': endDate,
      'start_time': startTime,
      'end_time': endTime,
      'is_all_day': isAllDay,
      'is_holiday': isHoliday,
      'target_audience': targetAudience,
      'applicable_classes': applicableClasses,
      'venue': venue,
      'color_code': colorCode ?? _getHexColor(getCategoryColor(category)),
      'is_published': true,
      'created_by': actor,
      'created_at': DateTime.now().toIso8601String(),
    };

    bool saved = false;

    // 1. Try school_academic_calendar table
    if (!SchoolService.isTableMissing('school_academic_calendar')) {
      try {
        await _supabase.from('school_academic_calendar').insert(payload);
        saved = true;
      } catch (e) {
        if (e.toString().contains('404') || e.toString().contains('does not exist')) {
          SchoolService.markTableMissing('school_academic_calendar');
        }
      }
    }

    // 2. Also write to circulars for complete redundancy
    try {
      await _supabase.from('school_circulars').insert({
        'institute_code': 'SHIV-SCH',
        'title': 'Calendar Event: $title',
        'content': jsonEncode(payload),
        'category': 'AcademicCalendarEvent',
        'target_audience': targetAudience,
        'published_by': actor,
        'published_at': DateTime.now().toIso8601String(),
      });
      saved = true;
    } catch (_) {}

    return saved;
  }

  /// Update an existing academic calendar event
  Future<bool> updateAcademicEvent({
    required String eventId,
    required Map<String, dynamic> updates,
  }) async {
    final (actor, role) = await _verifiedCalendarActor();
    final existing = await _supabase.from('school_academic_calendar').select('category').eq('id', eventId).maybeSingle();
    if (existing == null) throw Exception('Calendar event not found.');
    if (role == 'principal' && (existing['category'] == 'Holiday' || updates['category'] == 'Holiday')) {
      throw Exception('A principal cannot edit a Holiday calendar entry without an sadmin co-confirmation flow.');
    }
    final auditedUpdates = {...updates};
    try {
      if (!SchoolService.isTableMissing('school_academic_calendar')) {
        await _supabase
            .from('school_academic_calendar')
            .update({
              ...auditedUpdates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', eventId);
        await _supabase.from('school_audit_log').insert({
          'actor_username': actor,
          'action': 'update_academic_calendar_event',
          'entity_type': 'school_academic_calendar',
          'entity_id': eventId,
          'new_value': auditedUpdates,
        });
        return true;
      }
    } catch (_) {}

    try {
      await _supabase
          .from('school_circulars')
          .update({'content': jsonEncode(auditedUpdates)})
          .eq('id', eventId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete an event from academic calendar
  Future<bool> deleteAcademicEvent(String eventId) async {
    final (actor, role) = await _verifiedCalendarActor();
    final existing = await _supabase.from('school_academic_calendar').select('category,title').eq('id', eventId).maybeSingle();
    if (existing == null) throw Exception('Calendar event not found.');
    if (role == 'principal' && existing['category'] == 'Holiday') {
      throw Exception('A principal cannot delete a Holiday calendar entry without an sadmin co-confirmation flow.');
    }
    await _supabase.from('school_audit_log').insert({
      'actor_username': actor,
      'action': 'delete_academic_calendar_event',
      'entity_type': 'school_academic_calendar',
      'entity_id': eventId,
      'details': 'Deleted ${existing['title']}',
      'created_at': DateTime.now().toIso8601String(),
    });
    try {
      if (!SchoolService.isTableMissing('school_academic_calendar')) {
        await _supabase
            .from('school_academic_calendar')
            .delete()
            .eq('id', eventId);
      }
      await _supabase
          .from('school_circulars')
          .delete()
          .eq('id', eventId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates RFC 5545 iCalendar (.ics) string for 1-click subscription / download
  String generateIcsCalendarFeed({
    required List<Map<String, dynamic>> events,
    String calendarName = 'School Academic Calendar 2026-27',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//School ERP//Academic Calendar//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:$calendarName');
    buffer.writeln('X-WR-TIMEZONE:Asia/Kolkata');

    for (final e in events) {
      final id = e['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      final title = (e['title']?.toString() ?? 'Event').replaceAll('\n', ' ');
      final desc = (e['description']?.toString() ?? '').replaceAll('\n', ' ');
      final venue = e['venue']?.toString() ?? 'Main Campus';
      final category = e['category']?.toString() ?? 'Academic';

      final startStr = e['start_date']?.toString().replaceAll('-', '') ?? '20260401';
      final endStr = e['end_date']?.toString().replaceAll('-', '') ?? startStr;

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:evt-$id@schoolerp.in');
      buffer.writeln('DTSTAMP:${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z');
      buffer.writeln('DTSTART;VALUE=DATE:$startStr');
      buffer.writeln('DTEND;VALUE=DATE:$endStr');
      buffer.writeln('SUMMARY:$title');
      if (desc.isNotEmpty) buffer.writeln('DESCRIPTION:$desc');
      buffer.writeln('LOCATION:$venue');
      buffer.writeln('CATEGORIES:$category');
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// Download or share the .ics file feed
  Future<void> downloadIcsFile({
    required BuildContext context,
    required List<Map<String, dynamic>> events,
    String filename = 'School_Academic_Calendar.ics',
  }) async {
    final icsContent = generateIcsCalendarFeed(events: events);
    await Clipboard.setData(ClipboardData(text: icsContent));
    try {
      final bytes = utf8.encode(icsContent);
      final uri = Uri.dataFromBytes(bytes, mimeType: 'text/calendar');
      await launchUrl(uri);
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('$filename downloaded! Ready to import into Google / Apple Calendar.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  /// Calculate high-level summary metrics for executive dashboard
  Map<String, dynamic> calculateMetrics(List<Map<String, dynamic>> events) {
    int holidays = 0;
    int exams = 0;
    int ptms = 0;
    int coCurricular = 0;
    int upcomingNext30Days = 0;

    final now = DateTime.now();
    final future30 = now.add(const Duration(days: 30));

    for (final e in events) {
      final cat = e['category']?.toString() ?? 'Academic';
      if (e['is_holiday'] == true || cat == 'Holiday') holidays++;
      if (cat == 'Examination') exams++;
      if (cat == 'PTM') ptms++;
      if (cat == 'Co-Curricular') coCurricular++;

      try {
        final start = DateTime.parse(e['start_date'].toString());
        if (start.isAfter(now.subtract(const Duration(days: 1))) && start.isBefore(future30)) {
          upcomingNext30Days++;
        }
      } catch (_) {}
    }

    return {
      'total_events': events.length,
      'holidays': holidays,
      'examinations': exams,
      'ptms': ptms,
      'co_curricular': coCurricular,
      'upcoming_next_30_days': upcomingNext30Days,
      'working_instructional_days': (220 - holidays).clamp(180, 240),
    };
  }

  static String _getHexColor(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}

