import 'package:supabase_flutter/supabase_flutter.dart';

/// Payroll deepening service: monthly payroll runs + payslips.
///
/// Unlike the legacy HR payroll screen (which computed everything live
/// from `teacher_salary` and persisted nothing), a payroll run SNAPSHOTS
/// every active teacher's salary into `payslips`, so a month's pay stays
/// frozen even after the salary structure is edited.
///
/// LOP (loss of pay) rule — implemented from the ACTUAL leave schema:
/// `teacher_leaves.leave_type` has no unpaid/LWP type (only Sick / Casual /
/// Emergency), but `update_leave_deductions.sql` added the boolean flag
/// `is_salary_deducted` which HR sets on an approved leave when its pay is
/// to be deducted (the LWP marker). Therefore:
///   lopDays        = calendar days of overlap between each Approved leave
///                    with is_salary_deducted = true and the payroll month,
///                    capped at the leave's total_days.
///   workingDays    = calendar days in the payroll month.
///   lopDeduction   = gross / workingDays * lopDays.
///   netPay         = gross - statutory deductions - lopDeduction (>= 0).
class PayrollService {
  final _supabase = Supabase.instance.client;

  double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  double _round2(double v) => (v * 100).round() / 100;

  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ============================================================
  // RUNS
  // ============================================================

  /// All payroll runs, newest period first.
  Future<List<Map<String, dynamic>>> getRuns() async {
    try {
      final res = await _supabase
          .from('payroll_runs')
          .select()
          .order('year', ascending: false)
          .order('month', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error fetching payroll runs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getRunById(String id) async {
    try {
      final res =
          await _supabase.from('payroll_runs').select().eq('id', id).maybeSingle();
      return res;
    } catch (e) {
      print('Error fetching payroll run: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getRunByPeriod(int month, int year) async {
    try {
      final res = await _supabase
          .from('payroll_runs')
          .select()
          .eq('month', month)
          .eq('year', year)
          .maybeSingle();
      return res;
    } catch (e) {
      print('Error fetching payroll run by period: $e');
      return null;
    }
  }

  // ============================================================
  // PAYSLIPS
  // ============================================================

  /// Payslips of one run (the salary register for that month),
  /// enriched with the run's month/year/status.
  Future<List<Map<String, dynamic>>> getPayslips(String runId) async {
    try {
      final res = await _supabase
          .from('payslips')
          .select()
          .eq('run_id', runId)
          .order('teacher_name', ascending: true);
      final slips = List<Map<String, dynamic>>.from(res);
      final run = await getRunById(runId);
      if (run != null) {
        for (final s in slips) {
          s['month'] = run['month'];
          s['year'] = run['year'];
          s['run_status'] = run['status'];
        }
      }
      return slips;
    } catch (e) {
      print('Error fetching payslips: $e');
      return [];
    }
  }

  /// One employee's payslip history (by employee_id), newest first.
  Future<List<Map<String, dynamic>>> getPayslipForEmployee(
    String employeeId, {
    int limit = 24,
  }) async {
    try {
      final res = await _supabase
          .from('payslips')
          .select()
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false)
          .limit(limit);
      return await _enrichWithRunPeriod(List<Map<String, dynamic>>.from(res));
    } catch (e) {
      print('Error fetching employee payslips: $e');
      return [];
    }
  }

  /// A teacher's own payslips by login username (teacher_details.teacher_id).
  /// Falls back to resolving the employee_id when no username match exists
  /// (e.g. payslips generated before teacher_username was populated).
  Future<List<Map<String, dynamic>>> getPayslipsByUsername(
    String username, {
    int limit = 24,
  }) async {
    try {
      final res = await _supabase
          .from('payslips')
          .select()
          .eq('teacher_username', username)
          .order('created_at', ascending: false)
          .limit(limit);
      final slips = List<Map<String, dynamic>>.from(res);
      if (slips.isNotEmpty) return await _enrichWithRunPeriod(slips);

      final teacher = await _supabase
          .from('teacher_details')
          .select('employee_id')
          .eq('teacher_id', username)
          .maybeSingle();
      final employeeId = teacher?['employee_id']?.toString();
      if (employeeId == null || employeeId.isEmpty) return [];
      return await getPayslipForEmployee(employeeId, limit: limit);
    } catch (e) {
      print('Error fetching payslips by username: $e');
      return [];
    }
  }

  /// Merge month/year/run_status from payroll_runs into payslip rows.
  Future<List<Map<String, dynamic>>> _enrichWithRunPeriod(
    List<Map<String, dynamic>> slips,
  ) async {
    if (slips.isEmpty) return slips;
    try {
      final runIds =
          slips.map((s) => s['run_id']?.toString()).whereType<String>().toSet().toList();
      if (runIds.isEmpty) return slips;
      final runs = await _supabase
          .from('payroll_runs')
          .select('id, month, year, status')
          .inFilter('id', runIds);
      final byId = <String, Map<String, dynamic>>{
        for (final r in List<Map<String, dynamic>>.from(runs))
          r['id'].toString(): r,
      };
      for (final s in slips) {
        final run = byId[s['run_id']?.toString()];
        if (run != null) {
          s['month'] = run['month'];
          s['year'] = run['year'];
          s['run_status'] = run['status'];
        }
      }
      // Newest period first (created_at order is close, period is exact).
      slips.sort((a, b) {
        final ay = (a['year'] as num?)?.toInt() ?? 0;
        final by = (b['year'] as num?)?.toInt() ?? 0;
        if (ay != by) return by.compareTo(ay);
        final am = (a['month'] as num?)?.toInt() ?? 0;
        final bm = (b['month'] as num?)?.toInt() ?? 0;
        return bm.compareTo(am);
      });
      return slips;
    } catch (e) {
      print('Error enriching payslips with run period: $e');
      return slips;
    }
  }

  // ============================================================
  // GENERATE RUN
  // ============================================================

  /// Generates (or returns) the payroll run for [month]/[year].
  ///
  /// For every `teacher_details` row with status 'Active' that has an
  /// active `teacher_salary` structure, one payslip is computed and
  /// stored (see the LOP rule in the class doc). The run is created
  /// directly in 'processed' status with summed totals.
  ///
  /// Returns a map:
  /// - {'alreadyExists': true,  'run': <existing run row>} when a run for
  ///   the period already exists (nothing is duplicated or overwritten).
  /// - {'alreadyExists': false, 'run': <new run row>, 'payslips': n,
  ///    'skippedNoSalary': m} on success.
  /// - {'error': '...'} on failure.
  Future<Map<String, dynamic>> generateRun(
    int month,
    int year,
    String processedBy,
  ) async {
    try {
      final existing = await _getRunByPeriod(month, year);
      if (existing != null) {
        return {'alreadyExists': true, 'run': existing};
      }

      final workingDays = DateTime(year, month + 1, 0).day;
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month, workingDays);

      // Active teachers.
      final teachersRes = await _supabase
          .from('teacher_details')
          .select('teacher_id, employee_id, name, department')
          .eq('status', 'Active');
      final teachers = List<Map<String, dynamic>>.from(teachersRes);
      if (teachers.isEmpty) {
        return {'error': 'No active teachers found for payroll.'};
      }

      // Active salary structures by employee_id. gross_salary /
      // total_deductions / net_salary are GENERATED columns on
      // teacher_salary — read here, never inserted there.
      final salaryRes = await _supabase
          .from('teacher_salary')
          .select(
              'employee_id, basic_salary, hra, travel_allowance, medical_allowance, special_allowance, other_allowances, gross_salary, provident_fund, professional_tax, income_tax, other_deductions, total_deductions')
          .eq('is_active', true);
      final salaryByEmployee = <String, Map<String, dynamic>>{
        for (final s in List<Map<String, dynamic>>.from(salaryRes))
          s['employee_id'].toString(): s,
      };

      // Approved, salary-deducted (unpaid / LWP) leaves overlapping the
      // month: start_date <= monthEnd AND end_date >= monthStart.
      final leavesRes = await _supabase
          .from('teacher_leaves')
          .select('employee_id, start_date, end_date, total_days')
          .eq('status', 'Approved')
          .eq('is_salary_deducted', true)
          .lte('start_date', _dateStr(monthEnd))
          .gte('end_date', _dateStr(monthStart));
      final leavesByEmployee = <String, List<Map<String, dynamic>>>{};
      for (final l in List<Map<String, dynamic>>.from(leavesRes)) {
        final key = l['employee_id']?.toString() ?? '';
        leavesByEmployee.putIfAbsent(key, () => []).add(l);
      }

      // Build payslip rows.
      final payslipRows = <Map<String, dynamic>>[];
      double totalGross = 0, totalDed = 0, totalNet = 0;
      int skippedNoSalary = 0;

      for (final t in teachers) {
        final employeeId = t['employee_id']?.toString() ?? '';
        final salary = salaryByEmployee[employeeId];
        if (salary == null) {
          skippedNoSalary++;
          continue;
        }

        final gross = _toDouble(salary['gross_salary']);
        final statutory = _toDouble(salary['total_deductions']);

        // LOP days: overlap of each flagged approved leave with the month.
        double lopDays = 0;
        for (final l in leavesByEmployee[employeeId] ?? []) {
          final start = DateTime.tryParse(l['start_date']?.toString() ?? '');
          final end = DateTime.tryParse(l['end_date']?.toString() ?? '');
          if (start == null || end == null) continue;
          final oStart = start.isAfter(monthStart) ? start : monthStart;
          final oEnd = end.isBefore(monthEnd) ? end : monthEnd;
          if (oEnd.isBefore(oStart)) continue;
          double overlap = oEnd.difference(oStart).inDays + 1;
          final cap = _toDouble(l['total_days']);
          if (cap > 0 && overlap > cap) overlap = cap;
          lopDays += overlap;
        }
        if (lopDays > workingDays) lopDays = workingDays.toDouble();

        final lopDeduction =
            workingDays > 0 ? _round2(gross / workingDays * lopDays) : 0.0;
        double netPay = gross - statutory - lopDeduction;
        if (netPay < 0) netPay = 0;

        payslipRows.add({
          'employee_id': employeeId,
          'teacher_username': t['teacher_id']?.toString(),
          'teacher_name': t['name']?.toString(),
          'department': t['department']?.toString(),
          'working_days': workingDays,
          'present_days': _round2(workingDays - lopDays),
          'lop_days': _round2(lopDays),
          'basic': _toDouble(salary['basic_salary']),
          'hra': _toDouble(salary['hra']),
          'travel': _toDouble(salary['travel_allowance']),
          'medical': _toDouble(salary['medical_allowance']),
          'special': _toDouble(salary['special_allowance']),
          'other_allowances': _toDouble(salary['other_allowances']),
          'gross': gross,
          'pf': _toDouble(salary['provident_fund']),
          'professional_tax': _toDouble(salary['professional_tax']),
          'income_tax': _toDouble(salary['income_tax']),
          'other_deductions': _toDouble(salary['other_deductions']),
          'total_deductions': statutory,
          'lop_deduction': lopDeduction,
          'net_pay': _round2(netPay),
          'status': 'generated',
        });

        totalGross += gross;
        totalDed += statutory + lopDeduction;
        totalNet += netPay;
      }

      if (payslipRows.isEmpty) {
        return {
          'error':
              'No active teacher has an active salary structure. Set salaries first from HR Payroll Management.',
        };
      }

      // Create the run (processed immediately — payslips are the output).
      final runRow = await _supabase
          .from('payroll_runs')
          .insert({
            'month': month,
            'year': year,
            'status': 'processed',
            'total_gross': _round2(totalGross),
            'total_deductions': _round2(totalDed),
            'total_net': _round2(totalNet),
            'employees_count': payslipRows.length,
            'processed_by': processedBy,
            'processed_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final runId = runRow['id'].toString();
      for (final row in payslipRows) {
        row['run_id'] = runId;
      }
      await _supabase.from('payslips').insert(payslipRows);

      return {
        'alreadyExists': false,
        'run': runRow,
        'payslips': payslipRows.length,
        'skippedNoSalary': skippedNoSalary,
      };
    } catch (e) {
      print('Error generating payroll run: $e');
      return {'error': e.toString()};
    }
  }

  // ============================================================
  // PAY / HOLD ACTIONS
  // ============================================================

  /// Marks a run paid: run status 'paid' + paid_at, and every
  /// 'generated' payslip becomes 'paid'. Payslips on hold stay on hold
  /// (an explicit HR hold must be released individually).
  Future<bool> markRunPaid(String runId) async {
    try {
      await _supabase.from('payroll_runs').update({
        'status': 'paid',
        'paid_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', runId);
      await _supabase
          .from('payslips')
          .update({'status': 'paid'})
          .eq('run_id', runId)
          .eq('status', 'generated');
      return true;
    } catch (e) {
      print('Error marking payroll run paid: $e');
      return false;
    }
  }

  /// Put a payslip on hold, or release the hold (back to 'generated').
  Future<bool> setPayslipHold(String payslipId, bool hold) async {
    try {
      await _supabase
          .from('payslips')
          .update({'status': hold ? 'on_hold' : 'generated'})
          .eq('id', payslipId);
      return true;
    } catch (e) {
      print('Error updating payslip hold: $e');
      return false;
    }
  }

  // ============================================================
  // STATS
  // ============================================================

  /// Dashboard summary: latest run, last 6 runs (oldest→newest for
  /// trend display) and how many employees are on payroll.
  Future<Map<String, dynamic>> getPayrollStats() async {
    try {
      final runs = await getRuns(); // newest period first
      final latest = runs.isEmpty ? null : runs.first;
      final recent = runs.take(6).toList().reversed.toList();

      final activeSalaries = await _supabase
          .from('teacher_salary')
          .select('employee_id')
          .eq('is_active', true);

      return {
        'latestRun': latest,
        'recentRuns': recent,
        'totalRuns': runs.length,
        'employeesOnPayroll': (activeSalaries as List).length,
      };
    } catch (e) {
      print('Error fetching payroll stats: $e');
      return {
        'latestRun': null,
        'recentRuns': <Map<String, dynamic>>[],
        'totalRuns': 0,
        'employeesOnPayroll': 0,
      };
    }
  }
}
