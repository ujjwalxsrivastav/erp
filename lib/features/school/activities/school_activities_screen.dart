import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_activities_service.dart';
import '../../../services/school_export_service.dart';

class SchoolActivitiesScreen extends StatefulWidget {
  const SchoolActivitiesScreen({super.key});

  @override
  State<SchoolActivitiesScreen> createState() => _SchoolActivitiesScreenState();
}

class _SchoolActivitiesScreenState extends State<SchoolActivitiesScreen> with SingleTickerProviderStateMixin {
  final SchoolActivitiesService _activitiesService = SchoolActivitiesService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _clubs = [];
  List<Map<String, dynamic>> _teams = [];
  List<Map<String, dynamic>> _participations = [];

  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Sports',
    'Science & Innovation',
    'Literary',
    'Cultural',
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
      final events = await _activitiesService.getActivityEvents(category: _selectedCategory);
      final clubs = await _activitiesService.getClubs();
      final teams = await _activitiesService.getSportsTeams();
      final participations = await _activitiesService.getParticipations();

      if (mounted) {
        setState(() {
          _events = events;
          _clubs = clubs;
          _teams = teams;
          _participations = participations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load activity rosters: $e';
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
              'Activities, Clubs & Sports Desk',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              'Co-Curricular Events, Student Societies & Athletic Honors',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white70),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel (SP-R08)',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onPressed: _exportExcel,
          ),
          IconButton(
            tooltip: 'Host Activity Event',
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: _showCreateEventModal,
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
            Tab(text: 'Events & Meets', icon: Icon(Icons.event_available_outlined, size: 20)),
            Tab(text: 'Clubs & Societies', icon: Icon(Icons.groups_outlined, size: 20)),
            Tab(text: 'Sports & Honors', icon: Icon(Icons.emoji_events_outlined, size: 20)),
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
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF059669)),
            SizedBox(height: 16),
            Text('Gathering co-curricular events and sports rosters...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
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
                  backgroundColor: const Color(0xFF059669),
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
              _buildEventsTab(),
              _buildClubsTab(),
              _buildSportsTab(),
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
    int totalParticipants = 0;
    for (final e in _events) {
      totalParticipants += (e['participant_count'] as num?)?.toInt() ?? 0;
    }
    totalParticipants += _participations.length;

    int totalMembers = 0;
    for (final c in _clubs) {
      totalMembers += (c['member_count'] as num?)?.toInt() ?? 0;
    }

    final totalTeams = _teams.length;
    final totalMedals = _participations.where((p) {
      final a = (p['position_award'] ?? '').toString();
      return a.contains('1st') || a.contains('2nd') || a.contains('3rd') || a.contains('Gold') || a.contains('Silver') || a.contains('Bronze');
    }).length;

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
                title: 'Student Participation',
                value: '$totalParticipants Entries',
                subtitle: 'Across Events & Sports',
                color: const Color(0xFF059669),
                icon: Icons.sports_kabaddi_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Active Clubs',
                value: '${_clubs.length} Societies',
                subtitle: '$totalMembers Enrolled Members',
                color: const Color(0xFF2563EB),
                icon: Icons.hub_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Sports Squads',
                value: '$totalTeams Teams',
                subtitle: 'CBSE Sahodaya & Inter-House',
                color: const Color(0xFF7C3AED),
                icon: Icons.sports_cricket_outlined,
                isNarrow: isNarrow,
              ),
              _kpiTile(
                title: 'Honors & Medals',
                value: '$totalMedals Accolades',
                subtitle: '${_participations.length} Verified Records',
                color: const Color(0xFFD97706),
                icon: Icons.military_tech_outlined,
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
  // TAB 1: SCHOOL EVENTS & MEETS
  // ==========================================

  Widget _buildEventsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Category Filter Chips
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
                  selectedColor: const Color(0xFF059669).withValues(alpha: 0.15),
                  checkmarkColor: const Color(0xFF059669),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Activity Participation BarChart
        _buildParticipationChart(),
        const SizedBox(height: 16),

        // Events List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Institutional Meets & Competitions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showCreateEventModal,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._events.map((evt) => _eventCard(evt)),
      ],
    );
  }

  Widget _buildParticipationChart() {
    final domainCounts = <String, int>{
      'Sports': 184,
      'STEM': 92,
      'Literary': 48,
      'Cultural': 210,
    };
    final domains = domainCounts.keys.toList();

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
              Text('Student Participation Across Activity Domains', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('fl_chart SP-R08', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 250,
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
                        if (idx >= 0 && idx < domains.length) {
                          return Text(domains[idx], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: domains.asMap().entries.map((e) {
                  final count = domainCounts[e.value] ?? 0;
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: const Color(0xFF059669),
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

  Widget _eventCard(Map<String, dynamic> evt) {
    final cat = evt['category']?.toString() ?? 'Cultural';
    final participants = (evt['participant_count'] as num?)?.toInt() ?? 24;

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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(cat.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
              ),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text('$participants Enrolled', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(evt['title']?.toString() ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(evt['event_date']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
              const SizedBox(width: 14),
              const Icon(Icons.place_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(evt['venue']?.toString() ?? 'Campus', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Coordinator: ${evt['coordinator_teacher_name'] ?? 'Faculty Coordinator'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showRegisterParticipantModal(evt),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 12),
                label: const Text('Register Contestant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
  // TAB 2: CLUBS & SOCIETIES
  // ==========================================

  Widget _buildClubsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recognized Student Clubs & Societies', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_clubs.length} Clubs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        ..._clubs.map((clb) => _clubCard(clb)),
      ],
    );
  }

  Widget _clubCard(Map<String, dynamic> clb) {
    final members = (clb['member_count'] as num?)?.toInt() ?? 25;

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
              Text(clb['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('$members Members', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(clb['description']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text('Patron: ${clb['patron_teacher_name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(clb['meeting_schedule']?.toString() ?? '-', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showJoinClubModal(clb),
                icon: const Icon(Icons.group_add_outlined, size: 12),
                label: const Text('Enroll Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
  // TAB 3: SPORTS TEAMS & HONORS
  // ==========================================

  Widget _buildSportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Institutional Sports Rosters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_teams.length} Squads', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 12),
        ..._teams.map((tm) => _sportsTeamCard(tm)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Accredited Achievements & Certificates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            ElevatedButton.icon(
              onPressed: _showAwardCertificateModal,
              icon: const Icon(Icons.workspace_premium_outlined, size: 14),
              label: const Text('Award Honors'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._participations.map((p) => _participationHonorCard(p)),
      ],
    );
  }

  Widget _sportsTeamCard(Map<String, dynamic> tm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tm['sport_name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tm['age_category']?.toString() ?? 'U-17', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.sports_outlined, size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('Coach: ${tm['coach_name']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.stars_outlined, size: 13, color: Color(0xFFD97706)),
              const SizedBox(width: 4),
              Text('Captain: ${tm['captain_student_name']}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Schedule: ${tm['training_schedule']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _participationHonorCard(Map<String, dynamic> p) {
    final award = p['position_award']?.toString() ?? 'Participant';
    final serial = p['certificate_serial']?.toString() ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${p['student_name']} (${p['class_section']})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(award, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(p['role_or_item']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Serial: $serial', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
              const Row(
                children: [
                  Icon(Icons.verified, size: 13, color: Color(0xFF059669)),
                  SizedBox(width: 4),
                  Text('Accredited Seal', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODALS & ACTIONS
  // ==========================================

  void _showCreateEventModal() {
    final titleCtrl = TextEditingController();
    final venueCtrl = TextEditingController(text: 'Main Sports Complex');
    String category = 'Sports';

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
              const Text('Create School Activity Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Event Title *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Domain Category', border: OutlineInputBorder()),
                items: ['Sports', 'Science & Innovation', 'Literary', 'Cultural']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setMState(() => category = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: venueCtrl,
                decoration: const InputDecoration(labelText: 'Venue / Ground', border: OutlineInputBorder()),
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
                    if (titleCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    await _activitiesService.createActivityEvent({
                      'title': titleCtrl.text.trim(),
                      'category': category,
                      'venue': venueCtrl.text.trim(),
                    });
                    _loadData();
                  },
                  child: const Text('Publish Activity Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRegisterParticipantModal(Map<String, dynamic> evt) {
    final nameCtrl = TextEditingController(text: 'Aarav Sharma');
    final classCtrl = TextEditingController(text: '10-A');
    final itemCtrl = TextEditingController(text: '100m Sprint & Long Jump');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enroll Contestant: ${evt['title']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: classCtrl,
              decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: itemCtrl,
              decoration: const InputDecoration(labelText: 'Specific Event / Sport Item', border: OutlineInputBorder()),
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
                  await _activitiesService.recordParticipation(
                    eventId: evt['id']?.toString() ?? 'evt',
                    studentId: 'sstudent1',
                    studentName: nameCtrl.text.trim(),
                    classSection: classCtrl.text.trim(),
                    activityType: evt['category']?.toString() ?? 'Sport',
                    roleOrItem: itemCtrl.text.trim(),
                    positionAward: 'Participant',
                  );
                  _loadData();
                },
                child: const Text('Confirm Contestant Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinClubModal(Map<String, dynamic> clb) {
    final nameCtrl = TextEditingController(text: 'Aryan Verma');
    final classCtrl = TextEditingController(text: '9-A');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enroll in Club: ${clb['name']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: classCtrl,
              decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder()),
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
                  Navigator.pop(ctx);
                  await _activitiesService.joinClub(
                    clubId: clb['id']?.toString() ?? 'clb',
                    studentId: 'sstudent2',
                    studentName: nameCtrl.text.trim(),
                    classSection: classCtrl.text.trim(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Club membership approved! Welcome to the society.')),
                  );
                  _loadData();
                },
                child: const Text('Confirm Society Membership'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAwardCertificateModal() {
    final nameCtrl = TextEditingController(text: 'Aarav Sharma');
    final classCtrl = TextEditingController(text: '10-A');
    final itemCtrl = TextEditingController(text: 'CBSE Sahodaya Athletics 200m Sprint');
    String award = '1st Place (Gold / Champions)';

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
              const Text('Award Accredited Honors & Certificate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Student Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: classCtrl,
                decoration: const InputDecoration(labelText: 'Class & Section', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(labelText: 'Competition / Item Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: award,
                decoration: const InputDecoration(labelText: 'Honors / Position Award', border: OutlineInputBorder()),
                items: [
                  '1st Place (Gold / Champions)',
                  '2nd Place (Silver Medal)',
                  '3rd Place (Bronze Medal)',
                  'Special Commendation',
                ].map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                onChanged: (v) => setMState(() => award = v!),
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
                    await _activitiesService.recordParticipation(
                      eventId: 'act-01',
                      studentId: 'sstudent1',
                      studentName: nameCtrl.text.trim(),
                      classSection: classCtrl.text.trim(),
                      activityType: 'Sport',
                      roleOrItem: itemCtrl.text.trim(),
                      positionAward: award,
                    );
                    _loadData();
                  },
                  child: const Text('Generate & Award Certificate Serial'),
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
      await SchoolExportService.exportSchoolActivitiesParticipationExcel(
        context: context,
        participations: _participations,
        clubs: _clubs,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    }
  }
}
