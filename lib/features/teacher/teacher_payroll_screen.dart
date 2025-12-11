import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TeacherPayrollScreen extends StatefulWidget {
  final String teacherId;
  final String employeeId;

  const TeacherPayrollScreen({
    super.key,
    required this.teacherId,
    required this.employeeId,
  });

  @override
  State<TeacherPayrollScreen> createState() => _TeacherPayrollScreenState();
}

class _TeacherPayrollScreenState extends State<TeacherPayrollScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _payrollData;
  List<Map<String, dynamic>> _deductions = [];

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  Future<void> _loadPayrollData() async {
    try {
      // 1. Fetch monthly payroll summary (from view)
      // Note: Since we can't easily query the view with dynamic parameters in simple select,
      // we'll fetch base salary and calculate locally or use the view if possible.
      // For now, let's fetch base salary and deductions separately.

      final salaryData = await _supabase
          .from('teacher_salary')
          .select()
          .eq('employee_id', widget.employeeId)
          .eq('is_active', true)
          .maybeSingle();

      // 2. Fetch approved leave deductions for current month
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final leaveDeductions = await _supabase
          .from('teacher_leaves')
          .select()
          .eq('employee_id', widget.employeeId)
          .eq('status', 'Approved')
          .eq('is_salary_deducted', true)
          .gte('start_date', startOfMonth.toIso8601String())
          .lte('start_date', endOfMonth.toIso8601String());

      if (mounted) {
        setState(() {
          _payrollData = salaryData;
          _deductions = List<Map<String, dynamic>>.from(leaveDeductions);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading payroll: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Payroll'),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF059669)))
          : _payrollData == null
              ? const Center(child: Text('No salary record found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildNetSalaryCard(),
                      const SizedBox(height: 20),
                      _buildEarningsCard(),
                      const SizedBox(height: 20),
                      _buildDeductionsCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNetSalaryCard() {
    final baseNet = (_payrollData!['net_salary'] as num).toDouble();
    final totalLeaveDeductions = _deductions.fold(
        0.0, (sum, item) => sum + (item['deduction_amount'] as num).toDouble());
    final finalNet = baseNet - totalLeaveDeductions;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Net Salary (This Month)',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            NumberFormat.currency(symbol: '₹', locale: 'en_IN')
                .format(finalNet),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (totalLeaveDeductions > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Includes ₹${totalLeaveDeductions.toStringAsFixed(0)} leave deduction',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEarningsCard() {
    return _buildCard(
      title: 'Earnings',
      icon: Icons.arrow_upward,
      iconColor: Colors.green,
      children: [
        _buildRow('Basic Salary', _payrollData!['basic_salary']),
        _buildRow('HRA', _payrollData!['hra']),
        _buildRow('Travel Allowance', _payrollData!['travel_allowance']),
        _buildRow('Medical Allowance', _payrollData!['medical_allowance']),
        _buildRow('Special Allowance', _payrollData!['special_allowance']),
        const Divider(height: 24),
        _buildRow('Gross Salary', _payrollData!['gross_salary'], isBold: true),
      ],
    );
  }

  Widget _buildDeductionsCard() {
    final totalLeaveDeductions = _deductions.fold(
        0.0, (sum, item) => sum + (item['deduction_amount'] as num).toDouble());
    final baseDeductions =
        (_payrollData!['total_deductions'] as num).toDouble();
    final totalDeductions = baseDeductions + totalLeaveDeductions;

    return _buildCard(
      title: 'Deductions',
      icon: Icons.arrow_downward,
      iconColor: Colors.red,
      children: [
        _buildRow('Provident Fund', _payrollData!['provident_fund']),
        _buildRow('Professional Tax', _payrollData!['professional_tax']),
        _buildRow('Income Tax', _payrollData!['income_tax']),

        // Detailed Leave Deductions
        if (_deductions.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Leave Deductions:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 8),
          ..._deductions.map((leave) => _buildLeaveDeductionItem(leave)),
          const SizedBox(height: 4),
          _buildRow('Total Leave Deductions', totalLeaveDeductions,
              isRed: true, isBold: true),
        ],

        const Divider(height: 24),
        _buildRow('Total Deductions', totalDeductions,
            isBold: true, isRed: true),
      ],
    );
  }

  Widget _buildLeaveDeductionItem(Map<String, dynamic> leave) {
    final amount = (leave['deduction_amount'] as num).toDouble();
    final startDate = leave['start_date'] as String;
    final endDate = leave['end_date'] as String;
    final totalDays = leave['total_days'] as int;
    final reason = leave['reason'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalDays day${totalDays > 1 ? 's' : ''} leave',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
              Text(
                '- ₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$startDate to $endDate',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: $reason',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, dynamic value,
      {bool isBold = false, bool isRed = false}) {
    final amount = (value is num) ? value.toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '₹', locale: 'en_IN').format(amount),
            style: TextStyle(
              fontSize: 14,
              color: isRed
                  ? Colors.red
                  : (isBold ? Colors.black : Colors.grey.shade800),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
