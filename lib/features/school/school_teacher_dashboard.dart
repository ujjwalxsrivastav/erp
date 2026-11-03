import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/auth_service.dart';
import '../../services/school_service.dart';

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

  // Sage / mint / champagne / cream palette
  static const Color _sage = Color(0xFFA8C9B5);
  static const Color _mint = Color(0xFFD5EEE0);
  static const Color _gold = Color(0xFFF3D99B);
  static const Color _cream = Color(0xFFF8F5EC);
  static const Color _forest = Color(0xFF355B49);
  static const Color _ink = Color(0xFF23372D);
  static const Color _muted = Color(0xFF66786C);
  static const Color _sageDeep = Color(0xFF5C8570);
  static const Color _goldInk = Color(0xFF8A672A);
  static const Color _eucalyptus = Color(0xFF47796F);
  static const Color _clay = Color(0xFFA85F52);

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1080;
        final topInset = MediaQuery.paddingOf(context).top;

        return Scaffold(
          backgroundColor: _cream,
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
                                    _buildScheduleSection(isWide),
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
            Color(0xFFF8F5EC),
            Color(0xFFEFF6EF),
            Color(0xFFF7F1DE),
            Color(0xFFFDF9F0),
          ],
          stops: [0.0, 0.38, 0.72, 1.0],
        ),
      ),
      child: Stack(
        children: [
          _buildOrb(top: -120, left: -90, size: 360, color: _sage),
          _buildOrb(top: 150, right: -130, size: 390, color: _gold),
          _buildOrb(bottom: -150, left: 70, size: 380, color: _mint),
          _buildOrb(bottom: 40, right: -100, size: 310, color: _sage),
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
              color: color.withValues(alpha: 0.38),
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
          color: Colors.white.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: InkWell(
            onTap: onTap,
            child: const Icon(Icons.menu_rounded, color: _forest, size: 24),
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
            Color(0xFF355B49),
            Color(0xFF5F8E76),
            Color(0xFFA8C9B5),
            Color(0xFFF3D99B),
          ],
          stops: [0.0, 0.42, 0.74, 1.0],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _forest.withValues(alpha: 0.28),
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
              right: 20,
              top: 46,
              child: Icon(
                Icons.menu_book_rounded,
                size: 116,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              right: 128,
              bottom: 28,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.4,
                  ),
                ),
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
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _teacherName,
                                maxLines: 1,
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
                                _teacherClass,
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
        title: 'Students',
        value: '$_totalStudents',
        icon: Icons.people_outline,
        accent: _forest,
      ),
      _buildStatCard(
        title: 'Present Today',
        value: '$_presentToday',
        icon: Icons.how_to_reg_outlined,
        accent: _sageDeep,
        onTap: () => context.go('/school/attendance'),
      ),
      _buildStatCard(
        title: 'Homework',
        value: '$_pendingAssignments Pending',
        icon: Icons.assignment_outlined,
        accent: _goldInk,
        onTap: () => context.go('/school/homework'),
      ),
      _buildStatCard(
        title: 'Classes Today',
        value: '$_upcomingClasses',
        icon: Icons.class_outlined,
        accent: _eucalyptus,
        onTap: () => context.go('/school/timetable'),
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
    VoidCallback? onTap,
  }) {
    final card = _GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      blur: 16,
      shadowColor: accent,
      shadowOpacity: 0.16,
      gradientColors: [
        Colors.white.withValues(alpha: 0.86),
        accent.withValues(alpha: 0.12),
      ],
      borderColor: Colors.white.withValues(alpha: 0.85),
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
              if (onTap != null)
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
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  Widget _buildQuickActionsSection() {
    final actions = [
      {
        'label': 'Mark Attendance',
        'icon': Icons.how_to_reg,
        'accent': const Color(0xFF355B49),
        'route': '/school/attendance',
      },
      {
        'label': 'Upload Homework',
        'icon': Icons.upload_file,
        'accent': const Color(0xFF5F8A6E),
        'route': '/school/homework/upload',
      },
      {
        'label': 'Enter Marks',
        'icon': Icons.edit_note,
        'accent': const Color(0xFFB58C3E),
        'route': '/school/marks-entry',
      },
      {
        'label': 'Report Card',
        'icon': Icons.description_outlined,
        'accent': const Color(0xFF4C8079),
        'route': '/school/report-card',
      },
      {
        'label': 'Circular',
        'icon': Icons.campaign_outlined,
        'accent': const Color(0xFFA07A3C),
        'route': '/school/circulars',
      },
      {
        'label': 'Timetable',
        'icon': Icons.calendar_month,
        'accent': const Color(0xFF7C8F62),
        'route': '/school/timetable',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Quick Actions',
          icon: Icons.bolt_outlined,
          accent: _sageDeep,
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
    final accent = action['accent'] as Color;
    return GestureDetector(
      onTap: () => context.go(action['route'] as String),
      child: _GlassPanel(
        padding: const EdgeInsets.all(8),
        borderRadius: 22,
        blur: 14,
        shadowColor: accent,
        shadowOpacity: 0.14,
        gradientColors: [
          Colors.white.withValues(alpha: 0.86),
          accent.withValues(alpha: 0.16),
        ],
        borderColor: Colors.white.withValues(alpha: 0.85),
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
                  colors: [accent, accent.withValues(alpha: 0.66)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
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
                  color: Color(0xFF2C4438),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection(bool isWide) {
    return _GlassPanel(
      padding: const EdgeInsets.all(20),
      borderRadius: 26,
      blur: 18,
      shadowColor: _forest,
      shadowOpacity: 0.12,
      gradientColors: [
        Colors.white.withValues(alpha: 0.82),
        _mint.withValues(alpha: 0.42),
      ],
      borderColor: Colors.white.withValues(alpha: 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: "Today's Schedule",
            icon: Icons.calendar_today_outlined,
            accent: _sageDeep,
            actionLabel: 'Full Timetable',
            onAction: () => context.go('/school/timetable'),
          ),
          const SizedBox(height: 14),
          if (isWide)
            _buildScheduleGrid()
          else
            for (var i = 0; i < _todaySchedule.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: _buildScheduleTile(_todaySchedule[i]),
              ),
        ],
      ),
    );
  }

  Widget _buildScheduleGrid() {
    final count = _todaySchedule.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = count <= 3
            ? count
            : (constraints.maxWidth >= 860 ? 4 : 2);
        if (columns <= 1) {
          return _buildScheduleTile(_todaySchedule.first);
        }

        final rows = <Widget>[];
        for (var start = 0; start < count; start += columns) {
          if (start > 0) rows.add(const SizedBox(height: 14));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    Expanded(
                      child: start + i < count
                          ? _buildScheduleTile(_todaySchedule[start + i])
                          : const SizedBox.shrink(),
                    ),
                    if (i != columns - 1) const SizedBox(width: 14),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildScheduleTile(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.62),
            _mint.withValues(alpha: 0.34),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _sage.withValues(alpha: 0.55),
                      _mint.withValues(alpha: 0.45),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                ),
                child: const Icon(Icons.class_outlined, color: _forest, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _goldInk.withValues(alpha: 0.18)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        s['time'] as String,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _goldInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s['subject'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${s['class']} • ${s['room']}',
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
                accent.withValues(alpha: 0.20),
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
                  const Color(0xFFFBF8EF).withValues(alpha: 0.97),
                  const Color(0xFFF1F7F0).withValues(alpha: 0.95),
                  const Color(0xFFFBF3E1).withValues(alpha: 0.94),
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
            color: _forest.withValues(alpha: 0.16),
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
                  Colors.white.withValues(alpha: 0.90),
                  Colors.white.withValues(alpha: 0.65),
                  const Color(0xFFEAF3EC).withValues(alpha: 0.72),
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
                  icon: Icons.how_to_reg,
                  label: 'Attendance',
                  onTap: () => context.go('/school/attendance'),
                ),
                _buildSidebarItem(
                  icon: Icons.assignment_outlined,
                  label: 'Homework',
                  onTap: () => context.go('/school/homework'),
                ),
                _buildSidebarItem(
                  icon: Icons.edit_note,
                  label: 'Enter Marks',
                  onTap: () => context.go('/school/marks-entry'),
                ),
                _buildSidebarItem(
                  icon: Icons.description_outlined,
                  label: 'Report Card',
                  onTap: () => context.go('/school/report-card'),
                ),
                _buildSidebarItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Timetable',
                  onTap: () => context.go('/school/timetable'),
                ),
                _buildSidebarItem(
                  icon: Icons.campaign_outlined,
                  label: 'Circulars',
                  onTap: () => context.go('/school/circulars'),
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
              colors: [Color(0xFF355B49), Color(0xFF7BA78C)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _forest.withValues(alpha: 0.28),
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
                  color: _goldInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _teacherName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const Text(
                'School Teacher',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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
    final accent = destructive ? _clay : _forest;
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
                        _sage.withValues(alpha: 0.38),
                        _mint.withValues(alpha: 0.16),
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
                      color: destructive ? const Color(0xFF8E4A3E) : _ink,
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
    this.borderColor,
    this.shadowColor,
    this.shadowOpacity = 0.10,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
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
                color: borderColor ?? Colors.white.withValues(alpha: 0.80),
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
