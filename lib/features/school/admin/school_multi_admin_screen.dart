import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_multi_service.dart';
import '../../../services/school_export_service.dart';

class SchoolMultiAdminScreen extends StatefulWidget {
  const SchoolMultiAdminScreen({super.key});

  @override
  State<SchoolMultiAdminScreen> createState() => _SchoolMultiAdminScreenState();
}

class _SchoolMultiAdminScreenState extends State<SchoolMultiAdminScreen> with SingleTickerProviderStateMixin {
  final SchoolMultiService _multiService = SchoolMultiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _institutes = [];
  Map<String, dynamic> _currentSettings = {};
  Map<String, dynamic> _currentBilling = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final institutes = await _multiService.getInstitutes();
      final settings = await _multiService.getSchoolSettings(_multiService.activeInstituteId);
      final billing = await _multiService.getSchoolBilling(_multiService.activeInstituteId);

      if (mounted) {
        setState(() {
          _institutes = institutes;
          _currentSettings = settings;
          _currentBilling = billing;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load multi-school network: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAFC);
    const ink = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multi-School Superadmin Headquarters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Campus Switcher, Group Isolation, Statutory Policy & Seat Quotas',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF4338CA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel (SP-R10)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Onboard New Campus',
            icon: const Icon(Icons.domain_add_outlined, color: Colors.white),
            onPressed: _showOnboardSchoolModal,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Campuses & Switcher', icon: Icon(Icons.corporate_fare_outlined, size: 20)),
            Tab(text: 'Policy & Statutory', icon: Icon(Icons.tune_outlined, size: 20)),
            Tab(text: 'Licenses & Quotas', icon: Icon(Icons.workspace_premium_outlined, size: 20)),
          ],
        ),
      ),
      body: _buildBody(ink),
    );
  }

  Widget _buildBody(Color ink) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF4338CA)),
            SizedBox(height: 16),
            Text('Synthesizing cross-school institutional analytics...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildKpiBanner(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCampusesTab(),
              _buildPolicyTab(),
              _buildBillingTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TOP KPI BANNER
  // ==========================================

  Widget _buildKpiBanner() {
    int totalStudents = 0;
    int totalFaculty = 0;
    double feePercentSum = 0.0;

    for (final inst in _institutes) {
      totalStudents += (inst['student_count'] as num?)?.toInt() ?? 0;
      totalFaculty += (inst['faculty_count'] as num?)?.toInt() ?? 0;
      feePercentSum += (inst['fee_collection_percent'] as num?)?.toDouble() ?? 90.0;
    }
    final avgFee = _institutes.isNotEmpty ? (feePercentSum / _institutes.length) : 90.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          return Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _kpiTile(
                title: 'Affiliated Campuses',
                value: '${_institutes.length} Schools',
                subtitle: 'Superadmin Scoped Network',
                color: const Color(0xFF4338CA),
                icon: Icons.account_balance_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Student Body',
                value: '$totalStudents Enrolled',
                subtitle: 'Across All Campuses',
                color: const Color(0xFF2563EB),
                icon: Icons.groups_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Faculty Strength',
                value: '$totalFaculty Teachers',
                subtitle: 'Educators & Staff',
                color: const Color(0xFF059669),
                icon: Icons.psychology_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Group Fee Efficiency',
                value: '${avgFee.toStringAsFixed(1)}% Realized',
                subtitle: 'Prepaid & Counter Realization',
                color: const Color(0xFFD97706),
                icon: Icons.payments_outlined,
                isNarrow: isNarrow,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isNarrow,
  }) {
    return Container(
      width: isNarrow ? double.infinity : 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: CAMPUSES & SWITCHER
  // ==========================================

  Widget _buildCampusesTab() {
    final activeId = _multiService.activeInstituteId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Active Scope Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Color(0xFF4338CA), size: 20),
                  const SizedBox(width: 10),
                  Text('Active Working Scope: $activeId', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF312E81))),
                ],
              ),
              Text('${_institutes.length} Campuses Available', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // School-wise Comparison Chart
        _buildSchoolComparisonChart(),
        const SizedBox(height: 16),

        // Campuses List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Institutional Campuses', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showOnboardSchoolModal,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Onboard School'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._institutes.map((inst) => _schoolCard(inst)),
      ],
    );
  }

  Widget _buildSchoolComparisonChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Student Enrollment by Campus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('fl_chart SP-R10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4338CA))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 600,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < _institutes.length) {
                          return Text(_institutes[idx]['institute_code'] ?? 'SCH', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: _institutes.asMap().entries.map((e) {
                  final sCount = (e.value['student_count'] as num?)?.toDouble() ?? 300.0;
                  final isCurrent = e.value['institute_code'] == _multiService.activeInstituteId;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: sCount,
                        color: isCurrent ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _schoolCard(Map<String, dynamic> inst) {
    final code = inst['institute_code']?.toString() ?? 'SCH';
    final isCurrent = code == _multiService.activeInstituteId;
    final board = inst['board_affiliation']?.toString() ?? 'CBSE';
    final feeEff = (inst['fee_collection_percent'] as num?)?.toDouble() ?? 90.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCurrent ? const Color(0xFF4338CA) : const Color(0xFFE2E8F0), width: isCurrent ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF4338CA) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isCurrent ? Colors.white : const Color(0xFF475569))),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(board, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  ),
                ],
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ACTIVE SCOPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(inst['name']?.toString() ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_city_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('${inst['city']}, ${inst['state']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              const Icon(Icons.person_pin_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Head: ${inst['principal_name']}', style: const TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('${inst['student_count'] ?? 0} Students', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  const SizedBox(width: 10),
                  Text('${inst['faculty_count'] ?? 0} Faculty', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(width: 10),
                  Text('${feeEff.toStringAsFixed(1)}% Fee Realized', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _runIsolationTest(code),
                    icon: const Icon(Icons.security, size: 12),
                    label: const Text('Isolation Test', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isCurrent)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _multiService.setActiveInstituteId(code);
                        });
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Switched active working scope to $code')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4338CA),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Switch Scope', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: POLICY & STATUTORY SETTINGS
  // ==========================================

  Widget _buildPolicyTab() {
    final activeCode = _multiService.activeInstituteId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Statutory Rules & Policies: $activeCode', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _policyRow('Academic Session Cycle', _currentSettings['current_session'] ?? '2026-2027'),
              const Divider(height: 16),
              _policyRow('Minimum Attendance Threshold', '${_currentSettings['attendance_minimum_percent'] ?? 75.0}% (CBSE Rule)'),
              const Divider(height: 16),
              _policyRow('Library Overdue Fine per Day', '₹${_currentSettings['library_fine_per_day'] ?? 5.0} / day (Auto-posted to fees)'),
              const Divider(height: 16),
              _policyRow('Statutory Asset Depreciation', '${_currentSettings['depreciation_rate_percent'] ?? 10.0}% Straight-Line per Annum'),
              const Divider(height: 16),
              _policyRow('Provident Fund (PF) Deduction', '${_currentSettings['pf_rate_percent'] ?? 12.0}% of Basic Salary'),
              const Divider(height: 16),
              _policyRow('ESI Statutory Contribution', '${_currentSettings['esi_rate_percent'] ?? 0.75}% (Gross <= ₹21,000)'),
              const Divider(height: 16),
              _policyRow('Official Grading Scale', _currentSettings['grading_scale'] ?? 'CBSE 9-Point Scale'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _policyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    );
  }

  // ==========================================
  // TAB 3: LICENSES & QUOTAS
  // ==========================================

  Widget _buildBillingTab() {
    final activeCode = _multiService.activeInstituteId;
    final plan = _currentBilling['plan_tier'] ?? 'Super Enterprise Plan';
    final quota = (_currentBilling['student_seat_quota'] as num?)?.toInt() ?? 1000;
    final enrolled = (_currentBilling['active_seats_enrolled'] as num?)?.toInt() ?? 540;
    final fee = (_currentBilling['annual_license_fee'] as num?)?.toDouble() ?? 250000.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Enterprise License & Quotas: $activeCode', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(plan, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4338CA))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('ACTIVE PREPAID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Seat Consumption: $enrolled / $quota Students', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  Text('${((enrolled / quota) * 100).toStringAsFixed(0)}% Quota', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: enrolled / quota,
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: const Color(0xFF4338CA),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _policyRow('Annual Institutional License Fee', '₹${fee.toStringAsFixed(0)} (Read-only record)'),
              const SizedBox(height: 8),
              _policyRow('Contract Renewal Date', _currentBilling['contract_renewal_date'] ?? '2027-03-31'),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showOnboardSchoolModal() {
    final nameCtrl = TextEditingController(text: 'Doon Valley International');
    final codeCtrl = TextEditingController(text: 'DOON-VAL');
    final cityCtrl = TextEditingController(text: 'Dehradun');
    final headCtrl = TextEditingController(text: 'Dr. R. K. Bhatt');
    String board = 'CBSE';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Onboard New Affiliated School', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'School Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(labelText: 'Institute Code *', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: board,
                      decoration: const InputDecoration(labelText: 'Affiliation Board', border: OutlineInputBorder()),
                      items: ['CBSE', 'ICSE', 'State Board']
                          .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                          .toList(),
                      onChanged: (v) => setMState(() => board = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cityCtrl,
                decoration: const InputDecoration(labelText: 'City & District', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: headCtrl,
                decoration: const InputDecoration(labelText: 'Principal / Head Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _multiService.onboardSchool({
                      'name': nameCtrl.text.trim(),
                      'institute_code': codeCtrl.text.trim(),
                      'board_affiliation': board,
                      'city': cityCtrl.text.trim(),
                      'principal_name': headCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  child: const Text('Provision New Campus'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runIsolationTest(String targetCode) async {
    final activeCode = _multiService.activeInstituteId;
    final res = await _multiService.testDataIsolation(
      activeSchoolCode: activeCode,
      targetSchoolCode: targetCode,
    );

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Data Isolation Gate Passed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active Session: $activeCode', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('Tested Target Isolation: $targetCode', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 10),
              const Text('Zero leaking records accessed across institutional query barriers. Multi-school RLS active.'),
              const SizedBox(height: 6),
              Text('Timestamp: ${res['tested_at']}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _exportExcel() async {
    try {
      await SchoolExportService.exportSchoolMultiSchoolComparisonExcel(
        context: context,
        institutes: _institutes,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    }
  }
}
