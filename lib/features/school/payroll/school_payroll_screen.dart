import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_payroll_service.dart';
import '../../../services/school_export_service.dart';
import '../../../services/auth_service.dart';

class SchoolPayrollScreen extends StatefulWidget {
  const SchoolPayrollScreen({super.key});

  @override
  State<SchoolPayrollScreen> createState() => _SchoolPayrollScreenState();
}

class _SchoolPayrollScreenState extends State<SchoolPayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _payrollService = SchoolPayrollService();

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _runs = [];
  List<Map<String, dynamic>> _structures = [];
  Map<String, dynamic> _stats = {};

  // Tokens
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _emerald = Color(0xFF059669);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _amber = Color(0xFFD97706);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayrollData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayrollData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final runs = await _payrollService.getPayrollRuns();
      final structures = await _payrollService.getSalaryStructures();
      final stats = await _payrollService.getPayrollStats();

      if (mounted) {
        setState(() {
          _runs = runs;
          _structures = structures;
          _stats = stats;
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
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'School Payroll & Staff Remuneration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh Data',
            onPressed: _loadPayrollData,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Export Monthly Trend (SP-R01)',
            onPressed: () => _exportMonthlyCostTrend(context),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Payroll Runs'),
            Tab(icon: Icon(Icons.badge_rounded, size: 18), text: 'Salary Structures (HR)'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRunsTab(isWide),
                    _buildStructuresTab(isWide),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Generate Run', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: _showGenerateRunModal,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RUNS TAB
  // ---------------------------------------------------------------------------
  Widget _buildRunsTab(bool isWide) {
    return RefreshIndicator(
      onRefresh: _loadPayrollData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildKpiRow(isWide),
          const SizedBox(height: 16),
          _buildCostTrendCard(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payroll Cycles & Disbursement Register',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
              ),
              Text(
                '${_runs.length} Runs Recorded',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_runs.isEmpty)
            _buildEmptyRunsCard()
          else
            ..._runs.map((r) => _buildRunCard(r)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildKpiRow(bool isWide) {
    final gross = (_stats['latest_gross'] as num?)?.toDouble() ?? 0.0;
    final net = (_stats['latest_net'] as num?)?.toDouble() ?? 0.0;
    final ded = (_stats['latest_deductions'] as num?)?.toDouble() ?? 0.0;
    final staff = _stats['staff_count'] ?? 0;

    return isWide
        ? Row(
            children: [
              Expanded(child: _buildKpiTile('Gross Liability', '₹${gross.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined, _primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiTile('Statutory Deductions', '₹${ded.toStringAsFixed(0)}', Icons.shield_outlined, _amber)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiTile('Net Disbursement', '₹${net.toStringAsFixed(0)}', Icons.check_circle_outline, _emerald)),
              const SizedBox(width: 12),
              Expanded(child: _buildKpiTile('Staff on Payroll', '$staff Faculty', Icons.groups_outlined, _violet)),
            ],
          )
        : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildKpiTile('Gross Liability', '₹${gross.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined, _primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiTile('Net Disbursement', '₹${net.toStringAsFixed(0)}', Icons.check_circle_outline, _emerald)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildKpiTile('Statutory Deductions', '₹${ded.toStringAsFixed(0)}', Icons.shield_outlined, _amber)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildKpiTile('Staff on Payroll', '$staff Faculty', Icons.groups_outlined, _violet)),
                ],
              ),
            ],
          );
  }

  Widget _buildKpiTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _muted)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostTrendCard() {
    final costTrend = (_stats['cost_trend'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (costTrend.isEmpty) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (int i = 0; i < costTrend.length; i++) {
      final net = (costTrend[i]['net'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), net / 1000.0)); // In Thousands
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 18, color: _primary),
                  SizedBox(width: 8),
                  Text(
                    'Payroll Monthly Expenditure Trend (SP-R01)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('₹ in Thousands', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < costTrend.length) {
                          final m = costTrend[idx]['month']?.toString() ?? '';
                          return Text(m.length > 5 ? m.substring(5) : m, style: const TextStyle(fontSize: 10, color: _muted));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunCard(Map<String, dynamic> r) {
    final status = (r['status']?.toString() ?? 'draft').toLowerCase();
    final isLocked = status == 'locked' || status == 'paid';
    final isPaid = status == 'paid';

    Color statusColor = _amber;
    if (isPaid) {
      statusColor = _emerald;
    } else if (isLocked) {
      statusColor = _primary;
    }

    final net = (r['total_net_pay'] as num?)?.toDouble() ?? 0.0;
    final staff = r['total_staff'] ?? 0;
    final month = r['month_year']?.toString() ?? 'Current';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.calendar_month_rounded, color: statusColor, size: 22),
        ),
        title: Row(
          children: [
            Text(
              'Cycle: $month',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '$staff Employees • Net: ₹${net.toStringAsFixed(0)}',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cycle Start: ${r['start_date'] ?? '-'}', style: const TextStyle(fontSize: 11.5, color: _muted)),
              Text('Cycle End: ${r['end_date'] ?? '-'}', style: const TextStyle(fontSize: 11.5, color: _muted)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gross Pay: ₹${((r['total_gross'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink)),
              Text('Deductions: ₹${((r['total_deductions'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _danger)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.people_outline, size: 16),
                label: const Text('View Payslips'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _border),
                ),
                onPressed: () => _showPayslipsModal(r),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export Excel (SP-R02)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _emerald,
                  side: const BorderSide(color: _border),
                ),
                onPressed: () => _exportPayslipRegister(r),
              ),
              if (!isLocked)
                ElevatedButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Lock Month'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _confirmLockRun(r),
                ),
              if (isLocked && !isPaid)
                ElevatedButton.icon(
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Mark Paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _emerald,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _confirmPayRun(r),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRunsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: _muted),
          const SizedBox(height: 12),
          const Text(
            'No Payroll Cycles Generated',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'Generate monthly payroll runs to compute teacher salaries, PF, ESI, and LOP deductions automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _muted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showGenerateRunModal,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Generate First Run'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STRUCTURES TAB
  // ---------------------------------------------------------------------------
  Widget _buildStructuresTab(bool isWide) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Staff Remuneration Structures',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
            ),
            Text(
              '${_structures.length} Configured',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._structures.map((s) => _buildStructureCard(s)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStructureCard(Map<String, dynamic> s) {
    final empId = s['employee_id']?.toString() ?? '';
    final name = s['employee_name']?.toString() ?? 'Faculty Member';
    final desig = s['designation']?.toString() ?? 'Teacher';
    final gross = (s['gross_salary'] as num?)?.toDouble() ?? 0.0;
    final basic = (s['basic_pay'] as num?)?.toDouble() ?? 0.0;
    final pf = (s['provident_fund'] as num?)?.toDouble() ?? 0.0;
    final esi = (s['esi_deduction'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _primary.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name.substring(0, 1) : 'S',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                    Text('$empId • $desig', style: const TextStyle(fontSize: 11.5, color: _muted)),
                  ],
                ),
              ),
              Text(
                '₹${gross.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _emerald),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Basic: ₹${basic.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, color: _muted)),
              Text('PF (12%): ₹${pf.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, color: _muted)),
              Text('ESI (0.75%): ₹${esi.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODALS & ACTIONS
  // ---------------------------------------------------------------------------
  void _showGenerateRunModal() {
    final now = DateTime.now();
    final defaultMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final monthCtrl = TextEditingController(text: defaultMonth);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate School Payroll Run',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Computes gross earnings, PF (12%), ESI (0.75%), PT (₹200), and LOP deductions for all active faculty.',
              style: TextStyle(fontSize: 12.5, color: _muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: monthCtrl,
              decoration: const InputDecoration(
                labelText: 'Month / Year (YYYY-MM)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final monthYear = monthCtrl.text.trim();
                  if (monthYear.isEmpty) return;

                  final parts = monthYear.split('-');
                  final year = int.tryParse(parts[0]) ?? now.year;
                  final month = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? now.month;
                  final startDate = DateTime(year, month, 1);
                  final endDate = DateTime(year, month + 1, 0);

                  setState(() => _isLoading = true);
                  final currentUser = await AuthService().getCurrentUsername() ?? 'sadmin1';
                  await _payrollService.generatePayrollRun(
                    monthYear: monthYear,
                    startDate: startDate,
                    endDate: endDate,
                    createdBy: currentUser,
                  );
                  _loadPayrollData();
                },
                child: const Text('Execute Computation', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayslipsModal(Map<String, dynamic> run) async {
    final runId = run['id']?.toString() ?? '';
    final month = run['month_year']?.toString() ?? '';
    final slips = await _payrollService.getPayslipsForRun(runId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payslips: Cycle $month', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: slips.length,
                itemBuilder: (c, i) {
                  final s = slips[i];
                  final name = s['employee_name']?.toString() ?? '';
                  final empId = s['employee_id']?.toString() ?? '';
                  final net = (s['net_pay'] as num?)?.toDouble() ?? 0.0;
                  final status = s['status']?.toString() ?? 'normal';

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    subtitle: Text('$empId • Status: ${status.toUpperCase()}', style: const TextStyle(fontSize: 11, color: _muted)),
                    trailing: Text('₹${net.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: _emerald)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLockRun(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock Payroll Cycle?'),
        content: Text('Are you sure you want to lock the payroll cycle for ${r['month_year']}? No further modifications will be allowed without an administrative override.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final currentUser = await AuthService().getCurrentUsername() ?? 'sadmin1';
              await _payrollService.lockPayrollRun(r['id'], lockedBy: currentUser);
              _loadPayrollData();
            },
            child: const Text('Confirm Lock'),
          ),
        ],
      ),
    );
  }

  void _confirmPayRun(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Payroll as Paid?'),
        content: Text('Confirm disbursement for ${r['month_year']}. All active payslips will be marked as paid and audited.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _emerald, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final currentUser = await AuthService().getCurrentUsername() ?? 'sadmin1';
              await _payrollService.markPayrollRunPaid(r['id'], paidBy: currentUser);
              _loadPayrollData();
            },
            child: const Text('Confirm Disbursement'),
          ),
        ],
      ),
    );
  }

  void _exportMonthlyCostTrend(BuildContext context) async {
    await SchoolExportService.exportSchoolPayrollMonthlyCostExcel(
      context: context,
      runs: _runs,
    );
  }

  void _exportPayslipRegister(Map<String, dynamic> r) async {
    final runId = r['id']?.toString() ?? '';
    final month = r['month_year']?.toString() ?? '';
    final slips = await _payrollService.getPayslipsForRun(runId);
    if (!context.mounted) return;

    await SchoolExportService.exportSchoolPayslipRegisterExcel(
      context: context,
      monthYear: month,
      payslips: slips,
    );
  }

  Widget _buildLoadingSkeleton() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _danger),
          const SizedBox(height: 12),
          Text(_errorMessage ?? 'Failed to load payroll records', style: const TextStyle(fontSize: 14, color: _muted)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadPayrollData, child: const Text('Retry')),
        ],
      ),
    );
  }
}
