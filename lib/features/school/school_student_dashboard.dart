import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../core/widgets/erp_stat_card.dart';
import '../../core/widgets/erp_section_header.dart';

class SchoolStudentDashboard extends StatefulWidget {
  const SchoolStudentDashboard({super.key});

  @override
  State<SchoolStudentDashboard> createState() => _SchoolStudentDashboardState();
}

class _SchoolStudentDashboardState extends State<SchoolStudentDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late AnimationController _fadeController;

  String _studentName = 'Student';
  String _studentClass = 'Class 10-A';
  String _admissionNo = '';

  // Quick stats
  double _attendancePercent = 94.2;
  int _pendingHomework = 3;
  String _pendingFees = '₹0';
  int _upcomingTests = 2;

  // Recent homework
  List<Map<String, dynamic>> _homework = [
    {
      'subject': 'Mathematics',
      'title': 'Chapter 5 Exercise 5.3',
      'due': 'Tomorrow',
      'color': const Color(0xFF3B82F6),
    },
    {
      'subject': 'Science',
      'title': 'Draw diagram of human heart',
      'due': 'In 3 days',
      'color': const Color(0xFF10B981),
    },
    {
      'subject': 'English',
      'title': 'Write essay on environment',
      'due': 'In 5 days',
      'color': const Color(0xFFFF6B6B),
    },
  ];

  // Recent test results
  final List<Map<String, dynamic>> _recentResults = [
    {'subject': 'Math', 'marks': '45/50', 'grade': 'A+', 'color': const Color(0xFF10B981)},
    {'subject': 'Science', 'marks': '38/50', 'grade': 'B+', 'color': const Color(0xFF3B82F6)},
    {'subject': 'English', 'marks': '42/50', 'grade': 'A', 'color': const Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) {
      setState(() {
        _studentName = username ?? 'Student';
        _admissionNo = 'SCH2026${username?.toUpperCase() ?? "001"}';
      });
    }

    try {
      final hw = await _schoolService.getHomework(classId: _studentClass);
      final attPct = await _schoolService.getStudentAttendancePercent(username ?? '');
      if (mounted) {
        setState(() {
          if (hw.isNotEmpty) {
            _homework = hw.take(3).map((h) => {
              'subject': h['subject'] ?? 'General',
              'title': h['title'] ?? 'Homework Assignment',
              'due': h['due_date'] ?? 'Upcoming',
              'color': const Color(0xFF3B82F6),
            }).toList();
            _pendingHomework = hw.where((h) => h['status'] == 'pending').length;
          }
          _attendancePercent = attPct;
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
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  ERPSectionHeader(
                    title: 'Pending Homework',
                    actionLabel: 'View All',
                    onAction: () => context.go('/school/homework'),
                    icon: Icons.assignment_outlined,
                  ),
                  ..._homework.map((hw) => _buildHomeworkCard(hw)),
                  const SizedBox(height: 24),
                  const ERPSectionHeader(
                    title: 'Recent Test Results',
                    icon: Icons.grade_outlined,
                  ),
                  _buildResultsRow(),
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
      expandedHeight: 220,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFFFF6B6B),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              SafeArea(
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
                            child: const Icon(Icons.person, size: 32, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello, $_studentName 👋',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_studentClass • $_admissionNo',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 13,
                                  ),
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
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'SCHOOL',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Attendance',
                value: '${_attendancePercent.toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => context.go('/school/attendance'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Homework',
                value: '$_pendingHomework Due',
                icon: Icons.assignment_outlined,
                color: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFFFEE2E2),
                onTap: () => context.go('/school/homework'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Fees Due',
                value: _pendingFees,
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => context.go('/school/fees'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Tests',
                value: '$_upcomingTests Upcoming',
                icon: Icons.quiz_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
                onTap: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.calendar_today_outlined, 'label': 'Timetable', 'color': const Color(0xFF3B82F6), 'route': '/school/timetable'},
      {'icon': Icons.assignment_outlined, 'label': 'Homework', 'color': const Color(0xFFFF6B6B), 'route': '/school/homework'},
      {'icon': Icons.checklist_rtl, 'label': 'Attendance', 'color': const Color(0xFF10B981), 'route': '/school/attendance'},
      {'icon': Icons.payment_outlined, 'label': 'Fees', 'color': const Color(0xFFF59E0B), 'route': '/school/fees'},
      {'icon': Icons.campaign_outlined, 'label': 'Circulars', 'color': const Color(0xFF8B5CF6), 'route': '/school/circulars'},
      {'icon': Icons.directions_bus_outlined, 'label': 'Transport', 'color': const Color(0xFF06B6D4), 'route': '/school/transport'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ERPSectionHeader(title: 'Quick Actions', icon: Icons.grid_view_outlined),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          padding: EdgeInsets.zero,
          children: actions.map((action) => _buildQuickActionCard(action)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return GestureDetector(
      onTap: () => context.go(action['route'] as String),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (action['color'] as Color).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(action['icon'] as IconData, color: action['color'] as Color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              action['label'] as String,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
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
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: hw['color'] as Color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hw['title'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 4),
                Text(
                  hw['subject'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (hw['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              hw['due'] as String,
              style: TextStyle(
                fontSize: 11,
                color: hw['color'] as Color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsRow() {
    return Row(
      children: _recentResults.map((r) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 10),
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
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (r['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.grade, color: r['color'] as Color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                r['grade'] as String,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: r['color'] as Color,
                ),
              ),
              const SizedBox(height: 4),
              Text(r['marks'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(
                r['subject'] as String,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
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
                      child: const Icon(Icons.person, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studentName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _studentClass,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
              _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
              _buildDrawerItem(Icons.checklist_rtl, 'Attendance', () => context.go('/school/attendance')),
              _buildDrawerItem(Icons.calendar_today_outlined, 'Timetable', () => context.go('/school/timetable')),
              _buildDrawerItem(Icons.payment_outlined, 'Fees', () => context.go('/school/fees')),
              _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
              _buildDrawerItem(Icons.directions_bus_outlined, 'Transport', () => context.go('/school/transport')),
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

