import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../core/widgets/erp_section_header.dart';
import '../../../core/widgets/erp_stat_card.dart';

class SchoolParentDashboard extends StatefulWidget {
  const SchoolParentDashboard({super.key});

  @override
  State<SchoolParentDashboard> createState() => _SchoolParentDashboardState();
}

class _SchoolParentDashboardState extends State<SchoolParentDashboard>
    with TickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late AnimationController _fadeController;

  String _parentName = 'Parent';
  String _childName = 'Aarav Sharma';
  String _childClass = 'Class 10-A';
  String _admissionNo = 'SCH2026001';

  // Child stats
  double _attendance = 94.2;
  String _pendingFees = '₹0';
  int _pendingHomework = 2;
  String _lastResult = 'A+ (92%)';

  // Recent circulars
  List<Map<String, dynamic>> _circulars = [
    {'title': 'Annual Sports Day 2026', 'date': '15 Nov 2026', 'category': 'Event'},
    {'title': 'Parent-Teacher Meeting (PTM)', 'date': '20 Nov 2026', 'category': 'Academic'},
    {'title': 'Winter Uniform Guidelines', 'date': '25 Nov 2026', 'category': 'Notice'},
  ];

  static const Color _accent = Color(0xFFDB2777);
  static const Color _accentDeep = Color(0xFFBE185D);
  static const Color _accentSoft = Color(0xFFF472B6);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)..forward();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getCurrentUsername();
    if (mounted) setState(() => _parentName = username ?? 'Parent');

    try {
      final circs = await _schoolService.getCirculars();
      if (mounted && circs.isNotEmpty) {
        setState(() {
          _circulars = circs.take(3).map((c) => {
            'title': c['title'] ?? 'Notice',
            'date': c['published_at'] ?? 'Recent',
            'category': c['category'] ?? 'General',
          }).toList();
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
                        _buildChildInfoCard(),
                        const SizedBox(height: 20),
                        _buildStatsGrid(),
                        const SizedBox(height: 22),
                        ERPSectionHeader(
                          title: 'Recent Circulars',
                          icon: Icons.campaign_outlined,
                          actionLabel: 'View All',
                          onAction: () => context.go('/school/circulars'),
                        ),
                        ..._circulars.map((c) => _buildCircularCard(c)),
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
          colors: [Color(0xFFFDF2F8), Color(0xFFFFF1F2), Color(0xFFF5F3FF)],
        ),
      ),
      child: Stack(
        children: [
          _buildOrb(top: -90, right: -70, size: 280, color: _accent),
          _buildOrb(top: 330, left: -110, size: 260, color: const Color(0xFF8B5CF6)),
          _buildOrb(bottom: -80, right: -60, size: 240, color: const Color(0xFFF59E0B)),
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
      expandedHeight: 210,
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
              colors: [Color(0xFF9D174D), Color(0xFFDB2777), Color(0xFFF472B6)],
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
                bottom: 30,
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
                              width: 55,
                              height: 55,
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
                              child: const Icon(Icons.family_restroom, size: 30, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, $_parentName ðŸ‘‹',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Parent Portal',
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

  Widget _buildChildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFDB2777), Color(0xFFF472B6)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.child_care, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _childName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_childClass • $_admissionNo',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  child: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                ),
              ],
            ),
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
                value: '${_attendance.toStringAsFixed(0)}%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
                onTap: () => context.go('/school/attendance'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Fees Due',
                value: _pendingFees,
                icon: Icons.payment_outlined,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                onTap: () => context.go('/school/fees'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ERPStatCard(
                title: 'Homework Due',
                value: '$_pendingHomework',
                icon: Icons.assignment_outlined,
                color: const Color(0xFFFF6B6B),
                bgColor: const Color(0xFFFEE2E2),
                onTap: () => context.go('/school/homework'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ERPStatCard(
                title: 'Last Result',
                value: _lastResult,
                icon: Icons.grade_outlined,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF3E8FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularCard(Map<String, dynamic> c) {
    return _GlassPanel(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderRadius: 18,
      blur: 14,
      shadowOpacity: 0.06,
      gradientColors: [
        Colors.white.withValues(alpha: 0.82),
        const Color(0xFF8B5CF6).withValues(alpha: 0.10),
      ],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.20)),
            ),
            child: const Icon(Icons.campaign_outlined, color: Color(0xFF8B5CF6), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['title'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c['date'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.18)),
            ),
            child: Text(
              c['category'] as String,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF3B82F6),
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
                  const Color(0xFF9D174D).withValues(alpha: 0.94),
                  _accent.withValues(alpha: 0.89),
                  _accentSoft.withValues(alpha: 0.86),
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
                            child: const Icon(Icons.family_restroom, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Parent',
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
                  _buildDrawerItem(Icons.check_circle_outline, 'Attendance', () => context.go('/school/attendance')),
                  _buildDrawerItem(Icons.assignment_outlined, 'Homework', () => context.go('/school/homework')),
                  _buildDrawerItem(Icons.payment_outlined, 'Fees', () => context.go('/school/fees')),
                  _buildDrawerItem(Icons.campaign_outlined, 'Circulars', () => context.go('/school/circulars')),
                  _buildDrawerItem(Icons.directions_bus_outlined, 'Transport', () => context.go('/school/transport')),
                  _buildDrawerItem(Icons.grade_outlined, 'Results', () => context.go('/school/report-card')),
                  _buildDrawerItem(Icons.calendar_today_outlined, 'Timetable', () => context.go('/school/timetable')),
                  _buildDrawerItem(Icons.local_library_outlined, 'Library', () => context.go('/school/library')),
                  _buildDrawerItem(Icons.card_membership_outlined, 'Certificates', () => context.go('/school/certificates')),
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
