import 'dart:ui' show ImageFilter;

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

  static const Color _accent = Color(0xFF14B8A6);
  static const Color _accentDeep = Color(0xFF0F766E);

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
                        _buildStatsRow(),
                        const SizedBox(height: 22),
                        _buildActionButtons(),
                        const SizedBox(height: 22),
                        ERPSectionHeader(
                          title: "Today's Schedule",
                          icon: Icons.calendar_today_outlined,
                          actionLabel: 'Full Timetable',
                          onAction: () => context.go('/school/timetable'),
                        ),
                        ..._todaySchedule.map((s) => _buildScheduleCard(s)),
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
          colors: [Color(0xFFF0FDFA), Color(0xFFEFF6FF), Color(0xFFF5F3FF)],
        ),
      ),
      child: Stack(
        children: [
          _buildOrb(top: -90, right: -70, size: 280, color: _accentDeep),
          _buildOrb(top: 320, left: -110, size: 260, color: const Color(0xFF3B82F6)),
          _buildOrb(bottom: -80, right: -60, size: 240, color: const Color(0xFF8B5CF6)),
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
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF2DD4BF)],
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
                              child: const Icon(Icons.school, size: 32, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _teacherName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _teacherClass,
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
        'label': 'Leave Requests',
        'icon': Icons.event_busy_outlined,
        'gradient': [const Color(0xFFBE123C), const Color(0xFFFB7185)],
        'route': '/school/leave',
      },
      {
        'label': 'Add Homework',
        'icon': Icons.assignment_add,
        'gradient': [const Color(0xFF10B981), const Color(0xFF34D399)],
        'route': '/school/homework/add',
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
      {
        'label': 'Library',
        'icon': Icons.local_library_outlined,
        'gradient': [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
        'route': '/school/library',
      },
      {
        'label': 'Reports Hub',
        'icon': Icons.analytics_outlined,
        'gradient': [const Color(0xFF059669), const Color(0xFF34D399)],
        'route': '/school/reports',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ERPSectionHeader(title: 'Quick Actions', icon: Icons.bolt_outlined),
        const SizedBox(height: 6),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          padding: EdgeInsets.zero,
          children: actions.map((action) {
            final colors = action['gradient'] as List<Color>;
            return GestureDetector(
              onTap: () => context.go(action['route'] as String),
              child: _GlassPanel(
                padding: const EdgeInsets.all(8),
                borderRadius: 20,
                blur: 12,
                shadowColor: colors[0],
                shadowOpacity: 0.26,
                gradientColors: [
                  colors[0].withValues(alpha: 0.92),
                  colors[1].withValues(alpha: 0.78),
                ],
                borderColor: Colors.white.withValues(alpha: 0.42),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: Icon(action['icon'] as IconData, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        action['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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

  Widget _buildScheduleCard(Map<String, dynamic> s) {
    return _GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      blur: 14,
      shadowOpacity: 0.06,
      gradientColors: [
        Colors.white.withValues(alpha: 0.82),
        _accent.withValues(alpha: 0.10),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.class_outlined, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (s['subject']?.toString() ?? 'Subject'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${s['class'] ?? s['class_name'] ?? s['class_id'] ?? 'Class'} • ${s['room'] ?? 'Room'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.20)),
            ),
            child: Text(
              (s['time'] ?? (s['start_time'] != null && s['end_time'] != null ? '${s['start_time']} - ${s['end_time']}' : (s['start_time']?.toString() ?? 'Scheduled'))).toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF0F766E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
                  _accentDeep.withValues(alpha: 0.94),
                  _accent.withValues(alpha: 0.88),
                  const Color(0xFF2DD4BF).withValues(alpha: 0.86),
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
                            child: const Icon(Icons.school, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teacherName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'School Teacher',
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
                  _buildDrawerItem(Icons.how_to_reg, 'Attendance', () => context.go('/school/attendance')),
                  _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
                  _buildDrawerItem(Icons.assignment_add, 'Add Homework', () => context.go('/school/homework/add')),
                  _buildDrawerItem(Icons.description_outlined, 'Report Card', () => context.go('/school/report-card')),
                  _buildDrawerItem(Icons.event_busy_outlined, 'Leave Requests', () => context.go('/school/leave')),
                  _buildDrawerItem(Icons.calendar_today_outlined, 'Timetable', () => context.go('/school/timetable')),
                  _buildDrawerItem(Icons.local_library_outlined, 'Library', () => context.go('/school/library')),
                  _buildDrawerItem(Icons.analytics_outlined, 'Reports Hub', () => context.go('/school/reports')),
                  _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
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
    this.shadowColor,
    this.shadowOpacity = 0.10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final Color? shadowColor;
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
            color: (shadowColor ?? const Color(0xFF334155)).withValues(alpha: shadowOpacity),
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

