import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../services/school_export_service.dart';

/// Full-screen roster of every student in the sections where the signed-in
/// teacher is the class teacher (`school_classes.class_teacher_id`). Reached
/// from the dashboard's "My Students Roster" strip via "See more".
class SchoolClassStudentsScreen extends StatefulWidget {
  const SchoolClassStudentsScreen({super.key});

  @override
  State<SchoolClassStudentsScreen> createState() =>
      _SchoolClassStudentsScreenState();
}

class _SchoolClassStudentsScreenState extends State<SchoolClassStudentsScreen> {
  final _authService = AuthService();
  final _schoolService = SchoolService();

  String _teacherName = 'Teacher';
  List<Map<String, dynamic>> _classTeacherClasses = [];
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedClassFilter = 'all';
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = await _authService.getCurrentUsername() ?? '';

      final results = await Future.wait([
        _schoolService
            .getTeacherDisplayName(username)
            .catchError((_) => null as String?),
        _schoolService
            .getClassTeacherClasses(username)
            .catchError((_) => <Map<String, dynamic>>[]),
        _schoolService
            .getStudentsForClassTeacher(username)
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final ctClasses =
          results[1] as List<Map<String, dynamic>>;
      var students = results[2] as List<Map<String, dynamic>>;

      // Attendance enrichment: one read per class-teacher section instead of
      // one query per student, keyed by the student username.
      final attendanceByStudent = <String, double>{};
      try {
        final maps = await Future.wait(ctClasses.map((c) {
          final classId = (c['id'] ?? c['class_id'] ?? '').toString();
          if (classId.isEmpty) return Future.value(<String, double>{});
          return _schoolService
              .getClassAttendancePercents(
                classId: classId,
                className: c['name']?.toString(),
              )
              .catchError((_) => <String, double>{});
        }));
        for (final map in maps) {
          attendanceByStudent.addAll(map);
        }
      } catch (_) {}

      students = students.map((s) {
        final username2 = s['username']?.toString() ?? '';
        final id = s['id']?.toString() ?? '';
        return <String, dynamic>{
          ...s,
          'attendance_pct':
              attendanceByStudent[username2] ?? attendanceByStudent[id] ?? 0.0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          final displayName = results[0] as String?;
          _teacherName = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : (username.isEmpty ? 'Teacher' : username);
          _classTeacherClasses = ctClasses;
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load the class roster. Please retry.';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _searchQuery.trim().toLowerCase();
    return _students.where((s) {
      if (_selectedClassFilter != 'all') {
        final sid = (s['class_id'] ?? s['id'] ?? '').toString();
        final sname = (s['class_name'] ?? '').toString();
        final sel = _selectedClassFilter;
        if (sid != sel &&
            sname != sel &&
            !sname.toLowerCase().contains(sel.toLowerCase())) {
          return false;
        }
      }
      if (query.isEmpty) return true;
      final name =
          (s['name'] ?? s['student_name'] ?? '').toString().toLowerCase();
      final roll =
          (s['roll_number'] ?? s['roll_no'] ?? '').toString().toLowerCase();
      final adm = (s['admission_no'] ?? s['id'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          roll.contains(query) ||
          adm.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStudents;
    final hasClassTeacherClasses = _classTeacherClasses.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Class Students',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
            ),
            Text(
              'All students of your class-teacher section',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Export roster to Excel',
            onPressed: _students.isEmpty || _isLoading
                ? null
                : () {
                    final classLabel = _selectedClassFilter == 'all'
                        ? (_classTeacherClasses.length == 1
                            ? (_classTeacherClasses.first['name']?.toString() ??
                                'Class')
                            : 'All Sections')
                        : _classTeacherClasses
                                .firstWhere(
                                  (c) =>
                                      (c['id']?.toString() ??
                                          c['class_id']?.toString() ??
                                          '') ==
                                      _selectedClassFilter,
                                  orElse: () =>
                                      {'name': _selectedClassFilter},
                                )['name']
                                ?.toString() ??
                            _selectedClassFilter;
                    SchoolExportService.exportClassRosterExcel(
                      context: context,
                      className: classLabel,
                      teacherName: _teacherName,
                      students: filtered,
                    );
                  },
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Color(0xFF2563EB))),
                  SizedBox(height: 12),
                  Text('Loading class roster...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      Text(_errorMessage!,
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 13)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _loadData,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB)),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : !hasClassTeacherClasses
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.co_present_outlined,
                              size: 44, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text(
                            'You are not a class teacher for any section.',
                            style: TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'This page lists the students of sections where you are assigned as the class teacher.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF64748B), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF2563EB),
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Search box
                          TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText:
                                  'Search student by name, roll number, or admission ID...',
                              hintStyle: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 20, color: Color(0xFF64748B)),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded,
                                          size: 18, color: Color(0xFF64748B)),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 14),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF2563EB), width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Section filter chips (only when there is more than one)
                          if (_classTeacherClasses.length > 1) ...[
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: Text(
                                        'All Sections (${_students.length})'),
                                    selected: _selectedClassFilter == 'all',
                                    onSelected: (sel) {
                                      if (sel &&
                                          _selectedClassFilter != 'all') {
                                        setState(() =>
                                            _selectedClassFilter = 'all');
                                      }
                                    },
                                    selectedColor: const Color(0xFF0F172A),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    labelStyle: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: _selectedClassFilter == 'all'
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    side: BorderSide.none,
                                  ),
                                  const SizedBox(width: 8),
                                  ..._classTeacherClasses.map((c) {
                                    final cid = (c['id'] ?? c['class_id'] ?? '')
                                        .toString();
                                    final cname = (c['section'] != null &&
                                            c['section'].toString().isNotEmpty &&
                                            !(c['name']?.toString() ?? '')
                                                .contains(
                                                    c['section'].toString()))
                                        ? '${c['name']}-${c['section']}'
                                        : (c['name']?.toString() ?? 'Class');
                                    final isSelected =
                                        _selectedClassFilter == cid;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(cname),
                                        selected: isSelected,
                                        onSelected: (sel) {
                                          if (sel &&
                                              _selectedClassFilter != cid) {
                                            setState(() =>
                                                _selectedClassFilter = cid);
                                          }
                                        },
                                        selectedColor: const Color(0xFF0F172A),
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        labelStyle: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF475569),
                                        ),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        side: BorderSide.none,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Result count
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              '${filtered.length} student${filtered.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF475569)),
                            ),
                          ),

                          // Student list
                          if (filtered.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off_rounded,
                                        size: 36, color: Color(0xFF94A3B8)),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No students matching "$_searchQuery".'
                                          : 'No enrolled students found in this section.',
                                      style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...filtered.map(_buildStudentRow),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> s) {
    final name = (s['name'] ?? s['student_name'] ?? 'Student').toString();
    final roll = (s['roll_number'] ?? s['roll_no'] ?? '-').toString();
    final adm =
        (s['admission_no'] ?? s['username'] ?? s['id'] ?? '-').toString();
    final contact = (s['contact'] ?? s['parent_contact'] ?? '').toString();
    final className = (s['class_name'] ?? s['class_id'] ?? 'Class').toString();
    final attPct = (s['attendance_pct'] as num?)?.toDouble() ?? 0.0;
    final isAtRisk = attPct > 0 && attPct < 75.0;

    final nameParts = name.trim().split(RegExp(r'\s+'));
    final initials = nameParts.length >= 2
        ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
        : (name.isNotEmpty
            ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase()
            : 'ST');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                isAtRisk ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor:
                isAtRisk ? const Color(0xFFFEE2E2) : const Color(0xFFEFF6FF),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isAtRisk
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll: $roll • Adm: $adm',
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Contact: $contact',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    className,
                    style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: attPct <= 0
                  ? const Color(0xFFF1F5F9)
                  : (isAtRisk
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFECFDF5)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: attPct <= 0
                    ? const Color(0xFFCBD5E1)
                    : (isAtRisk
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFA7F3D0)),
              ),
            ),
            child: Text(
              attPct <= 0
                  ? 'Att. --'
                  : '${attPct.toStringAsFixed(0)}% Att',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: attPct <= 0
                    ? const Color(0xFF64748B)
                    : (isAtRisk
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
