import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_alumni_service.dart';
import '../../../services/school_export_service.dart';

class SchoolAlumniScreen extends StatefulWidget {
  const SchoolAlumniScreen({super.key});

  @override
  State<SchoolAlumniScreen> createState() => _SchoolAlumniScreenState();
}

class _SchoolAlumniScreenState extends State<SchoolAlumniScreen> with SingleTickerProviderStateMixin {
  final SchoolAlumniService _alumniService = SchoolAlumniService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _alumni = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _donations = [];

  String _searchQuery = '';
  int? _selectedPassingYear;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final alumniList = await _alumniService.getAlumniProfiles(
        search: _searchQuery,
        passingYear: _selectedPassingYear,
      );
      final eventsList = await _alumniService.getAlumniEvents();
      final donationsList = await _alumniService.getDonationInterests();

      if (mounted) {
        setState(() {
          _alumni = alumniList;
          _events = eventsList;
          _donations = donationsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load alumni community data: $e';
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
              'Alumni Relations & Network',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Community Directory, Reunions, Mentorship & Giving',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel (SP-R06)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Send Alumni Notice',
            icon: const Icon(Icons.campaign_outlined, color: Colors.white),
            onPressed: _showBroadcastModal,
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
            Tab(text: 'Alumni Directory', icon: Icon(Icons.groups_outlined, size: 20)),
            Tab(text: 'Events & Reunions', icon: Icon(Icons.event_outlined, size: 20)),
            Tab(text: 'Institutional Causes', icon: Icon(Icons.volunteer_activism_outlined, size: 20)),
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
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
            SizedBox(height: 16),
            Text('Connecting to Shivalik Alumni Network...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  backgroundColor: const Color(0xFF2563EB),
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
              _buildDirectoryTab(),
              _buildEventsTab(),
              _buildDonationsTab(),
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
    final totalAlumni = _alumni.length;
    final totalMentors = _alumni.where((a) => a['willing_to_mentor'] == true).length;
    final totalEvents = _events.length;
    double totalPledges = 0.0;
    for (final d in _donations) {
      totalPledges += (d['pledge_amount_estimate'] as num?)?.toDouble() ?? 0.0;
    }

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
                title: 'Alumni Strength',
                value: '$totalAlumni Registered',
                subtitle: 'Batches 2018–2024',
                color: const Color(0xFF2563EB),
                icon: Icons.school_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Active Mentors',
                value: '$totalMentors Mentors',
                subtitle: 'Available for Students',
                color: const Color(0xFF059669),
                icon: Icons.psychology_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Upcoming Meets',
                value: '$totalEvents Events',
                subtitle: 'Reunions & Lectures',
                color: const Color(0xFF7C3AED),
                icon: Icons.calendar_month_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Expressed Causes',
                value: '₹${(totalPledges / 1000).toStringAsFixed(1)}k Pledged',
                subtitle: '${_donations.length} Expressions',
                color: const Color(0xFFD97706),
                icon: Icons.volunteer_activism_outlined,
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
  // TAB 1: ALUMNI DIRECTORY
  // ==========================================

  Widget _buildDirectoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search & Filters Bar
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, college, company, or degree...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onSubmitted: (val) {
                  setState(() => _searchQuery = val.trim());
                  _loadData();
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _showRegisterAlumnusModal,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text('Add Alumnus'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Batch Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _batchChip('All Batches', null),
              _batchChip('2023', 2023),
              _batchChip('2022', 2022),
              _batchChip('2021', 2021),
              _batchChip('2020', 2020),
              _batchChip('2019', 2019),
              _batchChip('2018', 2018),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Batch-wise Distribution Chart
        _buildBatchDistributionChart(),
        const SizedBox(height: 16),

        // Directory Cards List
        if (_alumni.isEmpty)
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
                Icon(Icons.person_search_outlined, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text('No alumni found matching your criteria', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                SizedBox(height: 4),
                Text('Try clearing the search query or changing the batch filter.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          )
        else
          ..._alumni.map((a) => _alumniCard(a)),
      ],
    );
  }

  Widget _batchChip(String label, int? year) {
    final isSelected = _selectedPassingYear == year;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedPassingYear = year);
          _loadData();
        },
        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  Widget _buildBatchDistributionChart() {
    final counts = <int, int>{};
    for (final a in _alumni) {
      final y = (a['passing_year'] as num?)?.toInt() ?? 2020;
      counts[y] = (counts[y] ?? 0) + 1;
    }
    final sortedYears = [2018, 2019, 2020, 2021, 2022, 2023];

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
              Text('Alumni Representation by Graduation Year', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('fl_chart SP-R06', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 6,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < sortedYears.length) {
                          return Text(sortedYears[idx].toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: sortedYears.asMap().entries.map((e) {
                  final y = e.value;
                  final count = counts[y] ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: const Color(0xFF2563EB),
                        width: 18,
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

  Widget _alumniCard(Map<String, dynamic> a) {
    final status = a['current_status']?.toString() ?? 'Employed';
    final isMentor = a['willing_to_mentor'] == true;
    final year = a['passing_year']?.toString() ?? '2020';

    Color statusColor;
    if (status.contains('Higher')) {
      statusColor = const Color(0xFF2563EB);
    } else if (status.contains('Civil')) {
      statusColor = const Color(0xFF7C3AED);
    } else if (status.contains('Entrepreneur')) {
      statusColor = const Color(0xFFD97706);
    } else {
      statusColor = const Color(0xFF059669);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), offset: Offset(0, 2), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.12),
                child: Text(
                  (a['full_name']?.toString() ?? 'A').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          a['full_name']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Class of $year', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a['designation_degree']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    Text(
                      a['organization_college']?.toString() ?? '-',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                ),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('${a['city'] ?? 'Dehradun'}, ${a['country'] ?? 'India'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(width: 12),
                  const Icon(Icons.lock_outline, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  const Text('Contact masked for privacy', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
              if (isMentor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 12, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text('Student Mentor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EVENTS & REUNIONS
  // ==========================================

  Widget _buildEventsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Upcoming Meets & Reunions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showCreateEventModal,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Host Meet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._events.map((evt) => _eventCard(evt)),
      ],
    );
  }

  Widget _eventCard(Map<String, dynamic> evt) {
    final mode = evt['mode']?.toString() ?? 'In-Person';
    final rsvps = (evt['rsvp_count'] as num?)?.toInt() ?? 12;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(evt['event_type']?.toString().toUpperCase() ?? 'REUNION',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mode.contains('Hybrid') ? const Color(0xFFD97706).withValues(alpha: 0.1) : const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(mode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: mode.contains('Hybrid') ? const Color(0xFFD97706) : const Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(evt['title']?.toString() ?? '-', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(evt['description']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                (evt['event_date']?.toString() ?? '').split('T')[0],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.place_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  evt['venue']?.toString() ?? 'Auditorium',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$rsvps Alumni Attending', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
              ElevatedButton.icon(
                onPressed: () => _showRsvpModal(evt),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: const Text('RSVP Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: INSTITUTIONAL GIVING & CAUSES
  // ==========================================

  Widget _buildDonationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transparent Institutional Giving: This module tracks alumni interest and pledges for school development causes. Per policy, NO monetary transactions are collected in this software.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Community Pledges & Interest Expressions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showPledgeInterestModal,
              icon: const Icon(Icons.volunteer_activism_outlined, size: 16),
              label: const Text('Express Pledge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._donations.map((d) => _donationCard(d)),
      ],
    );
  }

  Widget _donationCard(Map<String, dynamic> d) {
    final amount = (d['pledge_amount_estimate'] as num?)?.toDouble() ?? 5000.0;
    final status = d['status']?.toString() ?? 'Expressed Interest';

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
              Text(d['alumni_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('₹${amount.toStringAsFixed(0)} Est. Pledge', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(d['cause_area']?.toString() ?? 'Scholarship', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              ),
              const SizedBox(width: 8),
              Text('Status: $status', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          if (d['message'] != null && d['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${d['message']}"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF334155))),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showRegisterAlumnusModal() {
    final nameCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '2023');
    final collegeCtrl = TextEditingController();
    final degreeCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Dehradun');
    bool willingMentor = true;
    String status = 'Higher Education';

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
              const Text('Register New Alumnus', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Passing Year', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Current Status', border: OutlineInputBorder()),
                      items: ['Higher Education', 'Employed', 'Entrepreneur', 'Civil Services']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setMState(() => status = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: collegeCtrl,
                decoration: const InputDecoration(labelText: 'University / Company', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: degreeCtrl,
                decoration: const InputDecoration(labelText: 'Degree / Job Designation', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Willing to Mentor Current Students', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: willingMentor,
                activeThumbColor: const Color(0xFF059669),
                onChanged: (v) => setMState(() => willingMentor = v),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _alumniService.registerAlumniProfile({
                      'full_name': nameCtrl.text.trim(),
                      'passing_year': int.tryParse(yearCtrl.text) ?? 2023,
                      'batch_name': 'Class of ${yearCtrl.text}',
                      'current_status': status,
                      'organization_college': collegeCtrl.text.trim(),
                      'designation_degree': degreeCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                      'willing_to_mentor': willingMentor,
                    });
                    _loadData();
                  },
                  child: const Text('Save Alumnus Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateEventModal() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final venueCtrl = TextEditingController(text: 'School Auditorium');
    String mode = 'In-Person';
    String eventType = 'Reunion';

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
              const Text('Create Alumni Event / Meet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Event Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: eventType,
                      decoration: const InputDecoration(labelText: 'Event Type', border: OutlineInputBorder()),
                      items: ['Reunion', 'Guest Lecture', 'Career Mentorship', 'Networking']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setMState(() => eventType = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                      items: ['In-Person', 'Hybrid', 'Virtual / Webinar']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setMState(() => mode = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: venueCtrl,
                decoration: const InputDecoration(labelText: 'Venue / Meeting Details', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _alumniService.createAlumniEvent({
                      'title': titleCtrl.text.trim(),
                      'event_type': eventType,
                      'mode': mode,
                      'venue': venueCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  child: const Text('Publish Alumni Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRsvpModal(Map<String, dynamic> evt) {
    final nameCtrl = TextEditingController(text: 'Rohan Mehrotra');
    final emailCtrl = TextEditingController(text: 'rohan.m@alumni.org');
    int guests = 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm RSVP: ${evt['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Your Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Your Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Accompanying Guests:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: guests > 0 ? () => setMState(() => guests--) : null,
                      ),
                      Text('$guests', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setMState(() => guests++),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _alumniService.submitAlumniRsvp(
                      eventId: evt['id']?.toString() ?? 'evt',
                      alumniName: nameCtrl.text.trim(),
                      alumniEmail: emailCtrl.text.trim(),
                      status: 'Attending',
                      guestCount: guests,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('RSVP confirmed successfully! See you at the reunion!')),
                    );
                    _loadData();
                  },
                  child: const Text('Confirm Attendance (Attending)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPledgeInterestModal() {
    final nameCtrl = TextEditingController(text: 'Aditya Kapoor');
    final emailCtrl = TextEditingController(text: 'aditya.k@alumni.org');
    final msgCtrl = TextEditingController();
    String cause = 'STEM & Robotics Lab';
    double amount = 25000;

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
              const Text('Express Institutional Cause Pledge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Your Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: cause,
                decoration: const InputDecoration(labelText: 'Cause Area', border: OutlineInputBorder()),
                items: ['Student Scholarship', 'STEM & Robotics Lab', 'Sports Complex', 'Library Books', 'General Infrastructure']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (v) => setMState(() => cause = v!),
              ),
              const SizedBox(height: 10),
              Text('Estimated Contribution: ₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Slider(
                value: amount,
                min: 5000,
                max: 100000,
                divisions: 19,
                activeColor: const Color(0xFFD97706),
                label: '₹${amount.toStringAsFixed(0)}',
                onChanged: (v) => setMState(() => amount = v),
              ),
              TextField(
                controller: msgCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Personal Message / Vision (Optional)', border: OutlineInputBorder()),
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
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _alumniService.submitDonationInterest(
                      alumniName: nameCtrl.text.trim(),
                      alumniEmail: emailCtrl.text.trim(),
                      causeArea: cause,
                      pledgeAmountEstimate: amount,
                      message: msgCtrl.text.trim(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pledge expression submitted. Our alumni cell will contact you.')),
                    );
                    _loadData();
                  },
                  child: const Text('Submit Pledge Expression'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastModal() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Alumni Community Notice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Notice Title *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Message Body *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _alumniService.sendAlumniCircular(
                title: titleCtrl.text.trim(),
                content: bodyCtrl.text.trim(),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alumni circular delivered successfully.')),
              );
            },
            child: const Text('Broadcast Notice'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportExcel() async {
    try {
      await SchoolExportService.exportSchoolAlumniEngagementExcel(
        context: context,
        alumniList: _alumni,
        donationInterests: _donations,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    }
  }
}
