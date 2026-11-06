import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_discipline_service.dart';
import '../../../services/school_export_service.dart';

class SchoolDisciplineScreen extends StatefulWidget {
  const SchoolDisciplineScreen({super.key});

  @override
  State<SchoolDisciplineScreen> createState() => _SchoolDisciplineScreenState();
}

class _SchoolDisciplineScreenState extends State<SchoolDisciplineScreen> with SingleTickerProviderStateMixin {
  final SchoolDisciplineService _disciplineService = SchoolDisciplineService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _incidents = [];
  String _selectedCategory = 'All';
  String _selectedSeverity = 'All';

  final List<String> _categories = [
    'All',
    'Classroom Disruption',
    'Bullying / Misconduct',
    'Late / Punctuality',
    'Property Damage',
    'Academic Dishonesty',
  ];

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
      final incidents = await _disciplineService.getIncidents(
        category: _selectedCategory,
        severity: _selectedSeverity,
      );

      if (mounted) {
        setState(() {
          _incidents = incidents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load discipline register: $e';
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
              'Discipline & Behavioural Conduct',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Incident Tracking, Inquiries, Administrative Actions & Parent Collaboration',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF881337), Color(0xFFBE123C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel (SP-R09)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Report Incident',
            icon: const Icon(Icons.add_alert_outlined, color: Colors.white),
            onPressed: _showReportIncidentModal,
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
            Tab(text: 'Case Register', icon: Icon(Icons.list_alt_outlined, size: 20)),
            Tab(text: 'Inquiry Desk', icon: Icon(Icons.find_in_page_outlined, size: 20)),
            Tab(text: 'Actions & Notices', icon: Icon(Icons.gavel_outlined, size: 20)),
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
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFBE123C)),
            SizedBox(height: 16),
            Text('Gathering incident records and inquiry ledgers...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  backgroundColor: const Color(0xFFBE123C),
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
              _buildRegisterTab(),
              _buildInquiryTab(),
              _buildActionsTab(),
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
    final totalCases = _incidents.length;
    final inqCases = _incidents.where((i) => i['status'] == 'Reported' || i['status'] == 'Inquiring').length;
    final criticalCases = _incidents.where((i) => i['severity'] == 'High' || i['severity'] == 'Critical').length;
    final resolvedCases = _incidents.where((i) => i['status'] == 'Resolved').length;

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
                title: 'Logged Cases',
                value: '$totalCases Total',
                subtitle: 'All Recorded Incidents',
                color: const Color(0xFFBE123C),
                icon: Icons.shield_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Open Inquiries',
                value: '$inqCases Pending',
                subtitle: 'In Investigation Phase',
                color: const Color(0xFFD97706),
                icon: Icons.pending_actions_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'High / Critical',
                value: '$criticalCases Severe',
                subtitle: 'Requiring Admin Review',
                color: const Color(0xFFEF4444),
                icon: Icons.warning_amber_rounded,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Fully Resolved',
                value: '$resolvedCases Cases',
                subtitle: 'Fair Process Closed',
                color: const Color(0xFF059669),
                icon: Icons.check_circle_outline,
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
  // TAB 1: INCIDENTS & CASE LEDGER
  // ==========================================

  Widget _buildRegisterTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Category Filters
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedCategory = cat);
                    _loadData();
                  },
                  selectedColor: const Color(0xFFBE123C).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFFBE123C),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? const Color(0xFFBE123C) : const Color(0xFFE2E8F0)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Incident Categories BarChart
        _buildIncidentCategoryChart(),
        const SizedBox(height: 16),

        // Cases List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Logged Incident Cases', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showReportIncidentModal,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Log Incident'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._incidents.map((inc) => _incidentCard(inc)),
      ],
    );
  }

  Widget _buildIncidentCategoryChart() {
    final catCounts = <String, int>{
      'Late': 1,
      'Disruption': 1,
      'Misconduct': 1,
      'Property': 0,
      'Academic': 0,
    };
    final labels = catCounts.keys.toList();

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
              Text('Incident Distribution by Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('fl_chart SP-R09', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBE123C))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 5,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < labels.length) {
                          return Text(labels[idx], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: labels.asMap().entries.map((e) {
                  final count = catCounts[e.value] ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: const Color(0xFFBE123C),
                        width: 22,
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

  Widget _incidentCard(Map<String, dynamic> inc) {
    final sev = inc['severity']?.toString() ?? 'Medium';
    final status = inc['status']?.toString() ?? 'Reported';

    Color sevColor;
    if (sev == 'Critical' || sev == 'High') {
      sevColor = const Color(0xFFEF4444);
    } else if (sev == 'Medium') {
      sevColor = const Color(0xFFD97706);
    } else {
      sevColor = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(inc['incident_number']?.toString() ?? 'INC', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: sevColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(sev.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sevColor)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'Resolved' ? const Color(0xFF059669).withValues(alpha: 0.1) : const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: status == 'Resolved' ? const Color(0xFF059669) : const Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${inc['student_name']} (${inc['class_section']})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(inc['description']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.room_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(inc['location']?.toString() ?? 'Classroom', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              const Icon(Icons.person_outline, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Reported: ${inc['reported_by_name'] ?? 'Faculty'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          if (inc['action_summary'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel, size: 13, color: Color(0xFFBE123C)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Action: ${inc['action_summary']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status != 'Resolved') ...[
                OutlinedButton.icon(
                  onPressed: () => _showRecordInquiryModal(inc),
                  icon: const Icon(Icons.find_in_page_outlined, size: 12),
                  label: const Text('Inquire', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showTakeActionModal(inc),
                  icon: const Icon(Icons.gavel_outlined, size: 12),
                  label: const Text('Take Action', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: INQUIRY DESK
  // ==========================================

  Widget _buildInquiryTab() {
    final pendingInquiries = _incidents.where((i) => i['status'] == 'Reported' || i['status'] == 'Inquiring').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Inquiries in Investigation', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${pendingInquiries.length} Cases', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingInquiries.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.verified_user_outlined, size: 48, color: Color(0xFF059669)),
                SizedBox(height: 12),
                Text('All reported incidents have completed inquiry', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                SizedBox(height: 4),
                Text('Fair process verified across institutional cases.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          )
        else
          ...pendingInquiries.map((inc) => _incidentCard(inc)),
      ],
    );
  }

  // ==========================================
  // TAB 3: ACTIONS & PARENT NOTICES
  // ==========================================

  Widget _buildActionsTab() {
    final resolvedCases = _incidents.where((i) => i['status'] == 'Resolved' || i['status'] == 'Action Taken').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Actions Enforced & Parent Notifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${resolvedCases.length} Enforced', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        ...resolvedCases.map((inc) => _incidentCard(inc)),
      ],
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showReportIncidentModal() {
    final nameCtrl = TextEditingController(text: 'Aarav Sharma');
    final classCtrl = TextEditingController(text: '10-A');
    final roomCtrl = TextEditingController(text: 'Classroom 102');
    final descCtrl = TextEditingController();
    String category = 'Classroom Disruption';
    String severity = 'Medium';

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
              const Text('Report Disciplinary Incident', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: classCtrl,
                      decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: _categories.where((c) => c != 'All')
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setMState(() => category = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: severity,
                      decoration: const InputDecoration(labelText: 'Severity Level', border: OutlineInputBorder()),
                      items: ['Low', 'Medium', 'High', 'Critical']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setMState(() => severity = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Location / Room', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Factual Description of Incident *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _disciplineService.reportIncident({
                      'student_name': nameCtrl.text.trim(),
                      'class_section': classCtrl.text.trim(),
                      'location': roomCtrl.text.trim(),
                      'category': category,
                      'severity': severity,
                      'description': descCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  child: const Text('File Incident Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordInquiryModal(Map<String, dynamic> inc) {
    final findingsCtrl = TextEditingController(text: 'Interrogated witnesses; student admitted responsibility and showed remorse.');
    final studentStmtCtrl = TextEditingController(text: 'I acknowledge the disruption and will not repeat this behavior.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
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
            Text('Fair Inquiry: ${inc['incident_number']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: studentStmtCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Student Statement / Perspective', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: findingsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Investigation Findings *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _disciplineService.recordInquiry(
                    incidentId: inc['id']?.toString() ?? 'inc',
                    findings: findingsCtrl.text.trim(),
                    studentStatement: studentStmtCtrl.text.trim(),
                  );
                  _loadData();
                },
                child: const Text('Record Inquiry Findings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTakeActionModal(Map<String, dynamic> inc) {
    final notesCtrl = TextEditingController(text: 'Formal parent conference conducted with class teacher and student counselor.');
    String actionType = 'Parent Conference';
    bool notifyParent = true;

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
              Text('Enforce Action: ${inc['incident_number']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: actionType,
                decoration: const InputDecoration(labelText: 'Administrative Action', border: OutlineInputBorder()),
                items: [
                  'Verbal Warning',
                  'Written Reprimand',
                  'Counselling Session',
                  'Parent Conference',
                  'Suspension',
                  'Community Service',
                ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setMState(() => actionType = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Resolution & Corrective Plan Notes', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Dispatch In-App Notice to Parent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: notifyParent,
                activeThumbColor: const Color(0xFFBE123C),
                onChanged: (v) => setMState(() => notifyParent = v),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBE123C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _disciplineService.recordDisciplinaryAction(
                      incidentId: inc['id']?.toString() ?? 'inc',
                      studentId: inc['student_id']?.toString() ?? 'sstudent1',
                      studentName: inc['student_name']?.toString() ?? 'Student',
                      actionType: actionType,
                      actionNotes: notesCtrl.text.trim(),
                    );
                    if (notifyParent) {
                      await _disciplineService.sendDisciplineParentNotice(
                        incidentId: inc['id']?.toString() ?? 'inc',
                        studentId: inc['student_id']?.toString() ?? 'sstudent1',
                        noticeTitle: 'Discipline Notice: $actionType for ${inc['student_name']}',
                        noticeBody: notesCtrl.text.trim(),
                        scheduledMeetingDate: DateTime.now().add(const Duration(days: 3)),
                      );
                    }
                    _loadData();
                  },
                  child: const Text('Enforce Action & Close Case'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      await SchoolExportService.exportSchoolDisciplineRegisterExcel(
        context: context,
        incidents: _incidents,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    }
  }
}
