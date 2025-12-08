import 'package:supabase_flutter/supabase_flutter.dart';

class ArrangementService {
  final _supabase = Supabase.instance.client;

  /// Get teachers who are on approved leave for a specific date
  Future<List<Map<String, dynamic>>> getTeachersOnLeave(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('teacher_leaves')
          .select('''
            *,
            teacher_details:teacher_details!teacher_leaves_teacher_id_fkey(
              teacher_id, name, department, subject
            )
          ''')
          .eq('status', 'Approved')
          .lte('start_date', dateStr)
          .gte('end_date', dateStr);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teachers on leave: $e');
      return [];
    }
  }

  /// Get pending arrangements for a date (where substitute not assigned)
  Future<List<Map<String, dynamic>>> getPendingArrangements(
      DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      final response = await _supabase.from('teacher_arrangements').select('''
            *,
            original_teacher:teacher_details!teacher_arrangements_original_teacher_id_fkey(name, department),
            substitute_teacher:teacher_details!teacher_arrangements_substitute_teacher_id_fkey(name, department),
            timetable:timetable!teacher_arrangements_timetable_id_fkey(
              day_of_week, time_slot, start_time, end_time, room_number,
              subjects(subject_name),
              classes(class_name)
            )
          ''').eq('arrangement_date', dateStr).eq('status', 'pending');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching pending arrangements: $e');
      return [];
    }
  }

  /// Get all arrangements for today with their status
  Future<List<Map<String, dynamic>>> getTodaysArrangements() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('teacher_arrangements')
          .select('''
            *,
            original_teacher:teacher_details!teacher_arrangements_original_teacher_id_fkey(name, department, subject),
            substitute_teacher:teacher_details!teacher_arrangements_substitute_teacher_id_fkey(name, department),
            timetable:timetable!teacher_arrangements_timetable_id_fkey(
              day_of_week, time_slot, start_time, end_time, room_number,
              subjects(subject_name)
            )
          ''')
          .eq('arrangement_date', today)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching todays arrangements: $e');
      return [];
    }
  }

  /// Create arrangement entries for a teacher on leave
  Future<void> createArrangementsForLeave({
    required String teacherId,
    required int leaveId,
    required DateTime startDate,
    required DateTime endDate,
    required String createdBy,
  }) async {
    try {
      // Get teacher's timetable entries
      final timetableEntries = await _supabase
          .from('timetable')
          .select()
          .eq('teacher_id', teacherId);

      if (timetableEntries.isEmpty) return;

      // For each day in leave period
      for (var date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        // Get day name
        final dayName = _getDayName(date.weekday);
        if (dayName == null) continue; // Skip weekends

        // Get timetable entries for this day
        final dayEntries =
            timetableEntries.where((t) => t['day_of_week'] == dayName).toList();

        for (var entry in dayEntries) {
          // Check if arrangement already exists
          final existing = await _supabase
              .from('teacher_arrangements')
              .select()
              .eq('original_teacher_id', teacherId)
              .eq('arrangement_date', date.toIso8601String().split('T')[0])
              .eq('timetable_id', entry['id'])
              .maybeSingle();

          if (existing == null) {
            await _supabase.from('teacher_arrangements').insert({
              'original_teacher_id': teacherId,
              'leave_id': leaveId,
              'arrangement_date': date.toIso8601String().split('T')[0],
              'timetable_id': entry['id'],
              'status': 'pending',
              'created_by': createdBy,
            });
          }
        }
      }
    } catch (e) {
      print('Error creating arrangements: $e');
    }
  }

  /// Assign a substitute teacher
  Future<bool> assignSubstitute({
    required int arrangementId,
    required String substituteTeacherId,
    String? notes,
    required String assignedBy,
  }) async {
    try {
      await _supabase.from('teacher_arrangements').update({
        'substitute_teacher_id': substituteTeacherId,
        'status': 'arranged',
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', arrangementId);

      return true;
    } catch (e) {
      print('Error assigning substitute: $e');
      return false;
    }
  }

  /// Get available teachers for a time slot (not on leave, not already teaching)
  Future<List<Map<String, dynamic>>> getAvailableTeachers({
    required DateTime date,
    required String timeSlot,
    required String dayOfWeek,
  }) async {
    try {
      // Get all teachers
      final allTeachers = await _supabase
          .from('teacher_details')
          .select()
          .eq('status', 'Active');

      // Get teachers on leave
      final teachersOnLeave = await getTeachersOnLeave(date);
      final leaveTeacherIds =
          teachersOnLeave.map((l) => l['teacher_id'] as String).toSet();

      // Get teachers already teaching in this slot
      final busyTeachers = await _supabase
          .from('timetable')
          .select('teacher_id')
          .eq('day_of_week', dayOfWeek)
          .eq('time_slot', timeSlot);
      final busyTeacherIds =
          busyTeachers.map((t) => t['teacher_id'] as String).toSet();

      // Filter available teachers
      final available = allTeachers.where((t) {
        final teacherId = t['teacher_id'] as String;
        return !leaveTeacherIds.contains(teacherId) &&
            !busyTeacherIds.contains(teacherId);
      }).toList();

      return List<Map<String, dynamic>>.from(available);
    } catch (e) {
      print('Error fetching available teachers: $e');
      return [];
    }
  }

  /// Check if a teacher is on leave for a specific date
  Future<bool> isTeacherOnLeave(String teacherId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      final response = await _supabase
          .from('teacher_leaves')
          .select()
          .eq('teacher_id', teacherId)
          .eq('status', 'Approved')
          .lte('start_date', dateStr)
          .gte('end_date', dateStr)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking leave status: $e');
      return false;
    }
  }

  /// Get arrangement alerts count for HOD dashboard
  Future<int> getPendingArrangementsCount() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('teacher_arrangements')
          .select('id')
          .eq('arrangement_date', today)
          .eq('status', 'pending');

      return response.length;
    } catch (e) {
      print('Error counting pending arrangements: $e');
      return 0;
    }
  }

  String? _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      default:
        return null; // Weekend
    }
  }
}
