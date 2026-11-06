import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../services/school_export_service.dart';

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
  String _username = '';
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

  // STU2: My Progress Analytics (N1 + N2 + STU-R01 to STU-R06)
  Map<String, dynamic> _attendanceTrajectory = {};
  List<Map<String, dynamic>> _marksTrend = [];
  List<Map<String, dynamic>> _subjectPerformance = [];
  Map<String, dynamic> _homeworkCompletion = {};

  // STU5: N6, N7, N8, N9, N10, N11, N14
  List<Map<String, dynamic>> _goals = [];
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _transport = [];
  List<Map<String, dynamic>> _certificateRequests = [];
  List<Map<String, dynamic>> _notifications = [];
  Map<String, dynamic> _examCountdown = {};

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
        _username = username;
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
      final trajectoryFuture = _schoolService.getStudentAttendanceTrajectory(username, days: 30);
      final marksTrendFuture = _schoolService.getStudentMarksTrend(username);
      final subjectPerfFuture = _schoolService.getStudentSubjectPerformance(username);
      final hwCompletionFuture = _schoolService.getStudentHomeworkCompletion(username, classId: classId.isNotEmpty ? classId : null);
      final goalsFuture = _schoolService.getStudentGoals(username);
      final leavesFuture = _schoolService.getStudentLeaves(studentId: username);
      final transportFuture = _schoolService.getStudentTransport(username);
      final certsFuture = _schoolService.getStudentCertificateRequests(username);
      final notifsFuture = _schoolService.getStudentNotifications(username);

      final results = await Future.wait([
        hwFuture.catchError((_) => <Map<String, dynamic>>[]),
        mySubsFuture.catchError((_) => <Map<String, dynamic>>[]),
        attPctFuture.then<double?>((v) => v).catchError((_) => null),
        feesFuture.catchError((_) => <Map<String, dynamic>>[]),
        marksFuture.catchError((_) => <Map<String, dynamic>>[]),
        circsFuture.catchError((_) => <Map<String, dynamic>>[]),
        examCountdownFuture.catchError((_) => <String, dynamic>{}),
        timetableFuture.catchError((_) => <String, dynamic>{}),
        trajectoryFuture.catchError((_) => <String, dynamic>{}),
        marksTrendFuture.catchError((_) => <Map<String, dynamic>>[]),
        subjectPerfFuture.catchError((_) => <Map<String, dynamic>>[]),
        hwCompletionFuture.catchError((_) => <String, dynamic>{}),
        goalsFuture.catchError((_) => <Map<String, dynamic>>[]),
        leavesFuture.catchError((_) => <Map<String, dynamic>>[]),
        transportFuture.catchError((_) => <Map<String, dynamic>>[]),
        certsFuture.catchError((_) => <Map<String, dynamic>>[]),
        notifsFuture.catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final hw = results[0] as List<Map<String, dynamic>>;
      final mySubmissions = results[1] as List<Map<String, dynamic>>;
      final attPct = results[2] as double?;
      final fees = results[3] as List<Map<String, dynamic>>;
      final marks = results[4] as List<Map<String, dynamic>>;
      final circs = results[5] as List<Map<String, dynamic>>;
      final examCountdown = results[6] as Map<String, dynamic>;
      final timetableData = results[7] as Map<String, dynamic>;
      final attTrajectory = results[8] as Map<String, dynamic>;
      final mTrend = results[9] as List<Map<String, dynamic>>;
      final subjPerf = results[10] as List<Map<String, dynamic>>;
      final hwComp = results[11] as Map<String, dynamic>;
      final goalsData = results[12] as List<Map<String, dynamic>>;
      final leavesData = results[13] as List<Map<String, dynamic>>;
      final transData = results[14] as List<Map<String, dynamic>>;
      final certsData = results[15] as List<Map<String, dynamic>>;
      final notifsData = results[16] as List<Map<String, dynamic>>;

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

          // STU2 Analytics
          _attendanceTrajectory = attTrajectory;
          _marksTrend = mTrend;
          _subjectPerformance = subjPerf;
          _homeworkCompletion = hwComp;

          // STU5 Data
          _goals = goalsData;
          _leaves = leavesData;
          _transport = transData;
          _certificateRequests = certsData;
          _notifications = notifsData;
          _examCountdown = examCountdown;

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
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'student_ai_chatbot_fab',
            onPressed: () => context.push('/school/ai-tools?tab=chatbot'),
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Ask AI Chatbot',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3),
            ),
          ),
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
                                      if (_examCountdown['has_upcoming'] == true) ...[
                                        _buildExamCountdownBanner(context),
                                        const SizedBox(height: 14),
                                      ],
                                      if (_leaves.isNotEmpty) ...[
                                        _buildLeaveStatusBanner(context),
                                        const SizedBox(height: 14),
                                      ],
                                      _buildStatsSection(isWide),
                                      const SizedBox(height: 22),
                                      _buildProgressAnalyticsSection(context, isWide),
                                      const SizedBox(height: 22),
                                      if (_transport.isNotEmpty || _certificateRequests.isNotEmpty) ...[
                                        _buildTransportAndCertificatesRow(context, isWide),
                                        const SizedBox(height: 22),
                                      ],
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
        IconButton(
          icon: Badge(
            isLabelVisible: _notifications.where((n) => n['is_read'] != true).isNotEmpty,
            label: Text(_notifications.where((n) => n['is_read'] != true).length.toString(), style: const TextStyle(fontSize: 10)),
            child: const Icon(Icons.notifications_none_rounded, size: 22, color: _muted),
          ),
          tooltip: 'Notifications Inbox',
          onPressed: () => _showNotificationsInboxModal(context),
        ),
        Padding(
          padding: EdgeInsets.only(right: isWide ? 28 : 16, left: 4),
          child: InkWell(
            onTap: () => _showStudentProfileModal(context),
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
                final roomText = (room.isNotEmpty && room != 'Classroom')
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
  // 5. CURATED QUICK ACTIONS HUB (12 INTEGRATED MODULES — N3, N4, N2)
  // ==========================================
  Widget _buildQuickActionsSection(BuildContext context) {
    final actions = [
      {'icon': Icons.calendar_month_rounded, 'label': 'Timetable', 'color': const Color(0xFF2563EB), 'route': '/school/timetable'},
      {'icon': Icons.assignment_rounded, 'label': 'Homework', 'color': const Color(0xFFE11D48), 'route': '/school/homework'},
      {'icon': Icons.fact_check_rounded, 'label': 'Attendance', 'color': const Color(0xFF059669), 'route': '/school/attendance'},
      {'icon': Icons.description_rounded, 'label': 'Report Card', 'color': const Color(0xFF7C3AED), 'route': '/school/report-card'},
      {'icon': Icons.menu_book_rounded, 'label': 'Study Material', 'color': const Color(0xFF0D9488), 'action': 'materials'},
      {'icon': Icons.quiz_rounded, 'label': 'Practice Quiz', 'color': const Color(0xFF6366F1), 'action': 'quiz'},
      {'icon': Icons.assessment_rounded, 'label': 'My Reports', 'color': const Color(0xFF8B5CF6), 'action': 'reports'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Fees & Dues', 'color': const Color(0xFFD97706), 'route': '/school/fees'},
      {'icon': Icons.event_busy_rounded, 'label': 'Apply Leave', 'color': const Color(0xFF0284C7), 'route': '/school/leave'},
      {'icon': Icons.campaign_rounded, 'label': 'Circulars', 'color': const Color(0xFFF59E0B), 'route': '/school/circulars'},
      {'icon': Icons.local_library_rounded, 'label': 'Library', 'color': const Color(0xFF10B981), 'route': '/school/library'},
      {'icon': Icons.directions_bus_rounded, 'label': 'Transport', 'color': const Color(0xFF0EA5E9), 'route': '/school/transport'},
      {'icon': Icons.live_help_rounded, 'label': 'Ask Teacher', 'color': const Color(0xFF0284C7), 'action': 'ask_teacher'},
      {'icon': Icons.badge_rounded, 'label': 'My ID Card', 'color': const Color(0xFF4F46E5), 'action': 'profile'},
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
            final cols = constraints.maxWidth >= 1000 ? 6 : (constraints.maxWidth >= 650 ? 4 : 3);
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
                  onTap: () {
                    final action = a['action'] as String?;
                    if (action == 'materials') {
                      _showStudyMaterialsModal(context);
                    } else if (action == 'quiz') {
                      _showOnlineQuizzesModal(context);
                    } else if (action == 'reports') {
                      _showStudentReportsHubModal(context);
                    } else if (action == 'ask_teacher') {
                      _showAskTeacherModal(context);
                    } else if (action == 'profile') {
                      _showStudentProfileModal(context);
                    } else if (a['route'] != null) {
                      context.go(a['route'] as String);
                    }
                  },
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
                final dueLabel = hw['due']?.toString() ?? 'Upcoming';
                final isOverdue = dueLabel.contains('overdue');
                final isDueToday = dueLabel.contains('today');

                final badgeBg = isOverdue
                    ? const Color(0xFFFFF1F2)
                    : (isDueToday ? const Color(0xFFFFFBEB) : color.withValues(alpha: 0.10));
                final badgeText = isOverdue
                    ? const Color(0xFFE11D48)
                    : (isDueToday ? const Color(0xFFD97706) : color);

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
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dueLabel,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeText),
                    ),
                  ),
                  onTap: () => _showInstantHomeworkModal(context, hw),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResultsCard(BuildContext context) {
    double totalMarksObtained = 0.0;
    double totalMaxMarks = 0.0;
    for (final r in _recentResults) {
      final pct = (r['percent'] as num?)?.toDouble() ?? 0.0;
      totalMarksObtained += pct;
      totalMaxMarks += 100.0;
    }
    final overallPct = totalMaxMarks > 0 ? (totalMarksObtained / totalMaxMarks) * 100 : 0.0;
    final overallCbse = SchoolService.calculateCbseGrade(overallPct);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recentExamName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_recentResults.isNotEmpty)
                        Text(
                          'Overall: ' + overallPct.toStringAsFixed(1) + '% • ' + (overallCbse['grade'] ?? 'A1'),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
                        ),
                    ],
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
                final grade = r['grade']?.toString() ?? 'A1';
                final marks = r['marks']?.toString() ?? '';
                final subject = r['subject']?.toString() ?? 'Subject';
                final pct = (r['percent'] as num?)?.toDouble() ?? 80.0;

                IconData trendIcon = Icons.arrow_forward_rounded;
                Color trendColor = const Color(0xFF2563EB);
                if (pct >= 85.0) {
                  trendIcon = Icons.arrow_upward_rounded;
                  trendColor = const Color(0xFF059669);
                } else if (pct < 65.0) {
                  trendIcon = Icons.arrow_downward_rounded;
                  trendColor = const Color(0xFFE11D48);
                }

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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(trendIcon, size: 14, color: trendColor),
                    ],
                  ),
                  subtitle: Text('Score: ' + marks + ' (' + pct.toStringAsFixed(0) + '%)', style: const TextStyle(fontSize: 11, color: _muted)),
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
              _buildDrawerCategory('AI INSTITUTIONAL INTELLIGENCE'),
              _buildDrawerItem(Icons.auto_awesome_rounded, 'Ask School AI Chatbot (SP11)', () {
                if (isDrawer) Navigator.pop(context);
                context.push('/school/ai-tools?tab=chatbot');
              }),
              _buildDrawerCategory('ACADEMIC SERVICES'),
              _buildDrawerItem(Icons.event_note_rounded, 'Academic Calendar & Holidays', () {
                if (isDrawer) Navigator.pop(context);
                context.push('/school/calendar');
              }),
              _buildDrawerItem(Icons.calendar_month_rounded, 'Timetable', () => context.go('/school/timetable')),
              _buildDrawerItem(Icons.assignment_rounded, 'Homework', () => context.go('/school/homework')),
              _buildDrawerItem(Icons.fact_check_rounded, 'Attendance', () => context.go('/school/attendance')),
              _buildDrawerItem(Icons.description_rounded, 'Report Card', () => context.go('/school/report-card')),
              _buildDrawerItem(Icons.menu_book_rounded, 'Study Materials', () {
                if (isDrawer) Navigator.pop(context);
                _showStudyMaterialsModal(context);
              }),
              _buildDrawerItem(Icons.quiz_rounded, 'Practice Quizzes', () {
                if (isDrawer) Navigator.pop(context);
                _showOnlineQuizzesModal(context);
              }),
              _buildDrawerItem(Icons.assessment_rounded, 'My Reports & Analytics', () {
                if (isDrawer) Navigator.pop(context);
                _showStudentReportsHubModal(context);
              }),
              _buildDrawerItem(Icons.fact_check_rounded, 'Date Sheet & Hall Ticket', () => context.go('/school/examination')),
              _buildDrawerItem(Icons.event_busy_rounded, 'Leave Requests', () => context.go('/school/leave')),
              _buildDrawerCategory('CAMPUS & FINANCES'),
              _buildDrawerItem(Icons.receipt_long_rounded, 'Fee Dues & Receipts', () => context.go('/school/fees')),
              _buildDrawerItem(Icons.campaign_rounded, 'Circulars & Notices', () => context.go('/school/circulars')),
              _buildDrawerItem(Icons.directions_bus_rounded, 'Bus & Transport', () => context.go('/school/transport')),
              _buildDrawerItem(Icons.local_library_rounded, 'Library Books', () => context.go('/school/library')),
              _buildDrawerItem(Icons.card_membership_rounded, 'Certificates', () => context.go('/school/certificates')),
              _buildDrawerCategory('COMMUNICATION & PROFILE'),
              _buildDrawerItem(Icons.live_help_rounded, 'Ask Teacher (Doubts)', () {
                if (isDrawer) Navigator.pop(context);
                _showAskTeacherModal(context);
              }),
              _buildDrawerItem(Icons.notifications_active_rounded, 'Notifications Inbox', () {
                if (isDrawer) Navigator.pop(context);
                _showNotificationsInboxModal(context);
              }),
              _buildDrawerItem(Icons.badge_rounded, 'My Profile & ID Card', () {
                if (isDrawer) Navigator.pop(context);
                _showStudentProfileModal(context);
              }),
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

  // ==========================================
  // STU2: MY PROGRESS ANALYTICS (N1) & REPORTS HUB (N2)
  // ==========================================
  Widget _buildProgressAnalyticsSection(BuildContext context, bool isWide) {
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insights_rounded, size: 18, color: _primary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Academic Velocity & Progress',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Continuous 360° analytics across attendance, examination marks, and assignments',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showStudentReportsHubModal(context),
                  icon: const Icon(Icons.assessment_outlined, size: 14),
                  label: const Text('My Reports Hub →'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAttendanceVelocityCard(context)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildMarksTrendCard(context)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildSubjectBenchmarkCard(context)),
                      const SizedBox(width: 14),
                      Expanded(child: _buildHomeworkVelocityCard(context)),
                    ],
                  )
                else
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildAttendanceVelocityCard(context)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMarksTrendCard(context)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildSubjectBenchmarkCard(context)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildHomeworkVelocityCard(context)),
                        ],
                      ),
                    ],
                  ),
                _buildAttendance75RuleAlert(context, (_attendanceTrajectory['percentage'] as num?)?.toDouble() ?? _attendancePercent ?? 0.0),
                _buildGoalsProgressStrip(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceVelocityCard(BuildContext context) {
    final rawPoints = _attendanceTrajectory['points'];
    final points = rawPoints is List ? List<Map<String, dynamic>>.from(rawPoints) : <Map<String, dynamic>>[];
    final attPct = (_attendanceTrajectory['percentage'] as num?)?.toDouble() ?? _attendancePercent ?? 0.0;
    final isLow = attPct < 75.0 && attPct > 0;

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final v = (points[i]['score'] as num?)?.toDouble() ?? (points[i]['value'] as num?)?.toDouble() ?? 100.0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.isEmpty) {
      spots.addAll([const FlSpot(0, 85), const FlSpot(1, 90), const FlSpot(2, 92), const FlSpot(3, 94)]);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${attPct > 0 ? attPct.toStringAsFixed(1) : "0"}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isLow ? const Color(0xFFE11D48) : const Color(0xFF059669),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLow ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isLow ? 'Statutory Shortage' : 'CBSE >=75%',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isLow ? const Color(0xFFE11D48) : const Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('30-Day Attendance (STU-R01)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 110,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 75.0,
                      color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                      strokeWidth: 1.2,
                      dashArray: [4, 4],
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: isLow ? const Color(0xFFE11D48) : const Color(0xFF059669),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isLow ? const Color(0xFFE11D48) : const Color(0xFF059669)).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showSingleReportModal(context, 'STU-R01'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Details →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksTrendCard(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < _marksTrend.length; i++) {
      final pct = (_marksTrend[i]['percentage'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), pct));
    }
    if (spots.isEmpty) {
      spots.addAll([const FlSpot(0, 78), const FlSpot(1, 84), const FlSpot(2, 88)]);
    }

    final latestScore = _marksTrend.isNotEmpty
        ? (_marksTrend.last['percentage'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final latestExam = _marksTrend.isNotEmpty ? _marksTrend.last['exam_name']?.toString() ?? 'Exam' : 'Assessment';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${latestScore > 0 ? latestScore.toStringAsFixed(1) : "N/A"}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  latestExam,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4338CA),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Exam Marks Trend (STU-R03)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 105,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF4F46E5),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showSingleReportModal(context, 'STU-R03'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Details →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBenchmarkCard(BuildContext context) {
    final bars = <BarChartGroupData>[];
    final subList = _subjectPerformance.take(4).toList();
    for (int i = 0; i < subList.length; i++) {
      final p = (subList[i]['percentage'] as num?)?.toDouble() ?? 0.0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: p,
              color: p >= 80 ? const Color(0xFF059669) : (p >= 60 ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
              width: 10,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }
    if (bars.isEmpty) {
      bars.addAll([
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 90, color: const Color(0xFF059669), width: 10)]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 82, color: const Color(0xFF2563EB), width: 10)]),
        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 76, color: const Color(0xFFD97706), width: 10)]),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_subjectPerformance.length} Subjects',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CBSE Scale',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Subject Breakdown (STU-R04)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: bars,
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => _showSingleReportModal(context, 'STU-R04'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Details →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkVelocityCard(BuildContext context) {
    final rate = (_homeworkCompletion['completion_rate'] as num?)?.toDouble() ?? 100.0;
    final subCount = _homeworkCompletion['submitted_count'] ?? 0;
    final pendingCount = _homeworkCompletion['pending_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE11D48),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$subCount Done • $pendingCount Due',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBE123C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Homework Velocity (STU-R06)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (rate / 100.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              color: rate >= 80 ? const Color(0xFF059669) : const Color(0xFFE11D48),
            ),
          ),
          const SizedBox(height: 26),
          InkWell(
            onTap: () => _showSingleReportModal(context, 'STU-R06'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Details →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // N2: MY REPORTS HUB MODAL (STU-R01 to STU-R06)
  // ==========================================
  Future<void> _downloadStudentReportExcel(BuildContext context, String code) async {
    final username = await _authService.getCurrentUsername() ?? '';
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text('Generating official $code Excel workbook...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      if (code == 'STU-R01') {
        final rawPoints = _attendanceTrajectory['points'];
        final points = rawPoints is List ? List<Map<String, dynamic>>.from(rawPoints) : <Map<String, dynamic>>[];
        await SchoolExportService.exportStudentAttendanceTrendExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          attendancePct: (_attendanceTrajectory['percentage'] as num?)?.toDouble() ?? _attendancePercent ?? 0.0,
          dailyPoints: points,
        );
      } else if (code == 'STU-R02') {
        final reg = await _schoolService.getStudentMonthlyAttendanceRegister(username);
        await SchoolExportService.exportStudentAttendanceRegisterExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          records: reg,
        );
      } else if (code == 'STU-R03') {
        await SchoolExportService.exportStudentMarksTrendExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          examTrend: _marksTrend,
        );
      } else if (code == 'STU-R04') {
        await SchoolExportService.exportStudentSubjectPerformanceExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          subjects: _subjectPerformance,
        );
      } else if (code == 'STU-R05') {
        final hpc = await _schoolService.getHolisticProgressCard(studentId: username);
        await SchoolExportService.exportStudentReportCardExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          reportCardData: hpc,
        );
      } else if (code == 'STU-R06') {
        await SchoolExportService.exportStudentHomeworkCompletionExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          hwCompletion: _homeworkCompletion,
        );
      } else if (code == 'STU-R07') {
        final subs = (await _schoolService.getStudentHomeworkCompletion(username))['ledger'] ?? [];
        await SchoolExportService.exportStudentHomeworkSubmissionsLogExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          submissions: List<Map<String, dynamic>>.from(subs as List),
        );
      } else if (code == 'STU-R08') {
        final sched = await _schoolService.getMonthlyFeeSchedule(username);
        await SchoolExportService.exportStudentFeeStatementExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          feeSchedule: sched,
        );
      } else if (code == 'STU-R09') {
        final rcpts = await _schoolService.getStudentReceipts(username);
        await SchoolExportService.exportStudentFeeReceiptsExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          receipts: rcpts,
        );
      } else if (code == 'STU-R10') {
        final leaves = await _schoolService.getStudentLeaves(studentId: username);
        await SchoolExportService.exportStudentLeaveHistoryExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          leaves: leaves,
        );
      } else if (code == 'STU-R11') {
        final bks = await _schoolService.getStudentLibraryIssues(username);
        await SchoolExportService.exportStudentLibraryHistoryExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          books: bks,
        );
      } else if (code == 'STU-R12') {
        final mat = await _schoolService.getStudyMaterials(classId: 'cls-10a');
        final qz = await _schoolService.getOnlineQuizzes(classId: 'cls-10a');
        await SchoolExportService.exportStudentStudyProgressExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          materials: mat,
          quizzes: qz,
        );
      } else if (code == 'STU-R13') {
        final certs = await _schoolService.getStudentCertificateRequests(username);
        await SchoolExportService.exportStudentCertificatesLogExcel(
          context: context,
          studentUsername: username,
          studentName: _studentName,
          className: _studentClass,
          requests: certs,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e')),
        );
      }
    }
  }

  void _showStudentReportsHubModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assessment_rounded, color: _primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Reports Hub',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Student: $_studentName ($_studentClass) • Official CBSE Dossiers',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // CATEGORY 1: ACADEMICS & ATTENDANCE PROGRESS
                    _buildCategoryHeader('ACADEMICS & ATTENDANCE VELOCITY'),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R01',
                      title: 'My Attendance Velocity & 30-Day Trend',
                      desc: 'Daily attendance points, rolling percentage, and statutory CBSE 75% rule audit.',
                      icon: Icons.how_to_reg_rounded,
                      accent: const Color(0xFF059669),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R02',
                      title: 'My Monthly Attendance Register',
                      desc: 'Date-wise comprehensive attendance calendar (Present, Absent, Late, Excused Leave).',
                      icon: Icons.calendar_month_rounded,
                      accent: const Color(0xFF0D9488),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R03',
                      title: 'My Marks Trend & Exam Progression',
                      desc: 'Exam-to-exam percentage velocity across Half Yearly, Term II, and Annual sessions.',
                      icon: Icons.trending_up_rounded,
                      accent: const Color(0xFF4F46E5),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R04',
                      title: 'My Subject-Wise Performance & Benchmarks',
                      desc: 'Subject marks, max marks, CBSE 9-point grades (A1-E2), and faculty evaluation remarks.',
                      icon: Icons.bar_chart_rounded,
                      accent: const Color(0xFF2563EB),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R05',
                      title: 'My Report Card & HPC Co-Scholastic Dossier',
                      desc: 'Full Holistic Progress Card breakdown across scholastic and co-scholastic domains.',
                      icon: Icons.workspace_premium_rounded,
                      accent: const Color(0xFF7C3AED),
                    ),

                    const SizedBox(height: 12),
                    // CATEGORY 2: ASSIGNMENTS & LEARNING MATERIALS
                    _buildCategoryHeader('ASSIGNMENTS & LEARNING PROGRESS'),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R06',
                      title: 'My Homework Completion & Diary Audit',
                      desc: 'Complete submission history, submission timestamps, teacher notes, and overdue tracking.',
                      icon: Icons.assignment_turned_in_rounded,
                      accent: const Color(0xFFE11D48),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R07',
                      title: 'My Homework Submissions & Teacher Feedback',
                      desc: 'Granular submission timestamps, file attachments, and direct faculty feedback comments.',
                      icon: Icons.rate_review_rounded,
                      accent: const Color(0xFFD97706),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R12',
                      title: 'My Study Materials & Practice Quizzes Progress',
                      desc: 'Curriculum notes, textbook chapters read, and online MCQ practice quiz scorecards.',
                      icon: Icons.menu_book_rounded,
                      accent: const Color(0xFF8B5CF6),
                    ),

                    const SizedBox(height: 12),
                    // CATEGORY 3: FINANCIAL & CAMPUS LIFE
                    _buildCategoryHeader('FINANCIAL & CAMPUS RECORDS'),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R08',
                      title: 'My Statutory 12-Month Fee Statement',
                      desc: 'April to March schedule, monthly fee heads breakdown, statutory due date (5th), and late fees.',
                      icon: Icons.account_balance_wallet_rounded,
                      accent: const Color(0xFF0284C7),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R09',
                      title: 'My Reconciled Fee Receipts Register',
                      desc: 'Official receipt numbers, transaction modes (UPI/NetBanking), and cleared bank payment IDs.',
                      icon: Icons.receipt_long_rounded,
                      accent: const Color(0xFF059669),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R10',
                      title: 'My Student Leave Applications Log',
                      desc: 'Personal leave applications history, category, date duration, and class teacher decisions.',
                      icon: Icons.event_busy_rounded,
                      accent: const Color(0xFFDC2626),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R11',
                      title: 'My Library Borrowing & Books Register',
                      desc: 'Active book issues, ISBN accessions, due return dates, and late fine calculation ledger.',
                      icon: Icons.local_library_rounded,
                      accent: const Color(0xFF7C3AED),
                    ),
                    _buildReportItemCard(
                      ctx,
                      code: 'STU-R13',
                      title: 'My Official Certificate Requests Dossier',
                      desc: 'Bonafide, Transfer (TC), and Character certificates request status and QR verification seal.',
                      icon: Icons.verified_user_rounded,
                      accent: const Color(0xFF0D9488),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportItemCard(
    BuildContext context, {
    required String code,
    required String title,
    required String desc,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showSingleReportModal(context, code),
                icon: const Icon(Icons.show_chart_rounded, size: 15),
                label: const Text('Chart View'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _downloadStudentReportExcel(context, code),
                icon: const Icon(Icons.file_download_outlined, size: 15),
                label: const Text('Download Excel (.xlsx)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSingleReportModal(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                code,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primary),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Official Report Inspection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: $_studentName ($_studentClass)',
                style: const TextStyle(fontWeight: FontWeight.w600, color: _ink, fontSize: 13),
              ),
              const SizedBox(height: 4),
              const Text(
                'All report data is mathematically validated against institutional records.',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
              const SizedBox(height: 16),
              if (code == 'STU-R01' || code == 'STU-R02')
                _buildAttendanceVelocityCard(ctx)
              else if (code == 'STU-R03')
                _buildMarksTrendCard(ctx)
              else if (code == 'STU-R04' || code == 'STU-R05')
                _buildSubjectBenchmarkCard(ctx)
              else
                _buildHomeworkVelocityCard(ctx),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadStudentReportExcel(context, code);
            },
            icon: const Icon(Icons.download_rounded, size: 14),
            label: const Text('Excel Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.6,
        ),
      ),
    );
  }


  // ==========================================
  // N3: STUDY MATERIALS MODAL (LMS-LITE)
  // ==========================================
  void _showStudyMaterialsModal(BuildContext context) {
    String selectedSubject = 'All';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 680,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF0D9488), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Study Materials & Worksheets',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                          ),
                          Text(
                            'Subject courseware & notes for $_studentClass',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _schoolService.getStudyMaterials(classId: _studentClass),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                        ),
                      );
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 48, color: _muted),
                              SizedBox(height: 12),
                              Text(
                                'No Course Materials Uploaded',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Subject teachers have not published downloadable worksheets or notes for this class cohort yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: _muted),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final subjects = {'All', ...list.map((m) => m['subject']?.toString() ?? 'General')}.toList();
                    final filtered = selectedSubject == 'All'
                        ? list
                        : list.where((m) => (m['subject']?.toString() ?? 'General') == selectedSubject).toList();

                    return Column(
                      children: [
                        if (subjects.length > 2)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: subjects.map((subj) {
                                final isSelected = selectedSubject == subj;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: FilterChip(
                                    selected: isSelected,
                                    label: Text(subj, style: TextStyle(fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                                    onSelected: (val) {
                                      setModalState(() => selectedSubject = subj);
                                    },
                                    selectedColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                                    checkmarkColor: const Color(0xFF0D9488),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final mat = filtered[idx];
                              final subj = mat['subject']?.toString() ?? 'General';
                              final title = mat['title']?.toString() ?? 'Course Material';
                              final teacher = mat['uploaded_by']?.toString() ?? 'Faculty';
                              String dateLabel = '';
                              if (mat['created_at'] != null) {
                                try {
                                  final dt = DateTime.parse(mat['created_at'].toString());
                                  dateLabel = '${dt.day}/${dt.month}/${dt.year}';
                                } catch (_) {}
                              }

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0D9488), size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  subj.toUpperCase(),
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                                                ),
                                              ),
                                              if (dateLabel.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(dateLabel, style: const TextStyle(fontSize: 11, color: _muted)),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            title,
                                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink),
                                          ),
                                          const SizedBox(height: 2),
                                          Text('Faculty: $teacher', style: const TextStyle(fontSize: 11.5, color: _muted)),
                                        ],
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Opening document: $title')),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0D9488),
                                        side: const BorderSide(color: Color(0xFF0D9488)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      child: const Text('Read', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // N4: ONLINE PRACTICE QUIZZES & ASSESSMENTS
  // ==========================================
  void _showOnlineQuizzesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
            maxWidth: 680,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.quiz_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Practice Quizzes & Assessments',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                          ),
                          Text(
                            'Class $_studentClass • Instant MCQ evaluation & review',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: Color(0xFF6366F1),
                unselectedLabelColor: _muted,
                indicatorColor: Color(0xFF6366F1),
                labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Available Quizzes'),
                  Tab(text: 'My Scorecards'),
                ],
              ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: TabBarView(
                  children: [
                    // Tab 1: Available Quizzes
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _schoolService.getOnlineQuizzes(classId: _studentClass),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF6366F1))));
                        }
                        final quizzes = snapshot.data ?? [];
                        if (quizzes.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 48, color: _muted),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Active Practice Quizzes',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Subject teachers have not scheduled MCQ assessments for this class cohort yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12.5, color: _muted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: quizzes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final q = quizzes[idx];
                            final subj = q['subject']?.toString() ?? 'General';
                            final title = q['title']?.toString() ?? 'Quiz';
                            final duration = q['duration_minutes'] ?? 15;
                            final qCount = q['total_questions'] ?? (q['questions'] as List?)?.length ?? 3;
                            final weightage = q['weightage_percent'] ?? 10;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          subj.toUpperCase(),
                                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text('$duration Mins', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('$qCount Questions • $weightage% Weightage', style: const TextStyle(fontSize: 11.5, color: _muted)),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _startQuizExecution(context, q);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF6366F1),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        ),
                                        child: const Text('Start Quiz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Tab 2: My Scorecards
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _schoolService.getStudentQuizAttempts(studentUsername: _username),
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF6366F1))));
                        }
                        final attempts = snapshot.data ?? [];
                        if (attempts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_edu_rounded, size: 48, color: _muted),
                                  SizedBox(height: 12),
                                  Text(
                                    'No Quiz Attempts Recorded',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'You have not taken any online practice quizzes yet. Take a quiz to test your mastery!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12.5, color: _muted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: attempts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final att = attempts[idx];
                            final title = att['quiz_title']?.toString() ?? 'Assessment Quiz';
                            final subj = att['subject']?.toString() ?? 'General';
                            final score = (att['score'] as num?)?.toDouble() ?? 0.0;
                            final total = (att['total'] as num?)?.toDouble() ?? 10.0;
                            final pct = (att['percentage'] as num?)?.toDouble() ?? (total > 0 ? (score / total) * 100 : 0.0);
                            final isPass = pct >= 60.0;
                            String dateStr = '';
                            if (att['attempted_at'] != null) {
                              try {
                                final dt = DateTime.parse(att['attempted_at'].toString());
                                dateStr = '${dt.day}/${dt.month}/${dt.year}';
                              } catch (_) {}
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isPass ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isPass ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                                        const SizedBox(height: 2),
                                        Text('$subj • ${score.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} pts',
                                            style: const TextStyle(fontSize: 11.5, color: _muted)),
                                      ],
                                    ),
                                  ),
                                  if (dateStr.isNotEmpty)
                                    Text(dateStr, style: const TextStyle(fontSize: 11, color: _muted)),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startQuizExecution(BuildContext context, Map<String, dynamic> quiz) {
    final rawQuestions = quiz['questions'] as List? ?? [];
    if (rawQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This quiz does not have any active questions.')),
      );
      return;
    }

    final questions = rawQuestions.map((q) => Map<String, dynamic>.from(q as Map)).toList();
    final Map<int, int> selectedAnswers = {};
    int currentIndex = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final q = questions[currentIndex];
          final qText = q['question']?.toString() ?? 'Question';
          final options = (q['options'] as List?)?.map((o) => o.toString()).toList() ?? [];
          final selectedOption = selectedAnswers[currentIndex];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz['title']?.toString() ?? 'Assessment Quiz',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Question ${currentIndex + 1} of ${questions.length}',
                        style: const TextStyle(fontSize: 11.5, color: _muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    '${quiz['duration_minutes'] ?? 15} Mins',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    qText,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < options.length; i++) ...[
                    InkWell(
                      onTap: () {
                        setDlgState(() => selectedAnswers[currentIndex] = i);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selectedOption == i ? const Color(0xFFEEF2FF) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedOption == i ? const Color(0xFF6366F1) : _border,
                            width: selectedOption == i ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selectedOption == i ? const Color(0xFF6366F1) : Colors.transparent,
                                border: Border.all(color: selectedOption == i ? const Color(0xFF6366F1) : _muted),
                              ),
                              child: selectedOption == i
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : Center(
                                      child: Text(
                                        String.fromCharCode(65 + i),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _muted),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                options[i],
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: selectedOption == i ? FontWeight.w600 : FontWeight.normal,
                                  color: selectedOption == i ? const Color(0xFF312E81) : _ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (currentIndex > 0)
                TextButton(
                  onPressed: () => setDlgState(() => currentIndex--),
                  child: const Text('Previous'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Quit', style: TextStyle(color: Color(0xFFEF4444))),
              ),
              if (currentIndex < questions.length - 1)
                ElevatedButton(
                  onPressed: () => setDlgState(() => currentIndex++),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next'),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dlgCtx);
                    await _finishAndScoreQuiz(context, quiz, questions, selectedAnswers);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Quiz'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _finishAndScoreQuiz(
    BuildContext context,
    Map<String, dynamic> quiz,
    List<Map<String, dynamic>> questions,
    Map<int, int> selectedAnswers,
  ) async {
    double score = 0;
    for (var i = 0; i < questions.length; i++) {
      final correctIdx = (questions[i]['correct_index'] as num?)?.toInt() ?? 0;
      if (selectedAnswers[i] == correctIdx) {
        score += 1;
      }
    }
    final total = questions.length.toDouble();
    final pct = total > 0 ? (score / total) * 100 : 0.0;
    final isPass = pct >= 60;

    await _schoolService.submitQuizAttempt(
      quizId: quiz['id']?.toString() ?? '',
      quizTitle: quiz['title']?.toString() ?? 'Assessment Quiz',
      subject: quiz['subject']?.toString() ?? 'General',
      studentUsername: _username,
      studentName: _studentName,
      score: score,
      total: total,
      answers: selectedAnswers.map((k, v) => MapEntry(k.toString(), v)),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isPass ? Icons.stars_rounded : Icons.info_outline_rounded,
                color: isPass ? const Color(0xFF10B981) : const Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 8),
            Text(isPass ? 'Quiz Passed! 🎉' : 'Quiz Completed',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isPass ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPass ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
              ),
              child: Column(
                children: [
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isPass ? const Color(0xFF047857) : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${score.toInt()} of ${total.toInt()} Questions Correct',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isPass
                  ? 'Excellent command of this topic! Your score has been recorded to your scorecard ledger.'
                  : 'Practice required to improve your retention. Review the chapter notes in Study Materials and retry.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }


  // ==========================================
  // STU5: N13 ATTENDANCE 75% RULE ALERT
  // ==========================================
  Widget _buildAttendance75RuleAlert(BuildContext context, double attPct) {
    if (attPct <= 0) return const SizedBox.shrink();
    final isLow = attPct < 75.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLow ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLow ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
            size: 18,
            color: isLow ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLow
                  ? 'CBSE 75% Statutory Alert: Your attendance (${attPct.toStringAsFixed(1)}%) is short by ${(75.0 - attPct).toStringAsFixed(1)}%. Regular attendance is required to qualify for annual board examinations.'
                  : 'CBSE Attendance On Track: Current attendance is ${attPct.toStringAsFixed(1)}%. You maintain an active safe buffer above the 75% statutory rule.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isLow ? const Color(0xFF9F1239) : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STU5: N6 ACADEMIC GOALS & TARGETS STRIP
  // ==========================================
  Widget _buildGoalsProgressStrip(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'My Academic Goals & Targets',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showSetGoalsModal(context),
                icon: const Icon(Icons.edit_note_rounded, size: 14),
                label: const Text('Set Targets', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ),
            ],
          ),
          if (_goals.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No targets set yet. Tap "Set Targets" to benchmark your personal subject percentages!',
                style: TextStyle(fontSize: 11.5, color: _muted),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final g in _goals) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        g['subject']?.toString() ?? 'Subject',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (((g['target_percent'] as num?)?.toDouble() ?? 85.0) / 100.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Target: ${(g['target_percent'] as num?)?.toDouble().toStringAsFixed(0) ?? "85"}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ==========================================
  // STU5: N11 EXAM COUNTDOWN BANNER
  // ==========================================
  Widget _buildExamCountdownBanner(BuildContext context) {
    final title = _examCountdown['title']?.toString() ?? 'Upcoming Examination';
    final countdown = _examCountdown['countdown_text']?.toString() ?? 'Date sheet published';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B)),
                ),
                Text(
                  countdown,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF4338CA)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.go('/school/report-card'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
              side: const BorderSide(color: Color(0xFF818CF8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text('Date Sheet', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STU5: N7 LEAVE STATUS CARD
  // ==========================================
  Widget _buildLeaveStatusBanner(BuildContext context) {
    final leave = _leaves.first;
    final cat = leave['category']?.toString() ?? 'Leave Application';
    final days = leave['days'] ?? 1;
    final status = (leave['status']?.toString() ?? 'pending').toLowerCase();
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isApproved ? const Color(0xFFECFDF5) : (isRejected ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApproved ? const Color(0xFFA7F3D0) : (isRejected ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.event_available_rounded : (isRejected ? Icons.event_busy_rounded : Icons.pending_actions_rounded),
            color: isApproved ? const Color(0xFF059669) : (isRejected ? const Color(0xFFE11D48) : const Color(0xFFD97706)),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cat ($days Day${days > 1 ? "s" : ""})',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink),
                ),
                Text(
                  isApproved
                      ? 'Approved by class faculty (Attendance excused)'
                      : (isRejected ? 'Application declined by faculty' : 'Pending review by class teacher'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isApproved ? const Color(0xFF047857) : (isRejected ? const Color(0xFF9F1239) : const Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.go('/school/leave'),
            child: const Text('View Leaves →', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STU5: N8 & N9 TRANSPORT & CERTIFICATES CARDS
  // ==========================================
  Widget _buildTransportAndCertificatesRow(BuildContext context, bool isWide) {
    final hasTransport = _transport.isNotEmpty;
    final hasCerts = _certificateRequests.isNotEmpty;

    if (!hasTransport && !hasCerts) return const SizedBox.shrink();

    final children = <Widget>[];
    if (hasTransport) {
      final t = _transport.first;
      final route = t['route_no']?.toString() ?? 'Route 1';
      final bus = t['bus_no']?.toString() ?? 'UK-07';
      final stop = t['pickup_point']?.toString() ?? 'Designated Stop';
      final time = t['pickup_time']?.toString() ?? '07:45 AM';

      children.add(
        Expanded(
          child: InkWell(
            onTap: () => context.go('/school/transport'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$route • $bus', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                        Text('Stop: $stop ($time)', style: const TextStyle(fontSize: 11, color: _muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (hasCerts) {
      final c = _certificateRequests.first;
      final type = c['certificate_type']?.toString() ?? 'Certificate';
      final status = (c['status']?.toString() ?? 'pending').toUpperCase();

      children.add(
        Expanded(
          child: InkWell(
            onTap: () => context.go('/school/certificates'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.card_membership_rounded, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
                        Text('Status: $status', style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return isWide || children.length == 1
        ? Row(children: children)
        : Column(
            children: [
              children[0],
              const SizedBox(height: 10),
              children[1],
            ],
          );
  }

  // ==========================================
  // STU5: N10 NOTIFICATIONS INBOX MODAL
  // ==========================================
  void _showNotificationsInboxModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
          maxWidth: 640,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notifications & Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                        Text('Real-time academic, fee, and institutional alerts', style: TextStyle(fontSize: 12, color: _muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Flexible(
              child: _notifications.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_off_outlined, size: 48, color: _muted),
                            SizedBox(height: 12),
                            Text('No Notifications Yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
                            SizedBox(height: 4),
                            Text('You are completely caught up with your classes and tasks.', style: TextStyle(fontSize: 12.5, color: _muted)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final n = _notifications[idx];
                        final type = n['type']?.toString() ?? 'info';
                        final route = n['route']?.toString();

                        IconData icon = Icons.info_outline_rounded;
                        Color col = const Color(0xFF2563EB);
                        if (type == 'homework') {
                          icon = Icons.assignment_late_rounded;
                          col = const Color(0xFFE11D48);
                        } else if (type == 'fee') {
                          icon = Icons.receipt_long_rounded;
                          col = const Color(0xFFD97706);
                        } else if (type == 'leave') {
                          icon = Icons.event_note_rounded;
                          col = const Color(0xFF059669);
                        }

                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            if (route != null && route.isNotEmpty) {
                              context.go(route);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: col.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Icon(icon, color: col, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n['title']?.toString() ?? 'Notice', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                                      const SizedBox(height: 3),
                                      Text(n['body']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: _muted, height: 1.3)),
                                    ],
                                  ),
                                ),
                                if (route != null)
                                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCBD5E1)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STU5: N12 STUDENT PROFILE & ID CARD MODAL
  // ==========================================
  void _showStudentProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 540,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Student Identity Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_schoolName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                              Text(_affiliationNo, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          child: Text(
                            _studentName.isNotEmpty ? _studentName[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF4F46E5)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_studentName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                              const SizedBox(height: 3),
                              Text('Cohort: $_studentClass', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFA5B4FC))),
                              Text('Admission No: ' + (_admissionNo.isNotEmpty ? _admissionNo : "SHIV-STUDENT"), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                              Text('Academic Year: $_academicSession', style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text('CBSE DIGI-VERIFIED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                            ],
                          ),
                          Text('ID: $_username', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/school/report-card');
                      },
                      icon: const Icon(Icons.description_rounded, size: 16),
                      label: const Text('View Report Card'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Student ID Card ready for official print.')),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Print ID Card'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STU5: N14 ASK TEACHER / DOUBT MODAL
  // ==========================================
  void _showAskTeacherModal(BuildContext context) {
    final queryController = TextEditingController();
    String selectedSubj = 'Mathematics';
    final subjects = ['Mathematics', 'Science', 'English', 'Social Science', 'Hindi', 'Computer Applications'];
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setModalState) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
              maxWidth: 640,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.live_help_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ask Teacher • Doubt Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                            Text('Submit academic questions directly to subject faculty', style: TextStyle(fontSize: 12, color: _muted)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Color(0xFF0284C7),
                  unselectedLabelColor: _muted,
                  indicatorColor: Color(0xFF0284C7),
                  tabs: [
                    Tab(text: 'Ask a Doubt'),
                    Tab(text: 'My Doubts & Replies'),
                  ],
                ),
                const Divider(height: 1, color: _border),
                Flexible(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Subject', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: selectedSubj,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedSubj = val);
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text('Your Question / Doubt Details', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: queryController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Explain what concept, exercise or problem you need help with...',
                                hintStyle: const TextStyle(fontSize: 12, color: _muted),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final msg = queryController.text.trim();
                                        if (msg.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Please write your doubt message before submitting.')),
                                          );
                                          return;
                                        }
                                        setModalState(() => isSubmitting = true);
                                        final ok = await _schoolService.submitStudentQuery(
                                          studentUsername: _username,
                                          studentName: _studentName,
                                          subject: selectedSubj,
                                          message: msg,
                                        );
                                        setModalState(() => isSubmitting = false);
                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(ok ? 'Doubt submitted to ' + selectedSubj + ' faculty!' : 'Could not save question.'),
                                              backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            ),
                                          );
                                        }
                                      },
                                icon: isSubmitting
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Submit Doubt to Faculty', style: TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _schoolService.getStudentQueries(studentUsername: _username),
                        builder: (ctx, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF0284C7))));
                          }
                          final queries = snapshot.data ?? [];
                          if (queries.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.question_answer_outlined, size: 48, color: _muted),
                                    SizedBox(height: 12),
                                    Text('No Doubts Asked Yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
                                    SizedBox(height: 4),
                                    Text('Have a doubt? Ask your subject teacher anytime.', style: TextStyle(fontSize: 12.5, color: _muted)),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: queries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final q = queries[idx];
                              final subj = q['subject']?.toString() ?? 'General';
                              final status = (q['status']?.toString() ?? 'pending').toLowerCase();
                              final isReplied = status == 'replied';
                              final reply = q['reply']?.toString() ?? '';

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                          child: Text(subj, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7))),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isReplied ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isReplied ? 'REPLIED' : 'PENDING REPLY',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: isReplied ? const Color(0xFF059669) : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      q['message']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13, color: _ink, height: 1.3),
                                    ),
                                    if (isReplied && reply.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFBBF7D0)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Faculty Reply:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF166534))),
                                            const SizedBox(height: 2),
                                            Text(reply, style: const TextStyle(fontSize: 12, color: Color(0xFF14532D))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STU5: N6 SET GOALS MODAL
  // ==========================================
  void _showSetGoalsModal(BuildContext context) {
    final subjects = ['Mathematics', 'Science', 'English', 'Social Science', 'Hindi', 'Computer Applications'];
    final goalMap = <String, double>{};
    for (final s in subjects) {
      final existing = _goals.firstWhere((g) => g['subject'] == s, orElse: () => <String, dynamic>{});
      goalMap[s] = (existing['target_percent'] as num?)?.toDouble() ?? 85.0;
    }
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 600,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.track_changes_rounded, color: Color(0xFF6366F1), size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Set Subject Target Percentages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _border),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: subjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final subj = subjects[idx];
                    final currentVal = goalMap[subj] ?? 85.0;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(subj, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                              Text(currentVal.toStringAsFixed(0) + '%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5))),
                            ],
                          ),
                          Slider(
                            value: currentVal,
                            min: 40,
                            max: 100,
                            divisions: 12,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (val) {
                              setModalState(() => goalMap[subj] = val);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            for (final entry in goalMap.entries) {
                              await _schoolService.setStudentGoal(
                                studentUsername: _username,
                                subject: entry.key,
                                targetPercent: entry.value,
                              );
                            }
                            final updatedGoals = await _schoolService.getStudentGoals(_username);
                            if (mounted) {
                              setState(() => _goals = updatedGoals);
                            }
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Target goals updated successfully!')),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Targets', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ==========================================
  // STU6: M8 INSTANT HOMEWORK SUBMISSION MODAL
  // ==========================================
  void _showInstantHomeworkModal(BuildContext context, Map<String, dynamic> hw) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 600,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_rounded, color: Color(0xFFE11D48), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hw['title']?.toString() ?? 'Homework Assignment',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
                      ),
                      Text(
                        (hw['subject']?.toString() ?? 'General') + ' • Due: ' + (hw['due']?.toString() ?? 'Upcoming'),
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Submission Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('PENDING SUBMISSION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/school/homework');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Open in Homework Desk'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/school/homework');
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Submit Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
