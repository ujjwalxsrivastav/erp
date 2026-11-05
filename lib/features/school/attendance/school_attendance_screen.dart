import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/school_export_service.dart';

class SchoolAttendanceScreen extends StatefulWidget {
  const SchoolAttendanceScreen({super.key});

  @override
  State<SchoolAttendanceScreen> createState() => _SchoolAttendanceScreenState();
}

class _SchoolAttendanceScreenState extends State<SchoolAttendanceScreen> {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  // Role & identity
  String? _username;
  bool _isEditable = false;
  bool _isStudent = false;
  bool _isTeacher = false;
  bool _isAdmin = false;
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
  Map<String, String> _remarksMap = {}; // studentId -> remark/note
  bool _loadingStudents = false;
  String? _studentsError;
  String _searchQuery = '';

  // Date
  DateTime _selectedDate = DateTime.now();

  // Monthly summary
  Map<String, Map<String, dynamic>> _monthlySummary = {}; // date -> counts
  Map<String, Map<String, dynamic>> _studentMonthly = {}; // student -> counts
  bool _loadingMonthly = false;

  // Save state
  bool _saving = false;
  bool _isSubmitted = false;
  bool _forceEditMode = false;

  // Color & Token Palettes
  static const _statusColors = {
    'present': Color(0xFF10B981),
    'absent': Color(0xFFEF4444),
    'late': Color(0xFFF59E0B),
    'excused': Color(0xFF6366F1),
    'unmarked': Color(0xFF94A3B8),
  };

  static const _statusBgColors = {
    'present': Color(0xFFECFDF5),
    'absent': Color(0xFFFEF2F2),
    'late': Color(0xFFFFFBEB),
    'excused': Color(0xFFEEF2FF),
    'unmarked': Color(0xFFF1F5F9),
  };

  static const _statusBorderColors = {
    'present': Color(0xFFA7F3D0),
    'absent': Color(0xFFFECACA),
    'late': Color(0xFFFDE68A),
    'excused': Color(0xFFC7D2FE),
    'unmarked': Color(0xFFCBD5E1),
  };

  static const _statusIcons = {
    'present': Icons.check_circle_rounded,
    'absent': Icons.cancel_rounded,
    'late': Icons.alarm_rounded,
    'excused': Icons.beach_access_rounded,
    'unmarked': Icons.help_outline_rounded,
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final role = await _authService.getCurrentUserRole() ?? 'student';
    final username = await _authService.getCurrentUsername() ?? 'sstudent1';
    if (!mounted) return;
    setState(() {
      _username = username;
      _isStudent = role == 'student' || role == 'parent';
      _isTeacher = role == 'teacher' || role == 'steacher';
      _isAdmin = role == 'admin' || role == 'sadmin';
      _isEditable = _isTeacher || _isAdmin;
    });

    if (_isStudent) {
      try {
        final profile = await _schoolService.getSchoolStudentProfile(username);
        if (mounted && profile != null) {
          setState(() {
            _myName = profile['name']?.toString() ?? username;
            _myClass = profile['class_name']?.toString() ?? 'Class 10';
          });
        }
        await _loadMyAttendance();
      } catch (_) {}
      return;
    }

    await _loadClasses();
  }

  Future<void> _loadMyAttendance() async {
    if (_username == null) return;
    try {
      final records = await _schoolService.getStudentAttendanceRecords(_username!);
      if (mounted) setState(() => _myRecords = records);
    } catch (_) {}
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _classesError = null;
    });
    try {
      final List<Map<String, dynamic>> classes;
      if (_isTeacher && !_isAdmin) {
        classes = await _schoolService.getTeacherAllAssignedClasses(_username ?? '');
        if (classes.isEmpty) {
          if (!mounted) return;
          setState(() {
            _classes = [];
            _selectedClass = null;
            _loadingClasses = false;
            _classesError = 'No classes are assigned to you.';
          });
          return;
        }
      } else {
        classes = await _schoolService.getSchoolClasses(null);
      }
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
        _loadMonthlySummary();
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

    setState(() {
      _loadingStudents = true;
      _studentsError = null;
      _students = [];
      _attendanceMap = {};
      _remarksMap = {};
      _isSubmitted = false;
      _forceEditMode = false;
    });

    try {
      final students = await _schoolService.getStudentsInClass(
        classId,
        className: className,
      );
      final existing = await _schoolService.getAttendance(
        classId: classId,
        className: className,
        date: _selectedDate,
      );

      final attMap = <String, String>{};
      final remMap = <String, String>{};
      for (final a in existing) {
        final sid = a['student_id']?.toString() ?? '';
        final status = a['status']?.toString() ?? 'present';
        final remark = a['remark']?.toString() ?? a['notes']?.toString() ?? '';
        if (sid.isNotEmpty) {
          attMap[sid] = status;
          if (remark.isNotEmpty) remMap[sid] = remark;
        }
      }

      // Default unrecorded students to 'present' for seamless teacher workflow
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
        _remarksMap = remMap;
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

    setState(() => _loadingMonthly = true);

    try {
      final from = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final to = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final report = await _schoolService.getAttendanceReport(
        classId: classId,
        className: className,
        from: from,
        to: to,
      );

      final Map<String, Map<String, dynamic>> summary = {};
      final Map<String, Map<String, dynamic>> students = {};

      for (final r in report) {
        final date = r['date']?.toString() ?? '';
        final status = (r['status']?.toString() ?? '').toLowerCase();
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
            'student_id': sid,
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
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF0F172A),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
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
      _loadMonthlySummary();
    }
  }

  void _shiftDay(int deltaDays) {
    final newDate = _selectedDate.add(Duration(days: deltaDays));
    if (newDate.isAfter(DateTime.now())) return;
    setState(() {
      _selectedDate = newDate;
    });
    _loadStudentsAndAttendance();
  }

  void _markAllPresent() {
    setState(() {
      for (final s in _students) {
        final sid = s['username']?.toString() ?? s['id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          _attendanceMap[sid] = 'present';
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All ${_students.length} students marked Present.'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _students.isEmpty) return;

    if (_isSubmitted && !_forceEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance is locked. Tap "Unlock & Edit" to make corrections.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final classId = _selectedClass!['id']?.toString() ?? '';
    final className = _selectedClass!['name']?.toString() ?? '';
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);

    final records = _students
        .map((s) {
          final sid = s['username']?.toString() ?? s['id']?.toString() ?? '';
          return <String, dynamic>{
            'institute_code': 'SHIV-SCH',
            'class_id': classId,
            'class_name': className.isNotEmpty
                ? className
                : (s['class_name']?.toString() ?? ''),
            'section': '',
            'student_id': sid,
            'student_name': s['name']?.toString() ?? s['username']?.toString() ?? '',
            'date': dateStr,
            'status': _attendanceMap[sid] ?? 'present',
            'marked_by': _username ?? 'teacher',
            if (_remarksMap.containsKey(sid) && _remarksMap[sid]!.isNotEmpty)
              'notes': _remarksMap[sid],
          };
        })
        .where((r) => (r['student_id'] as String).isNotEmpty)
        .toList();

    final success = await _schoolService.markAttendance(
      records,
      forceUpdate: _forceEditMode,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daily register saved! $_presentCount Present, $_absentCount Absent, $_lateCount Late.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _monthlySummary = {};
      _studentMonthly = {};
      setState(() {
        _isSubmitted = true;
        _forceEditMode = false;
      });
      await _loadStudentsAndAttendance();
      _loadMonthlySummary();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save attendance to the server. Please try again.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showRemarkDialog(String sid, String studentName) {
    final ctrl = TextEditingController(text: _remarksMap[sid] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_alt_outlined, color: Color(0xFF0F172A), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Note for $studentName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Medical leave, parent called, bus delay…',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (ctrl.text.trim().isEmpty) {
                  _remarksMap.remove(sid);
                } else {
                  _remarksMap[sid] = ctrl.text.trim();
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  // Counts
  int get _presentCount => _attendanceMap.values.where((s) => s == 'present').length;
  int get _absentCount => _attendanceMap.values.where((s) => s == 'absent').length;
  int get _lateCount => _attendanceMap.values.where((s) => s == 'late').length;
  int get _leaveCount => _attendanceMap.values.where((s) => s == 'excused' || s == 'leave').length;
  double get _presentPercent => _students.isEmpty ? 0.0 : (_presentCount / _students.length) * 100;

  List<Map<String, dynamic>> get _filteredStudents {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _students;
    return _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final uname = (s['username'] ?? '').toString().toLowerCase();
      final roll = (s['roll_number'] ?? '').toString().toLowerCase();
      return name.contains(q) || uname.contains(q) || roll.contains(q);
    }).toList();
  }

  // ──────────────────────────────────────────────
  // BUILD ENTRY POINT
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isStudent) {
      return _buildStudentScaffold();
    }
    return _buildTeacherAdminScaffold();
  }

  // ──────────────────────────────────────────────
  // TEACHER / ADMIN SCAFFOLD (3 TABS)
  // ──────────────────────────────────────────────
  Widget _buildTeacherAdminScaffold() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                'Attendance Register',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
              Text(
                _selectedClass != null
                    ? '${_className(_selectedClass!)} • ${_formatDate(_selectedDate)}'
                    : 'CBSE Academic Year 2026-27',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: const TabBar(
                labelColor: Color(0xFF0F172A),
                unselectedLabelColor: Color(0xFF64748B),
                indicatorColor: Color(0xFF0F172A),
                indicatorWeight: 3,
                labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(text: 'Daily Register'),
                  Tab(text: 'Monthly Register'),
                  Tab(text: 'CBSE Defaulters (<75%)'),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Export Register',
              icon: const Icon(Icons.download_outlined, size: 20),
              onPressed: _showExportModal,
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () async {
                await _loadStudentsAndAttendance();
                await _loadMonthlySummary();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _loadingClasses
            ? _buildLoadingSkeleton()
            : _classesError != null
                ? _buildErrorView(_classesError!, _loadClasses)
                : TabBarView(
                    children: [
                      _buildDailyTab(),
                      _buildMonthlyTab(),
                      _buildDefaultersTab(),
                    ],
                  ),
        bottomNavigationBar: (_isEditable && _students.isNotEmpty && !_loadingStudents)
            ? _buildDailyRegisterBottomDock()
            : null,
      ),
    );
  }

  Widget _buildDailyRegisterBottomDock() {
    final canSave = !_saving && (!_isSubmitted || _forceEditMode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_presentCount of ${_students.length} Present',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _presentPercent >= 75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_presentPercent.toStringAsFixed(1)}% rate • ${_isSubmitted && !_forceEditMode ? "Locked" : "Unsaved Changes"}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: _isSubmitted && !_forceEditMode ? const Color(0xFF64748B) : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            if (_isSubmitted && !_forceEditMode)
              OutlinedButton.icon(
                onPressed: () => setState(() => _forceEditMode = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text('Unlock & Edit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              )
            else
              ElevatedButton.icon(
                onPressed: canSave ? _saveAttendance : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(_forceEditMode ? Icons.check_circle_outline : Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  _saving
                      ? 'Submitting…'
                      : _forceEditMode
                          ? 'Update Register'
                          : 'Submit Register',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: DAILY REGISTER
  // ──────────────────────────────────────────────
  Widget _buildDailyTab() {
    return Column(
      children: [
        _buildControlHeader(),
        _buildKpiMetricsStrip(),
        _buildSearchBarAndBatchRow(),
        Expanded(child: _buildStudentList()),
      ],
    );
  }

  Widget _buildControlHeader() {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Class dropdown chip
              if (_classes.isNotEmpty)
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        value: _selectedClass,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        items: _classes.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              _className(c),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          );
                        }).toList(),
                        onChanged: _isEditable
                            ? (v) async {
                                setState(() {
                                  _selectedClass = v;
                                  _monthlySummary = {};
                                });
                                await _loadStudentsAndAttendance();
                                _loadMonthlySummary();
                              }
                            : null,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),

              // Date Picker with previous/next buttons
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => _shiftDay(-1),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF64748B)),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0F172A)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isToday ? 'Today' : _fmtShortDate(_selectedDate),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: isToday ? null : () => _shiftDay(1),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isToday ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              _buildMiniKpiCard('Present', '$_presentCount', _statusColors['present']!, _statusBgColors['present']!),
              const SizedBox(width: 8),
              _buildMiniKpiCard('Absent', '$_absentCount', _statusColors['absent']!, _statusBgColors['absent']!),
              const SizedBox(width: 8),
              _buildMiniKpiCard('Late', '$_lateCount', _statusColors['late']!, _statusBgColors['late']!),
              const SizedBox(width: 8),
              _buildMiniKpiCard('Leave', '$_leaveCount', _statusColors['excused']!, _statusBgColors['excused']!),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _students.isEmpty ? 0.0 : (_presentPercent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              color: _presentPercent >= 75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniKpiCard(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBarAndBatchRow() {
    final isLocked = _isSubmitted && !_forceEditMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Search by student name or roll…',
                  hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          if (_isEditable && !isLocked && _students.isNotEmpty) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _markAllPresent,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFECFDF5),
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('All Present', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_loadingStudents) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)));
    }
    if (_studentsError != null) {
      return _buildErrorView(_studentsError!, _loadStudentsAndAttendance);
    }
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 54, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _selectedClass == null ? 'No class selected' : 'No students registered in this class',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final list = _filteredStudents;
    if (list.isEmpty) {
      return const Center(
        child: Text('No students match your search filter', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }

    final isLocked = _isSubmitted && !_forceEditMode;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return _buildStudentCard(s, isLocked);
      },
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isLocked) {
    final sid = student['username']?.toString() ?? student['id']?.toString() ?? '';
    final status = _attendanceMap[sid] ?? 'present';
    final roll = student['roll_number']?.toString() ?? '${student['roll'] ?? (student['id'] ?? '')}';
    final name = student['name']?.toString() ?? student['username']?.toString() ?? 'Student';
    final remark = _remarksMap[sid];

    final statusColor = _statusColors[status] ?? const Color(0xFF10B981);
    final statusBg = _statusBgColors[status] ?? const Color(0xFFECFDF5);
    final statusBorder = _statusBorderColors[status] ?? const Color(0xFFA7F3D0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Roll avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                roll.isEmpty ? '•' : roll,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: statusColor),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      sid,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    if (remark != null && remark.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          remark,
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Note / Remark icon
          if (_isEditable && !isLocked)
            IconButton(
              icon: Icon(
                remark != null && remark.isNotEmpty ? Icons.note_rounded : Icons.note_add_outlined,
                size: 18,
                color: remark != null && remark.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
              ),
              tooltip: 'Add remark',
              onPressed: () => _showRemarkDialog(sid, name),
            ),

          // Segmented Status Selector
          if (_isEditable && !isLocked)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentItem(sid, 'present', 'P', _statusColors['present']!),
                const SizedBox(width: 4),
                _buildSegmentItem(sid, 'absent', 'A', _statusColors['absent']!),
                const SizedBox(width: 4),
                _buildSegmentItem(sid, 'late', 'L', _statusColors['late']!),
                const SizedBox(width: 4),
                _buildSegmentItem(sid, 'excused', 'E', _statusColors['excused']!),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusBorder),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(String studentId, String statusKey, String label, Color color) {
    final isSelected = _attendanceMap[studentId] == statusKey;
    return InkWell(
      onTap: () => setState(() => _attendanceMap[studentId] = statusKey),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.2)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: MONTHLY REGISTER & ANALYTICS
  // ──────────────────────────────────────────────
  Widget _buildMonthlyTab() {
    if (_selectedClass == null) {
      return const Center(child: Text('No class selected', style: TextStyle(color: Color(0xFF64748B))));
    }

    final sortedDates = _monthlySummary.keys.toList()..sort();
    final studentList = _studentMonthly.values.toList()
      ..sort((a, b) => (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));

    // Compute period totals
    int totalWorkingDays = sortedDates.length;
    double periodPct = 0.0;
    if (studentList.isNotEmpty) {
      final sum = studentList.fold<double>(0.0, (acc, s) {
        final tot = s['total'] as int? ?? 0;
        final pres = (s['present'] as int? ?? 0) + (s['late'] as int? ?? 0);
        return acc + (tot == 0 ? 0.0 : (pres / tot) * 100);
      });
      periodPct = sum / studentList.length;
    }

    return RefreshIndicator(
      onRefresh: _loadMonthlySummary,
      color: const Color(0xFF0F172A),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_monthLabel(_selectedDate.month)} ${_selectedDate.year}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_className(_selectedClass!)} • $totalWorkingDays Recorded Sessions',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: periodPct >= 75 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: periodPct >= 75 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${periodPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: periodPct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                      Text(
                        periodPct >= 75 ? 'CBSE Compliant' : 'Shortage Alert',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: periodPct >= 75 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (sortedDates.isNotEmpty) ...[
            Container(
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.show_chart_rounded, size: 16, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Monthly Attendance Trajectory',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _showExportModal,
                        icon: const Icon(Icons.file_download_outlined, size: 13),
                        label: const Text('Export Excel (T-R01)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
                    'Daily attendance percentage against CBSE 75.0% statutory threshold.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (sortedDates.length - 1).toDouble().clamp(1.0, 31.0),
                        minY: 0,
                        maxY: 100,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (val) => const FlLine(
                            color: Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 25,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.toInt()}%',
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              interval: (sortedDates.length / 5).ceilToDouble().clamp(1.0, 10.0),
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx < 0 || idx >= sortedDates.length) return const SizedBox.shrink();
                                final parts = sortedDates[idx].split('-');
                                return Text(
                                  parts.length >= 3 ? '${parts[1]}/${parts[2]}' : '',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 75,
                              color: const Color(0xFFEF4444).withValues(alpha: 0.7),
                              strokeWidth: 1.5,
                              dashArray: [4, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.only(right: 6, bottom: 2),
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                                labelResolver: (_) => '75% CBSE Limit',
                              ),
                            ),
                          ],
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (int i = 0; i < sortedDates.length; i++) ...[
                                () {
                                  final d = sortedDates[i];
                                  final data = _monthlySummary[d]!;
                                  final pres = data['present'] as int? ?? 0;
                                  final tot = data['total'] as int? ?? 0;
                                  final rate = tot == 0 ? 0.0 : (pres / tot) * 100;
                                  return FlSpot(i.toDouble(), rate);
                                }(),
                              ],
                            ],
                            isCurved: true,
                            curveSmoothness: 0.25,
                            color: const Color(0xFF2563EB),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, bar, index) {
                                final isLow = spot.y < 75.0;
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: isLow ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Day-by-Day Register Table
          const Text(
            'Daily Register Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          if (_loadingMonthly)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (sortedDates.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Text('No attendance records logged for this month yet.', style: TextStyle(color: Color(0xFF64748B))),
              ),
            )
          else ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Center(child: Text('Present', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))))),
                        Expanded(flex: 2, child: Center(child: Text('Absent', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))))),
                        Expanded(flex: 2, child: Center(child: Text('Rate %', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ...sortedDates.map((d) {
                    final data = _monthlySummary[d]!;
                    final pres = data['present'] as int? ?? 0;
                    final abs = data['absent'] as int? ?? 0;
                    final tot = data['total'] as int? ?? 0;
                    final rate = tot == 0 ? 0.0 : (pres / tot) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              _fmtShortDate(DateTime.tryParse(d) ?? DateTime.now()),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text('$pres', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text('$abs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                '${rate.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: rate >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          // Student cumulative ranking
          const Text(
            'Student-wise Cumulative Breakdown',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          ...studentList.map((s) {
            final pres = s['present'] as int? ?? 0;
            final abs = s['absent'] as int? ?? 0;
            final late = s['late'] as int? ?? 0;
            final excused = s['excused'] as int? ?? 0;
            final tot = s['total'] as int? ?? 0;
            final pct = tot == 0 ? 0.0 : ((pres + late) / tot) * 100;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['name']?.toString() ?? 'Student',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$pres Present • $abs Absent • $late Late • $excused Excused',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pct >= 75 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pct >= 75 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
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

  // ──────────────────────────────────────────────
  // TAB 3: CBSE DEFAULTERS AUDIT (<75%)
  // ──────────────────────────────────────────────
  Widget _buildDefaultersTab() {
    final defaulters = _studentMonthly.values.where((s) {
      final tot = s['total'] as int? ?? 0;
      final pres = (s['present'] as int? ?? 0) + (s['late'] as int? ?? 0);
      final pct = tot == 0 ? 0.0 : (pres / tot) * 100;
      return pct < 75.0 && tot > 0;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // CBSE Compliance Warning Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CBSE Rule 13 — 75% Mandatory Attendance',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Students with cumulative attendance below 75% are ineligible for board/annual examinations unless condoned on medical grounds.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Identified Defaulters (${defaulters.length})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            if (defaulters.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _showExportModal,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_outlined, size: 14),
                label: const Text('Export Audit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (defaulters.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_rounded, size: 48, color: Color(0xFF10B981)),
                const SizedBox(height: 10),
                const Text(
                  '100% CBSE Compliant!',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'All students in ${_className(_selectedClass ?? {})} currently meet or exceed the 75% minimum threshold.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...defaulters.map((s) {
            final pres = s['present'] as int? ?? 0;
            final abs = s['absent'] as int? ?? 0;
            final tot = s['total'] as int? ?? 0;
            final pct = tot == 0 ? 0.0 : (pres / tot) * 100;
            final needed = ((0.75 * tot) - pres).ceil();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Center(
                      child: Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s['name']?.toString() ?? 'Student',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$pres Attended / $tot Working Days • $abs Absent',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        if (needed > 0)
                          Text(
                            'Needs $needed more consecutive days to reach 75%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // STUDENT / PARENT SELF-VIEW
  // ──────────────────────────────────────────────
  Widget _buildStudentScaffold() {
    final monthRecords = _myRecords.where((r) {
      final d = DateTime.tryParse(r['date']?.toString() ?? '');
      return d != null &&
          d.year == _selectedDate.year &&
          d.month == _selectedDate.month;
    }).toList();

    final present = monthRecords.where((r) => r['status'] == 'present').length;
    final absent = monthRecords.where((r) => r['status'] == 'absent').length;
    final late = monthRecords.where((r) => r['status'] == 'late').length;
    final leave = monthRecords.where((r) => r['status'] == 'excused' || r['status'] == 'leave').length;
    final counted = monthRecords.where((r) => r['status'] != 'excused' && r['status'] != 'leave').toList();
    final pct = counted.isEmpty ? 0.0 : ((present + late) / counted.length) * 100;

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
              'My Attendance Record',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            Text(
              _myName.isNotEmpty ? '$_myName • $_myClass' : 'CBSE Session 2026-27',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Apply for Leave',
            icon: const Icon(Icons.add_task_rounded, size: 20),
            onPressed: () => context.push('/school/leave'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _loadMyAttendance,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyAttendance,
        color: const Color(0xFF0F172A),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Hero Radial / Gauge Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_monthLabel(_selectedDate.month)} ${_selectedDate.year}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: pct >= 75 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pct >= 75 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              pct >= 75 ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
                              size: 20,
                              color: pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pct >= 75 ? 'Safe Zone' : 'Shortage',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pct >= 75 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF1F5F9),
                      color: pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0%', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                      Text('CBSE Target: 75%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      Text('100%', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Month Navigator Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                    });
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '${_monthLabel(_selectedDate.month)} ${_selectedDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  onPressed: () {
                    final next = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                    if (next.isBefore(DateTime.now()) || (next.year == DateTime.now().year && next.month == DateTime.now().month)) {
                      setState(() {
                        _selectedDate = next;
                      });
                    }
                  },
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Stat Chips Row
            Row(
              children: [
                _myStatChip('Present', present, _statusColors['present']!, _statusBgColors['present']!),
                const SizedBox(width: 8),
                _myStatChip('Absent', absent, _statusColors['absent']!, _statusBgColors['absent']!),
                const SizedBox(width: 8),
                _myStatChip('Late', late, _statusColors['late']!, _statusBgColors['late']!),
                const SizedBox(width: 8),
                _myStatChip('Leave', leave, _statusColors['excused']!, _statusBgColors['excused']!),
              ],
            ),
            const SizedBox(height: 16),

            // Monthly Visual Heatmap Calendar
            _buildStudentMonthCalendar(monthRecords),
            const SizedBox(height: 16),

            // Day-by-day activity log
            const Text(
              'Activity Log',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),

            if (monthRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.event_busy_outlined, size: 48, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 10),
                    Text('No attendance records logged for this month yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              )
            else
              ...monthRecords.map((r) {
                final status = (r['status']?.toString() ?? '').toLowerCase();
                final color = _statusColors[status] ?? const Color(0xFF64748B);
                final bg = _statusBgColors[status] ?? const Color(0xFFF1F5F9);
                final icon = _statusIcons[status] ?? Icons.help_outline;
                DateTime? d = DateTime.tryParse(r['date'].toString());
                final weekday = d != null ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1] : '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            d != null ? '${d.day}' : '-',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d != null ? '$weekday, ${_monthLabel(d.month)} ${d.day}, ${d.year}' : '-',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF0F172A)),
                            ),
                            if (r['notes'] != null && r['notes'].toString().isNotEmpty)
                              Text(
                                r['notes'].toString(),
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 13, color: color),
                            const SizedBox(width: 4),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
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
      ),
    );
  }

  Widget _buildStudentMonthCalendar(List<Map<String, dynamic>> records) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final firstDayWeekday = DateTime(_selectedDate.year, _selectedDate.month, 1).weekday; // 1 = Mon, 7 = Sun

    final recordByDay = <int, String>{};
    for (final r in records) {
      final d = DateTime.tryParse(r['date']?.toString() ?? '');
      if (d != null) {
        recordByDay[d.day] = (r['status']?.toString() ?? '').toLowerCase();
      }
    }

    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
          const Text(
            'Monthly Attendance Heatmap',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          // Weekday header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((w) {
              return SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (firstDayWeekday - 1) + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (ctx, i) {
              if (i < firstDayWeekday - 1) {
                return const SizedBox.shrink();
              }
              final dayNum = i - (firstDayWeekday - 1) + 1;
              final status = recordByDay[dayNum];
              Color bg = const Color(0xFFF8FAFC);
              Color textColor = const Color(0xFF64748B);
              Color border = const Color(0xFFE2E8F0);

              if (status != null) {
                bg = _statusBgColors[status] ?? bg;
                textColor = _statusColors[status] ?? textColor;
                border = _statusBorderColors[status] ?? border;
              }

              return Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Center(
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: status != null ? FontWeight.w800 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _myStatChip(String label, int count, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.9)),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // EXPORT MODAL
  // ──────────────────────────────────────────────
  void _showExportModal() {
    final className = _selectedClass != null ? _className(_selectedClass!) : 'Class 10';
    final from = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final to = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    // Build flattened row list for PDF/CSV
    final rows = <Map<String, dynamic>>[];
    _monthlySummary.forEach((date, data) {
      rows.add({
        'date': date,
        'class': className,
        'present': data['present'] ?? 0,
        'absent': data['absent'] ?? 0,
        'late': data['late'] ?? 0,
        'total': data['total'] ?? 0,
        'rate': data['total'] == 0 ? 0.0 : ((data['present'] as int) / (data['total'] as int)) * 100,
      });
    });

    final overallPct = rows.isEmpty
        ? 0.0
        : rows.fold<double>(0.0, (acc, r) => acc + ((r['rate'] as num?)?.toDouble() ?? 0.0)) / rows.length;

    SchoolExportService.showExportOptionsModal(
      context: context,
      title: 'Export Attendance Register',
      subtitle: '$className • ${_monthLabel(_selectedDate.month)} ${_selectedDate.year}',
      onExportPdf: () => SchoolExportService.exportAttendancePdf(
        context: context,
        className: className,
        fromDate: from,
        toDate: to,
        overallPct: overallPct,
        attendanceRows: rows,
      ),
      onExportCsv: () => SchoolExportService.exportAttendanceCsv(
        context: context,
        className: className,
        fromDate: from,
        toDate: to,
        overallPct: overallPct,
        attendanceRows: rows,
      ),
      onExportExcel: () async {
        final trendRows = rows.map((r) => {
          'date': r['date'],
          'day': '',
          'present': r['present'],
          'total': r['total'],
          'percent': r['rate'],
          'is_marked': (r['total'] as int? ?? 0) > 0,
        }).toList();
        await SchoolExportService.exportAttendanceTrendExcel(
          context: context,
          className: className,
          teacherName: _myName.isNotEmpty ? _myName : (_username ?? 'Faculty'),
          trendRows: trendRows,
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // COMMON HELPERS
  // ──────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _className(Map<String, dynamic> c) =>
      c['name']?.toString() ?? c['class_name']?.toString() ?? c['id']?.toString() ?? '';

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_monthLabel(d.month)} ${d.year}';

  String _fmtShortDate(DateTime d) =>
      '${d.day} ${_monthShort(d.month)}';

  String _monthLabel(int m) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m - 1];

  String _monthShort(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];
}
