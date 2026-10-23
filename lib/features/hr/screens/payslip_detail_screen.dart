import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/payroll_service.dart';

/// Clean, frozen payslip breakdown for one employee + one payroll run.
/// The [payslip] map is a `payslips` row enriched with `month` / `year`
/// (PayrollService does that). When [isHR] is true, HR can put the slip
/// on hold / release it (paid slips can no longer be held).
class PayslipDetailScreen extends StatefulWidget {
  final Map<String, dynamic> payslip;
  final bool isHR;

  const PayslipDetailScreen({
    super.key,
    required this.payslip,
    this.isHR = false,
  });

  @override
  State<PayslipDetailScreen> createState() => _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends State<PayslipDetailScreen> {
  final _service = PayrollService();
  late Map<String, dynamic> _slip;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _slip = Map<String, dynamic>.from(widget.payslip);
  }

  double _v(dynamic k) => (k as num?)?.toDouble() ?? 0.0;

  String _money(double v) => NumberFormat.currency(
        symbol: '₹',
        locale: 'en_IN',
        decimalDigits: 0,
      ).format(v);

  String get _periodLabel {
    final m = (_slip['month'] as num?)?.toInt();
    final y = (_slip['year'] as num?)?.toInt();
    if (m == null || y == null) return 'Payslip';
    return '${DateFormat.MMMM().format(DateTime(y, m))} $y';
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid':
        return 'Paid';
      case 'on_hold':
        return 'On Hold';
      default:
        return 'Generated';
    }
  }

  Future<void> _toggleHold(bool hold) async {
    setState(() => _updating = true);
    final ok = await _service.setPayslipHold(_slip['id'].toString(), hold);
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (ok) _slip['status'] = hold ? 'on_hold' : 'generated';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (hold ? 'Payslip put on hold' : 'Payslip hold released')
            : 'Could not update payslip. Please try again.'),
        backgroundColor: ok ? AppTheme.teacherPrimary : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _slip['status']?.toString() ?? 'generated';
    final lopDays = _v(_slip['lop_days']);
    final totalDed = _v(_slip['total_deductions']) + _v(_slip['lop_deduction']);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.teacherPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration:
                    const BoxDecoration(gradient: AppTheme.teacherGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payslip • $_periodLabel',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _slip['teacher_name']?.toString() ?? 'Teacher',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_slip['employee_id'] ?? ''} • ${_slip['department'] ?? ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Net pay hero
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.teacherGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.glowShadow(AppTheme.teacherPrimary),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Pay',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(_v(_slip['net_pay'])),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Working days ${_v(_slip['working_days']).toStringAsFixed(0)} • Present ${_v(_slip['present_days']).toStringAsFixed(lopDays % 1 == 0 ? 0 : 1)} • LOP ${lopDays.toStringAsFixed(lopDays % 1 == 0 ? 0 : 1)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Earnings
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(Icons.trending_up, 'Earnings',
                          AppTheme.teacherPrimary),
                      const SizedBox(height: 16),
                      _row('Basic Salary', _v(_slip['basic'])),
                      _row('HRA', _v(_slip['hra'])),
                      _row('Travel Allowance', _v(_slip['travel'])),
                      _row('Medical Allowance', _v(_slip['medical'])),
                      if (_v(_slip['special']) > 0)
                        _row('Special Allowance', _v(_slip['special'])),
                      if (_v(_slip['other_allowances']) > 0)
                        _row('Other Allowances', _v(_slip['other_allowances'])),
                      const Divider(height: 24),
                      _row('Gross Salary', _v(_slip['gross']), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Deductions
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                          Icons.trending_down, 'Deductions', AppTheme.error),
                      const SizedBox(height: 16),
                      _row('Provident Fund', _v(_slip['pf'])),
                      if (_v(_slip['professional_tax']) > 0)
                        _row('Professional Tax', _v(_slip['professional_tax'])),
                      if (_v(_slip['income_tax']) > 0)
                        _row('Income Tax', _v(_slip['income_tax'])),
                      if (_v(_slip['other_deductions']) > 0)
                        _row('Other Deductions', _v(_slip['other_deductions'])),
                      if (_v(_slip['lop_deduction']) > 0)
                        _row(
                          'LOP Deduction (${lopDays.toStringAsFixed(lopDays % 1 == 0 ? 0 : 1)} days)',
                          _v(_slip['lop_deduction']),
                          red: true,
                        ),
                      const Divider(height: 24),
                      _row('Total Deductions', totalDed, bold: true, red: true),
                    ],
                  ),
                ),

                // HR hold action
                if (widget.isHR && status != 'paid') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _updating
                          ? null
                          : () => _toggleHold(status != 'on_hold'),
                      icon: Icon(
                        status == 'on_hold'
                            ? Icons.play_circle_outline
                            : Icons.pause_circle_outline,
                        color: status == 'on_hold'
                            ? AppTheme.teacherPrimary
                            : AppTheme.error,
                      ),
                      label: Text(
                        status == 'on_hold' ? 'Release Hold' : 'Put on Hold',
                        style: TextStyle(
                          color: status == 'on_hold'
                              ? AppTheme.teacherPrimary
                              : AppTheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: status == 'on_hold'
                              ? AppTheme.teacherPrimary
                              : AppTheme.error,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, double value, {bool bold = false, bool red = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade600,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontSize: 13.5,
              color: red ? AppTheme.error : const Color(0xFF1F2937),
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
