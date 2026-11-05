import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';
import '../../services/school_export_service.dart';

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

  // My Students Roster & Filter State (N1 + M12)
  List<Map<String, dynamic>> _assignedClasses = [];
  String _selectedClassFilter = 'all';
  List<Map<String, dynamic>> _students = [];
  bool _isStudentsLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
          _isLoading = false;
          _errorMessage = null;
        });
        _loadStudents();
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
                      const SizedBox(height: 16),
                      _buildKpiGrid(),
                      const SizedBox(height: 20),
                      _buildMyStudentsSection(),
                      const SizedBox(height: 20),
                      _buildAcademicsAndMarksSection(),
                      const SizedBox(height: 20),
                      _buildDailyOperationsSection(),
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
              onTap: () => context.push(op['route'] as String),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            const Text(
              "Today's Teaching Schedule",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => context.push('/school/timetable'),
              icon: const Icon(Icons.calendar_today_outlined, size: 14),
              label: const Text('Weekly View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_todaySchedule.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text('No lectures scheduled for today. Free day!', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ),
          )
        else
          ..._todaySchedule.map((s) => _buildScheduleItem(s)),
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

          IconButton(
            tooltip: 'Take Attendance for $className ($period)',
            icon: const Icon(Icons.how_to_reg_rounded, size: 20, color: Color(0xFF10B981)),
            onPressed: () {
              final cId = item['class_id']?.toString() ?? item['class']?.toString() ?? '';
              context.push('/school/attendance?classId=$cId&period=$period');
            },
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      if (mounted) {
        setState(() {
          _profile = res;
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
}
