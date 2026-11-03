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
  bool _loadingMonthly = false;

  // Save state
  bool _saving = false;

  static const _statusColors = {
    'present': Color(0xFF10B981),
    'absent': Color(0xFFEF4444),
    'late': Color(0xFFF59E0B),
    'leave': Color(0xFF6366F1),
  };

  static const _statusIcons = {
    'present': Icons.check_circle,
    'absent': Icons.cancel,
    'late': Icons.watch_later,
    'leave': Icons.beach_access,
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
      _isEditable = role == 'teacher' || role == 'admin' || role == 'sadmin' || role == 'steacher';
    });
    await _resolveInstituteId();
    await _loadClasses();
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

    setState(() {
      _loadingStudents = true;
      _studentsError = null;
      _students = [];
      _attendanceMap = {};
    });

    try {
      final students = await _schoolService.getStudentsInClass(classId);
      final existing = await _schoolService.getAttendance(
        classId: classId,
        date: _selectedDate,
      );

      // Build map: studentId -> status
      final attMap = <String, String>{};
      for (final a in existing) {
        final sid = a['student_id']?.toString() ?? '';
        final status = a['status']?.toString() ?? 'present';
        if (sid.isNotEmpty) attMap[sid] = status;
      }

      // Default unrecorded students to 'present'
      for (final s in students) {
        final sid = s['id']?.toString() ?? '';
        if (sid.isNotEmpty && !attMap.containsKey(sid)) {
          attMap[sid] = 'present';
        }
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _attendanceMap = attMap;
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

    setState(() => _loadingMonthly = true);

    try {
      final from = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final to = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

      final report = await _schoolService.getAttendanceReport(
        classId: classId,
        from: from,
        to: to,
      );

      // Group by date
      final Map<String, Map<String, dynamic>> summary = {};
      for (final r in report) {
        final date = r['date']?.toString() ?? '';
        if (date.isEmpty) continue;
        summary[date] ??= {'present': 0, 'absent': 0, 'late': 0, 'leave': 0, 'total': 0};
        final status = r['status']?.toString() ?? '';
        if (_statusColors.containsKey(status)) {
          summary[date]![status] = (summary[date]![status] as int) + 1;
        }
        summary[date]!['total'] = (summary[date]!['total'] as int) + 1;
      }

      if (!mounted) return;
      setState(() {
        _monthlySummary = summary;
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
      });
      await _loadStudentsAndAttendance();
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedClass == null || _students.isEmpty) return;
    setState(() => _saving = true);

    final classId = _selectedClass!['id']?.toString() ?? '';
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);

    final records = _students.map((s) {
      final sid = s['id']?.toString() ?? '';
      return {
        'class_id': classId,
        'student_id': sid,
        'date': dateStr,
        'status': _attendanceMap[sid] ?? 'present',
      };
    }).toList();

    final success = await _schoolService.markAttendance(records);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Attendance saved: $_presentCount present, $_absentCount absent, $_lateCount late'
              : 'Failed to save attendance. Please try again.',
        ),
        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (success) _monthlySummary = {};
  }

  // ─── Counts ───
  int get _presentCount => _attendanceMap.values.where((s) => s == 'present').length;
  int get _absentCount => _attendanceMap.values.where((s) => s == 'absent').length;
  int get _lateCount => _attendanceMap.values.where((s) => s == 'late').length;
  int get _leaveCount => _attendanceMap.values.where((s) => s == 'leave').length;

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Daily', icon: Icon(Icons.list_alt, size: 18)),
            Tab(text: 'Monthly', icon: Icon(Icons.calendar_month, size: 18)),
          ],
        ),
        actions: [
          if (_isEditable && _tabController.index == 0)
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
                    icon: const Icon(Icons.save, color: Colors.white, size: 20),
                    label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
        ],
      ),
      body: _loadingClasses
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
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

  // ─── Daily Tab ───
  Widget _buildDailyTab() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildStudentList()),
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
              _buildStatChip('Total', _students.length, Colors.white.withOpacity(0.2), Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          // Date picker row
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
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
                color: Colors.white.withOpacity(0.15),
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
    final sid = student['id']?.toString() ?? '';
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
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Roll number avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
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
          if (_isEditable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusButton(sid, 'present', const Color(0xFF10B981), Icons.check),
                const SizedBox(width: 5),
                _buildStatusButton(sid, 'absent', const Color(0xFFEF4444), Icons.close),
                const SizedBox(width: 5),
                _buildStatusButton(sid, 'late', const Color(0xFFF59E0B), Icons.watch_later_outlined),
                const SizedBox(width: 5),
                _buildStatusButton(sid, 'leave', const Color(0xFF6366F1), Icons.beach_access_outlined),
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
    return GestureDetector(
      onTap: () => setState(() => _attendanceMap[studentId] = status),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
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
                  : _MonthlyAttendanceView(summary: _monthlySummary),
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
          Text(label, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8))),
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

  const _MonthlyAttendanceView({required this.summary});

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
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
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
