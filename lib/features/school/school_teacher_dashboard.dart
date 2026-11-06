import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../services/school_export_service.dart';
import 'package:fl_chart/fl_chart.dart';

class SchoolTeacherDashboard extends StatefulWidget {
  const SchoolTeacherDashboard({super.key});

  @override
  State<SchoolTeacherDashboard> createState() => _SchoolTeacherDashboardState();
}

class _SchoolTeacherDashboardState extends State<SchoolTeacherDashboard> {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  String _teacherUsername = '';
  String _teacherName = 'Teacher';
  String _teacherClass = 'Class Teacher';
  String? _instituteName;

  // Real Attendance State
  int? _totalStudents;
  int? _presentToday;
  bool _isAttendanceMarkedToday = false;
  List<Map<String, dynamic>> _todayAbsentees = [];

  // Real Activity Stats
  int _pendingAssignments = 0;
  int _upcomingClasses = 0;
  int _pendingLeaves = 0;

  // 4-State Lifecycle
  bool _isLoading = true;
  String? _errorMessage;

  // Real Schedule
  List<Map<String, dynamic>> _todaySchedule = [];

  // Teacher Analytics State (N2: T-R01, T-R04, T-R05, T-R07)
  List<Map<String, dynamic>> _attendanceTrend = [];
  Map<String, dynamic> _gradeDistribution = {};
  List<Map<String, dynamic>> _subjectAverages = [];
  Map<String, dynamic> _homeworkStats = {};

  // My Students Roster & Filter State (N1 + M12)
  List<Map<String, dynamic>> _assignedClasses = [];
  String _selectedClassFilter = 'all';
  List<Map<String, dynamic>> _students = [];
  bool _isStudentsLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Step T5 New Features State (N4 to N14)
  List<Map<String, dynamic>> _substitutionsToday = []; // N5
  Map<String, dynamic>? _upcomingExam; // N9
  List<Map<String, dynamic>> _atRiskStudents = []; // N8
  List<Map<String, dynamic>> _gradingQueue = []; // N12
  List<Map<String, dynamic>> _ptmBookings = []; // N10
  List<Map<String, dynamic>> _teacherLeaves = []; // N6
  List<Map<String, dynamic>> _notifications = []; // N14
  Map<String, dynamic>? _weeklyWorkload; // N11
  String _scheduleViewMode = 'today'; // 'today' | 'weekly' (N11)
  Set<String> _attendanceMarkedClassesToday = {}; // N13
  List<Map<String, dynamic>> _syllabusVelocity = []; // M5
  List<Map<String, dynamic>> _pendingStudentLeaves = []; // M9

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final username = await _authService.getCurrentUsername() ?? '';
      _teacherUsername = username;
      final displayName = await _schoolService.getTeacherDisplayName(username);
      final teacherClasses = await _schoolService.getClassTeacherClasses(username);
      final instName = await _schoolService.getSchoolInstituteName();

      final schedule = await _schoolService.getTeacherTimetable(username);
      final pendingHw = await _schoolService.getPendingHomeworkToGrade(username);
      final pendingLeavesList = await _schoolService.getLeaveRequestsForClassTeacher(username);

      // Real Assigned Classes (Union of Class Teacher and Subject Faculty)
      final allAssigned = await _schoolService.getTeacherAllAssignedClasses(username);

      // Real Teacher Analytics (N2 + T-R01, T-R04, T-R05, T-R07)
      final attTrend = await _schoolService.getTeacherAttendanceTrend(username);
      final gradeDist = await _schoolService.getTeacherClassGradeDistribution(username);
      final subAvgs = await _schoolService.getTeacherSubjectAverages(username);
      final hwStats = await _schoolService.getTeacherHomeworkCompletionStats(username);

      // Real Attendance for Class Teacher's assigned class today
      int? totalStd;
      int? presentStd;
      bool isMarked = false;
      List<Map<String, dynamic>> absentees = [];

      if (teacherClasses.isNotEmpty) {
        final classId = teacherClasses.first['id']?.toString() ?? '';
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final attSummary = await _schoolService.getAttendanceSummary(
          classId: classId,
          from: today,
          to: today,
        );
        final total = (attSummary['total'] as num?)?.toInt() ?? 0;
        final present = (attSummary['present'] as num?)?.toInt() ?? 0;
        if (total > 0) {
          isMarked = true;
          totalStd = total;
          presentStd = present;
          final attReport = await _schoolService.getAttendanceReport(
            classId: classId,
            from: today,
            to: today,
          );
          absentees = attReport.where((r) => r['status'] == 'absent').toList();
        } else {
          isMarked = false;
          final students = await _schoolService.getStudentsByClass(classId);
          totalStd = students.isNotEmpty ? students.length : null;
          presentStd = null;
        }
      }

      if (mounted) {
        setState(() {
          _teacherName = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : (username.isEmpty ? 'Teacher' : username);
          _teacherClass = teacherClasses.isEmpty
              ? 'Subject Faculty'
              : 'Class Teacher • ${teacherClasses.first['name'] ?? ''}'.trim();
          _instituteName = instName;
          _todaySchedule = schedule;
          _upcomingClasses = schedule.length;
          _pendingAssignments = pendingHw;
          _pendingLeaves = pendingLeavesList.length;
          _isAttendanceMarkedToday = isMarked;
          _totalStudents = totalStd;
          _presentToday = presentStd;
          _todayAbsentees = absentees;
          _assignedClasses = allAssigned;
          _attendanceTrend = attTrend;
          _gradeDistribution = gradeDist;
          _subjectAverages = subAvgs;
          _homeworkStats = hwStats;
        });

        // Step T5 Queries
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final subs = await _schoolService.getSubstitutionLogs(date: todayStr);
        final mySubs = subs.where((s) {
          final subT = (s['substitute_teacher']?.toString() ?? '').toLowerCase();
          return subT.contains(username.toLowerCase()) || subT.contains((_teacherName).toLowerCase());
        }).toList();

        final upExam = await _schoolService.getNextUpcomingExamForTeacher(username);
        final atRisk = await _schoolService.getTeacherAtRiskStudents(username);
        final queue = await _schoolService.getTeacherHomeworkGradingQueue(username);
        final ptms = await _schoolService.getTeacherPtmBookings(displayName ?? username);
        final myLeaves = await _schoolService.getTeacherLeaves(username);
        final notifs = await _schoolService.getTeacherNotifications(username);
        final workload = await _schoolService.getTeacherWeeklyWorkload(username);

        // Period-wise attendance marked checks for today (N13)
        final markedClasses = <String>{};
        if (isMarked && teacherClasses.isNotEmpty) {
          final tid = teacherClasses.first['id']?.toString() ?? '';
          final tname = teacherClasses.first['name']?.toString() ?? '';
          if (tid.isNotEmpty) markedClasses.add(tid);
          if (tname.isNotEmpty) markedClasses.add(tname);
        }
        for (final s in schedule) {
          final cid = (s['class_id'] ?? s['class'] ?? '').toString();
          if (cid.isNotEmpty && !markedClasses.contains(cid)) {
            final marked = await _schoolService.hasMarkedAttendanceToday(username, cid);
            if (marked) markedClasses.add(cid);
          }
        }

        if (mounted) {
          setState(() {
            _substitutionsToday = mySubs;
            _upcomingExam = upExam;
            _atRiskStudents = atRisk;
            _gradingQueue = queue;
            _ptmBookings = ptms;
            _teacherLeaves = myLeaves;
            _notifications = notifs;
            _weeklyWorkload = workload;
            _attendanceMarkedClassesToday = markedClasses;
            _pendingStudentLeaves = pendingLeavesList;
          });

          final velocity = await _schoolService.getTeacherSyllabusVelocity(username);
          if (mounted) {
            setState(() {
              _syllabusVelocity = velocity;
              _isLoading = false;
              _errorMessage = null;
            });
          }
          _loadStudents();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load teacher workspace. Please check your connection and tap retry.';
        });
      }
    }
  }

  Future<void> _loadStudents() async {
    if (_teacherUsername.isEmpty) return;
    setState(() => _isStudentsLoading = true);

    try {
      final rawStudents = await _schoolService.getStudentsForTeacher(
        _teacherUsername,
        classId: _selectedClassFilter == 'all' ? null : _selectedClassFilter,
      );

      // Enrich with fast real-time attendance rate for current visible cohort
      final enriched = <Map<String, dynamic>>[];
      for (final s in rawStudents) {
        final sid = s['id']?.toString() ?? s['username']?.toString() ?? '';
        final cid = s['class_id']?.toString() ?? '';
        double att = 0.0;
        try {
          att = await _schoolService.getStudentAttendancePercent(sid);
        } catch (_) {}

        enriched.add({
          ...s,
          'attendance_pct': att,
          'resolved_class_id': cid,
        });
      }

      if (mounted) {
        setState(() {
          _students = enriched;
          _isStudentsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isStudentsLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teacher & Faculty Workspace',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            Text(
              _instituteName != null && _instituteName!.isNotEmpty
                  ? '$_instituteName • $dateStr'
                  : dateStr,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          // AI Assistant & Chatbot Studio
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/school/ai-tools'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
                      SizedBox(width: 5),
                      Text(
                        'AI Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Faculty Inbox & Notifications',
                icon: const Icon(Icons.notifications_outlined, size: 21),
                onPressed: _showInboxModal,
              ),
              if (_notifications.where((n) => n['is_read'] != true).isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Text(
                      '${_notifications.where((n) => n['is_read'] != true).length}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Refresh Workspace',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadData,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'teacher_ai_tools_fab',
        onPressed: () => context.push('/school/ai-tools'),
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
        label: const Text(
          'AI Assistant & Chatbot',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3),
        ),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFF0F172A),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                    children: [
                      _buildFacultyHeroCard(),
                      if (_upcomingExam != null) ...[
                        const SizedBox(height: 14),
                        _buildUpcomingExamBanner(),
                      ],
                      const SizedBox(height: 16),
                      _buildKpiGrid(),
                      if (_gradingQueue.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildHomeworkGradingQueueSection(),
                      ],
                      if (_pendingStudentLeaves.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildPendingStudentLeavesQueue(),
                      ],
                      const SizedBox(height: 20),
                      _buildTeacherAnalyticsSection(),
                      if (_atRiskStudents.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildAttentionNeededSection(),
                      ],
                      const SizedBox(height: 20),
                      _buildMyStudentsSection(),
                      const SizedBox(height: 20),
                      _buildAcademicsAndMarksSection(),
                      const SizedBox(height: 20),
                      _buildDailyOperationsSection(),
                      if (_substitutionsToday.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildSubstitutionDeskCard(),
                      ],
                      const SizedBox(height: 20),
                      _buildTodayScheduleSection(),
                    ],
                  ),
                ),
    );
  }

  // ──────────────────────────────────────────────
  // 1. HERO FACULTY BANNER
  // ──────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text(
            'Connecting to Faculty Ledger...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Unable to connect to school faculty ledger.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: const Center(
              child: Icon(Icons.school_rounded, color: Color(0xFF0F172A), size: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _teacherName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'FACULTY',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _teacherClass,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => context.push('/school/attendance'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            icon: const Icon(Icons.how_to_reg_rounded, size: 16),
            label: const Text('Register', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 2. 4-KPI SUMMARY GRID
  // ──────────────────────────────────────────────
  Widget _buildKpiGrid() {
    final hasAttendance = _isAttendanceMarkedToday && _presentToday != null && _totalStudents != null && _totalStudents! > 0;
    final attPct = hasAttendance ? (_presentToday! / _totalStudents!) * 100 : 0.0;
    final attValue = hasAttendance
        ? '$_presentToday / $_totalStudents'
        : (_totalStudents != null ? 'Not Marked' : 'No Class');
    final attBadge = hasAttendance
        ? '${attPct.toStringAsFixed(0)}% Rate'
        : (_totalStudents != null ? 'Mark Now' : 'Subject Faculty');

    return Row(
      children: [
        _buildKpiCard(
          title: "Attendance Today",
          value: attValue,
          badgeText: attBadge,
          badgeBg: hasAttendance ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
          badgeColor: hasAttendance ? const Color(0xFF10B981) : const Color(0xFFD97706),
          icon: Icons.how_to_reg_outlined,
          onTap: () {
            if (_todayAbsentees.isNotEmpty) {
              _showAbsenteesDialog(context);
            } else {
              context.push('/school/attendance');
            }
          },
        ),
        const SizedBox(width: 10),
        _buildKpiCard(
          title: "Homework to Grade",
          value: '$_pendingAssignments Pending',
          badgeText: 'Submissions',
          badgeBg: const Color(0xFFFFFBEB),
          badgeColor: const Color(0xFFD97706),
          icon: Icons.assignment_outlined,
          onTap: () => context.push('/school/homework'),
        ),
        const SizedBox(width: 10),
        _buildKpiCard(
          title: "Classes Today",
          value: '$_upcomingClasses Lectures',
          badgeText: 'Scheduled',
          badgeBg: const Color(0xFFEFF6FF),
          badgeColor: const Color(0xFF2563EB),
          icon: Icons.class_outlined,
          onTap: () => context.push('/school/timetable'),
        ),
        const SizedBox(width: 10),
        _buildKpiCard(
          title: "Leave Approvals",
          value: '$_pendingLeaves Pending',
          badgeText: 'Student',
          badgeBg: const Color(0xFFFEF2F2),
          badgeColor: const Color(0xFFEF4444),
          icon: Icons.event_busy_outlined,
          onTap: () => context.push('/school/leave'),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badgeText,
    required Color badgeBg,
    required Color badgeColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF64748B)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      badgeText,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 2.5 TEACHER ANALYTICS & FL_CHART MATRICES (N2)
  // ──────────────────────────────────────────────
  Widget _buildTeacherAnalyticsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Class Analytics & Academic Velocity',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '30-day attendance trajectory, CBSE evaluation distribution, and subject benchmarks',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/school/reports'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('My Reports Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2x2 Analytics Charts Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 850;
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAttendanceTrendChartCard()),
                      if (isWide) ...[
                        const SizedBox(width: 14),
                        Expanded(child: _buildGradeDistributionChartCard()),
                      ],
                    ],
                  ),
                  if (!isWide) ...[
                    const SizedBox(height: 14),
                    _buildGradeDistributionChartCard(),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSubjectAveragesChartCard()),
                      if (isWide) ...[
                        const SizedBox(width: 14),
                        Expanded(child: _buildHomeworkDonutChartCard()),
                      ],
                    ],
                  ),
                  if (!isWide) ...[
                    const SizedBox(height: 14),
                    _buildHomeworkDonutChartCard(),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // 1. 30-Day Attendance Trajectory Chart (T-R01)
  Widget _buildAttendanceTrendChartCard() {
    double totalPct = 0;
    int count = 0;
    final spots = <FlSpot>[];

    for (int i = 0; i < _attendanceTrend.length; i++) {
      final r = _attendanceTrend[i];
      final pct = (r['percent'] as num?)?.toDouble() ?? 0.0;
      final isMarked = (r['is_marked'] as bool?) ?? false;
      if (isMarked) {
        totalPct += pct;
        count++;
      }
      spots.add(FlSpot(i.toDouble(), pct));
    }
    final avg = count > 0 ? totalPct / count : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance Trajectory (30 Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('CBSE 75% Statutory Limit Reference', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: avg >= 75 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  count > 0 ? '${avg.toStringAsFixed(1)}% Avg' : 'Unrecorded',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: avg >= 75 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: spots.isEmpty
                ? const Center(child: Text('No attendance trajectory data available', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))))
                : LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              if (v == 0 || v == 50 || v == 75 || v == 100) {
                                return Text('${v.toInt()}%', style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            interval: 5,
                            getTitlesWidget: (v, m) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < _attendanceTrend.length) {
                                final dayNum = _attendanceTrend[idx]['day_number']?.toString() ?? '$idx';
                                return Text(dayNum, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 75.0,
                            color: const Color(0xFFEF4444),
                            strokeWidth: 1.5,
                            dashArray: [4, 4],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              labelResolver: (l) => '75% CBSE',
                              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend reflects active cohort attendance', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              InkWell(
                onTap: () => context.push('/school/reports'),
                child: const Row(
                  children: [
                    Text('Full Register (T-R02)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 11, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. CBSE Class Grade Distribution Chart (T-R04)
  Widget _buildGradeDistributionChartCard() {
    final counts = (_gradeDistribution['counts'] as Map?)?.cast<String, int>() ?? {};
    final total = (_gradeDistribution['total'] as num?)?.toInt() ?? 0;
    final avg = (_gradeDistribution['average'] as num?)?.toDouble() ?? 0.0;
    const grades = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'D', 'E'];

    int maxCount = 0;
    for (final g in grades) {
      final c = counts[g] ?? 0;
      if (c > maxCount) maxCount = c;
    }
    final maxY = maxCount > 0 ? (maxCount * 1.3).ceilToDouble() : 10.0;

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < grades.length; i++) {
      final g = grades[i];
      final c = (counts[g] ?? 0).toDouble();
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: c,
              color: const Color(0xFF2563EB),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Evaluation Grade Distribution', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('CBSE 9-Point Performance Scale', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$total Evaluated (${avg.toStringAsFixed(0)}% Avg)',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: total == 0
                ? const Center(child: Text('No examination evaluation records available', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))))
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, m) {
                              if (v == 0 || v == (maxY / 2).round() || v == maxY) {
                                return Text('${v.toInt()}', style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            getTitlesWidget: (v, m) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < grades.length) {
                                return Text(grades[idx], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: barGroups,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('A1 (Top 1/8th) to E2 (Essential Repeat)', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              InkWell(
                onTap: () => context.push('/school/reports'),
                child: const Row(
                  children: [
                    Text('Gradebook (T-R04)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 11, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Subject-Wise Performance Benchmarks Chart (T-R05)
  Widget _buildSubjectAveragesChartCard() {
    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < _subjectAverages.length; i++) {
      final sa = _subjectAverages[i];
      final avg = (sa['average'] as num?)?.toDouble() ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: avg,
              color: const Color(0xFF0D9488),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject Performance Averages', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('Comparative Cohort Benchmark', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDFA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_subjectAverages.length} Subjects',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: _subjectAverages.isEmpty
                ? const Center(child: Text('No subject benchmarks available', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))))
                : BarChart(
                    BarChartData(
                      maxY: 100,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              if (v == 0 || v == 50 || v == 100) {
                                return Text('${v.toInt()}%', style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 18,
                            getTitlesWidget: (v, m) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < _subjectAverages.length) {
                                final sub = _subjectAverages[idx]['subject']?.toString() ?? '';
                                final shortName = sub.length > 5 ? sub.substring(0, 4) : sub;
                                return Text(shortName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)));
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: barGroups,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Marks mean across all class cohorts', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              InkWell(
                onTap: () => context.push('/school/reports'),
                child: const Row(
                  children: [
                    Text('Subject Comparison (T-R05)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 11, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Homework Completion Distribution Donut Chart (T-R07)
  Widget _buildHomeworkDonutChartCard() {
    final sub = (_homeworkStats['submitted'] as num?)?.toInt() ?? 0;
    final late = (_homeworkStats['late'] as num?)?.toInt() ?? 0;
    final missing = (_homeworkStats['missing'] as num?)?.toInt() ?? 0;
    final rate = (_homeworkStats['completion_rate'] as num?)?.toDouble() ?? 0.0;
    final total = sub + late + missing;

    final sections = <PieChartSectionData>[];
    if (total == 0) {
      sections.add(PieChartSectionData(value: 1, color: const Color(0xFFE2E8F0), title: '', radius: 24));
    } else {
      if (sub > 0) {
        sections.add(PieChartSectionData(value: sub.toDouble(), color: const Color(0xFF10B981), title: '$sub', radius: 24, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)));
      }
      if (late > 0) {
        sections.add(PieChartSectionData(value: late.toDouble(), color: const Color(0xFFF59E0B), title: '$late', radius: 24, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)));
      }
      if (missing > 0) {
        sections.add(PieChartSectionData(value: missing.toDouble(), color: const Color(0xFFEF4444), title: '$missing', radius: 24, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)));
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Homework Completion Velocity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  Text('Submission & Grading Distribution', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: rate >= 70 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${rate.toStringAsFixed(0)}% Submitted',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: rate >= 70 ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 36,
                    sectionsSpace: 2,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const Text('Completed', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegendDot(const Color(0xFF10B981), 'Done ($sub)'),
              const SizedBox(width: 12),
              _buildChartLegendDot(const Color(0xFFF59E0B), 'Late ($late)'),
              const SizedBox(width: 12),
              _buildChartLegendDot(const Color(0xFFEF4444), 'Missing ($missing)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // 3. MY STUDENTS ROSTER & 360 PROFILE (N1 + M12)
  // ──────────────────────────────────────────────
  Widget _buildMyStudentsSection() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _students.where((s) {
      if (query.isEmpty) return true;
      final name = (s['name'] ?? s['student_name'] ?? '').toString().toLowerCase();
      final roll = (s['roll_number'] ?? s['roll_no'] ?? '').toString().toLowerCase();
      final adm = (s['admission_no'] ?? s['id'] ?? '').toString().toLowerCase();
      return name.contains(query) || roll.contains(query) || adm.contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Title, Count & Excel Export
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'My Students Roster',
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${filtered.length} Enrolled',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Assigned classes, daily attendance rates & holistic student 360° cards',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _students.isEmpty
                    ? null
                    : () {
                        final currentClassLabel = _selectedClassFilter == 'all'
                            ? 'All Assigned Classes'
                            : (_assignedClasses.firstWhere(
                                (c) => c['class_id'] == _selectedClassFilter || c['id'] == _selectedClassFilter,
                                orElse: () => {'name': _selectedClassFilter},
                              )['name']?.toString() ?? _selectedClassFilter);
                        SchoolExportService.exportClassRosterExcel(
                          context: context,
                          className: currentClassLabel,
                          teacherName: _teacherName,
                          students: filtered,
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Excel Roster', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search Box (M12)
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search student by name, roll number, or admission ID...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Class Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('All Classes (${_students.length})'),
                  selected: _selectedClassFilter == 'all',
                  onSelected: (sel) {
                    if (sel && _selectedClassFilter != 'all') {
                      setState(() => _selectedClassFilter = 'all');
                      _loadStudents();
                    }
                  },
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _selectedClassFilter == 'all' ? Colors.white : const Color(0xFF475569),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide.none,
                ),
                const SizedBox(width: 8),
                ..._assignedClasses.map((c) {
                  final cid = c['class_id']?.toString() ?? c['id']?.toString() ?? '';
                  final cname = c['name']?.toString() ?? 'Class';
                  final role = c['role']?.toString() ?? '';
                  final isSelected = _selectedClassFilter == cid;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$cname ($role)'),
                      selected: isSelected,
                      onSelected: (sel) {
                        if (sel && _selectedClassFilter != cid) {
                          setState(() => _selectedClassFilter = cid);
                          _loadStudents();
                        }
                      },
                      selectedColor: const Color(0xFF0F172A),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Students Roster Grid / List (4-State Lifecycle)
          if (_isStudentsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB))),
                    SizedBox(height: 12),
                    Text('Loading cohort roster & attendance...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else if (_assignedClasses.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No assigned teaching cohorts found for this account.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No students matching "$_searchQuery" in your assigned classes.'
                          : 'No enrolled students found in this cohort.',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 900;
                final isMedium = constraints.maxWidth > 580;
                final crossCount = isWide ? 3 : (isMedium ? 2 : 1);

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: isWide ? 2.3 : (isMedium ? 2.1 : 2.5),
                  ),
                  itemBuilder: (ctx, idx) {
                    final s = filtered[idx];
                    return _buildStudentCard(s);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> s) {
    final name = (s['name'] ?? s['student_name'] ?? 'Student').toString();
    final roll = (s['roll_number'] ?? s['roll_no'] ?? '-').toString();
    final adm = (s['admission_no'] ?? s['id'] ?? '-').toString();
    final className = (s['class_name'] ?? s['class_id'] ?? 'Class').toString();
    final attPct = (s['attendance_pct'] as num?)?.toDouble() ?? 0.0;
    final isAtRisk = attPct > 0 && attPct < 75.0;

    // Generate Initials
    final nameParts = name.trim().split(RegExp(r'\s+'));
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : 'ST');

    return InkWell(
      onTap: () => _showStudent360Modal(context, s),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAtRisk ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Initials Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: isAtRisk ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isAtRisk ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name & Demographics
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Roll: $roll • $adm',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      className,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Attendance Pill & Drill-Down
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: attPct <= 0
                        ? const Color(0xFFF1F5F9)
                        : (isAtRisk ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5)),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: attPct <= 0
                          ? const Color(0xFFCBD5E1)
                          : (isAtRisk ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0)),
                    ),
                  ),
                  child: Text(
                    attPct <= 0
                        ? 'Att. --'
                        : '${attPct.toStringAsFixed(0)}% Att',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: attPct <= 0
                          ? const Color(0xFF64748B)
                          : (isAtRisk ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '360° View',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_rounded, size: 10, color: Color(0xFF2563EB)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 4. STUDENT 360° PROFILE MODAL (N1)
  // ──────────────────────────────────────────────
  void _showStudent360Modal(BuildContext context, Map<String, dynamic> student) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
            child: _Student360ProfileSheet(
              student: student,
              schoolService: _schoolService,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.9,
          child: _Student360ProfileSheet(
            student: student,
            schoolService: _schoolService,
          ),
        ),
      );
    }
  }

  // ──────────────────────────────────────────────
  // 5. ACADEMICS & EXAMINATION MASTER
  // ──────────────────────────────────────────────
  Widget _buildAcademicsAndMarksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.grade_outlined, size: 18, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            const Text(
              'Examination & Marks Master',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/school/report-card'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('All Cards', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'Enter / Edit Marks',
                subtitle: 'Subject marks, CBSE grades & narrative remarks',
                icon: Icons.edit_note_rounded,
                accentColor: const Color(0xFF2563EB),
                tag: 'Primary',
                onTap: () => context.push('/school/marks-entry'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Bulk CSV Upload',
                subtitle: 'Import class marks from spreadsheet files',
                icon: Icons.upload_file_rounded,
                accentColor: const Color(0xFF0D9488),
                tag: 'Excel/CSV',
                onTap: () => context.push('/school/marks/csv'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Report Cards & HPC',
                subtitle: 'Preview, print & export PDF cards with CBSE seal',
                icon: Icons.description_outlined,
                accentColor: const Color(0xFFD97706),
                tag: 'CBSE Report',
                onTap: () => context.push('/school/report-card'),
              ),
            ),
          ],
        ),
        if (_syllabusVelocity.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildLessonPlanVelocityCard(),
        ],
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String tag,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 6. DAILY OPERATIONS & PASTORAL
  // ──────────────────────────────────────────────
  Widget _buildDailyOperationsSection() {
    final operations = [
      {
        'title': 'Daily Attendance',
        'subtitle': 'Mark register & CBSE audit',
        'icon': Icons.how_to_reg_rounded,
        'color': const Color(0xFF10B981),
        'route': '/school/attendance',
      },
      {
        'title': 'Lesson Plan & 5E Studio',
        'subtitle': "5E constructivist plans & Bloom's levels",
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF4338CA),
        'route': '/school/lesson-plans',
      },
      {
        'title': 'Homework & Tasks',
        'subtitle': 'Assign exercises & view submissions',
        'icon': Icons.assignment_add,
        'color': const Color(0xFF8B5CF6),
        'route': '/school/homework',
      },
      {
        'title': 'Leave Requests',
        'subtitle': 'Review student absence applications',
        'icon': Icons.event_busy_rounded,
        'color': const Color(0xFFEF4444),
        'route': '/school/leave',
      },
      {
        'title': 'Class Timetable',
        'subtitle': 'Schedule, rooms & lesson tracking',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFF59E0B),
        'route': '/school/timetable',
      },
      {
        'title': 'Official Circulars',
        'subtitle': 'School events & exam notifications',
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF0284C7),
        'route': '/school/circulars',
      },
      {
        'title': 'Message Parents (N4)',
        'subtitle': 'Broadcast class announcements',
        'icon': Icons.chat_bubble_outline_rounded,
        'color': const Color(0xFF2563EB),
        'action': () => _showMessageParentsDialog(),
      },
      {
        'title': 'My Leave Desk (N6)',
        'subtitle': 'Apply & review faculty leave',
        'icon': Icons.time_to_leave_rounded,
        'color': const Color(0xFFEA580C),
        'action': () => _showMyLeaveModal(),
      },
      {
        'title': 'PTM Meetings (N10)',
        'subtitle': 'Scheduled parent conference slots',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF7C3AED),
        'action': () => _showPtmSlotsModal(),
      },
      {
        'title': 'Library Books',
        'subtitle': 'Resource search & issued titles',
        'icon': Icons.local_library_rounded,
        'color': const Color(0xFF6366F1),
        'route': '/school/library',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text(
              'Daily Operations & Classroom Tools',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: operations.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
          ),
          itemBuilder: (ctx, i) {
            final op = operations[i];
            final color = op['color'] as Color;
            return InkWell(
              onTap: () {
                final action = op['action'] as VoidCallback?;
                if (action != null) {
                  action();
                } else if (op['route'] != null) {
                  context.push(op['route'] as String);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(op['icon'] as IconData, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            op['title'] as String,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            op['subtitle'] as String,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // 7. TODAY'S TEACHING SCHEDULE
  // ──────────────────────────────────────────────
  Widget _buildTodayScheduleSection() {
    final isWeekly = _scheduleViewMode == 'weekly';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                Text(
                  isWeekly ? 'Weekly Teaching Workload (N11)' : "Today's Teaching Schedule",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            Row(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('Today', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    ButtonSegment(value: 'weekly', label: Text('Week Load', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                  ],
                  selected: {_scheduleViewMode},
                  onSelectionChanged: (val) {
                    setState(() => _scheduleViewMode = val.first);
                  },
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                if (isWeekly) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Export Workload Excel (T-R12)',
                    icon: const Icon(Icons.file_download_outlined, color: Color(0xFF107C41), size: 20),
                    onPressed: () async {
                      if (_weeklyWorkload != null) {
                        await SchoolExportService.exportWeeklyWorkloadExcel(
                          context: context,
                          teacherName: _teacherName,
                          workload: _weeklyWorkload!,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isWeekly) ...[
          _buildWeeklyWorkloadCards(),
        ] else ...[
          if (_todaySchedule.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No lectures scheduled for today. Enjoy your preparation time!', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ),
            )
          else ...[
            ..._todaySchedule.map((s) => _buildScheduleItem(s)),
          ],
        ],
      ],
    );
  }

  Widget _buildWeeklyWorkloadCards() {
    if (_weeklyWorkload == null) return const SizedBox.shrink();
    final days = (_weeklyWorkload!['days'] as List?) ?? [];
    final total = _weeklyWorkload!['total_lectures'] ?? 0;
    final util = (_weeklyWorkload!['utilization_rate'] as num?)?.toDouble() ?? 0.0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('$total', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Text('Total Weekly Periods', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
              Column(
                children: [
                  const Text('48', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const Text('School Capacity (8x6)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
              Column(
                children: [
                  Text('${util.toStringAsFixed(1)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: util > 85 ? const Color(0xFFDC2626) : const Color(0xFF2563EB))),
                  const Text('Utilization Rate', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (ctx, i) {
            final d = days[i];
            final dayName = d['day']?.toString() ?? '';
            final lecs = d['lectures'] ?? 0;
            final free = d['free_periods'] ?? 0;
            final isOver = (d['is_overloaded'] as bool?) ?? false;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isOver ? const Color(0xFFFEF2F2) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isOver ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  const SizedBox(height: 2),
                  Text('$lecs Lectures • $free Free', style: TextStyle(fontSize: 11, color: isOver ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> item) {
    final subject = item['subject']?.toString() ?? 'Subject';
    final className = (item['class'] ?? item['class_name'] ?? item['class_id'] ?? 'Class').toString();
    final room = item['room']?.toString().trim();
    final time = (item['time'] ?? (item['start_time'] != null && item['end_time'] != null ? '${item['start_time']} - ${item['end_time']}' : (item['start_time']?.toString() ?? 'Scheduled'))).toString();
    final period = item['period']?.toString() ?? 'Period';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.menu_book_rounded, color: Color(0xFF2563EB), size: 20),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        period,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  room != null && room.isNotEmpty ? '$className • Room $room' : className,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              time,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 8),

          () {
            final cId = item['class_id']?.toString() ?? item['class']?.toString() ?? '';
            final isMarked = _attendanceMarkedClassesToday.contains(cId) || _attendanceMarkedClassesToday.contains(className);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isMarked ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isMarked ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    isMarked ? '✓ Marked' : 'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isMarked ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Take Attendance for $className ($period)',
                  icon: Icon(Icons.how_to_reg_rounded, size: 20, color: isMarked ? const Color(0xFF10B981) : const Color(0xFFD97706)),
                  onPressed: () {
                    context.push('/school/attendance?classId=$cId&period=$period');
                  },
                ),
              ],
            );
          }(),
        ],
      ),
    );
  }


  // ──────────────────────────────────────────────
  // T6.1: LESSON PLAN SYLLABUS VELOCITY CARD (M5)
  // ──────────────────────────────────────────────
  Widget _buildLessonPlanVelocityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, size: 16, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Curriculum Pacing & Syllabus Velocity',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await SchoolExportService.exportLessonPlanVelocityExcel(
                    context: context,
                    teacherName: _teacherName,
                    velocityList: _syllabusVelocity,
                  );
                },
                icon: const Icon(Icons.file_download_outlined, size: 13),
                label: const Text('Export Excel (T-R09)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF107C41),
                  side: const BorderSide(color: Color(0xFFA7F3D0)),
                  backgroundColor: const Color(0xFFECFDF5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'CBSE curriculum coverage tracking across assigned cohorts and syllabus units.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ..._syllabusVelocity.map((v) {
            final cName = v['class_name']?.toString() ?? 'Class';
            final total = v['total_plans'] ?? 0;
            final taught = v['taught_count'] ?? 0;
            final inProg = v['in_progress'] ?? 0;
            final lagging = v['lagging_count'] ?? 0;
            final rate = (v['completion_rate'] as num?)?.toDouble() ?? 0.0;
            final isLagging = lagging > 0 || (rate < 60 && total > 0);

            return InkWell(
              onTap: () => context.push('/school/lesson-plans'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$cName (${v['role'] ?? 'Faculty'})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLagging ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLagging ? 'LAGGING ALERT' : 'ON SCHEDULE',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isLagging ? const Color(0xFFDC2626) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (rate / 100).clamp(0.0, 1.0),
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(isLagging ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$taught of $total units taught • $inProg in progress${lagging > 0 ? " • $lagging need revision" : ""}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T6.2: PENDING STUDENT LEAVES QUEUE (M9)
  // ──────────────────────────────────────────────
  Widget _buildPendingStudentLeavesQueue() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_busy_rounded, size: 16, color: Color(0xFFEA580C)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Student Leave Approvals Needed (${_pendingStudentLeaves.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/school/leave'),
                child: const Text('Leave Desk', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._pendingStudentLeaves.take(3).map((l) {
            final sName = l['student_name']?.toString() ?? 'Student';
            final cName = l['class_name']?.toString() ?? 'Class';
            final reason = l['reason']?.toString() ?? 'Absence reason';
            final from = l['start_date'] ?? l['from_date'] ?? '';
            final to = l['end_date'] ?? l['to_date'] ?? '';
            final lid = l['id']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$sName ($cName)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('$from to $to • Reason: $reason', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          final ok = await _schoolService.approveStudentLeave(
                            leaveId: lid,
                            approvedBy: _teacherName,
                            remarks: 'Approved by Class Teacher',
                          );
                          if (ok && mounted) {
                            setState(() => _pendingStudentLeaves.removeWhere((x) => x['id']?.toString() == lid));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave approved.')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await _schoolService.rejectStudentLeave(
                            leaveId: lid,
                            rejectedBy: _teacherName,
                            remarks: 'Rejected by Class Teacher',
                          );
                          if (ok && mounted) {
                            setState(() => _pendingStudentLeaves.removeWhere((x) => x['id']?.toString() == lid));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave rejected.')));
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.1: FACULTY INBOX & NOTIFICATIONS (N14)
  // ──────────────────────────────────────────────
  void _showInboxModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inbox_rounded, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Text('Faculty Notifications & Inbox', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final n in _notifications) {
                        n['is_read'] = true;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Mark all read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_notifications.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No unread alerts or notifications.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final n = _notifications[i];
                    final type = n['type']?.toString() ?? 'Notice';
                    final isRead = (n['is_read'] as bool?) ?? false;

                    Color badgeColor = const Color(0xFF2563EB);
                    IconData icon = Icons.notifications_outlined;
                    if (type == 'Substitution') {
                      badgeColor = const Color(0xFFD97706);
                      icon = Icons.swap_calls_rounded;
                    } else if (type == 'Grading') {
                      badgeColor = const Color(0xFF9333EA);
                      icon = Icons.assignment_late_rounded;
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: badgeColor.withValues(alpha: 0.1),
                        child: Icon(icon, color: badgeColor, size: 18),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              n['title']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        n['body']?.toString() ?? '',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      onTap: () {
                        setState(() => n['is_read'] = true);
                        Navigator.pop(ctx);
                        if (type == 'Substitution') {
                          context.push('/school/timetable');
                        } else if (type == 'Grading') {
                          context.push('/school/homework');
                        } else {
                          context.push('/school/circulars');
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.2: UPCOMING EXAM COUNTDOWN BANNER (N9)
  // ──────────────────────────────────────────────
  Widget _buildUpcomingExamBanner() {
    if (_upcomingExam == null) return const SizedBox.shrink();
    final name = _upcomingExam!['name'] ?? _upcomingExam!['subject'] ?? 'Upcoming Examination';
    final date = _upcomingExam!['exam_date']?.toString() ?? '';
    final days = _upcomingExam!['days_remaining'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.timer_outlined, color: Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$name',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        days == 0 ? 'TODAY' : 'IN $days DAYS',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Scheduled on $date • CBSE Term Assessment Cycle',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => context.push('/school/examination'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF475569)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Datesheet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.3: HOMEWORK GRADING QUEUE (N12)
  // ──────────────────────────────────────────────
  Widget _buildHomeworkGradingQueueSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.pending_actions_rounded, size: 16, color: Color(0xFF9333EA)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Homework Grading Queue (${_gradingQueue.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/school/homework'),
                child: const Text('View All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._gradingQueue.take(3).map((hw) {
            final title = hw['title']?.toString() ?? 'Homework';
            final cName = hw['class_grade'] ?? hw['class_name'] ?? 'Cohort';
            final count = hw['pending_review_count'] ?? 0;
            final isOverdue = (hw['is_overdue'] as bool?) ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isOverdue ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('Class $cName • Due: ${hw['due_date'] ?? 'Upcoming'}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverdue ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count Pending Review',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isOverdue ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => context.push('/school/homework'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('Grade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.4: ATTENTION NEEDED / AT-RISK SIGNALS (N8)
  // ──────────────────────────────────────────────
  Widget _buildAttentionNeededSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Attention Needed & Early Warning (${_atRiskStudents.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final rows = _atRiskStudents.map((s) => {
                    'name': s['name'] ?? 'Student',
                    'roll_number': s['roll_number'] ?? '-',
                    'class': s['class_name'] ?? 'Class',
                    'attendance_pct': s['attendance_pct'] ?? 0.0,
                    'risk_reasons': (s['reasons'] as List?)?.join(', ') ?? 'At-risk',
                  }).toList();
                  await SchoolExportService.exportDefaultersExcel(
                    context: context,
                    className: 'All Assigned Cohorts',
                    teacherName: _teacherName,
                    defaulters: rows,
                  );
                },
                icon: const Icon(Icons.file_download_outlined, size: 13),
                label: const Text('Export Excel (T-R03)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  backgroundColor: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Rule-based triggers: CBSE attendance <75%, failing score (<35%), or 2+ missing homeworks.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ..._atRiskStudents.take(4).map((s) {
            final name = s['name']?.toString() ?? 'Student';
            final cName = s['class_name']?.toString() ?? 'Class';
            final reasons = (s['reasons'] as List?) ?? [];
            final riskLevel = s['risk_level']?.toString() ?? 'Moderate';
            final isHigh = riskLevel == 'High';

            return InkWell(
              onTap: () => _showStudent360Modal(context, s),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHigh ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isHigh ? const Color(0xFFFECDD3) : const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isHigh ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                      child: Text(
                        name.isNotEmpty ? name[0] : 'S',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A))),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                child: Text(cName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            reasons.join(' • '),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isHigh ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.5: SUBSTITUTION DESK CARD (N5)
  // ──────────────────────────────────────────────
  Widget _buildSubstitutionDeskCard() {
    if (_substitutionsToday.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_calls_rounded, color: Color(0xFFD97706), size: 18),
              const SizedBox(width: 8),
              Text(
                "Today's Substitution Duty (${_substitutionsToday.length})",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 13.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                child: const Text('ASSIGNED DUTY', style: TextStyle(color: Color(0xFFB45309), fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._substitutionsToday.map((sub) => Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Period ${sub['period']} • Class ${sub['class_id']} • Room ${sub['room'] ?? 'Lab'} • Covering for ${sub['original_teacher']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Substitution duty acknowledged.')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: const Text('Acknowledge', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.6: MESSAGE CLASS PARENTS DIALOG (N4)
  // ──────────────────────────────────────────────
  void _showMessageParentsDialog() {
    if (_assignedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned classes found.')),
      );
      return;
    }

    String selectedClassId = _assignedClasses.first['class_id']?.toString() ?? _assignedClasses.first['id']?.toString() ?? '';
    String selectedClassName = _assignedClasses.first['name']?.toString() ?? 'Class';
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String priority = 'Normal';
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Broadcast Notice to Class Parents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Target Cohort', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedClassId,
                items: _assignedClasses.map((c) {
                  final cid = c['class_id']?.toString() ?? c['id']?.toString() ?? '';
                  final cname = c['name']?.toString() ?? 'Class';
                  return DropdownMenuItem(value: cid, child: Text(cname, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    final matched = _assignedClasses.firstWhere((c) => (c['class_id']?.toString() ?? c['id']?.toString()) == v, orElse: () => {});
                    setDlgState(() {
                      selectedClassId = v;
                      selectedClassName = matched['name']?.toString() ?? 'Class';
                    });
                  }
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Notice Subject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Science Test on Friday / Field Trip Consent',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text('Message Body', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write the announcement details clearly for parents...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty || bodyCtrl.text.trim().isEmpty) return;
                      setDlgState(() => isSending = true);
                      final ok = await _schoolService.sendClassAnnouncement(
                        teacherUsername: _teacherUsername,
                        teacherName: _teacherName,
                        classId: selectedClassId,
                        className: selectedClassName,
                        title: titleCtrl.text.trim(),
                        message: bodyCtrl.text.trim(),
                        priority: priority,
                      );
                      if (context.mounted) {
                        Navigator.pop(dlgCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ok ? 'Notice broadcasted to parents.' : 'Failed to broadcast.')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: const Text('Send Notice'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.7: MY LEAVE DESK MODAL (N6)
  // ──────────────────────────────────────────────
  void _showMyLeaveModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Faculty Leave Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ElevatedButton.icon(
                    onPressed: () => _openApplyLeaveDialog(context, () async {
                      final updated = await _schoolService.getTeacherLeaves(_teacherUsername);
                      setSheetState(() => _teacherLeaves = updated);
                    }),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Apply Leave', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_teacherLeaves.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No leave applications recorded for this academic session.', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _teacherLeaves.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final l = _teacherLeaves[i];
                      final st = (l['status']?.toString() ?? 'Pending').toLowerCase();
                      Color c = const Color(0xFFF59E0B);
                      if (st == 'approved') c = const Color(0xFF10B981);
                      if (st == 'rejected') c = const Color(0xFFEF4444);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text('${l['type']} Leave', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${l['start_date']} to ${l['end_date']} • Reason: ${l['reason']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(st.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
                        ),
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

  void _openApplyLeaveDialog(BuildContext context, VoidCallback onApplied) {
    String leaveType = 'Casual Leave';
    final reasonCtrl = TextEditingController();
    DateTime start = DateTime.now().add(const Duration(days: 1));
    DateTime end = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Apply Faculty Leave', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: leaveType,
                items: const [
                  DropdownMenuItem(value: 'Casual Leave', child: Text('Casual Leave')),
                  DropdownMenuItem(value: 'Medical Leave', child: Text('Medical Leave')),
                  DropdownMenuItem(value: 'Duty Leave', child: Text('Duty Leave')),
                  DropdownMenuItem(value: 'Earned Leave', child: Text('Earned Leave')),
                ],
                onChanged: (v) {
                  if (v != null) setDlgState(() => leaveType = v);
                },
                decoration: InputDecoration(
                  labelText: 'Leave Type',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason for absence',
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
                final endStr = '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
                await _schoolService.applyTeacherLeave(
                  teacherUsername: _teacherUsername,
                  teacherName: _teacherName,
                  leaveType: leaveType,
                  startDate: startStr,
                  endDate: endStr,
                  reason: reasonCtrl.text.trim().isEmpty ? 'Personal reasons' : reasonCtrl.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(dlgCtx);
                  onApplied();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave application filed.')));
                }
              },
              child: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // T5.8: PTM SLOTS MODAL (N10)
  // ──────────────────────────────────────────────
  void _showPtmSlotsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('Parent-Teacher Meeting (PTM) Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text('Review scheduled parent conferences and update completion status.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
              const Divider(height: 20),
              if (_ptmBookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No parent meeting appointments booked currently.', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _ptmBookings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final b = _ptmBookings[i];
                      final st = b['status']?.toString() ?? 'Confirmed';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFEFF6FF),
                          child: Icon(Icons.people_alt_outlined, color: Color(0xFF2563EB), size: 18),
                        ),
                        title: Text('Student: ${b['student']} (Parent: ${b['parent']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('Date: ${b['date']} • Time: ${b['time_slot']}\nAgenda: ${b['agenda']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final newStatus = st == 'Completed' ? 'Confirmed' : 'Completed';
                            await _schoolService.updatePtmBookingStatus(b['id'], newStatus);
                            setSheetState(() => b['status'] = newStatus);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: st == 'Completed' ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          ),
                          child: Text(st == 'Completed' ? 'Done' : 'Mark Done', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        ),
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

  // ──────────────────────────────────────────────
  // 8. MINIMALIST DRAWER (M11 Parity)
  // ──────────────────────────────────────────────
  void _showAbsenteesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person_off_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Absentees Today (${_todayAbsentees.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_teacherClass • Today',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              ..._todayAbsentees.map((a) {
                final name = a['student_name']?.toString() ?? a['name']?.toString() ?? 'Student';
                final roll = a['roll_no']?.toString() ?? a['roll_number']?.toString() ?? '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFFFEE2E2),
                        child: Icon(Icons.person, size: 14, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$name ${roll.isNotEmpty ? "(Roll: $roll)" : ""}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const Text(
                        'Absent',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/school/attendance');
            },
            child: const Text('Open Register'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Icon(Icons.school_rounded, color: Color(0xFF0F172A), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _teacherName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          _teacherClass,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _buildDrawerTile(Icons.dashboard_rounded, 'Dashboard', () => Navigator.pop(context)),
                  _buildDrawerTile(Icons.people_alt_rounded, 'My Students Roster', () {
                    Navigator.pop(context);
                    _loadStudents();
                  }),
                  _buildDrawerTile(Icons.auto_awesome_rounded, 'AI Studio & Question Paper Generator (SP11)', () {
                    Navigator.pop(context);
                    context.push('/school/ai-tools');
                  }),
                  _buildDrawerTile(Icons.analytics_rounded, 'My Reports & Analytics', () {
                    Navigator.pop(context);
                    context.push('/school/reports');
                  }),
                  _buildDrawerTile(Icons.menu_book_rounded, 'Lesson Plans & 5E Studio', () {
                    Navigator.pop(context);
                    context.push('/school/lesson-plans');
                  }),
                  _buildDrawerTile(Icons.edit_note_rounded, 'Enter & Upload Marks', () {
                    Navigator.pop(context);
                    context.push('/school/marks-entry');
                  }),
                  _buildDrawerTile(Icons.upload_file_rounded, 'Bulk CSV Marks Upload', () {
                    Navigator.pop(context);
                    context.push('/school/marks/csv');
                  }),
                  _buildDrawerTile(Icons.description_outlined, 'Report Cards & HPC', () {
                    Navigator.pop(context);
                    context.push('/school/report-card');
                  }),
                  _buildDrawerTile(Icons.fact_check_outlined, 'Exam Sessions & Date Sheet', () {
                    Navigator.pop(context);
                    context.push('/school/examination');
                  }),
                  _buildDrawerTile(Icons.how_to_reg_rounded, 'Daily Attendance', () {
                    Navigator.pop(context);
                    context.push('/school/attendance');
                  }),
                  _buildDrawerTile(Icons.assignment_outlined, 'Homework & Tasks', () {
                    Navigator.pop(context);
                    context.push('/school/homework');
                  }),
                  _buildDrawerTile(Icons.event_busy_rounded, 'Leave Approvals', () {
                    Navigator.pop(context);
                    context.push('/school/leave');
                  }),
                  _buildDrawerTile(Icons.calendar_month_rounded, 'Class Timetable', () {
                    Navigator.pop(context);
                    context.push('/school/timetable');
                  }),
                  _buildDrawerTile(Icons.campaign_outlined, 'Official Circulars', () {
                    Navigator.pop(context);
                    context.push('/school/circulars');
                  }),
                  _buildDrawerTile(Icons.chat_bubble_outline_rounded, 'Message Class Parents (N4)', () {
                    Navigator.pop(context);
                    _showMessageParentsDialog();
                  }),
                  _buildDrawerTile(Icons.time_to_leave_rounded, 'Faculty Leave Desk (N6)', () {
                    Navigator.pop(context);
                    _showMyLeaveModal();
                  }),
                  _buildDrawerTile(Icons.groups_rounded, 'PTM Meeting Slots (N10)', () {
                    Navigator.pop(context);
                    _showPtmSlotsModal();
                  }),
                  _buildDrawerTile(Icons.inbox_rounded, 'Faculty Notifications & Inbox (N14)', () {
                    Navigator.pop(context);
                    _showInboxModal();
                  }),
                  _buildDrawerTile(Icons.local_library_outlined, 'School Library', () {
                    Navigator.pop(context);
                    context.push('/school/library');
                  }),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                onTap: () async {
                  await _authService.logout();
                  if (context.mounted) context.go('/login');
                },
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: const Color(0xFF475569)),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
      dense: true,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT 360° HOLISTIC PROFILE SHEET COMPONENT (N1)
// ─────────────────────────────────────────────────────────────────────────────
class _Student360ProfileSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final SchoolService schoolService;

  const _Student360ProfileSheet({
    required this.student,
    required this.schoolService,
  });

  @override
  State<_Student360ProfileSheet> createState() => _Student360ProfileSheetState();
}

class _Student360ProfileSheetState extends State<_Student360ProfileSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _behaviourNotes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final sId = widget.student['id']?.toString() ?? widget.student['username']?.toString() ?? '';
      final cId = widget.student['class_id']?.toString() ?? '';
      final res = await widget.schoolService.getStudent360Profile(studentId: sId, classId: cId);
      final notes = await widget.schoolService.getStudentBehaviourNotes(sId);
      if (mounted) {
        setState(() {
          _profile = res;
          _behaviourNotes = notes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Could not load student 360 profile. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.student['name'] ?? widget.student['student_name'] ?? 'Student').toString();
    final roll = (widget.student['roll_number'] ?? widget.student['roll_no'] ?? '-').toString();
    final adm = (widget.student['admission_no'] ?? widget.student['id'] ?? '-').toString();
    final cls = (widget.student['class_name'] ?? widget.student['class_id'] ?? 'Class').toString();

    return Column(
      children: [
        // Top Header Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEFF6FF),
                child: const Icon(Icons.person_outline_rounded, color: Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cls,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roll No: $roll • Admission ID: $adm',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // 5-Tab Bar
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0)),
              bottom: BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2.5,
            tabs: const [
              Tab(icon: Icon(Icons.badge_outlined, size: 16), text: 'Overview'),
              Tab(icon: Icon(Icons.how_to_reg_outlined, size: 16), text: 'Attendance'),
              Tab(icon: Icon(Icons.school_outlined, size: 16), text: 'Marks & CBSE'),
              Tab(icon: Icon(Icons.assignment_outlined, size: 16), text: 'Homework'),
              Tab(icon: Icon(Icons.event_busy_outlined, size: 16), text: 'Leaves'),
              Tab(icon: Icon(Icons.psychology_outlined, size: 16), text: 'Behaviour (N7)'),
            ],
          ),
        ),

        // Tab View Body
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
                          const SizedBox(height: 8),
                          Text(_errorMessage!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadProfileData, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildAttendanceTab(),
                        _buildMarksTab(),
                        _buildHomeworkTab(),
                        _buildLeavesTab(),
                        _buildBehaviourNotesTab(),
                      ],
                    ),
        ),
      ],
    );
  }

  // 1. Overview Tab
  Widget _buildOverviewTab() {
    final attPct = (_profile?['attendance_pct'] as num?)?.toDouble() ?? 0.0;
    final marksPct = (_profile?['overall_percentage'] as num?)?.toDouble() ?? 0.0;
    final cbseGrade = _profile?['cbse_grade']?.toString() ?? 'N/A';
    final hwDone = _profile?['homework_submitted'] ?? 0;
    final hwTotal = _profile?['homework_assigned'] ?? 0;
    final leavesCount = (_profile?['leaves'] as List?)?.length ?? 0;
    final isAtRisk = attPct > 0 && attPct < 75.0;

    final std = _profile?['student'] as Map<String, dynamic>? ?? widget.student;
    final parent = std['parent_name']?.toString() ?? 'Parent / Guardian';
    final contact = std['contact']?.toString() ?? 'Not Recorded';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // 4 Fast KPI Tiles
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Attendance Rate',
                value: attPct > 0 ? '${attPct.toStringAsFixed(1)}%' : 'Not Recorded',
                subtitle: isAtRisk ? 'Below 75% CBSE limit' : 'Good Standing',
                color: isAtRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                icon: Icons.how_to_reg_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Scholastic Standing',
                value: marksPct > 0 ? '${marksPct.toStringAsFixed(1)}%' : 'No Marks',
                subtitle: 'CBSE Grade: $cbseGrade',
                color: const Color(0xFF2563EB),
                icon: Icons.school_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Homework Tasks',
                value: '$hwDone / $hwTotal',
                subtitle: 'Submitted on time',
                color: const Color(0xFF8B5CF6),
                icon: Icons.assignment_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Student Leaves',
                value: '$leavesCount Filed',
                subtitle: 'Academic Session',
                color: const Color(0xFFF59E0B),
                icon: Icons.event_busy_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Demographics Information Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Identity & Academic Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              _buildInfoRow('Full Name', std['name']?.toString() ?? '-'),
              _buildInfoRow('Admission Number', std['admission_no']?.toString() ?? std['id']?.toString() ?? '-'),
              _buildInfoRow('Roll Number', std['roll_number']?.toString() ?? '-'),
              _buildInfoRow('Enrolled Class', std['class_name']?.toString() ?? std['class_id']?.toString() ?? '-'),
              _buildInfoRow('Academic Session', '2026-2027 (CBSE Affiliated)'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Parent / Guardian Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Parent / Guardian Information', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              _buildInfoRow('Parent / Guardian Name', parent),
              _buildInfoRow('Emergency Contact Phone', contact),
              _buildInfoRow('Relationship', 'Father / Mother / Guardian'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
          Text(subtitle, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  // 2. Attendance Tab
  Widget _buildAttendanceTab() {
    final attPct = (_profile?['attendance_pct'] as num?)?.toDouble() ?? 0.0;
    final records = (_profile?['attendance_records'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Rate Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Overall Attendance Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${attPct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (attPct / 100).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(attPct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              const Text('CBSE Statutory Minimum Requirement: 75.0% for Examination Eligibility', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Recent Daily Register Entries (Last 45 Days)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        if (records.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(child: Text('No daily attendance entries recorded in this period.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5))),
          )
        else
          ...records.map((r) {
            final date = r['date']?.toString() ?? '-';
            final status = (r['status']?.toString() ?? 'present').toLowerCase();
            final markedBy = r['marked_by']?.toString() ?? 'Faculty';

            Color color = const Color(0xFF10B981);
            if (status == 'absent') color = const Color(0xFFEF4444);
            if (status == 'excused') color = const Color(0xFFF59E0B);
            if (status == 'late') color = const Color(0xFFF97316);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: color),
                      const SizedBox(width: 10),
                      Text(date, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                  Text('Marked by: $markedBy', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 3. Marks & CBSE Tab
  Widget _buildMarksTab() {
    final marks = (_profile?['marks'] as List?) ?? [];
    final overallPct = (_profile?['overall_percentage'] as num?)?.toDouble() ?? 0.0;
    final cbseGrade = _profile?['cbse_grade']?.toString() ?? 'N/A';
    final cbseRemarks = _profile?['cbse_remarks']?.toString() ?? 'No examination records';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // CBSE 9-Point Grade Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(cbseGrade, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CBSE 9-Point Scale: $cbseGrade', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
                    const SizedBox(height: 2),
                    Text(cbseRemarks, style: const TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6))),
                  ],
                ),
              ),
              Text(
                '${overallPct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Subject-Wise Examination Marks', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        if (marks.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(child: Text('No examination marks entered for this student yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5))),
          )
        else
          ...marks.map((m) {
            final subject = m['subject']?.toString() ?? 'Subject';
            final exam = m['exam_type']?.toString() ?? 'Term Exam';
            final obt = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
            final maxM = (m['total_marks'] as num?)?.toDouble() ?? 100.0;
            final pct = maxM > 0 ? (obt / maxM) * 100 : 0.0;
            final grade = m['grade']?.toString() ?? 'B1';
            final remark = m['remarks']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('$exam • Total Max: ${maxM.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        if (remark != null && remark.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Remark: $remark', style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${obt.toStringAsFixed(1)} / ${maxM.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$grade (${pct.toStringAsFixed(1)}%)',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 4. Homework Tab
  Widget _buildHomeworkTab() {
    final hwList = (_profile?['homework_list'] as List?) ?? [];
    final hwSubmitted = _profile?['homework_submitted'] ?? 0;
    final hwPending = _profile?['homework_pending'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Column(
                  children: [
                    Text('$hwSubmitted', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                    const Text('Completed / Submitted', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  children: [
                    Text('$hwPending', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFD97706))),
                    const Text('Pending Homework', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        const Text('Assigned Class Homework Tasks', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        if (hwList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(child: Text('No homework assignments found for this cohort.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5))),
          )
        else
          ...hwList.map((h) {
            final title = h['title']?.toString() ?? 'Exercise';
            final subject = h['subject']?.toString() ?? 'Subject';
            final dueDate = h['due_date']?.toString() ?? '-';
            final status = h['submission_status']?.toString() ?? 'pending';
            final isSubmitted = status == 'submitted' || status == 'completed';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    isSubmitted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                    color: isSubmitted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('$subject • Due: $dueDate', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSubmitted ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isSubmitted ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      isSubmitted ? 'SUBMITTED' : 'PENDING',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSubmitted ? const Color(0xFF059669) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 5. Leaves Tab
  Widget _buildLeavesTab() {
    final leaves = (_profile?['leaves'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Student Absence & Leave History', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 10),

        if (leaves.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(child: Text('No leave applications submitted by this student.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5))),
          )
        else
          ...leaves.map((l) {
            final reason = l['reason']?.toString() ?? 'Leave application';
            final status = (l['status']?.toString() ?? 'pending').toLowerCase();
            final from = l['start_date'] ?? l['from_date'] ?? '-';
            final to = l['end_date'] ?? l['to_date'] ?? '-';
            final type = l['leave_type']?.toString() ?? 'Medical';

            Color color = const Color(0xFFF59E0B);
            if (status == 'approved') color = const Color(0xFF10B981);
            if (status == 'rejected') color = const Color(0xFFEF4444);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$type Leave', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Dates: $from to $to', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('Reason: $reason', style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                ],
              ),
            );
          }),
      ],
    );
  }

  // 6. Behaviour & Pastoral Notes Tab (N7)
  Widget _buildBehaviourNotesTab() {
    final sId = widget.student['id']?.toString() ?? widget.student['username']?.toString() ?? '';
    final sName = (widget.student['name'] ?? widget.student['student_name'] ?? 'Student').toString();
    final cId = widget.student['class_id']?.toString() ?? '';

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pastoral Care & Behaviour Log',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            ElevatedButton.icon(
              onPressed: () => _openAddNoteDialog(context, sId, sName, cId),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Log Note', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_behaviourNotes.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No behavioural concerns or disciplinary incidents logged for this student. Exemplary record!',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ..._behaviourNotes.map((n) {
            final type = n['type']?.toString() ?? 'Observation';
            final note = n['note']?.toString() ?? '';
            final teacher = n['teacher']?.toString() ?? 'Faculty';
            final date = n['created_at']?.toString().split('T')[0] ?? '';

            Color color = const Color(0xFF2563EB);
            IconData icon = Icons.info_outline;
            if (type.contains('Commendation') || type.contains('Positive')) {
              color = const Color(0xFF10B981);
              icon = Icons.emoji_events_rounded;
            } else if (type.contains('Concern') || type.contains('Discipline')) {
              color = const Color(0xFFDC2626);
              icon = Icons.warning_amber_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(type, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: color)),
                            Text(date, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(note, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                        const SizedBox(height: 2),
                        Text('Recorded by: $teacher', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _openAddNoteDialog(BuildContext context, String studentId, String studentName, String classId) {
    String noteType = 'Commendation / Merit';
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Log Note • $studentName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: noteType,
                items: const [
                  DropdownMenuItem(value: 'Commendation / Merit', child: Text('Commendation / Merit')),
                  DropdownMenuItem(value: 'Concern / Discipline', child: Text('Concern / Discipline')),
                  DropdownMenuItem(value: 'Academic Observation', child: Text('Academic Observation')),
                ],
                onChanged: (v) {
                  if (v != null) setDlgState(() => noteType = v);
                },
                decoration: InputDecoration(
                  labelText: 'Note Category',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note description',
                  hintText: 'e.g. Excellent participation in science lab...',
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (noteCtrl.text.trim().isEmpty) return;
                await widget.schoolService.addStudentBehaviourNote(
                  studentId: studentId,
                  studentName: studentName,
                  classId: classId,
                  teacherUsername: 'teacher',
                  teacherName: 'Faculty',
                  type: noteType,
                  note: noteCtrl.text.trim(),
                );
                final updated = await widget.schoolService.getStudentBehaviourNotes(studentId);
                setState(() => _behaviourNotes = updated);
                if (context.mounted) {
                  Navigator.pop(dlgCtx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pastoral note recorded.')));
                }
              },
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }
}
