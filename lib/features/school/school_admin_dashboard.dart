import 'dart:ui' show ImageFilter;

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

  static const Color _accent = Color(0xFF8B5CF6);
  static const Color _accentDeep = Color(0xFF6D28D9);

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
          _totalStudents = (stats['total_students'] as num?)?.toInt() ?? 0;
          _totalTeachers = (stats['total_teachers'] as num?)?.toInt() ?? 0;
          _totalClasses = (stats['total_classes'] as num?)?.toInt() ?? 0;
          _attendanceToday = (stats['attendance_today'] as num?)?.toDouble() ?? 0.0;
          _pendingFeesCount = (stats['pending_fees_count'] as num?)?.toInt() ?? 0;
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
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildSidebar(context),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground()),
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeController,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildStatsGrid(),
                        const SizedBox(height: 22),
                        _buildManagementModules(),
                        const SizedBox(height: 22),
                        _buildRecentActivity(),
                      ]),
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

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F3FF), Color(0xFFEEF2FF), Color(0xFFFDF2F8)],
        ),
      ),
      child: Stack(
        children: [
          _buildOrb(top: -90, right: -70, size: 280, color: _accentDeep),
          _buildOrb(top: 330, left: -110, size: 260, color: const Color(0xFF3B82F6)),
          _buildOrb(bottom: -80, right: -60, size: 240, color: const Color(0xFFEC4899)),
        ],
      ),
    );
  }

  Widget _buildOrb({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 216,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _accentDeep,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF8B5CF6)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                right: 34,
                bottom: 34,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.4,
                    ),
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
                      _GlassPanel(
                        padding: const EdgeInsets.all(14),
                        borderRadius: 22,
                        blur: 16,
                        shadowOpacity: 0.14,
                        gradientColors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                        borderColor: Colors.white.withValues(alpha: 0.38),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Principal / School Admin',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.30),
                                ),
                              ),
                              child: const Text(
                                'SCHOOL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
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
      {'icon': Icons.trending_up_rounded, 'label': 'Promotion', 'color': const Color(0xFF0D9488), 'route': '/school/promotion'},
      {'icon': Icons.assignment_outlined, 'label': 'Homework', 'color': const Color(0xFFEC4899), 'route': '/school/homework'},
      {'icon': Icons.manage_accounts_outlined, 'label': 'Manage Users', 'color': const Color(0xFF6366F1), 'route': '/admin/manage-users'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ERPSectionHeader(title: 'Management Modules', icon: Icons.grid_view_rounded),
        const SizedBox(height: 6),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          padding: EdgeInsets.zero,
          children: modules.map((m) {
            final color = m['color'] as Color;
            return GestureDetector(
              onTap: () => context.go(m['route'] as String),
              child: _GlassPanel(
                padding: const EdgeInsets.all(8),
                borderRadius: 20,
                blur: 14,
                shadowOpacity: 0.06,
                gradientColors: [
                  Colors.white.withValues(alpha: 0.82),
                  color.withValues(alpha: 0.14),
                ],
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.22),
                            color.withValues(alpha: 0.06),
                          ],
                        ),
                        border: Border.all(color: color.withValues(alpha: 0.22)),
                      ),
                      child: Icon(m['icon'] as IconData, color: color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        m['label'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
        const SizedBox(height: 2),
        ...activities.map((a) {
          final color = a['color'] as Color;
          return _GlassPanel(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            borderRadius: 18,
            blur: 14,
            shadowOpacity: 0.06,
            gradientColors: [
              Colors.white.withValues(alpha: 0.82),
              color.withValues(alpha: 0.10),
            ],
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.20)),
                  ),
                  child: Icon(a['icon'] as IconData, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    (a['text']?.toString() ?? ''),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Text(
                  (a['time']?.toString() ?? ''),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4C1D95).withValues(alpha: 0.94),
                  _accentDeep.withValues(alpha: 0.90),
                  _accent.withValues(alpha: 0.86),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    child: _GlassPanel(
                      padding: const EdgeInsets.all(14),
                      borderRadius: 20,
                      blur: 12,
                      shadowOpacity: 0,
                      gradientColors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                      borderColor: Colors.white.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.20),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _adminName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'School Admin',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.80),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
                  _buildDrawerItem(Icons.person_add_outlined, 'Admissions', () => context.go('/school/admissions')),
                  _buildDrawerItem(Icons.payment_outlined, 'Fees', () => context.go('/school/fees')),
                  _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
                  _buildDrawerItem(Icons.directions_bus_outlined, 'Transport', () => context.go('/school/transport')),
                  _buildDrawerItem(Icons.description_outlined, 'Report Cards', () => context.go('/school/report-card')),
                  _buildDrawerItem(Icons.how_to_reg, 'Attendance', () => context.go('/school/attendance')),
                  _buildDrawerItem(Icons.local_library_outlined, 'Library', () => context.go('/school/library')),
                  _buildDrawerItem(Icons.card_membership_outlined, 'Certificates', () => context.go('/school/certificates')),
                  _buildDrawerItem(Icons.trending_up_rounded, 'Promotion', () => context.go('/school/promotion')),
                  _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
                  _buildDrawerItem(Icons.analytics_outlined, 'Reports Hub', () => context.go('/school/reports')),
                  _buildDrawerItem(Icons.manage_accounts_outlined, 'Manage Users', () => context.go('/admin/manage-users')),
                  const Spacer(),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                  const SizedBox(height: 8),
                  _buildDrawerItem(Icons.logout, 'Logout', () async {
                    await _authService.logout();
                    if (mounted) context.go('/login');
                  }),
                  const SizedBox(height: 18),
                ],
              ),
)
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        splashColor: Colors.white.withValues(alpha: 0.10),
        hoverColor: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

/// Frosted glass surface used by the School dashboards.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 22,
    this.blur = 18,
    this.gradientColors,
    this.borderColor,
    this.shadowOpacity = 0.10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF334155).withValues(alpha: shadowOpacity),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors ??
                    [
                      Colors.white.withValues(alpha: 0.78),
                      Colors.white.withValues(alpha: 0.46),
                    ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.75),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
