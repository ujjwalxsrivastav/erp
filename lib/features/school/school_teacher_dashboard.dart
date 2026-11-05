import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../services/school_service.dart';

class SchoolTeacherDashboard extends StatefulWidget {
  const SchoolTeacherDashboard({super.key});

  @override
  State<SchoolTeacherDashboard> createState() => _SchoolTeacherDashboardState();
}

class _SchoolTeacherDashboardState extends State<SchoolTeacherDashboard> {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  String _teacherName = 'Teacher';
  String _teacherClass = 'Class Teacher';
  // Stats
  final int _totalStudents = 42;
  final int _presentToday = 38;
  int _pendingAssignments = 5;
  int _upcomingClasses = 3;
  int _pendingLeaves = 2;

  // Today's classes
  List<Map<String, dynamic>> _todaySchedule = [
    {'time': '08:00 - 08:45 AM', 'subject': 'Mathematics', 'class': 'Class 10-A', 'room': 'Room 201', 'period': 'Period 1'},
    {'time': '09:00 - 09:45 AM', 'subject': 'Mathematics', 'class': 'Class 10-B', 'room': 'Room 301', 'period': 'Period 2'},
    {'time': '11:15 - 12:00 PM', 'subject': 'Mathematics', 'class': 'Class 9-A', 'room': 'Room 101', 'period': 'Period 4'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final username = await _authService.getCurrentUsername() ?? '';

    final displayName = await _schoolService.getTeacherDisplayName(username);
    final teacherClasses = await _schoolService.getClassTeacherClasses(username);

    if (mounted) {
      setState(() {
        _teacherName = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : (username.isEmpty ? 'Teacher' : username);
        _teacherClass = teacherClasses.isEmpty
            ? 'Subject Faculty'
            : 'Class Teacher • ${teacherClasses.first['name'] ?? ''}'.trim();
      });
    }

    try {
      final schedule = await _schoolService.getTeacherTimetable(username);
      final pendingHw = await _schoolService.getPendingHomeworkToGrade(username);
      final pendingLeavesList = await _schoolService.getLeaveRequestsForClassTeacher(username);

      if (mounted) {
        setState(() {
          if (schedule.isNotEmpty) {
            _todaySchedule = schedule;
            _upcomingClasses = schedule.length;
          }
          _pendingAssignments = pendingHw;
          _pendingLeaves = pendingLeavesList.length;
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
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
              'Shivalik International School • $dateStr',
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF0F172A),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
          children: [
            _buildFacultyHeroCard(),
            const SizedBox(height: 16),
            _buildKpiGrid(),
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
    final attPct = _totalStudents == 0 ? 0.0 : (_presentToday / _totalStudents) * 100;
    return Row(
      children: [
        _buildKpiCard(
          title: "Attendance Today",
          value: '$_presentToday / $_totalStudents',
          badgeText: '${attPct.toStringAsFixed(0)}% Rate',
          badgeBg: const Color(0xFFECFDF5),
          badgeColor: const Color(0xFF10B981),
          icon: Icons.how_to_reg_outlined,
          onTap: () => context.push('/school/attendance'),
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
  // 3. ACADEMICS & EXAMINATION MASTER
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
  // 4. DAILY OPERATIONS & PASTORAL
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
        'subtitle': '5E constructivist plans & Bloom\'s levels',
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
  // 5. TODAY'S TEACHING SCHEDULE
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
    final className = item['class'] ?? item['class_name'] ?? item['class_id'] ?? 'Class';
    final room = item['room']?.toString() ?? 'Room 201';
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
                  '$className • $room',
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
            tooltip: 'Take Attendance for $className',
            icon: const Icon(Icons.how_to_reg_rounded, size: 20, color: Color(0xFF10B981)),
            onPressed: () => context.push('/school/attendance'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 6. MINIMALIST DRAWER
  // ──────────────────────────────────────────────
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
