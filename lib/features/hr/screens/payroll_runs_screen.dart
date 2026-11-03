import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/payroll_service.dart';
import 'payslip_detail_screen.dart';

/// HR: monthly payroll runs.
/// Generate a run for a month → every active teacher's salary structure
/// is frozen into payslips (with LOP from salary-deducted approved
/// leaves) → review the register → mark the run paid.
class PayrollRunsScreen extends StatefulWidget {
  const PayrollRunsScreen({super.key});

  @override
  State<PayrollRunsScreen> createState() => _PayrollRunsScreenState();
}

class _PayrollRunsScreenState extends State<PayrollRunsScreen> {
  final _service = PayrollService();

  List<Map<String, dynamic>> _runs = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  bool _generating = false;

  late int _selMonth;
  late int _selYear;

  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    // Default to the previous month — the one usually being processed.
    final prev = DateTime(DateTime.now().year, DateTime.now().month - 1);
    _selMonth = prev.month;
    _selYear = prev.year;
    _load();
  }

  double _v(dynamic k) => (k as num?)?.toDouble() ?? 0.0;

  String _money(double v) => NumberFormat.currency(
        symbol: '₹',
        locale: 'en_IN',
        decimalDigits: 0,
      ).format(v);

  String _periodLabel(Map<String, dynamic> run) {
    final m = (run['month'] as num?)?.toInt() ?? 1;
    final y = (run['year'] as num?)?.toInt() ?? 0;
    return '${monthNames[(m - 1).clamp(0, 11)]} $y';
  }

  Future<void> _load() async {
    final stats = await _service.getPayrollStats();
    final runs = await _service.getRuns();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _runs = runs;
      _loading = false;
    });
  }

  static Color runStatusColor(String s) {
    switch (s) {
      case 'paid':
        return AppTheme.success;
      case 'locked':
        return AppTheme.adminPrimary;
      case 'processed':
        return AppTheme.warning;
      default:
        return AppTheme.lightGray;
    }
  }

  Future<void> _confirmGenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text('Generate Payroll — ${monthNames[_selMonth - 1]} $_selYear'),
        content: const Text(
          'Payslips will be generated for every active teacher with an '
          'active salary structure.\n\n'
          'LOP rule: approved leaves flagged as salary-deducted count as '
          'loss-of-pay days. Deduction = Gross ÷ days in month × LOP days.\n\n'
          'A month can only be generated once — the payslips are then '
          'frozen as the salary register for that month.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teacherPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _generating = true);
    final result = await _service.generateRun(_selMonth, _selYear, 'hr');
    if (!mounted) return;
    setState(() => _generating = false);

    if (result['error'] != null) {
      _snack(result['error'].toString(), error: true);
      return;
    }
    if (result['alreadyExists'] == true) {
      _snack(
          'Payroll for ${monthNames[_selMonth - 1]} $_selYear is already generated.');
      return;
    }
    final skipped = (result['skippedNoSalary'] as num?)?.toInt() ?? 0;
    _snack(
      'Payroll generated: ${result['payslips']} payslips'
      '${skipped > 0 ? ' • $skipped teacher(s) skipped (no salary structure)' : ''}.',
    );
    _load();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.error : AppTheme.teacherPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = _stats['latestRun'] as Map<String, dynamic>?;
    final onPayroll = (_stats['employeesOnPayroll'] as num?)?.toInt() ?? 0;
    final totalRuns = (_stats['totalRuns'] as num?)?.toInt() ?? 0;
    final years = <int>{
      DateTime.now().year - 2,
      DateTime.now().year - 1,
      DateTime.now().year,
      DateTime.now().year + 1,
    }.toList()
      ..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        color: AppTheme.teacherPrimary,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 190,
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
                            'Payroll Runs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _headerStat('On Payroll', onPayroll.toString()),
                              const SizedBox(width: 10),
                              _headerStat('Total Runs', totalRuns.toString()),
                              const SizedBox(width: 10),
                              _headerStat(
                                'Latest Net',
                                latest == null
                                    ? '—'
                                    : _money(_v(latest['total_net'])),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Generator card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Monthly Payroll',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              value: _selMonth,
                              decoration: _inputDeco('Month'),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(monthNames[i]),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _selMonth = v ?? _selMonth),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: _selYear,
                              decoration: _inputDeco('Year'),
                              items: years
                                  .map((y) => DropdownMenuItem(
                                        value: y,
                                        child: Text(y.toString()),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selYear = v ?? _selYear),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generating ? null : _confirmGenerate,
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.playlist_add_check_rounded),
                          label:
                              Text(_generating ? 'Generating…' : 'Generate Payroll'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.teacherPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Runs list
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.teacherPrimary),
                ),
              )
            else if (_runs.isEmpty)
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
                        'No payroll runs yet.\nGenerate the first one above.',
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _runCard(_runs[i]),
                    childCount: _runs.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.extraLightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.extraLightGray),
        ),
      );

  Widget _headerStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _runCard(Map<String, dynamic> run) {
    final status = run['status']?.toString() ?? 'draft';
    final color = runStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayrollRunDetailScreen(run: run),
            ),
          );
          _load();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.teacherPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppTheme.teacherPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _periodLabel(run),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        '${(run['employees_count'] as num?)?.toInt() ?? 0} employees'
                        '${run['processed_by'] != null ? ' • by ${run['processed_by']}' : ''}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _miniFigure('Gross', _money(_v(run['total_gross']))),
                _miniFigure('Deductions', _money(_v(run['total_deductions'])),
                    red: true),
                _miniFigure('Net Payable', _money(_v(run['total_net'])),
                    bold: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniFigure(String label, String value,
      {bool bold = false, bool red = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: red ? AppTheme.error : const Color(0xFF1F2937),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Register view for one run: searchable payslip list + Mark Paid.
class PayrollRunDetailScreen extends StatefulWidget {
  final Map<String, dynamic> run;

  const PayrollRunDetailScreen({super.key, required this.run});

  @override
  State<PayrollRunDetailScreen> createState() => _PayrollRunDetailScreenState();
}

class _PayrollRunDetailScreenState extends State<PayrollRunDetailScreen> {
  final _service = PayrollService();

  late Map<String, dynamic> _run;
  List<Map<String, dynamic>> _slips = [];
  bool _loading = true;
  bool _paying = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _run = Map<String, dynamic>.from(widget.run);
    _load();
  }

  double _v(dynamic k) => (k as num?)?.toDouble() ?? 0.0;

  String _money(double v) => NumberFormat.currency(
        symbol: '₹',
        locale: 'en_IN',
        decimalDigits: 0,
      ).format(v);

  String get _periodLabel {
    final m = (_run['month'] as num?)?.toInt() ?? 1;
    final y = (_run['year'] as num?)?.toInt() ?? 0;
    return '${_PayrollRunsScreenState.monthNames[(m - 1).clamp(0, 11)]} $y';
  }

  Future<void> _load() async {
    final fresh = await _service.getRunById(_run['id'].toString());
    final slips = await _service.getPayslips(_run['id'].toString());
    if (!mounted) return;
    setState(() {
      if (fresh != null) _run = fresh;
      _slips = slips;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _slips;
    final q = _search.toLowerCase();
    return _slips.where((s) {
      return (s['teacher_name']?.toString() ?? '').toLowerCase().contains(q) ||
          (s['employee_id']?.toString() ?? '').toLowerCase().contains(q) ||
          (s['department']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _markPaid() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark $_periodLabel as Paid?'),
        content: const Text(
          'All generated payslips in this run will be marked Paid. '
          'Payslips on hold will stay on hold until released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.teacherPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _paying = true);
    final ok = await _service.markRunPaid(_run['id'].toString());
    if (!mounted) return;
    setState(() => _paying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '$_periodLabel payroll marked as paid.'
            : 'Could not update the run. Please try again.'),
        backgroundColor: ok ? AppTheme.teacherPrimary : AppTheme.error,
      ),
    );
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _run['status']?.toString() ?? 'draft';
    final canPay = status == 'processed';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppTheme.teacherPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _periodLabel,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canPay)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _paying ? null : _markPaid,
                icon: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 18),
                label: Text(_paying ? 'Paying…' : 'Mark Paid',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: const BoxDecoration(gradient: AppTheme.teacherGradient),
            child: Row(
              children: [
                _stripFigure('Employees',
                    '${(_run['employees_count'] as num?)?.toInt() ?? _slips.length}'),
                _stripFigure('Gross', _money(_v(_run['total_gross']))),
                _stripFigure('Net', _money(_v(_run['total_net']))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.cardShadow,
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search name, employee ID, department…',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppTheme.teacherPrimary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.teacherPrimary),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _slips.isEmpty
                              ? 'No payslips in this run.'
                              : 'No payslips match your search.',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.teacherPrimary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) =>
                              _slipRow(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _stripFigure(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slipRow(Map<String, dynamic> s) {
    final name = s['teacher_name']?.toString() ?? 'Teacher';
    final lop = _v(s['lop_days']);
    final status = s['status']?.toString() ?? 'generated';
    final statusColor = status == 'paid'
        ? AppTheme.success
        : status == 'on_hold'
            ? AppTheme.error
            : AppTheme.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PayslipDetailScreen(payslip: s, isHR: true),
            ),
          );
          _load();
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.teacherPrimary.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'T',
                style: const TextStyle(
                  color: AppTheme.teacherPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${s['employee_id'] ?? ''} • ${s['department'] ?? ''}',
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status == 'on_hold'
                              ? 'ON HOLD'
                              : status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (lop > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LOP ${lop.toStringAsFixed(lop % 1 == 0 ? 0 : 1)}d',
                            style: const TextStyle(
                              color: AppTheme.error,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(_v(s['net_pay'])),
                  style: const TextStyle(
                    fontSize: 15,
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
          ],
        ),
      ),
    );
  }
}
