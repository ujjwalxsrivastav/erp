import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/school_service.dart';

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

  static const Color _ink = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _coral = Color(0xFFFB7185);

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final topInset = MediaQuery.paddingOf(context).top;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F5FF),
          drawer: isWide ? null : _buildSidebar(context),
          extendBodyBehindAppBar: true,
          appBar: isWide
              ? null
              : AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  leadingWidth: 80,
                  leading: Builder(
                    builder: (scaffoldContext) => Padding(
                      padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
                      child: _buildMenuButton(
                        () => Scaffold.of(scaffoldContext).openDrawer(),
                      ),
                    ),
                  ),
                ),
          body: Stack(
            children: [
              Positioned.fill(child: _buildBackground()),
              Positioned.fill(
                child: SafeArea(
                  top: isWide,
                  bottom: isWide,
                  left: false,
                  right: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isWide)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
                          child: _buildDesktopSidebar(context),
                        ),
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeController,
                          child: CustomScrollView(
                            physics: const BouncingScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  isWide ? 26 : 16,
                                  isWide ? 24 : topInset + 72,
                                  isWide ? 26 : 16,
                                  44,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    _buildWelcomeBanner(isWide),
                                    const SizedBox(height: 20),
                                    _buildStatsSection(isWide),
                                    const SizedBox(height: 26),
                                    _buildQuickActionsSection(),
                                    const SizedBox(height: 26),
                                    _buildLowerSections(isWide),
                                  ]),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF2FF),
            Color(0xFFF1EBFF),
            Color(0xFFFFEAF5),
            Color(0xFFFFF2EC),
          ],
          stops: [0.0, 0.42, 0.72, 1.0],
        ),
      ),
      child: Stack(
        children: [
          _buildOrb(top: -120, left: -90, size: 340, color: const Color(0xFF93C5FD)),
          _buildOrb(top: 140, right: -130, size: 380, color: const Color(0xFFC4B5FD)),
          _buildOrb(bottom: -150, left: 60, size: 380, color: const Color(0xFFFBCFE8)),
          _buildOrb(bottom: 30, right: -90, size: 300, color: const Color(0xFFFDBA74)),
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
          imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.34),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: InkWell(
            onTap: onTap,
            child: const Icon(Icons.menu_rounded, color: _ink, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(bool isWide) {
    return Container(
      height: isWide ? 244 : 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5C8DFF),
            Color(0xFF8B7CF6),
            Color(0xFFEC7FB4),
            Color(0xFFFFA17F),
          ],
          stops: [0.0, 0.45, 0.78, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _violet.withValues(alpha: 0.30),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(right: -70, top: -80, child: _bannerCircle(240, 0.14)),
            Positioned(right: 90, bottom: -90, child: _bannerCircle(190, 0.10)),
            Positioned(left: -60, bottom: -100, child: _bannerCircle(220, 0.08)),
            Positioned(
              right: 26,
              top: 42,
              child: Icon(
                Icons.auto_stories_rounded,
                size: 112,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 28 : 22,
                isWide ? 24 : 20,
                isWide ? 28 : 22,
                22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      _buildSchoolBadge(),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.36),
                                Colors.white.withValues(alpha: 0.16),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.70),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, $_studentName 👋',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isWide ? 25 : 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$_studentClass • $_admissionNo',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  Widget _buildSchoolBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_rounded, size: 13, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'SCHOOL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(bool isWide) {
    final stats = <Widget>[
      _buildStatCard(
        title: 'Attendance',
        value: '${_attendancePercent.toStringAsFixed(0)}%',
        icon: Icons.check_circle_outline,
        accent: const Color(0xFF10B981),
        onTap: () => context.go('/school/attendance'),
      ),
      _buildStatCard(
        title: 'Homework',
        value: '$_pendingHomework Due',
        icon: Icons.assignment_outlined,
        accent: _coral,
        onTap: () => context.go('/school/homework'),
      ),
      _buildStatCard(
        title: 'Fees Due',
        value: _pendingFees,
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFFF59E0B),
        onTap: () => context.go('/school/fees'),
      ),
      _buildStatCard(
        title: 'Tests',
        value: '$_upcomingTests Upcoming',
        icon: Icons.quiz_outlined,
        accent: _violet,
        onTap: () {},
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(child: stats[i]),
            if (i != stats.length - 1) const SizedBox(width: 14),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: stats[0]),
            const SizedBox(width: 12),
            Expanded(child: stats[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: stats[2]),
            const SizedBox(width: 12),
            Expanded(child: stats[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassPanel(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        blur: 16,
        shadowColor: accent,
        shadowOpacity: 0.16,
        gradientColors: [
          Colors.white.withValues(alpha: 0.86),
          accent.withValues(alpha: 0.16),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.22),
                        accent.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.55),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: accent.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      {'icon': Icons.calendar_today_outlined, 'label': 'Timetable', 'color': const Color(0xFF3B82F6), 'route': '/school/timetable'},
      {'icon': Icons.assignment_outlined, 'label': 'Homework', 'color': const Color(0xFFFB7185), 'route': '/school/homework'},
      {'icon': Icons.checklist_rtl, 'label': 'Attendance', 'color': const Color(0xFF10B981), 'route': '/school/attendance'},
      {'icon': Icons.payment_outlined, 'label': 'Fees', 'color': const Color(0xFFF59E0B), 'route': '/school/fees'},
      {'icon': Icons.campaign_outlined, 'label': 'Circulars', 'color': const Color(0xFF8B5CF6), 'route': '/school/circulars'},
      {'icon': Icons.directions_bus_outlined, 'label': 'Transport', 'color': const Color(0xFF06B6D4), 'route': '/school/transport'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Quick Actions',
          icon: Icons.grid_view_outlined,
          accent: _indigo,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720 ? 6 : 3;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 6 ? 0.95 : 0.92,
              padding: EdgeInsets.zero,
              children: actions.map((action) => _buildQuickActionCard(action)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    final color = action['color'] as Color;
    return GestureDetector(
      onTap: () => context.go(action['route'] as String),
      child: _GlassPanel(
        padding: const EdgeInsets.all(8),
        borderRadius: 22,
        blur: 14,
        shadowColor: color,
        shadowOpacity: 0.14,
        gradientColors: [
          Colors.white.withValues(alpha: 0.86),
          color.withValues(alpha: 0.18),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.66)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(action['icon'] as IconData, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: Text(
                action['label'] as String,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowerSections(bool isWide) {
    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildHomeworkSection(fill: true)),
            const SizedBox(width: 20),
            Expanded(child: _buildResultsSection(fill: true)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHomeworkSection(fill: false),
        const SizedBox(height: 22),
        _buildResultsSection(fill: false),
      ],
    );
  }

  Widget _buildHomeworkSection({required bool fill}) {
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 26,
      blur: 18,
      shadowColor: _indigo,
      shadowOpacity: 0.12,
      gradientColors: [
        Colors.white.withValues(alpha: 0.82),
        Colors.white.withValues(alpha: 0.52),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Pending Homework',
            icon: Icons.assignment_outlined,
            accent: _indigo,
            actionLabel: 'View All',
            onAction: () => context.go('/school/homework'),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _homework.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: _buildHomeworkRow(_homework[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeworkRow(Map<String, dynamic> hw) {
    final color = hw['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color, color.withValues(alpha: 0.35)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hw['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hw['subject'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Text(
              hw['due'] as String,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection({required bool fill}) {
    final tiles = Row(
      children: _recentResults.asMap().entries.map((entry) {
        final isLast = entry.key == _recentResults.length - 1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: _buildResultTile(entry.value),
          ),
        );
      }).toList(),
    );

    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 26,
      blur: 18,
      shadowColor: _violet,
      shadowOpacity: 0.12,
      gradientColors: [
        Colors.white.withValues(alpha: 0.82),
        Colors.white.withValues(alpha: 0.52),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Recent Test Results',
            icon: Icons.grade_outlined,
            accent: _violet,
          ),
          const SizedBox(height: 14),
          if (fill)
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: tiles,
              ),
            )
          else
            tiles,
        ],
      ),
    );
  }

  Widget _buildResultTile(Map<String, dynamic> result) {
    final color = result['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            color.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.14),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(Icons.grade, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            result['grade'] as String,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result['marks'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              color: _muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result['subject'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color accent,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                accent.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.90)),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: accent),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 304,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF8F6FF).withValues(alpha: 0.97),
                  const Color(0xFFF3EEFF).withValues(alpha: 0.94),
                  const Color(0xFFFFF0F8).withValues(alpha: 0.94),
                ],
              ),
            ),
            child: SafeArea(
              child: _buildSidebarContent(context, isDrawer: true),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: 276,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _violet.withValues(alpha: 0.16),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  Colors.white.withValues(alpha: 0.60),
                  const Color(0xFFEDE9FE).withValues(alpha: 0.70),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.90), width: 1.2),
            ),
            child: _buildSidebarContent(context, isDrawer: false),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, {required bool isDrawer}) {
    return Column(
      children: [
        SizedBox(height: isDrawer ? 20 : 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _buildBranding(),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Column(
              children: [
                _buildSidebarItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  active: true,
                  onTap: isDrawer ? () => Navigator.pop(context) : () {},
                ),
                _buildSidebarItem(
                  icon: Icons.assignment_outlined,
                  label: 'Homework',
                  onTap: () => context.go('/school/homework'),
                ),
                _buildSidebarItem(
                  icon: Icons.checklist_rtl,
                  label: 'Attendance',
                  onTap: () => context.go('/school/attendance'),
                ),
                _buildSidebarItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Timetable',
                  onTap: () => context.go('/school/timetable'),
                ),
                _buildSidebarItem(
                  icon: Icons.payment_outlined,
                  label: 'Fees',
                  onTap: () => context.go('/school/fees'),
                ),
                _buildSidebarItem(
                  icon: Icons.campaign_outlined,
                  label: 'Circulars',
                  onTap: () => context.go('/school/circulars'),
                ),
                _buildSidebarItem(
                  icon: Icons.directions_bus_outlined,
                  label: 'Transport',
                  onTap: () => context.go('/school/transport'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 6),
        _buildSidebarItem(
          icon: Icons.logout,
          label: 'Logout',
          destructive: true,
          onTap: () async {
            await _authService.logout();
            if (mounted) context.go('/login');
          },
        ),
        SizedBox(height: isDrawer ? 20 : 16),
      ],
    );
  }

  Widget _buildBranding() {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6D8DFF), Color(0xFFB18CFF)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _violet.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SCHOOL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: _violet,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _studentName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(
                _studentClass,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool destructive = false,
  }) {
    final accent = destructive ? const Color(0xFFF43F5E) : _indigo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: accent.withValues(alpha: 0.10),
          highlightColor: accent.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _indigo.withValues(alpha: 0.16),
                        _violet.withValues(alpha: 0.08),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? Colors.white.withValues(alpha: 0.90)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: destructive ? const Color(0xFFE11D48) : _ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass surface used by the School dashboards.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 22,
    this.blur = 18,
    this.gradientColors,
    this.shadowColor,
    this.shadowOpacity = 0.10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final List<Color>? gradientColors;
  final Color? shadowColor;
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
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
                      Colors.white.withValues(alpha: 0.80),
                      Colors.white.withValues(alpha: 0.48),
                    ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.80),
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
