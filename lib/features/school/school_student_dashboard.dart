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

  String _studentName = '';
  String _studentClass = '';
  String _admissionNo = '';
  String _schoolName = 'Shivalik International School';
  String _affiliationNo = 'CBSE Affiliation #3530124';
  String _academicSession = 'Session 2025-26';

  // Quick stats (Authentic live DB data only - zero fake constants)
  double? _attendancePercent;
  int _pendingHomework = 0;
  String _pendingFees = '₹0';
  int _upcomingTests = 0;
  String _upcomingExamBadge = '';
  String _recentExamName = 'Recent Exam Scores';
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRefreshing = false;

  // Real data collections
  List<Map<String, dynamic>> _homework = [];
  List<Map<String, dynamic>> _recentResults = [];
  List<Map<String, dynamic>> _todaySchedule = [];
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
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final username = await _authService.getCurrentUsername() ?? '';

    // 1. Dynamic institutional settings
    try {
      final settings = await _schoolService.getSchoolSettings();
      if (mounted) {
        setState(() {
          _schoolName = settings['school_name']?.toString() ?? 'Shivalik International School';
          _affiliationNo = settings['affiliation_no']?.toString() ?? 'CBSE Affiliation #3530124';
          _academicSession = settings['active_academic_year']?.toString() ??
              settings['academic_session']?.toString() ??
              'Session 2025-26';
        });
      }
    } catch (_) {}

    // 2. Identity from backend
    Map<String, dynamic>? profile;
    try {
      profile = await _schoolService.getSchoolStudentProfile(username);
    } catch (_) {}

    if (mounted) {
      final className = profile?['class_name']?.toString() ?? '';
      final section = profile?['section']?.toString() ?? '';
      String fullClass = className;
      if (className.isNotEmpty && section.isNotEmpty) {
        fullClass = '$className-$section';
      }

      setState(() {
        _studentName = profile?['name']?.toString() ?? username;
        _studentClass = fullClass.isNotEmpty ? fullClass : 'Class Not Assigned';
        _admissionNo = profile?['admission_no']?.toString() ?? '';
      });
    }

    try {
      final classId = profile?['class_id']?.toString() ?? '';
      final className = profile?['class_name']?.toString() ?? '';

      final hwFuture = _schoolService.getHomework(
        classId: classId.isNotEmpty ? classId : null,
        className: className.isNotEmpty ? className : null,
      );
      final mySubsFuture = _schoolService.getHomeworkSubmissions(studentUsername: username);
      final attPctFuture = _schoolService.getStudentAttendancePercent(username);
      final feesFuture = _schoolService.getStudentFees(username);
      final marksFuture = _schoolService.getStudentMarks(username);
      final circsFuture = _schoolService.getCirculars();
      final examCountdownFuture = _schoolService.getChildUpcomingExamCountdown(className: _studentClass);
      final timetableFuture = classId.isNotEmpty
          ? _schoolService.getParentChildTodayTimetable(classId)
          : Future.value(<String, dynamic>{});

      final results = await Future.wait([
        hwFuture.catchError((_) => <Map<String, dynamic>>[]),
        mySubsFuture.catchError((_) => <Map<String, dynamic>>[]),
        attPctFuture.then<double?>((v) => v).catchError((_) => null),
        feesFuture.catchError((_) => <Map<String, dynamic>>[]),
        marksFuture.catchError((_) => <Map<String, dynamic>>[]),
        circsFuture.catchError((_) => <Map<String, dynamic>>[]),
        examCountdownFuture.catchError((_) => <String, dynamic>{}),
        timetableFuture.catchError((_) => <String, dynamic>{}),
      ]);

      final hw = results[0] as List<Map<String, dynamic>>;
      final mySubmissions = results[1] as List<Map<String, dynamic>>;
      final attPct = results[2] as double?;
      final fees = results[3] as List<Map<String, dynamic>>;
      final marks = results[4] as List<Map<String, dynamic>>;
      final circs = results[5] as List<Map<String, dynamic>>;
      final examCountdown = results[6] as Map<String, dynamic>;
      final timetableData = results[7] as Map<String, dynamic>;

      // Homework processing
      final submittedIds = mySubmissions
          .map((s) => s['homework_id']?.toString() ?? '')
          .toSet();
      final notSubmitted =
          hw.where((h) => !submittedIds.contains(h['id']?.toString() ?? '')).toList();
      final selectedHw = notSubmitted.take(3).toList();

      // Fee processing
      double feesDue = 0.0;
      for (final f in fees) {
        final amount = (f['amount'] as num?)?.toDouble() ?? 0.0;
        final paid = (f['paid_amount'] as num?)?.toDouble() ?? 0.0;
        feesDue += (amount - (paid < amount ? paid : amount));
      }

      // Exam countdown processing
      int upcomingExamCount = 0;
      String examBadge = 'Curriculum On Track';
      if (examCountdown['has_upcoming'] == true) {
        upcomingExamCount = 1;
        examBadge = examCountdown['title']?.toString() ?? 'Assessment Active';
      } else {
        try {
          final sessions = await _schoolService.getExamSessions();
          upcomingExamCount = sessions.length;
          examBadge = sessions.isNotEmpty
              ? sessions.first
              : 'No Active Exams';
        } catch (_) {}
      }

      // Today's Timetable processing (real periods from school_timetable)
      final rawPeriods = timetableData['periods'];
      final todayPeriods = rawPeriods is List
          ? List<Map<String, dynamic>>.from(rawPeriods)
          : <Map<String, dynamic>>[];

      if (mounted) {
        setState(() {
          // Homework
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
            if (subj.toLowerCase().contains('math')) {
              col = const Color(0xFF2563EB);
            } else if (subj.toLowerCase().contains('sci')) {
              col = const Color(0xFF059669);
            } else if (subj.toLowerCase().contains('eng')) {
              col = const Color(0xFFE11D48);
            } else if (subj.toLowerCase().contains('soc') || subj.toLowerCase().contains('hist')) {
              col = const Color(0xFFD97706);
            }

            return {
              'id': h['id']?.toString() ?? '',
              'subject': subj,
              'title': h['title'] ?? 'Homework Assignment',
              'due': due,
              'color': col,
            };
          }).toList();

          // Marks processing with CBSE 9-point scale & Latest Exam grouping
          if (marks.isNotEmpty) {
            marks.sort((a, b) {
              final d1 = a['created_at']?.toString() ?? '';
              final d2 = b['created_at']?.toString() ?? '';
              return d2.compareTo(d1);
            });
            final latestExam = marks.first['exam_type']?.toString() ?? 'Term Examination';
            _recentExamName = latestExam;
            final latestMarks = marks
                .where((m) => (m['exam_type']?.toString() ?? '') == latestExam)
                .take(6)
                .toList();

            _recentResults = latestMarks.map((m) {
              final marksObt = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
              final maxM = (m['total_marks'] as num?)?.toDouble() ??
                  (m['max_marks'] as num?)?.toDouble() ??
                  100.0;
              final pct = maxM > 0 ? (marksObt / maxM) * 100 : 0.0;
              final cbse = SchoolService.calculateCbseGrade(pct);
              final grade = m['grade']?.toString() ?? cbse['grade'] ?? 'A1';

              Color col = const Color(0xFF059669);
              if (grade.startsWith('A')) {
                col = const Color(0xFF059669);
              } else if (grade.startsWith('B')) {
                col = const Color(0xFF2563EB);
              } else if (grade.startsWith('C')) {
                col = const Color(0xFFD97706);
              } else {
                col = const Color(0xFFE11D48);
              }

              return {
                'subject': m['subject']?.toString() ?? 'Subject',
                'marks': '${marksObt.toStringAsFixed(0)}/${maxM.toStringAsFixed(0)}',
                'grade': grade,
                'color': col,
                'percent': pct,
                'exam_type': latestExam,
              };
            }).toList();
          } else {
            _recentResults = [];
          }

          // Announcements
          _announcements = circs.take(3).toList();

          // Today's schedule
          _todaySchedule = todayPeriods;

          // KPIs
          _pendingHomework = notSubmitted.length;
          _attendancePercent = attPct;
          _pendingFees = feesDue > 0 ? '₹${NumberFormat('#,##,###').format(feesDue.round())}' : '₹0';
          _upcomingTests = upcomingExamCount;
          _upcomingExamBadge = examBadge;

          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load student dashboard data: $e';
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
              ? _buildLoadingSkeleton(isWide)
              : _errorMessage != null
                  ? _buildErrorState(context, isWide)
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
                                      const SizedBox(height: 22),
                                      _buildAnnouncementsSection(context),
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
                Text(
                  _schoolName,
                  style: const TextStyle(
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
                    Text(
                      '$_affiliationNo • $_academicSession',
                      style: const TextStyle(
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
                            _admissionNo.isNotEmpty
                                ? '$_studentClass • Admission No: $_admissionNo'
                                : _studentClass,
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
        value: _attendancePercent != null ? '${_attendancePercent!.toStringAsFixed(0)}%' : 'N/A',
        badgeText: _attendancePercent == null
            ? 'Not Recorded'
            : (_attendancePercent! >= 75 ? 'On Track (>=75%)' : 'Needs Attention (<75%)'),
        isPositive: (_attendancePercent ?? 0) >= 75,
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
        value: _upcomingTests > 0 ? '$_upcomingTests Scheduled' : 'No Exams Active',
        badgeText: _upcomingExamBadge.isNotEmpty ? _upcomingExamBadge : 'Curriculum Active',
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
          if (_todaySchedule.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_available_rounded, size: 28, color: _muted),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No lectures scheduled for today',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enjoy your break or explore study materials & assignments.',
                      style: TextStyle(fontSize: 11, color: _muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              primary: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todaySchedule.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF8FAFC), indent: 56),
              itemBuilder: (ctx, index) {
                final item = _todaySchedule[index];
                final period = item['period']?.toString() ?? '${index + 1}';
                final time = item['time']?.toString() ?? 'Period $period';
                final subject = item['subject']?.toString() ?? 'Class';
                final room = item['room']?.toString() ?? '';
                final teacher = item['teacher']?.toString() ?? '';
                final roomText = (room.isNotEmpty && room != 'Room 102' && room != 'Classroom')
                    ? ' • $room'
                    : '';
                final teacherText = teacher.isNotEmpty ? ' • $teacher' : '';

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
                    '$time$roomText$teacherText',
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
              primary: false,
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
                Expanded(
                  child: Text(
                    _recentExamName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
          if (_recentResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.grade_outlined, size: 28, color: _muted),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No examination marks recorded yet',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Examination scores will appear here once published by faculty.',
                      style: TextStyle(fontSize: 11, color: _muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              primary: false,
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
          if (_announcements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.campaign_outlined, size: 28, color: _muted),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No active school circulars',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'All institutional broadcasts and notices are caught up.',
                      style: TextStyle(fontSize: 11, color: _muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              primary: false,
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
                    Text(
                      _schoolName,
                      style: const TextStyle(
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

  // ==========================================
  // 8. 4-STATE LIFECYCLE: LOADING SKELETON & ERROR STATE
  // ==========================================
  Widget _buildLoadingSkeleton(bool isWide) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide) _buildDesktopSidebar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 24, isWide ? 28 : 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero skeleton
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // KPI skeleton
                  Row(
                    children: [
                      for (int i = 0; i < (isWide ? 4 : 2); i++) ...[
                        Expanded(
                          child: Container(
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _border),
                            ),
                          ),
                        ),
                        if (i != (isWide ? 3 : 1)) const SizedBox(width: 12),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  // Schedule skeleton
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
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

  Widget _buildErrorState(BuildContext context, bool isWide) {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide) _buildDesktopSidebar(context),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 440),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF1F2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_off_rounded, size: 32, color: Color(0xFFE11D48)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to load student data',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage ?? 'Network or service timeout encountered.',
                        style: const TextStyle(fontSize: 12.5, color: _muted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _loadStudentData(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
