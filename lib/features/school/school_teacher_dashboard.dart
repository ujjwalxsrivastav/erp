import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../core/widgets/erp_stat_card.dart';
import '../../core/widgets/erp_section_header.dart';

class SchoolTeacherDashboard extends StatefulWidget {
  const SchoolTeacherDashboard({super.key});

  @override
  State<SchoolTeacherDashboard> createState() => _SchoolTeacherDashboardState();
}

class _SchoolTeacherDashboardState extends State<SchoolTeacherDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late AnimationController _fadeController;

  String _teacherName = 'Teacher';
  String _teacherClass = 'Class Teacher - 10A';

  // Stats
  int _totalStudents = 42;
  int _presentToday = 38;
  int _pendingAssignments = 5;
  int _upcomingClasses = 3;

  // Today's classes
  List<Map<String, dynamic>> _todaySchedule = [
    {'time': '08:00 - 09:00', 'subject': 'Mathematics', 'class': 'Class 10-A', 'room': 'Room 201'},
    {'time': '09:00 - 10:00', 'subject': 'Mathematics', 'class': 'Class 10-B', 'room': 'Room 301'},
    {'time': '11:00 - 12:00', 'subject': 'Mathematics', 'class': 'Class 9-A', 'room': 'Room 101'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) {
      setState(() {
        _teacherName = username ?? 'Teacher';
      });
    }

    try {
      final schedule = await _schoolService.getTeacherTimetable(username ?? '');
      final pendingHw = await _schoolService.getPendingHomeworkToGrade(username ?? '');
      if (mounted) {
        setState(() {
          if (schedule.isNotEmpty) {
            _todaySchedule = schedule;
            _upcomingClasses = schedule.length;
          }
          _pendingAssignments = pendingHw;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      drawer: _buildSidebar(context),
      body: FadeTransition(
        opacity: _fadeController,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  ERPSectionHeader(
                    title: "Today's Schedule",
                    icon: Icons.calendar_today_outlined,
                    actionLabel: 'Full Timetable',
                    onAction: () => context.go('/school/timetable'),
                  ),
                  ..._todaySchedule.map((s) => _buildScheduleCard(s)),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF0F766E),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                        ),
                        child: const Icon(Icons.school, size: 32, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _teacherName,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _teacherClass,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'SCHOOL',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Students',
                value: '$_totalStudents',
                icon: Icons.people_outline,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Present Today',
                value: '$_presentToday',
                icon: Icons.how_to_reg_outlined,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => context.go('/school/attendance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Homework',
                value: '$_pendingAssignments Pending',
                icon: Icons.assignment_outlined,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => context.go('/school/homework'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: "Classes Today",
                value: '$_upcomingClasses',
                icon: Icons.class_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                onTap: () => context.go('/school/timetable'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final actions = [
      {
        'label': 'Mark Attendance',
        'icon': Icons.how_to_reg,
        'gradient': [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
        'route': '/school/attendance',
      },
      {
        'label': 'Upload Homework',
        'icon': Icons.upload_file,
        'gradient': [const Color(0xFF10B981), const Color(0xFF34D399)],
        'route': '/school/homework/upload',
      },
      {
        'label': 'Enter Marks',
        'icon': Icons.edit_note,
        'gradient': [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
        'route': '/school/marks-entry',
      },
      {
        'label': 'Report Card',
        'icon': Icons.description_outlined,
        'gradient': [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
        'route': '/school/report-card',
      },
      {
        'label': 'Circular',
        'icon': Icons.campaign_outlined,
        'gradient': [const Color(0xFF0891B2), const Color(0xFF22D3EE)],
        'route': '/school/circulars',
      },
      {
        'label': 'Timetable',
        'icon': Icons.calendar_month,
        'gradient': [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
        'route': '/school/timetable',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ERPSectionHeader(title: 'Quick Actions', icon: Icons.bolt_outlined),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          padding: EdgeInsets.zero,
          children: actions.map((action) {
            final colors = action['gradient'] as List<Color>;
            return GestureDetector(
              onTap: () => context.go(action['route'] as String),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action['icon'] as IconData, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      action['label'] as String,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_outlined, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['subject'] as String,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s['class']} • ${s['room']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              s['time'] as String,
              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_teacherName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('School Teacher', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
              _buildDrawerItem(Icons.how_to_reg, 'Attendance', () => context.go('/school/attendance')),
              _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
              _buildDrawerItem(Icons.edit_note, 'Enter Marks', () => context.go('/school/marks-entry')),
              _buildDrawerItem(Icons.description_outlined, 'Report Card', () => context.go('/school/report-card')),
              _buildDrawerItem(Icons.calendar_today_outlined, 'Timetable', () => context.go('/school/timetable')),
              _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
              const Spacer(),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.logout, 'Logout', () async {
                await _authService.logout();
                if (mounted) context.go('/login');
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }
}

