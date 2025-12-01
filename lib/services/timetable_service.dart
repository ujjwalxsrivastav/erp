import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class TimetableService {
  final SupabaseClient _supabase = SupabaseService.client;

  // Get timetable for a specific day
  Future<List<Map<String, dynamic>>> getTimetableByDay(String dayOfWeek) async {
    try {
      final response = await _supabase.from('timetable').select('''
            *,
            subjects:subject_id (subject_name),
            teacher_details:teacher_id (name, employee_id)
          ''').eq('day_of_week', dayOfWeek).order('start_time');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching timetable: $e');
      return [];
    }
  }

  // Get full week timetable
  Future<Map<String, List<Map<String, dynamic>>>> getWeekTimetable() async {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final weekTimetable = <String, List<Map<String, dynamic>>>{};

    for (final day in days) {
      weekTimetable[day] = await getTimetableByDay(day);
    }

    return weekTimetable;
  }

  // Get today's timetable
  Future<List<Map<String, dynamic>>> getTodayTimetable() async {
    final now = DateTime.now();
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final today = dayNames[now.weekday - 1];

    if (today == 'Saturday' || today == 'Sunday') {
      return []; // No classes on weekends
    }

    return getTimetableByDay(today);
  }

  // Get subjects for a student
  Future<List<Map<String, dynamic>>> getStudentSubjects(
      String studentId) async {
    try {
      final response = await _supabase.from('student_subjects').select('''
            *,
            subjects:subject_id (subject_name, department),
            teacher_details:teacher_id (name, employee_id)
          ''').eq('student_id', studentId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching student subjects: $e');
      return [];
    }
  }

  // Get subjects taught by a teacher
  Future<List<Map<String, dynamic>>> getTeacherSubjects(
      String teacherId) async {
    try {
      final response = await _supabase
          .from('subjects')
          .select('*')
          .eq('teacher_id', teacherId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teacher subjects: $e');
      return [];
    }
  }

  // Get teacher's schedule for a specific day
  Future<List<Map<String, dynamic>>> getTeacherSchedule(
      String teacherId, String dayOfWeek) async {
    try {
      final response = await _supabase
          .from('timetable')
          .select('''
            *,
            subjects:subject_id (subject_name)
          ''')
          .eq('teacher_id', teacherId)
          .eq('day_of_week', dayOfWeek)
          .order('start_time');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching teacher schedule: $e');
      return [];
    }
  }

  // Get current/next class
  Future<Map<String, dynamic>?> getCurrentClass() async {
    final now = DateTime.now();
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final today = dayNames[now.weekday - 1];

    if (today == 'Saturday' || today == 'Sunday') {
      return null;
    }

    final todaySchedule = await getTimetableByDay(today);
    final currentTime = TimeOfDay.fromDateTime(now);

    for (final classItem in todaySchedule) {
      final startTime = _parseTime(classItem['start_time']);
      final endTime = _parseTime(classItem['end_time']);

      if (_isTimeBetween(currentTime, startTime, endTime)) {
        return classItem; // Current class
      } else if (_isTimeAfter(startTime, currentTime)) {
        return classItem; // Next class
      }
    }

    return null;
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool _isTimeBetween(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    final minutes1 = time1.hour * 60 + time1.minute;
    final minutes2 = time2.hour * 60 + time2.minute;
    return minutes1 > minutes2;
  }
}
