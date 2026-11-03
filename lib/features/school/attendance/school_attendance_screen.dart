import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';

class SchoolAttendanceScreen extends StatefulWidget {
  const SchoolAttendanceScreen({super.key});

  @override
  State<SchoolAttendanceScreen> createState() => _SchoolAttendanceScreenState();
}

class _SchoolAttendanceScreenState extends State<SchoolAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  late TabController _tabController;

  // Role & identity
  String? _username;
  String? _instituteId;
  bool _isEditable = false;
  bool _isStudent = false;
  String _myName = '';
  String _myClass = '';
  List<Map<String, dynamic>> _myRecords = [];

  // Classes
  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;
  bool _loadingClasses = true;
  String? _classesError;

  // Students & attendance for selected date
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _attendanceMap = {}; // studentId -> status
  bool _loadingStudents = false;
  String? _studentsError;

  // Date
  DateTime _selectedDate = DateTime.now();

  // Monthly summary
  Map<String, Map<String, dynamic>> _monthlySummary = {}; // date -> counts
  Map<String, Map<String, dynamic>> _studentMonthly = {}; // student -> counts
  bool _loadingMonthly = false;

  // Save state
  bool _saving = false;
  // A register that already has a row for every student is final.
  bool _isSubmitted = false;

  static const _statusColors = {
    'present': Color(0xFF10B981),
    'absent': Color(0xFFEF4444),
    'late': Color(0xFFF59E0B),
    'excused': Color(0xFF6366F1),
  };

  static const _statusIcons = {
    'present': Icons.check_circle,
    'absent': Icons.cancel,
    'late': Icons.watch_later,
    'excused': Icons.beach_access,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _monthlySummary.isEmpty && _selectedClass != null) {
        _loadMonthlySummary();
      }
    });
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final role = await _authService.getCurrentUserRole();
    final username = await _authService.getCurrentUsername();
    if (!mounted) return;
    setState(() {
      _username = username;
      _isStudent = role == 'student' || role == 'parent';
      _isEditable = role == 'teacher' || role == 'admin' || role == 'sadmin' || role == 'steacher';
    });

    // Students see THEIR OWN attendance — no class picking, no marking grid.
    if (_isStudent) {
      try {
        final profile =
            await _schoolService.getSchoolStudentProfile(username ?? '');
        if (mounted && profile != null) {
          setState(() {
            _myName = profile['name']?.toString() ?? (username ?? 'Student');
            final className = profile['class_name']?.toString();
            final section = profile['section']?.toString();
            _myClass = className ?? 'Class 10';
            if (section != null && section.isNotEmpty) {
              _myClass = '$_myClass-$section';
            }
          });
        }
        await _loadMyAttendance();
      } catch (_) {}
      return;
    }

    await _resolveInstituteId();
    await _loadClasses();
  }

  Future<void> _loadMyAttendance() async {
    if (_username == null) return;
    try {
      final records =
          await _schoolService.getStudentAttendanceRecords(_username!);
      if (mounted) setState(() => _myRecords = records);
    } catch (_) {}
  }

  Future<void> _resolveInstituteId() async {
    // Fetch the institute_id from the users table for this user
    try {
      if (_username == null) return;
      final res = await _schoolService.supabase
          .from('users')
          .select('institute_id')
          .eq('username', _username!)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _instituteId = res['institute_id']?.toString());
      }
    } catch (_) {}
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final classes = await _schoolService.getSchoolClasses(_instituteId);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _loadingClasses = false;
        if (classes.isNotEmpty) {
          _selectedClass = classes.first;
        }
      });
      if (_selectedClass != null) {
        await _loadStudentsAndAttendance();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingClasses = false;
        _classesError = 'Failed to load classes. Please try again.';
      });
    }
  }

  Future<void> _loadStudentsAndAttendance() async {
    if (_selectedClass == null) return;
    final classId = _selectedClass!['id']?.toString() ?? '';
    final className = _selectedClass!['name']?.toString() ?? '';
    final section = _selectedClass!['section']?.toString() ?? '';

    setState(() {
      _loadingStudents = true;
      _studentsError = null;
      _students = [];
      _attendanceMap = {};
      _isSubmitted = false;
    });

    try {
      final students = await _schoolService.getStudentsInClass(
        classId,
        className: className,
        section: section,
      );
      final existing = await _schoolService.getAttendance(
        classId: classId,
        className: className,
        section: section,
        date: _selectedDate,
      );

      // Build map: studentId -> status
      final attMap = <String, String>{};
      for (final a in existing) {
        final sid = a['student_id']?.toString() ?? '';
        final status = a['status']?.toString() ?? 'present';
        if (sid.isNotEmpty) attMap[sid] = status;
      }

      // Default unrecorded students to 'present'. Attendance rows are keyed
      // by the student's username, which is what the student app reads.
      for (final s in students) {
        final sid = s['username']?.toString() ?? s['id']?.toString() ?? '';
        if (sid.isNotEmpty && !attMap.containsKey(sid)) {
          attMap[sid] = 'present';
        }
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _attendanceMap = attMap;
        _isSubmitted = students.isNotEmpty && existing.length >= students.length;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStudents = false;
        _studentsError = 'Failed to load students. Please try again.';
      });
    }
  }

  Future<void> _loadMonthlySummary() async {
    if (_selectedClass == null) return;
    final classId = _selectedClass!['id']?.toString() ?? '';
    final className = _selectedClass!['name']?.toString() ?? '';
    final section = _selectedClass!['section']?.toString() ?? '';

    setState(() => _loadingMonthly = true);

    try {
      final from = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final to = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final report = await _schoolService.getAttendanceReport(
        classId: classId,
        className: className,
        section: section,
        from: from,
        to: to,
      );

      // Group by date and by student
      final Map<String, Map<String, dynamic>> summary = {};
      final Map<String, Map<String, dynamic>> students = {};
      for (final r in report) {
        final date = r['date']?.toString() ?? '';
        final status = r['status']?.toString() ?? '';
        if (date.isNotEmpty) {
          summary[date] ??= {
            'present': 0,
            'absent': 0,
            'late': 0,
            'excused': 0,
            'total': 0,
          };
          if (_statusColors.containsKey(status)) {
            summary[date]![status] = (summary[date]![status] as int) + 1;
          }
          summary[date]!['total'] = (summary[date]!['total'] as int) + 1;
        }

        final sid = r['student_id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          students[sid] ??= {
            'name': r['student_name']?.toString() ?? sid,
            'present': 0,
            'absent': 0,
            'late': 0,
            'excused': 0,
            'total': 0,
          };
          if (students[sid]!.containsKey(status)) {
            students[sid]![status] = (students[sid]![status] as int) + 1;
          }
          students[sid]!['total'] = (students[sid]!['total'] as int) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _monthlySummary = summary;
        _studentMonthly = students;
        _loadingMonthly = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMonthly = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _monthlySummary = {};
        _studentMonthly = {};
      });
      await _loadStudentsAndAttendance();
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _students.isEmpty) return;
    if (_isSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Attendance for this date is already submitted and cannot be changed.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);

    final classId = _selectedClass!['id']?.toString() ?? '';
    final className = _selectedClass!['name']?.toString() ?? '';
    final classSection = _selectedClass!['section']?.toString() ?? '';
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);

    final records = _students
        .map((s) {
          final sid =
              s['username']?.toString() ?? s['id']?.toString() ?? '';
          final studentSection = s['section']?.toString() ?? '';
          return <String, dynamic>{
            'institute_code': 'SHIV-SCH',
            'class_id': classId,
            'class_name': className.isNotEmpty
                ? className
                : (s['class_name']?.toString() ?? ''),
            'section': classSection.isNotEmpty ? classSection : studentSection,
            'student_id': sid,
            'student_name': s['name']?.toString() ??
                s['username']?.toString() ??
                '',
            'date': dateStr,
            'status': _attendanceMap[sid] ?? 'present',
            'marked_by': _username ?? 'teacher',
          };
        })
        .where((r) => (r['student_id'] as String).isNotEmpty)
        .toList();

    final success = await _schoolService.markAttendance(records);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Attendance submitted: $_presentCount present, $_absentCount absent, $_lateCount late, $_leaveCount excused'
              : 'Could not save attendance to the server. Please try again.',
        ),
        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (success) {
      _monthlySummary = {};
      _studentMonthly = {};
      setState(() => _isSubmitted = true);
      await _loadStudentsAndAttendance();
    }
  }

  // ─── Counts ───
  int get _presentCount => _attendanceMap.values.where((s) => s == 'present').length;
  int get _absentCount => _attendanceMap.values.where((s) => s == 'absent').length;
  int get _lateCount => _attendanceMap.values.where((s) => s == 'late').length;
  int get _leaveCount => _attendanceMap.values.where((s) => s == 'excused').length;

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    // Student self-view: their own attendance, never a class-marking grid.
    if (_isStudent) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'My Attendance',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          foregroundColor: Colors.white,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
              ),
            ),
          ),
        ),
        body: _buildStudentAttendanceView(),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Daily Attendance',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF064E3B),
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Daily Register', icon: Icon(Icons.list_alt, size: 16)),
                Tab(text: 'Monthly View', icon: Icon(Icons.calendar_month, size: 16)),
              ],
            ),
          ),
        ),
        actions: [
          if (_isEditable && !_isSubmitted && _tabController.index == 0)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _saveAttendance,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                    label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
        ],
      ),
      body: _loadingClasses
          ? _buildLoadingSkeleton()
          : _classesError != null
              ? _buildErrorView(_classesError!, _loadClasses)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDailyTab(),
                    _buildMonthlyTab(),
                  ],
                ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ─── Student self-view ───
  Widget _buildStudentAttendanceView() {
    // Keep only the current month's records
    final monthRecords = _myRecords.where((r) {
      final d = DateTime.tryParse(r['date']?.toString() ?? '');
      return d != null &&
          d.year == _selectedDate.year &&
          d.month == _selectedDate.month;
    }).toList();

    final present =
        monthRecords.where((r) => r['status'] == 'present').length;
    final absent = monthRecords.where((r) => r['status'] == 'absent').length;
    final late = monthRecords.where((r) => r['status'] == 'late').length;
    final leave = monthRecords
        .where((r) => r['status'] == 'excused' || r['status'] == 'leave')
        .length;
    final counted = monthRecords
        .where((r) => r['status'] != 'excused' && r['status'] != 'leave')
        .toList();
    final pct = counted.isEmpty
        ? 0.0
        : ((present + late) / counted.length) * 100;

    return RefreshIndicator(
      onRefresh: _loadMyAttendance,
      color: const Color(0xFF10B981),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Identity + month header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF34D399)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _myName.isNotEmpty ? '$_myName · $_myClass' : 'My Attendance',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    const Text('this month',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    Text(
                      '${_selectedDate.month}/${_selectedDate.year}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate =
                        DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_monthLabel(_selectedDate.month)} ${_selectedDate.year}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              IconButton(
                onPressed: () {
                  final now = DateTime.now();
                  final next =
                      DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                  if (next.isBefore(now) ||
                      (next.year == now.year && next.month == now.month)) {
                    setState(() {
                      _selectedDate = next;
                    });
                  }
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Month totals
          Row(
            children: [
              _myStatChip('Present', present, const Color(0xFF10B981)),
              _myStatChip('Absent', absent, const Color(0xFFEF4444)),
              _myStatChip('Late', late, const Color(0xFFF59E0B)),
              _myStatChip('Leave', leave, const Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 16),

          // Records for the month
          if (monthRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No attendance recorded this month',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                ],
              ),
            )
          else
            ...monthRecords.map((r) {
              final status = (r['status']?.toString() ?? '').toLowerCase();
              final color =
                  _statusColors[status] ?? const Color(0xFF64748B);
              final icon = _statusIcons[status] ?? Icons.help_outline;
              DateTime? d;
              try {
                d = DateTime.parse(r['date'].toString());
              } catch (_) {}
              final weekday = d != null
                  ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      [d.weekday - 1]
                  : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            d != null ? '${d.day}' : '-',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        d != null ? '$weekday, ${d.day}/${d.month}/${d.year}' : '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, size: 13, color: color),
                          const SizedBox(width: 4),
                          Text(
                            status.isEmpty ? 'Unknown' :
                                status[0].toUpperCase() + status.substring(1),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _myStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][month - 1];

  // ─── Daily Tab ───
  Widget _buildDailyTab() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildStudentList()),
        if (_isEditable && _students.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            color: const Color(0xFFF8FAFC),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    (_saving || _isSubmitted) ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubmitted
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF10B981),
                  foregroundColor:
                      _isSubmitted ? const Color(0xFF475569) : Colors.white,
                  disabledBackgroundColor: _isSubmitted
                      ? const Color(0xFFE2E8F0)
                      : const Color(0xFF10B981).withValues(alpha: 0.6),
                  disabledForegroundColor: _isSubmitted
                      ? const Color(0xFF64748B)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isSubmitted
                        ? Icons.lock_outline
                        : Icons.cloud_upload_outlined),
                label: Text(
                  _saving
                      ? 'Submitting…'
                      : _isSubmitted
                          ? 'Attendance already submitted'
                          : 'Submit Attendance (${_students.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF10B981),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Stat chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('Present', _presentCount, const Color(0xFFECFDF5), const Color(0xFF10B981)),
              _buildStatChip('Absent', _absentCount, const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
              _buildStatChip('Late', _lateCount, const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
              _buildStatChip('Leave', _leaveCount, const Color(0xFFEDE9FE), const Color(0xFF6366F1)),
              _buildStatChip('Total', _students.length, Colors.white.withValues(alpha: 0.2), Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          // Date picker row
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Class dropdown
          if (_classes.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedClass,
                dropdownColor: const Color(0xFF10B981),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                isExpanded: true,
                items: _classes.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    _className(c),
                    style: const TextStyle(color: Colors.white),
                  ),
                )).toList(),
                onChanged: _isEditable
                    ? (v) async {
                        setState(() {
                          _selectedClass = v;
                          _monthlySummary = {};
                        });
                        await _loadStudentsAndAttendance();
                      }
                    : null,
              ),
            )
          else if (!_loadingClasses)
            const Text('No classes found', style: TextStyle(color: Colors.white70)),
          if (_isSubmitted) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Submitted — attendance is locked',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    if (_studentsError != null) {
      return _buildErrorView(_studentsError!, _loadStudentsAndAttendance);
    }
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _selectedClass == null ? 'No class selected' : 'No students in this class',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) => _buildStudentCard(_students[index]),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final sid =
        student['username']?.toString() ?? student['id']?.toString() ?? '';
    final status = _attendanceMap[sid] ?? 'present';
    final statusColor = _statusColors[status] ?? Colors.grey;
    final statusIcon = _statusIcons[status] ?? Icons.help;
    final roll = student['roll_number']?.toString() ?? '?';
    final name = student['name']?.toString() ?? student['username']?.toString() ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Roll number avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                roll,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name & ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                Text(
                  student['username']?.toString() ?? sid,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // Status controls or read-only icon
          if (_isEditable && !_isSubmitted)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusButton(sid, 'present', const Color(0xFF10B981), Icons.check),
                const SizedBox(width: 5),
                _buildStatusButton(sid, 'absent', const Color(0xFFEF4444), Icons.close),
                const SizedBox(width: 5),
                _buildStatusButton(sid, 'late', const Color(0xFFF59E0B), Icons.watch_later_outlined),
                const SizedBox(width: 5),
                _buildStatusButton(sid, 'excused', const Color(0xFF6366F1), Icons.beach_access_outlined),
              ],
            )
          else
            Icon(statusIcon, color: statusColor, size: 28),
        ],
      ),
    );
  }

  Widget _buildStatusButton(String studentId, String status, Color color, IconData icon) {
    final isSelected = _attendanceMap[studentId] == status;
    return InkWell(
      onTap: () => setState(() => _attendanceMap[studentId] = status),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, size: 18, color: isSelected ? Colors.white : color),
      ),
    );
  }

  // ─── Monthly Tab ───
  Widget _buildMonthlyTab() {
    if (_selectedClass == null) {
      return const Center(child: Text('No class selected', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                '${_monthName(_selectedDate.month)} ${_selectedDate.year} — ${_className(_selectedClass!)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  setState(() => _monthlySummary = {});
                  await _loadMonthlySummary();
                },
                child: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingMonthly
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
              : _monthlySummary.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No data for this month',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadMonthlySummary,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Load Summary'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _MonthlyAttendanceView(
                      summary: _monthlySummary,
                      students: _studentMonthly,
                    ),
        ),
      ],
    );
  }

  // ─── Helpers ───
  Widget _buildStatChip(String label, int count, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text(label, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _className(Map<String, dynamic> c) {
    final name = c['name']?.toString() ?? '';
    final section = c['section']?.toString() ?? '';
    return section.isNotEmpty ? '$name-$section' : name;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}

// ─── Monthly Attendance Table Widget ───
class _MonthlyAttendanceView extends StatelessWidget {
  final Map<String, Map<String, dynamic>> summary;
  final Map<String, Map<String, dynamic>> students;

  const _MonthlyAttendanceView(
      {required this.summary, required this.students});

  @override
  Widget build(BuildContext context) {
    final sortedDates = summary.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(flex: 2, child: Center(child: Text('Present', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('Absent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('Late', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))),
                Expanded(flex: 2, child: Center(child: Text('%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Rows
          ...sortedDates.asMap().entries.map((entry) {
            final idx = entry.key;
            final date = entry.value;
            final data = summary[date]!;
            final present = (data['present'] as int? ?? 0);
            final absent = (data['absent'] as int? ?? 0);
            final late = (data['late'] as int? ?? 0);
            final total = (data['total'] as int? ?? 0);
            final pct = total == 0 ? 0.0 : present / total * 100;
            final pctColor = pct >= 80
                ? const Color(0xFF10B981)
                : pct >= 60
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFEF4444);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: idx.isEven ? Colors.white : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      _fmtDate(date),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1F2937)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: _countBadge('$present', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: _countBadge('$absent', const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: _countBadge('$late', const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: pctColor),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (sortedDates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No attendance records found', style: TextStyle(color: Colors.grey)),
            ),
          if (students.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Student-wise attendance',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937)),
              ),
            ),
            const SizedBox(height: 8),
            ...(students.entries.toList()
              ..sort((a, b) => (a.value['name']?.toString() ?? '')
                  .compareTo(b.value['name']?.toString() ?? '')))
                .map((entry) {
              final data = entry.value;
              final present = data['present'] as int? ?? 0;
              final late = data['late'] as int? ?? 0;
              final total = data['total'] as int? ?? 0;
              final pct = total == 0 ? 0.0 : (present + late) / total * 100;
              final color = pct >= 80
                  ? const Color(0xFF10B981)
                  : pct >= 60
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                          Text(
                            data['name']?.toString() ?? entry.key,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937)),
                          ),
                          Text(
                            '$present present · ${data['absent']} absent · $late late · ${data['excused']} excused',
                            style: const TextStyle(
                                fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _countBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  String _fmtDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return isoDate;
    }
  }
}
