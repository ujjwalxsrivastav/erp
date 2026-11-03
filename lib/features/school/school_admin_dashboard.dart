import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../core/widgets/erp_stat_card.dart';
import '../../core/widgets/erp_section_header.dart';

class SchoolAdminDashboard extends StatefulWidget {
  const SchoolAdminDashboard({super.key});

  @override
  State<SchoolAdminDashboard> createState() => _SchoolAdminDashboardState();
}

class _SchoolAdminDashboardState extends State<SchoolAdminDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _fadeController;

  final _schoolService = SchoolService();
  String _adminName = 'Principal';
  int _totalStudents = 1250;
  int _totalTeachers = 68;
  int _totalClasses = 24;
  double _attendanceToday = 91.5;
  int _pendingFeesCount = 18;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) setState(() => _adminName = username ?? 'Principal');

    try {
      final stats = await _schoolService.getSchoolStats(null);
      if (mounted) {
        setState(() {
          _totalStudents = (stats['total_students'] as num?)?.toInt() ?? 1250;
          _totalTeachers = (stats['total_teachers'] as num?)?.toInt() ?? 68;
          _totalClasses = (stats['total_classes'] as num?)?.toInt() ?? 24;
          _attendanceToday = (stats['attendance_today'] as num?)?.toDouble() ?? 91.5;
          _pendingFeesCount = (stats['pending_fees_count'] as num?)?.toInt() ?? 18;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
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
                  _buildManagementModules(),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
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
      backgroundColor: const Color(0xFF6D28D9),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
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
                        child: const Icon(Icons.admin_panel_settings, size: 32, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _adminName,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Principal / School Admin',
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

  Widget _buildStatsGrid() {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6))),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Total Students',
                value: '$_totalStudents',
                icon: Icons.people_outline,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Total Teachers',
                value: '$_totalTeachers',
                icon: Icons.school_outlined,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Total Classes',
                value: '$_totalClasses',
                icon: Icons.class_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: "Today's Attendance",
                value: '${_attendanceToday.toStringAsFixed(1)}%',
                icon: Icons.how_to_reg_outlined,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
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
                title: 'Pending Fee Defaulters',
                value: '$_pendingFeesCount Students',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                onTap: () => context.go('/school/fees'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagementModules() {
    final modules = [
      {'icon': Icons.analytics_outlined, 'label': 'Reports Hub', 'color': const Color(0xFF7C3AED), 'route': '/school/reports'},
      {'icon': Icons.person_add_outlined, 'label': 'Admissions', 'color': const Color(0xFF3B82F6), 'route': '/school/admissions'},
      {'icon': Icons.campaign_outlined, 'label': 'Circulars', 'color': const Color(0xFF10B981), 'route': '/school/circulars'},
      {'icon': Icons.payment_outlined, 'label': 'Fees', 'color': const Color(0xFFF59E0B), 'route': '/school/fees'},
      {'icon': Icons.directions_bus_outlined, 'label': 'Transport', 'color': const Color(0xFF8B5CF6), 'route': '/school/transport'},
      {'icon': Icons.calendar_month_outlined, 'label': 'Timetable', 'color': const Color(0xFFFF6B6B), 'route': '/school/timetable'},
      {'icon': Icons.description_outlined, 'label': 'Report Cards', 'color': const Color(0xFF06B6D4), 'route': '/school/report-card'},
      {'icon': Icons.how_to_reg_outlined, 'label': 'Attendance', 'color': const Color(0xFF10B981), 'route': '/school/attendance'},
      {'icon': Icons.local_library_outlined, 'label': 'Library', 'color': const Color(0xFF7C3AED), 'route': '/school/library'},
      {'icon': Icons.card_membership_outlined, 'label': 'Certificates', 'color': const Color(0xFF059669), 'route': '/school/certificates'},
      {'icon': Icons.assignment_outlined, 'label': 'Homework', 'color': const Color(0xFFEC4899), 'route': '/school/homework'},
      {'icon': Icons.manage_accounts_outlined, 'label': 'Manage Users', 'color': const Color(0xFF6366F1), 'route': '/admin/manage-users'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ERPSectionHeader(title: 'Management Modules', icon: Icons.grid_view_rounded),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          padding: EdgeInsets.zero,
          children: modules.map((m) => GestureDetector(
            onTap: () => context.go(m['route'] as String),
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
                      color: (m['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m['icon'] as IconData, color: m['color'] as Color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    m['label'] as String,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      {'icon': Icons.person_add, 'text': '3 new admission requests', 'time': '2h ago', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.payment, 'text': 'Fee collection: ₹45,000 today', 'time': '4h ago', 'color': const Color(0xFF10B981)},
      {'icon': Icons.campaign, 'text': 'Annual day circular published', 'time': '1d ago', 'color': const Color(0xFF8B5CF6)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ERPSectionHeader(title: 'Recent Activity', icon: Icons.history_outlined),
        ...activities.map((a) => Container(
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (a['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  a['text'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
                ),
              ),
              Text(
                a['time'] as String,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)],
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
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_adminName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('School Admin', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              _buildDrawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
              _buildDrawerItem(Icons.analytics_outlined, 'Reports Hub', () => context.go('/school/reports')),
              _buildDrawerItem(Icons.how_to_reg, 'Attendance', () => context.go('/school/attendance')),
              _buildDrawerItem(Icons.person_add_outlined, 'Admissions', () => context.go('/school/admissions')),
              _buildDrawerItem(Icons.payment_outlined, 'Fees', () => context.go('/school/fees')),
              _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
              _buildDrawerItem(Icons.directions_bus_outlined, 'Transport', () => context.go('/school/transport')),
              _buildDrawerItem(Icons.description_outlined, 'Report Cards', () => context.go('/school/report-card')),
              _buildDrawerItem(Icons.local_library_outlined, 'Library', () => context.go('/school/library')),
              _buildDrawerItem(Icons.card_membership_outlined, 'Certificates', () => context.go('/school/certificates')),
              _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
              _buildDrawerItem(Icons.manage_accounts_outlined, 'Manage Users', () => context.go('/admin/manage-users')),
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

