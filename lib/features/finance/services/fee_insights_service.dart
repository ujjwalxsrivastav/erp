import 'package:supabase_flutter/supabase_flutter.dart';

/// Finance — Fee Insights: defaulters & collection analytics.
///
/// Fills the gap left by Financial Reports, whose "Defaulter Report"
/// entry has no implementation and whose "Collection Report" only
/// shows aggregate dashboard stats (with a placeholder chart).
/// Everything here is computed live from `student_fee_allocations`
/// and `fee_receipts`.
class FeeInsightsService {
  final _supabase = Supabase.instance.client;

  double _toDouble(dynamic v) =>
      v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

  /// Students with an outstanding balance, aggregated per student
  /// across all of their fee allocations and sorted by balance
  /// (highest first). Each row carries the student's name/department/
  /// year/semester from student_details plus:
  /// total_balance, total_net, total_paid, heads (allocation count),
  /// oldest_due_date and an `overdue` flag.
  Future<List<Map<String, dynamic>>> getDefaulters({
    double minBalance = 0,
  }) async {
    try {
      final allocResponse = await _supabase
          .from('student_fee_allocations')
          .select(
              'student_id, balance_amount, paid_amount, net_amount, status, due_date')
          .gt('balance_amount', minBalance)
          .neq('status', 'waived')
          .neq('status', 'cancelled');
      final allocations = List<Map<String, dynamic>>.from(allocResponse);
      if (allocations.isEmpty) return [];

      // Aggregate allocations per student.
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final byStudent = <String, Map<String, dynamic>>{};
      for (final a in allocations) {
        final sid = a['student_id'].toString();
        final row = byStudent.putIfAbsent(
          sid,
          () => {
            'student_id': sid,
            'total_balance': 0.0,
            'total_net': 0.0,
            'total_paid': 0.0,
            'heads': 0,
            'oldest_due_date': null,
            'overdue': false,
          },
        );
        row['total_balance'] =
            (row['total_balance'] as double) + _toDouble(a['balance_amount']);
        row['total_net'] =
            (row['total_net'] as double) + _toDouble(a['net_amount']);
        row['total_paid'] =
            (row['total_paid'] as double) + _toDouble(a['paid_amount']);
        row['heads'] = (row['heads'] as int) + 1;

        final dueRaw = a['due_date']?.toString();
        if (dueRaw != null && dueRaw.isNotEmpty) {
          final due = DateTime.tryParse(dueRaw);
          if (due != null) {
            final current = row['oldest_due_date'] as String?;
            if (current == null || dueRaw.compareTo(current) < 0) {
              row['oldest_due_date'] = dueRaw;
            }
            if (due.isBefore(todayDate)) row['overdue'] = true;
          }
        }
        if (a['status'] == 'overdue') row['overdue'] = true;
      }

      // Resolve student details in one batched lookup.
      final ids = byStudent.keys.toList();
      try {
        final details = await _supabase
            .from('student_details')
            .select('student_id, name, department, year, semester, section')
            .inFilter('student_id', ids);
        for (final d in List<Map<String, dynamic>>.from(details)) {
          final row = byStudent[d['student_id'].toString()];
          if (row == null) continue;
          row['name'] = d['name'];
          row['department'] = d['department'];
          row['year'] = d['year'];
          row['semester'] = d['semester'];
          row['section'] = d['section'];
        }
      } catch (e) {
        print('Error resolving defaulter student details: $e');
      }

      final result = byStudent.values.toList()
        ..sort((a, b) => (b['total_balance'] as double)
            .compareTo(a['total_balance'] as double));
      return result;
    } catch (e) {
      print('Error fetching defaulters: $e');
      return [];
    }
  }

  /// Totals for the defaulters summary card, computed from the same
  /// allocation set [getDefaulters] aggregates.
  Future<Map<String, dynamic>> getDefaulterSummary() async {
    final defaulters = await getDefaulters();
    double totalOutstanding = 0;
    double overdueAmount = 0;
    int overdueCount = 0;
    for (final d in defaulters) {
      final bal = d['total_balance'] as double;
      totalOutstanding += bal;
      if (d['overdue'] == true) {
        overdueCount++;
        overdueAmount += bal;
      }
    }
    return {
      'totalOutstanding': totalOutstanding,
      'defaulterCount': defaulters.length,
      'overdueCount': overdueCount,
      'overdueAmount': overdueAmount,
    };
  }

  /// Collection analytics over the last [days] days, from completed
  /// fee_receipts: per-day totals (newest first), a payment-mode
  /// breakdown, the period total, today's collection and the
  /// receipt count.
  Future<Map<String, dynamic>> getCollectionSummary({int days = 30}) async {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final startDate = todayDate.subtract(Duration(days: days - 1));
      final startStr = _dateKey(startDate);

      final response = await _supabase
          .from('fee_receipts')
          .select('receipt_date, total_amount, payment_mode, status')
          .eq('status', 'completed')
          .gte('receipt_date', startStr)
          .order('receipt_date', ascending: false);
      final receipts = List<Map<String, dynamic>>.from(response);

      final byDay = <String, Map<String, dynamic>>{};
      final byMode = <String, Map<String, dynamic>>{};
      double totalCollected = 0;
      double todayCollection = 0;
      final todayStr = _dateKey(todayDate);

      for (final r in receipts) {
        final amount = _toDouble(r['total_amount']);
        totalCollected += amount;

        final dateRaw = (r['receipt_date'] ?? '').toString();
        final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
        final dayRow = byDay.putIfAbsent(
          date,
          () => {'date': date, 'total': 0.0, 'count': 0},
        );
        dayRow['total'] = (dayRow['total'] as double) + amount;
        dayRow['count'] = (dayRow['count'] as int) + 1;
        if (date == todayStr) todayCollection += amount;

        final mode = (r['payment_mode'] ?? 'cash').toString();
        final modeRow = byMode.putIfAbsent(
          mode,
          () => {'mode': mode, 'total': 0.0, 'count': 0},
        );
        modeRow['total'] = (modeRow['total'] as double) + amount;
        modeRow['count'] = (modeRow['count'] as int) + 1;
      }

      final daily = byDay.values.toList()
        ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
      final modes = byMode.values.toList()
        ..sort((a, b) =>
            (b['total'] as double).compareTo(a['total'] as double));

      return {
        'days': days,
        'daily': daily,
        'byMode': modes,
        'totalCollected': totalCollected,
        'todayCollection': todayCollection,
        'receiptCount': receipts.length,
      };
    } catch (e) {
      print('Error fetching collection summary: $e');
      return {
        'days': days,
        'daily': <Map<String, dynamic>>[],
        'byMode': <Map<String, dynamic>>[],
        'totalCollected': 0.0,
        'todayCollection': 0.0,
        'receiptCount': 0,
      };
    }
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
