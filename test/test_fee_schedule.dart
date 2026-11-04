import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:erp/services/supabase_service.dart';
import 'package:erp/services/school_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Fee Heads & 12-Month April-March Schedule with Late Fee Test', () async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseService.initialize();
    final service = SchoolService();
    final heads = await service.getSchoolFeeHeads();
    expect(heads.isNotEmpty, true);
    print('Total fee heads: ${heads.length}');
    for (var h in heads) {
      print(' - ${h["title"]}: ₹${h["amount"]} (${h["category"]})');
    }

    final schedule = await service.getMonthlyFeeSchedule('sstudent1');
    expect(schedule.length, 12);
    print('\n12-Month Schedule:');
    for (var m in schedule) {
      print(' * ${m["month_name"]} (Due: ${m["due_date"]}) -> Status: ${m["status"]}, Base: ₹${m["base_amount"]}, Late Fee: ₹${m["late_fee"]}, Total: ₹${m["total_amount"]}');
    }

    // Check months starting from April to March
    expect(schedule.first['short_month'], 'Apr');
    expect(schedule.last['short_month'], 'Mar');

    // Verify late fee rule for overdue months (months before current month)
    final overdueMonths = schedule.where((m) => m['is_overdue'] == true && m['is_paid'] != true);
    for (var m in overdueMonths) {
      expect(m['late_fee'], 100.0);
    }

    final summary = await service.getStudentFeeSummary('sstudent1');
    print('\nSummary: Total Annual: ₹${summary["total_annual"]}, Paid: ₹${summary["total_paid"]}, Pending: ₹${summary["total_pending"]}, Overdue Fines: ₹${summary["total_late_fees"]}');
    expect(summary['total_annual'], greaterThan(0));
  });
}
