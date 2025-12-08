import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveService {
  final _supabase = Supabase.instance.client;

  // ============================================
  // TEACHER LEAVE OPERATIONS
  // ============================================

  // Get teacher's leave balance for current month
  Future<Map<String, dynamic>?> getLeaveBalance(String teacherId) async {
    try {
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;

      // First, get the actual employee_id from teacher_details
      final teacherData = await _supabase
          .from('teacher_details')
          .select('employee_id')
          .eq('teacher_id', teacherId)
          .maybeSingle();

      if (teacherData == null) {
        print('Teacher not found: $teacherId');
        return null;
      }

      final employeeId = teacherData['employee_id'] as String;

      // Ensure balance record exists
      await _supabase.rpc('ensure_monthly_leave_balance', params: {
        'p_teacher_id': teacherId,
        'p_employee_id': employeeId, // Use actual employee_id
        'p_month': month,
        'p_year': year,
      });

      final response = await _supabase
          .from('teacher_leave_balance')
          .select()
          .eq('teacher_id', teacherId)
          .eq('month', month)
          .eq('year', year)
          .maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching leave balance: $e');
      return null;
    }
  }

  // Apply for leave
  Future<bool> applyLeave({
    required String teacherId,
    required String employeeId,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    String? documentUrl,
  }) async {
    try {
      final totalDays = endDate.difference(startDate).inDays + 1;

      // Get current balance (for reference, not blocking)
      int remainingBalance = 0;
      final balance = await getLeaveBalance(teacherId);
      if (balance != null) {
        remainingBalance = balance['sick_leaves_remaining'] as int;
      }

      await _supabase.from('teacher_leaves').insert({
        'teacher_id': teacherId,
        'employee_id': employeeId,
        'leave_type': leaveType,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'total_days': totalDays,
        'reason': reason,
        'document_url': documentUrl,
        'status': 'Pending',
      });

      return true;
    } catch (e) {
      print('Error applying leave: $e');
      rethrow;
    }
  }

  // Get teacher's leave history
  Future<List<Map<String, dynamic>>> getLeaveHistory(String teacherId) async {
    try {
      final response = await _supabase
          .from('teacher_leaves')
          .select()
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching leave history: $e');
      return [];
    }
  }

  // ============================================
  // HR LEAVE OPERATIONS
  // ============================================

  // Get all pending leaves
  Future<List<Map<String, dynamic>>> getPendingLeaves() async {
    try {
      final response = await _supabase.from('teacher_leaves').select('''
            *,
            teacher_details:teacher_details!teacher_leaves_employee_id_fkey!inner(name, department, designation)
          ''').eq('status', 'Pending').order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching pending leaves: $e');
      return [];
    }
  }

  // Get all leaves (for HR)
  Future<List<Map<String, dynamic>>> getAllLeaves() async {
    try {
      final response = await _supabase.from('teacher_leaves').select('''
            *,
            teacher_details:teacher_details!teacher_leaves_employee_id_fkey!inner(name, department, designation)
          ''').order('created_at', ascending: false).limit(100);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all leaves: $e');
      return [];
    }
  }

  // Approve leave
  Future<bool> approveLeave({
    required int leaveId,
    required String approvedBy,
    bool deductSalary = false,
  }) async {
    try {
      double deductionAmount = 0.0;
      String? teacherId;
      DateTime? startDate;
      DateTime? endDate;

      // Get leave details
      final leaveData = await _supabase
          .from('teacher_leaves')
          .select('total_days, employee_id, teacher_id, start_date, end_date')
          .eq('leave_id', leaveId)
          .single();

      teacherId = leaveData['teacher_id'] as String?;
      startDate = DateTime.tryParse(leaveData['start_date'] ?? '');
      endDate = DateTime.tryParse(leaveData['end_date'] ?? '');

      if (deductSalary) {
        final days = leaveData['total_days'] as int;
        final employeeId = leaveData['employee_id'] as String;

        // Get teacher's basic salary
        final salaryData = await _supabase
            .from('teacher_salary')
            .select('basic_salary')
            .eq('employee_id', employeeId)
            .eq('is_active', true)
            .maybeSingle();

        if (salaryData != null) {
          final basicSalary = salaryData['basic_salary'] as num;
          final perDaySalary = basicSalary / 30;
          deductionAmount = perDaySalary * days;
        }
      }

      await _supabase.from('teacher_leaves').update({
        'status': 'Approved',
        'approved_by': approvedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'is_salary_deducted': deductSalary,
        'deduction_amount': deductionAmount,
      }).eq('leave_id', leaveId);

      // Create arrangement entries for HOD to assign substitutes
      if (teacherId != null && startDate != null && endDate != null) {
        await _createArrangementsForLeave(
          teacherId: teacherId,
          leaveId: leaveId,
          startDate: startDate,
          endDate: endDate,
          createdBy: approvedBy,
        );
      }

      return true;
    } catch (e) {
      print('Error approving leave: $e');
      return false;
    }
  }

  // Helper to create arrangement entries
  Future<void> _createArrangementsForLeave({
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

      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

      // For each day in leave period
      for (var date = startDate;
          date.isBefore(endDate.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        // Get day name (1 = Monday, 7 = Sunday)
        if (date.weekday > 5) continue; // Skip weekends
        final dayName = days[date.weekday - 1];

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
      print('✅ Created arrangement entries for leave $leaveId');
    } catch (e) {
      print('Error creating arrangements: $e');
    }
  }

  // Reject leave
  Future<bool> rejectLeave({
    required int leaveId,
    required String rejectedBy,
    required String reason,
  }) async {
    try {
      await _supabase.from('teacher_leaves').update({
        'status': 'Rejected',
        'approved_by': rejectedBy,
        'approved_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
      }).eq('leave_id', leaveId);

      return true;
    } catch (e) {
      print('Error rejecting leave: $e');
      return false;
    }
  }

  // ============================================
  // HOLIDAY OPERATIONS
  // ============================================

  // Get all holidays
  Future<List<Map<String, dynamic>>> getAllHolidays() async {
    try {
      final response = await _supabase
          .from('holidays')
          .select()
          .order('holiday_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching holidays: $e');
      return [];
    }
  }

  // Get holidays for a specific month
  Future<List<Map<String, dynamic>>> getHolidaysForMonth(
      int year, int month) async {
    try {
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0);

      final response = await _supabase
          .from('holidays')
          .select()
          .gte('holiday_date', startDate.toIso8601String().split('T')[0])
          .lte('holiday_date', endDate.toIso8601String().split('T')[0])
          .order('holiday_date', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching holidays for month: $e');
      return [];
    }
  }

  // Add new holiday (HR only)
  Future<bool> addHoliday({
    required String name,
    required DateTime date,
    required String description,
    required String type,
    required String createdBy,
  }) async {
    try {
      await _supabase.from('holidays').insert({
        'holiday_name': name,
        'holiday_date': date.toIso8601String().split('T')[0],
        'description': description,
        'holiday_type': type,
        'is_holiday': true,
        'is_working_day': false,
        'created_by': createdBy,
      });

      return true;
    } catch (e) {
      print('Error adding holiday: $e');
      return false;
    }
  }

  // Update holiday (HR only)
  Future<bool> updateHoliday({
    required int holidayId,
    required String name,
    required String description,
    required String type,
  }) async {
    try {
      await _supabase.from('holidays').update({
        'holiday_name': name,
        'description': description,
        'holiday_type': type,
      }).eq('holiday_id', holidayId);

      return true;
    } catch (e) {
      print('Error updating holiday: $e');
      return false;
    }
  }

  // Delete holiday (HR only)
  Future<bool> deleteHoliday(int holidayId) async {
    try {
      await _supabase.from('holidays').delete().eq('holiday_id', holidayId);
      return true;
    } catch (e) {
      print('Error deleting holiday: $e');
      return false;
    }
  }

  // Toggle day type (Holiday <-> Working Day)
  Future<bool> toggleDayType({
    required DateTime date,
    required bool isHoliday,
    required String createdBy,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];

      // Check if date already exists
      final existing = await _supabase
          .from('holidays')
          .select()
          .eq('holiday_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await _supabase.from('holidays').update({
          'is_holiday': isHoliday,
          'is_working_day': !isHoliday,
        }).eq('holiday_date', dateStr);
      } else {
        // Create new
        await _supabase.from('holidays').insert({
          'holiday_name': isHoliday ? 'Custom Holiday' : 'Working Day',
          'holiday_date': dateStr,
          'description':
              isHoliday ? 'Marked as holiday' : 'Marked as working day',
          'holiday_type': 'Custom',
          'is_holiday': isHoliday,
          'is_working_day': !isHoliday,
          'created_by': createdBy,
        });
      }

      return true;
    } catch (e) {
      print('Error toggling day type: $e');
      return false;
    }
  }

  // Get holiday summary for a month
  Future<Map<String, int>> getMonthSummary(int year, int month) async {
    try {
      final holidays = await getHolidaysForMonth(year, month);
      final totalDays = DateTime(year, month + 1, 0).day;

      final holidayCount =
          holidays.where((h) => h['is_holiday'] == true).length;
      final workingDays = totalDays - holidayCount;

      return {
        'total_days': totalDays,
        'holidays': holidayCount,
        'working_days': workingDays,
      };
    } catch (e) {
      print('Error getting month summary: $e');
      return {
        'total_days': 0,
        'holidays': 0,
        'working_days': 0,
      };
    }
  }
}
