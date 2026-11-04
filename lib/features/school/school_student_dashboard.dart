import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/school_service.dart';

class SchoolStudentDashboard extends StatefulWidget {
  const SchoolStudentDashboard({super.key});

  @override
  State<SchoolStudentDashboard> createState() => _SchoolStudentDashboardState();
}

class _SchoolStudentDashboardState extends State<SchoolStudentDashboard>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();
  late AnimationController _fadeController;

  String _studentName = 'Student';
  String _studentClass = 'Class 10-A';
  String _admissionNo = 'SHIV-2024-89';
  static const String _schoolName = 'Shivalik International School';
  static const String _affiliationNo = 'CBSE #3530124';

  // Quick stats
  double _attendancePercent = 94.2;
  int _pendingHomework = 3;
  String _pendingFees = '₹0';
  int _upcomingTests = 2;
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Recent homework
  List<Map<String, dynamic>> _homework = [
    {
      'subject': 'Mathematics',
      'title': 'Chapter 5 Exercise 5.3',
      'due': 'Tomorrow',
      'color': const Color(0xFF2563EB),
    },
    {
      'subject': 'Science',
      'title': 'Draw diagram of human heart & label',
      'due': 'In 3 days',
      'color': const Color(0xFF059669),
    },
    {
      'subject': 'English',
      'title': 'Essay on environmental conservation',
      'due': 'In 5 days',
      'color': const Color(0xFFE11D48),
    },
  ];

  // Recent test results
  final List<Map<String, dynamic>> _recentResults = [
    {'subject': 'Mathematics', 'marks': '45/50', 'grade': 'A1', 'color': const Color(0xFF059669), 'percent': 90.0},
    {'subject': 'Science', 'marks': '38/50', 'grade': 'B1', 'color': const Color(0xFF2563EB), 'percent': 76.0},
    {'subject': 'English', 'marks': '42/50', 'grade': 'A2', 'color': const Color(0xFF7C3AED), 'percent': 84.0},
  ];

  // Today's schedule
  List<Map<String, dynamic>> _todaySchedule = [
    {'period': '1', 'time': '08:30 - 09:15', 'subject': 'Mathematics', 'room': 'Room 102', 'teacher': 'Mr. R. Sharma'},
    {'period': '2', 'time': '09:15 - 10:00', 'subject': 'English Literature', 'room': 'Room 102', 'teacher': 'Ms. A. Sen'},
    {'period': '3', 'time': '10:15 - 11:00', 'subject': 'Physics Lab', 'room': 'Sci Lab 1', 'teacher': 'Dr. K. Verma'},
    {'period': '4', 'time': '11:00 - 11:45', 'subject': 'Social Science', 'room': 'Room 102', 'teacher': 'Mrs. P. Joshi'},
  ];

  // Announcements
  List<Map<String, dynamic>> _announcements = [];

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();
    _loadStudentData();
  }

  Future<void> _loadStudentData({bool showRefreshing = false}) async {
    if (showRefreshing) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    final username = await _authService.getCurrentUsername() ?? '';

    // Identity from backend
    Map<String, dynamic>? profile;
    try {
      profile = await _schoolService.getSchoolStudentProfile(username);
    } catch (_) {}

    if (mounted && profile != null) {
      final className = profile['class_name']?.toString();
      final section = profile['section']?.toString();
      setState(() {
        _studentName = profile?['name']?.toString() ?? username;
        _studentClass = className ?? _studentClass;
        if (className != null && section != null && section.isNotEmpty) {
          _studentClass = '$_studentClass-$section';
        }
        _admissionNo = profile?['admission_no']?.toString() ?? _admissionNo;
      });
    }

    try {
      final hwFuture = _schoolService.getHomework(
        classId: profile?['class_id']?.toString(),
        className: profile?['class_name']?.toString(),
      );
      final mySubsFuture = _schoolService.getHomeworkSubmissions(studentUsername: username);
      final attPctFuture = _schoolService.getStudentAttendancePercent(username);
      final feesFuture = _schoolService.getStudentFees(username);
      final marksFuture = _schoolService.getStudentMarks(username);
      final circsFuture = _schoolService.getCirculars();

      final results = await Future.wait([
        hwFuture.catchError((_) => <Map<String, dynamic>>[]),
        mySubsFuture.catchError((_) => <Map<String, dynamic>>[]),
        attPctFuture.catchError((_) => 94.2),
        feesFuture.catchError((_) => <Map<String, dynamic>>[]),
        marksFuture.catchError((_) => <Map<String, dynamic>>[]),
        circsFuture.catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final hw = results[0] as List<Map<String, dynamic>>;
      final mySubmissions = results[1] as List<Map<String, dynamic>>;
      final attPct = results[2] as double;
      final fees = results[3] as List<Map<String, dynamic>>;
      final marks = results[4] as List<Map<String, dynamic>>;
      final circs = results[5] as List<Map<String, dynamic>>;

      final submittedIds = mySubmissions
          .map((s) => s['homework_id']?.toString() ?? '')
          .toSet();
      final notSubmitted =
          hw.where((h) => !submittedIds.contains(h['id']?.toString() ?? '')).toList();
      final selectedHw = notSubmitted.take(3).toList();

      double feesDue = 0.0;
      for (final f in fees) {
        final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
        feesDue += (amount - (paid < amount ? paid : amount));
      }

      if (mounted) {
        setState(() {
          if (selectedHw.isNotEmpty) {
            _homework = selectedHw.map((h) {
              final dueStr = h['due_date']?.toString() ?? '';
              String due = 'Upcoming';
              try {
                final dueDate = DateTime.parse(dueStr);
                final diff = dueDate.difference(DateTime.now()).inDays;
                if (diff < 0) {
                  due = '${-diff}d overdue';
                } else if (diff == 0) {
                  due = 'Due today';
                } else if (diff == 1) {
                  due = 'Tomorrow';
                } else {
                  due = 'In $diff days';
                }
              } catch (_) {
                due = dueStr.isNotEmpty ? dueStr : 'Upcoming';
              }
              final subj = h['subject']?.toString() ?? 'General';
              Color col = const Color(0xFF2563EB);
              if (subj.toLowerCase().contains('math')) col = const Color(0xFF2563EB);
              else if (subj.toLowerCase().contains('sci')) col = const Color(0xFF059669);
              else if (subj.toLowerCase().contains('eng')) col = const Color(0xFFE11D48);
              else if (subj.toLowerCase().contains('soc') || subj.toLowerCase().contains('hist')) col = const Color(0xFFD97706);

              return {
                'subject': subj,
                'title': h['title'] ?? 'Homework Assignment',
                'due': due,
                'color': col,
              };
            }).toList();
          }

          if (marks.isNotEmpty) {
            final mappedMarks = marks.take(4).map((m) {
              final marksObt = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
              final maxM = (m['max_marks'] as num?)?.toDouble() ?? 100.0;
              final pct = maxM > 0 ? (marksObt / maxM) * 100 : 0.0;
              String grade = 'A1';
              Color col = const Color(0xFF059669);
              if (pct >= 90) {
                grade = 'A1';
                col = const Color(0xFF059669);
              } else if (pct >= 80) {
                grade = 'A2';
                col = const Color(0xFF2563EB);
              } else if (pct >= 70) {
                grade = 'B1';
                col = const Color(0xFF7C3AED);
              } else {
                grade = 'B2';
                col = const Color(0xFFD97706);
              }
              return {
                'subject': m['subject']?.toString() ?? 'Subject',
                'marks': '${marksObt.toStringAsFixed(0)}/${maxM.toStringAsFixed(0)}',
                'grade': m['grade']?.toString() ?? grade,
                'color': col,
                'percent': pct,
              };
            }).toList();
            if (mappedMarks.isNotEmpty) {
              _recentResults.clear();
              _recentResults.addAll(mappedMarks);
            }
          }

          if (circs.isNotEmpty) {
            _announcements = circs.take(3).toList();
          }

          _pendingHomework = notSubmitted.length;
          _attendancePercent = attPct > 0 ? attPct : 94.2;
          _pendingFees = feesDue > 0 ? '₹${NumberFormat('#,##,###').format(feesDue.round())}' : '₹0';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
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

        return Scaffold(
          backgroundColor: _bg,
          drawer: isWide ? null : _buildSidebar(context),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : SafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isWide) _buildDesktopSidebar(context),
                      Expanded(
                        child: FadeTransition(
                          opacity: _fadeController,
                          child: RefreshIndicator(
                            onRefresh: () => _loadStudentData(showRefreshing: true),
                            color: _primary,
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                _buildTopAppBar(context, isWide),
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    isWide ? 28 : 16,
                                    12,
                                    isWide ? 28 : 16,
                                    48,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      _buildStudentHeroCard(isWide),
                                      const SizedBox(height: 18),
                                      _buildStatsSection(isWide),
                                      const SizedBox(height: 22),
                                      _buildTodayScheduleSection(context),
                                      const SizedBox(height: 22),
                                      _buildQuickActionsSection(context),
                                      const SizedBox(height: 22),
                                      _buildLowerSections(isWide),
                                      if (_announcements.isNotEmpty) ...[
                                        const SizedBox(height: 22),
                                        _buildAnnouncementsSection(context),
                                      ],
                                    ]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  // ==========================================
  // 1. MINIMALIST TOP APP BAR
  // ==========================================
  Widget _buildTopAppBar(BuildContext context, bool isWide) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      automaticallyImplyLeading: false,
      titleSpacing: isWide ? 28 : 16,
      title: Row(
        children: [
          if (!isWide) ...[
            Builder(
              builder: (ctx) => InkWell(
                onTap: () => Scaffold.of(ctx).openDrawer(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.menu_rounded, color: _ink, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.school_rounded, color: _primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  _schoolName,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '$_affiliationNo • Active Session 2025-26',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
                )
              : const Icon(Icons.refresh_rounded, size: 20, color: _muted),
          tooltip: 'Refresh Dashboard',
          onPressed: _isRefreshing ? null : () => _loadStudentData(showRefreshing: true),
        ),
        IconButton(
          icon: const Icon(Icons.campaign_outlined, size: 22, color: _muted),
          tooltip: 'School Circulars',
          onPressed: () => context.go('/school/circulars'),
        ),
        Padding(
          padding: EdgeInsets.only(right: isWide ? 28 : 16, left: 4),
          child: InkWell(
            onTap: () => context.go('/school/report-card'),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: _primary,
                    child: Text(
                      _studentName.isNotEmpty ? _studentName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _studentClass,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. SEXY MINIMALIST STUDENT HERO CARD
  // ==========================================
  Widget _buildStudentHeroCard(bool isWide) {
    final now = DateTime.now();
    final dateString = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle elegant accent line on top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFF10B981)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Squircle Avatar
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _studentName.isNotEmpty ? _studentName[0].toUpperCase() : 'S',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Hello, $_studentName 👋',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Text(
                                  'STUDENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF475569),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$_studentClass • Admission No: $_admissionNo',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: _primary),
                    const SizedBox(width: 6),
                    Text(
                      dateString,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            '$_pendingHomework Assignments Due',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF065F46),
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
        ],
      ),
    );
  }

  // ==========================================
  // 3. MINIMALIST 4 MASTER KPI STATS
  // ==========================================
  Widget _buildStatsSection(bool isWide) {
    final stats = [
      _buildStatCard(
        title: 'Attendance',
        value: '${_attendancePercent.toStringAsFixed(0)}%',
        badgeText: _attendancePercent >= 75 ? 'On Track (>=75%)' : 'Needs Attention',
        isPositive: _attendancePercent >= 75,
        icon: Icons.how_to_reg_rounded,
        accent: const Color(0xFF059669),
        bgAccent: const Color(0xFFECFDF5),
        onTap: () => context.go('/school/attendance'),
      ),
      _buildStatCard(
        title: 'Pending Homework',
        value: '$_pendingHomework Due',
        badgeText: _pendingHomework == 0 ? 'All Done 🎉' : 'Active Tasks',
        isPositive: _pendingHomework == 0,
        icon: Icons.assignment_rounded,
        accent: const Color(0xFFE11D48),
        bgAccent: const Color(0xFFFFF1F2),
        onTap: () => context.go('/school/homework'),
      ),
      _buildStatCard(
        title: 'School Fees Due',
        value: _pendingFees,
        badgeText: _pendingFees == '₹0' ? 'Fully Settled' : 'Pay Online',
        isPositive: _pendingFees == '₹0',
        icon: Icons.account_balance_wallet_rounded,
        accent: const Color(0xFFD97706),
        bgAccent: const Color(0xFFFFFBEB),
        onTap: () => context.go('/school/fees'),
      ),
      _buildStatCard(
        title: 'Upcoming Tests',
        value: '$_upcomingTests Scheduled',
        badgeText: 'CBSE Term II',
        isPositive: true,
        icon: Icons.quiz_rounded,
        accent: const Color(0xFF4F46E5),
        bgAccent: const Color(0xFFEEF2FF),
        onTap: () => context.go('/school/report-card'),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: stats.map((s) => SizedBox(width: cardWidth, child: s)).toList(),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String badgeText,
    required bool isPositive,
    required IconData icon,
    required Color accent,
    required Color bgAccent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: -0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isPositive ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? const Color(0xFF065F46) : const Color(0xFF9F1239),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. TODAY'S CLASS SCHEDULE SECTION
  // ==========================================
  Widget _buildTodayScheduleSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 17, color: _primary),
                const SizedBox(width: 8),
                const Text(
                  "Today's Class Schedule",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/school/timetable'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _primary,
                  ),
                  child: const Text(
                    'Full Timetable →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todaySchedule.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC), indent: 56),
            itemBuilder: (ctx, index) {
              final item = _todaySchedule[index];
              final period = item['period']?.toString() ?? '${index + 1}';
              final time = item['time']?.toString() ?? 'Period $period';
              final subject = item['subject']?.toString() ?? 'Class';
              final room = item['room']?.toString() ?? 'Room 102';
              final teacher = item['teacher']?.toString() ?? '';

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      'P$period',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                subtitle: Text(
                  '$time • $room ${teacher.isNotEmpty ? "• $teacher" : ""}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Scheduled',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. CURATED QUICK ACTIONS HUB (8 MODULES)
  // ==========================================
  Widget _buildQuickActionsSection(BuildContext context) {
    final actions = [
      {'icon': Icons.calendar_month_rounded, 'label': 'Timetable', 'color': const Color(0xFF2563EB), 'route': '/school/timetable'},
      {'icon': Icons.assignment_rounded, 'label': 'Homework', 'color': const Color(0xFFE11D48), 'route': '/school/homework'},
      {'icon': Icons.fact_check_rounded, 'label': 'Attendance', 'color': const Color(0xFF059669), 'route': '/school/attendance'},
      {'icon': Icons.description_rounded, 'label': 'Report Card', 'color': const Color(0xFF7C3AED), 'route': '/school/report-card'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Fees & Dues', 'color': const Color(0xFFD97706), 'route': '/school/fees'},
      {'icon': Icons.event_busy_rounded, 'label': 'Apply Leave', 'color': const Color(0xFF0284C7), 'route': '/school/leave'},
      {'icon': Icons.campaign_rounded, 'label': 'Circulars', 'color': const Color(0xFF8B5CF6), 'route': '/school/circulars'},
      {'icon': Icons.local_library_rounded, 'label': 'Library', 'color': const Color(0xFF10B981), 'route': '/school/library'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 17, color: _ink),
            SizedBox(width: 8),
            Text(
              'Quick Services & Tools',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 900 ? 8 : (constraints.maxWidth >= 600 ? 4 : 4);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.96,
              ),
              itemBuilder: (ctx, index) {
                final a = actions[index];
                final color = a['color'] as Color;
                return InkWell(
                  onTap: () => context.go(a['route'] as String),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(a['icon'] as IconData, color: color, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a['label'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // 6. LOWER SPLIT SECTIONS (HOMEWORK + RESULTS)
  // ==========================================
  Widget _buildLowerSections(bool isWide) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildHomeworkCard(context)),
          const SizedBox(width: 18),
          Expanded(child: _buildResultsCard(context)),
        ],
      );
    }

    return Column(
      children: [
        _buildHomeworkCard(context),
        const SizedBox(height: 18),
        _buildResultsCard(context),
      ],
    );
  }

  Widget _buildHomeworkCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.assignment_rounded, size: 17, color: Color(0xFFE11D48)),
                const SizedBox(width: 8),
                const Text(
                  'Pending Homework',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/school/homework'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _primary,
                  ),
                  child: const Text(
                    'View All →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (_homework.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  '🎉 All caught up! No pending homework.',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _homework.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
              itemBuilder: (ctx, idx) {
                final hw = _homework[idx];
                final color = hw['color'] as Color;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.menu_book_rounded, color: color, size: 16),
                  ),
                  title: Text(
                    hw['title']?.toString() ?? 'Homework',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    hw['subject']?.toString() ?? 'Subject',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hw['due']?.toString() ?? 'Upcoming',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  onTap: () => context.go('/school/homework'),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.grade_rounded, size: 17, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Text(
                  'Recent Exam Scores',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/school/report-card'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _primary,
                  ),
                  child: const Text(
                    'Report Card →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentResults.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
            itemBuilder: (ctx, idx) {
              final r = _recentResults[idx];
              final color = r['color'] as Color;
              final grade = r['grade']?.toString() ?? 'A';
              final marks = r['marks']?.toString() ?? '';
              final subject = r['subject']?.toString() ?? 'Subject';

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      grade,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                subtitle: Text('Score: $marks', style: const TextStyle(fontSize: 11, color: _muted)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                onTap: () => context.go('/school/report-card'),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. ANNOUNCEMENTS & CIRCULARS FEED
  // ==========================================
  Widget _buildAnnouncementsSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, size: 17, color: _primary),
                const SizedBox(width: 8),
                const Text(
                  'Latest School Circulars',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/school/circulars'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _primary,
                  ),
                  child: const Text(
                    'All Circulars →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _announcements.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC)),
            itemBuilder: (ctx, idx) {
              final a = _announcements[idx];
              final title = a['title']?.toString() ?? 'Notice';
              final category = a['category']?.toString() ?? 'General';
              final date = a['published_at']?.toString() ??
                  a['created_at']?.toString().substring(0, 10) ??
                  'Recent';

              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.feed_outlined, size: 16, color: Color(0xFF475569)),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('$category • $date', style: const TextStyle(fontSize: 11, color: _muted)),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                onTap: () => context.go('/school/circulars'),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 8. MINIMALIST LIGHT-THEME DRAWER
  // ==========================================
  Widget _buildSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      width: 290,
      child: SafeArea(
        child: _buildSidebarContent(context, isDrawer: true),
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: _buildSidebarContent(context, isDrawer: false),
    );
  }

  Widget _buildSidebarContent(BuildContext context, {required bool isDrawer}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: _primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      _schoolName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$_studentName • $_studentClass',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            children: [
              _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', () {
                if (isDrawer) Navigator.pop(context);
              }, isActive: true),
              _buildDrawerCategory('ACADEMIC SERVICES'),
              _buildDrawerItem(Icons.calendar_month_rounded, 'Timetable', () => context.go('/school/timetable')),
              _buildDrawerItem(Icons.assignment_rounded, 'Homework', () => context.go('/school/homework')),
              _buildDrawerItem(Icons.fact_check_rounded, 'Attendance', () => context.go('/school/attendance')),
              _buildDrawerItem(Icons.description_rounded, 'Report Card', () => context.go('/school/report-card')),
              _buildDrawerItem(Icons.fact_check_rounded, 'Date Sheet & Hall Ticket', () => context.go('/school/examination')),
              _buildDrawerItem(Icons.event_busy_rounded, 'Leave Requests', () => context.go('/school/leave')),
              _buildDrawerCategory('CAMPUS & FINANCES'),
              _buildDrawerItem(Icons.receipt_long_rounded, 'Fee Dues & Receipts', () => context.go('/school/fees')),
              _buildDrawerItem(Icons.campaign_rounded, 'Circulars & Notices', () => context.go('/school/circulars')),
              _buildDrawerItem(Icons.directions_bus_rounded, 'Bus & Transport', () => context.go('/school/transport')),
              _buildDrawerItem(Icons.local_library_rounded, 'Library Books', () => context.go('/school/library')),
              _buildDrawerItem(Icons.card_membership_rounded, 'Certificates', () => context.go('/school/certificates')),
            ],
          ),
        ),
        const Divider(height: 1, color: _border),
        ListTile(
          dense: true,
          leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 19),
          title: const Text(
            'Sign Out',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
          ),
          onTap: () async {
            await _authService.logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
    );
  }

  Widget _buildDrawerCategory(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return ListTile(
      leading: Icon(
        icon,
        size: 18,
        color: isActive ? _primary : const Color(0xFF64748B),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? _primary : const Color(0xFF334155),
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: isActive,
      selectedTileColor: const Color(0xFFEEF2FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      onTap: onTap,
    );
  }
}
