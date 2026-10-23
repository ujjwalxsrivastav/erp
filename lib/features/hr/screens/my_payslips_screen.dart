import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/payroll_service.dart';
import 'payslip_detail_screen.dart';

/// Teacher-facing: my own payslips across all payroll runs.
/// [username] is the teacher's login username (teacher_details.teacher_id).
class MyPayslipsScreen extends StatefulWidget {
  final String username;

  const MyPayslipsScreen({super.key, required this.username});

  @override
  State<MyPayslipsScreen> createState() => _MyPayslipsScreenState();
}

class _MyPayslipsScreenState extends State<MyPayslipsScreen> {
  final _service = PayrollService();

  List<Map<String, dynamic>> _slips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _v(dynamic k) => (k as num?)?.toDouble() ?? 0.0;

  String _money(double v) => NumberFormat.currency(
        symbol: '₹',
        locale: 'en_IN',
        decimalDigits: 0,
      ).format(v);

  String _periodLabel(Map<String, dynamic> s) {
    final m = (s['month'] as num?)?.toInt();
    final y = (s['year'] as num?)?.toInt();
    if (m == null || y == null) return 'Payslip';
    return '${DateFormat.MMMM().format(DateTime(y, m))} $y';
  }

  Future<void> _load() async {
    final slips = await _service.getPayslipsByUsername(widget.username);
    if (!mounted) return;
    setState(() {
      _slips = slips;
      _loading = false;
    });
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':
        return AppTheme.success;
      case 'on_hold':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'paid':
        return 'PAID';
      case 'on_hold':
        return 'ON HOLD';
      default:
        return 'GENERATED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final latest = _slips.isEmpty ? null : _slips.first;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        color: AppTheme.teacherPrimary,
        onRefresh: _load,
        child: CustomScrollView(
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
                      padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Payslips',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latest == null
                                ? 'Your salary slips will appear here'
                                : 'Latest: ${_periodLabel(latest)} • ${_money(_v(latest['net_pay']))} net',
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
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.teacherPrimary),
                ),
              )
            else if (_slips.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No payslips yet.\nHR has not generated payroll for any month yet.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _slipCard(_slips[i]),
                    childCount: _slips.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _slipCard(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? 'generated';
    final color = _statusColor(status);
    final lop = _v(s['lop_days']);
    final m = (s['month'] as num?)?.toInt() ?? 1;
    final y = (s['year'] as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayslipDetailScreen(payslip: s),
            ),
          );
          _load();
        },
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.teacherPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.MMM().format(DateTime(y, m)).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.teacherPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    y.toString(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _periodLabel(s),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            color: color,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (lop > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          'LOP ${lop.toStringAsFixed(lop % 1 == 0 ? 0 : 1)} days',
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(_v(s['net_pay'])),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  'net pay',
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
