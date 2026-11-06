import 'package:flutter/material.dart';
import '../../../services/school_payroll_service.dart';
import '../../../services/auth_service.dart';

class SchoolMyPayslipsScreen extends StatefulWidget {
  const SchoolMyPayslipsScreen({super.key});

  @override
  State<SchoolMyPayslipsScreen> createState() => _SchoolMyPayslipsScreenState();
}

class _SchoolMyPayslipsScreenState extends State<SchoolMyPayslipsScreen> {
  final _payrollService = SchoolPayrollService();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _myPayslips = [];

  // Tokens
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _amber = Color(0xFFD97706);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _loadMyPayslips();
  }

  Future<void> _loadMyPayslips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = await AuthService().getCurrentUsername();
      if (username == null || username.isEmpty) {
        throw StateError(
            'Your session could not be verified. Please sign in again.');
      }
      final slips = await _payrollService.getMyPayslips(username);
      if (mounted) {
        setState(() {
          _myPayslips = slips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'My Salary Slips & Remuneration',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadMyPayslips,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: _danger),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: const TextStyle(color: _muted)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _loadMyPayslips,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _myPayslips.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadMyPayslips,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _myPayslips.length,
                        itemBuilder: (ctx, idx) =>
                            _buildPayslipCard(_myPayslips[idx]),
                      ),
                    ),
    );
  }

  Widget _buildPayslipCard(Map<String, dynamic> s) {
    final month = s['month_year']?.toString() ?? 'Period';
    final net = (s['net_pay'] as num?)?.toDouble() ?? 0.0;
    final gross = (s['gross_salary'] as num?)?.toDouble() ?? 0.0;
    final basic = (s['basic_pay'] as num?)?.toDouble() ?? 0.0;
    final pf = (s['provident_fund'] as num?)?.toDouble() ?? 0.0;
    final esi = (s['esi_deduction'] as num?)?.toDouble() ?? 0.0;
    final pt = (s['professional_tax'] as num?)?.toDouble() ?? 0.0;
    final lop = (s['lop_deduction'] as num?)?.toDouble() ?? 0.0;
    final totalDed = (s['total_deductions'] as num?)?.toDouble() ?? 0.0;
    final status = (s['status']?.toString() ?? 'normal').toLowerCase();

    final isPaid = status == 'paid';
    final statusColor = isPaid ? _emerald : _amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.receipt_outlined, color: statusColor, size: 20),
        ),
        title: Row(
          children: [
            Text('Disbursement: $month',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: _ink)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(status.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ),
          ],
        ),
        subtitle: Text('Net Credited: ₹${net.toStringAsFixed(0)}',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: _emerald, fontSize: 13)),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildItemRow('Basic Pay', '₹${basic.toStringAsFixed(0)}'),
          _buildItemRow('Gross Earnings', '₹${gross.toStringAsFixed(0)}',
              isBold: true),
          _buildItemRow('Provident Fund (12%)', '₹${pf.toStringAsFixed(0)}'),
          _buildItemRow('ESI Deduction (0.75%)', '₹${esi.toStringAsFixed(0)}'),
          _buildItemRow('Professional Tax', '₹${pt.toStringAsFixed(0)}'),
          if (lop > 0)
            _buildItemRow('Loss of Pay (LOP)', '₹${lop.toStringAsFixed(0)}',
                color: _danger),
          _buildItemRow('Total Deductions', '₹${totalDed.toStringAsFixed(0)}',
              isBold: true, color: _danger),
          const Divider(height: 16),
          _buildItemRow('Take-Home Net Salary', '₹${net.toStringAsFixed(0)}',
              isBold: true, color: _emerald, fontSize: 15),
          const SizedBox(height: 8),
          if (s['payment_reference'] != null)
            Text('Bank Ref: ${s['payment_reference']}',
                style: const TextStyle(fontSize: 10.5, color: _muted)),
        ],
      ),
    );
  }

  Widget _buildItemRow(String label, String value,
      {bool isBold = false, Color? color, double fontSize = 12.5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: isBold ? _ink : _muted)),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? (isBold ? _ink : _ink))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: _muted),
            SizedBox(height: 12),
            Text('No Payslips Found',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
            SizedBox(height: 6),
            Text(
              'Your salary slips will be published here once administrative review and payroll runs are locked by the school office.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
