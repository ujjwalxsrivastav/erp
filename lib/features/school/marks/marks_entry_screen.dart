import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import '../../../services/school_export_service.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  final _schoolService = SchoolService();
  final _authService = AuthService();

  // Role and Identity
  bool _isStaff = false;
  bool _isAdminRole = false;
  bool _isTeacherRole = false;
  bool _isMarksLocked = false;
  bool _isInitialising = true;

  // Selected parameters
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _students = [];

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;
  String _selectedExam = 'Half Yearly';
  List<String> _examSessions = [
    'Half Yearly',
    'Final',
    'Periodic Test 1',
    'Periodic Test 2',
    'Unit Test 1',
    'Unit Test 2'
  ];

  // Scholastic Controllers
  final Map<String, TextEditingController> _marksControllers = {};
  final Map<String, TextEditingController> _internalMarksControllers = {};
  final Map<String, TextEditingController> _remarksControllers = {};
  int _maxMarks = 80;
  int _internalMaxMarks = 20;
  final _maxMarksController = TextEditingController(text: '80');

  // Co-Scholastic & Narrative Controllers (for Class Teachers & Admins)
  Map<String, dynamic>? _selectedStudentForNarrative;
  final TextEditingController _teacherRemarkController =
      TextEditingController();
  String _selectedPromotionVerdict = 'Promoted';
  static const List<String> _promotionVerdictOptions = [
    'Promoted',
    'Promoted with Grace',
    'Eligible for Compartment',
    'Detained',
  ];

  static String _normalizePromotionVerdict(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Promoted';
    final s = raw.trim().toLowerCase();
    if (s.contains('grace') || s.contains('concession'))
      return 'Promoted with Grace';
    if (s.contains('compartment') || s.contains('retest'))
      return 'Eligible for Compartment';
    if (s.contains('detained') || s.contains('failed') || s.contains('repeat'))
      return 'Detained';
    if (s.contains('promoted') || s.contains('pass')) return 'Promoted';
    return 'Promoted';
  }

  final Map<String, String> _coScholasticGrades = {
    'Work Education': 'A',
    'Art Education': 'A',
    'Health & Physical Education': 'A',
    'Discipline': 'A',
  };

  // State flags
  bool _isLoadingStudents = false;
  bool _isSavingMarks = false;
  bool _isSavingNarrative = false;
  String? _errorMessage;
  String _searchQuery = '';

  // Dedicated scroll controllers per tab (prevents ScrollController multi-attach assertion on Flutter Web)
  final ScrollController _scholasticScrollController = ScrollController();
  final ScrollController _coScholasticScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (mounted) setState(() => _isInitialising = true);
    var staffVerified = false;
    var teacherVerified = false;
    var adminVerified = false;
    try {
      final role = (await _authService.getLiveUserRole() ??
              await _authService.getCurrentUserRole() ??
              '')
          .toLowerCase()
          .trim();
      final username = await _authService.getCurrentUsername() ?? '';
      final normalizedRole = switch (role) {
        'steacher' => 'teacher',
        'sadmin' => 'admin',
        _ => role,
      };
      final isTeacher =
          normalizedRole == 'teacher' || normalizedRole == 'class_teacher';
      final isAdmin = {
        'admin',
        'principal',
        'superadmin',
      }.contains(normalizedRole);
      if (!isTeacher && !isAdmin) {
        if (mounted) {
          setState(() {
            _isStaff = false;
            _isInitialising = false;
          });
        }
        return;
      }
      staffVerified = true;
      teacherVerified = isTeacher;
      adminVerified = isAdmin;

      // Published sessions PLUS every assessment already used at marks entry,
      // so a class test created earlier stays selectable.
      final sessions = await _schoolService.getAvailableExamTypes();
      if (sessions.isNotEmpty) {
        _examSessions = sessions;
        _selectedExam = sessions.first;
      }

      // A teacher with no assigned class must see an empty state. Falling
      // back to the school-wide roster would expose every class.
      final classes = isTeacher
          ? await _schoolService.getClassTeacherClasses(username)
          : await _schoolService.getSchoolClasses();

      if (!mounted) return;
      setState(() {
        _isStaff = true;
        _isAdminRole = isAdmin;
        _isTeacherRole = isTeacher;
        _classes = classes;
        _selectedClass = classes.isNotEmpty ? classes.first : null;
        _isInitialising = false;
        if (classes.isEmpty) {
          _errorMessage = isTeacher
              ? 'Only a class teacher can enter and submit marks. No class is assigned to this account yet.'
              : 'No school classes are available.';
        }
      });

      if (_selectedClass != null) await _loadSubjectsAndStudents();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isStaff = staffVerified;
        _isTeacherRole = teacherVerified;
        _isAdminRole = adminVerified;
        _isInitialising = false;
        _errorMessage = 'Marks workspace could not be initialized: $error';
      });
    }
  }

  Future<void> _loadSubjectsAndStudents() async {
    final classId = _selectedClass?['id']?.toString();
    final className = _selectedClass?['name']?.toString() ?? '';
    if (classId == null) return;

    setState(() {
      _isLoadingStudents = true;
      _errorMessage = null;
    });

    try {
      var subjects = await _schoolService.getSchoolSubjects(classId: classId);
      final students = await _schoolService.getStudentsInClass(classId,
          className: className);

      if (!mounted) return;

      // Dispose existing controllers
      for (final c in _marksControllers.values) {
        c.dispose();
      }
      for (final c in _internalMarksControllers.values) {
        c.dispose();
      }
      for (final c in _remarksControllers.values) {
        c.dispose();
      }
      _marksControllers.clear();
      _internalMarksControllers.clear();
      _remarksControllers.clear();

      for (final s in students) {
        final sid = s['username']?.toString() ?? s['id']?.toString() ?? '';
        _marksControllers[sid] = TextEditingController();
        _internalMarksControllers[sid] = TextEditingController(text: '0');
        _remarksControllers[sid] = TextEditingController();
      }

      setState(() {
        _subjects = subjects;
        _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        _students = students;
        if (students.isNotEmpty) {
          _selectedStudentForNarrative = students.first;
        }
        _isLoadingStudents = false;
      });

      await _loadExistingMarks();
      if (_selectedStudentForNarrative != null) {
        await _loadStudentNarrative(_selectedStudentForNarrative!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStudents = false;
        _errorMessage = 'Could not load student roster: $e';
      });
    }
  }

  Future<void> _loadExistingMarks() async {
    final classId = _selectedClass?['id']?.toString();
    final subject = _selectedSubject?['name']?.toString() ??
        _selectedSubject?['id']?.toString();
    if (classId == null || subject == null) return;

    try {
      final existing = await _schoolService.getMarksByClassSubjectExam(
        classId: classId,
        subject: subject,
        examType: _selectedExam,
      );

      if (!mounted) return;

      for (final m in existing) {
        final sid = m['student_id']?.toString() ?? '';
        final obtained = m['theory_marks']?.toString() ??
            m['marks_obtained']?.toString() ??
            m['obtained_marks']?.toString() ??
            m['marks']?.toString() ??
            '';
        final remark = m['remarks']?.toString() ?? '';

        if (_marksControllers.containsKey(sid)) {
          _marksControllers[sid]!.text = obtained;
        }
        if (_internalMarksControllers.containsKey(sid)) {
          _internalMarksControllers[sid]!.text =
              m['internal_marks']?.toString() ?? '0';
        }
        if (_remarksControllers.containsKey(sid)) {
          _remarksControllers[sid]!.text = remark;
        }

        // Align max marks from DB if present
        final max = m['total_marks'] ?? m['max_marks'];
        if (max != null) {
          final maxInt = int.tryParse(max.toString());
          if (maxInt != null && maxInt != _maxMarks) {
            setState(() {
              _maxMarks = maxInt;
              _maxMarksController.text = maxInt.toString();
            });
          }
        }
      }
      _isMarksLocked = await _schoolService.permissions.isMarksLocked(
        examId: _selectedExam,
        classId: classId,
        subject: subject,
      );
      setState(() {});
    } catch (_) {}
  }

  Future<void> _loadStudentNarrative(Map<String, dynamic> student) async {
    final sid =
        student['username']?.toString() ?? student['id']?.toString() ?? '';
    if (sid.isEmpty) return;

    try {
      final meta = await _schoolService.getReportCardMeta(
        studentId: sid,
        examType: _selectedExam,
      );
      final coScholastic = await _schoolService.getCoScholastic(
        studentId: sid,
        examType: _selectedExam,
      );

      if (!mounted) return;
      setState(() {
        _teacherRemarkController.text =
            meta['teacher_remark']?.toString() ?? '';
        _selectedPromotionVerdict =
            _normalizePromotionVerdict(meta['promotion_verdict']?.toString());

        for (final item in coScholastic) {
          final area = item['area']?.toString() ?? '';
          final grade = item['grade']?.toString() ?? 'A';
          if (_coScholasticGrades.containsKey(area)) {
            _coScholasticGrades[area] = grade;
          }
        }
      });
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  // SAVE MARKS (SCHOLASTIC)
  // ──────────────────────────────────────────────
  Future<void> _saveMarks() async {
    final classId = _selectedClass?['id']?.toString() ?? '';
    final className = _selectedClass?['name']?.toString() ?? '';
    final subject = _selectedSubject?['name']?.toString() ??
        _selectedSubject?['id']?.toString() ??
        '';

    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a subject to enter marks.'),
            backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    // Validate marks bounds
    final marksList = <Map<String, dynamic>>[];
    for (final s in _students) {
      final sid = s['username']?.toString() ?? s['id']?.toString() ?? '';
      final text = _marksControllers[sid]?.text.trim() ?? '';
      final internalText = _internalMarksControllers[sid]?.text.trim() ?? '0';
      if (text.isEmpty && (internalText.isEmpty || internalText == '0'))
        continue;

      final val = double.tryParse(text.isEmpty ? '0' : text);
      final internal =
          double.tryParse(internalText.isEmpty ? '0' : internalText);
      if (val == null ||
          val < 0 ||
          val > _maxMarks ||
          internal == null ||
          internal < 0 ||
          internal > _internalMaxMarks) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Invalid marks for ${s['name'] ?? sid}. Theory: 0–$_maxMarks; internal assessment: 0–$_internalMaxMarks.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final remark = _remarksControllers[sid]?.text.trim() ?? '';

      marksList.add({
        'student_id': sid,
        'student_name': s['name'] ?? s['username'],
        'class_id': classId,
        'class_name': className,
        'section': _selectedClass?['section'] ?? '',
        'subject': subject,
        'exam_type': _selectedExam,
        'theory_marks': val,
        'internal_marks': internal,
        'marks_obtained': val + internal,
        'total_marks': (_maxMarks + _internalMaxMarks).toDouble(),
        if (remark.isNotEmpty) 'remarks': remark,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (marksList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No marks entered to save. Please type student marks in the inputs.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingMarks = true);
    bool ok;
    try {
      ok = await _schoolService.saveMarks(marksList);
    } catch (error) {
      if (mounted) {
        setState(() => _isSavingMarks = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save marks: $error'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _isSavingMarks = false);

    if (ok) {
      if (_isTeacherRole) {
        final submitted = await _schoolService.submitClassTeacherMarks(
          examId: _selectedExam,
          classId: classId,
          subject: subject,
        );
        if (!submitted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Marks were saved, but could not be submitted and locked.'),
                  backgroundColor: Color(0xFFF59E0B)),
            );
          }
          return;
        }
        _isMarksLocked = true;
      }
      final avg = marksList.fold<double>(
              0.0, (acc, m) => acc + (m['marks_obtained'] as double)) /
          marksList.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_isTeacherRole ? 'Submitted and locked' : 'Saved'} marks for ${marksList.length} students! Class Average: ${avg.toStringAsFixed(1)} / ${_maxMarks + _internalMaxMarks}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_schoolService.lastMarksError ??
              'Failed to save marks to the database.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ──────────────────────────────────────────────
  // SAVE NARRATIVE & CO-SCHOLASTIC
  // ──────────────────────────────────────────────
  Future<void> _saveNarrative() async {
    final student = _selectedStudentForNarrative;
    if (student == null) return;
    final sid =
        student['username']?.toString() ?? student['id']?.toString() ?? '';
    if (sid.isEmpty) return;

    setState(() => _isSavingNarrative = true);

    final okMeta = await _schoolService.saveReportCardMeta(
      studentId: sid,
      examType: _selectedExam,
      teacherRemark: _teacherRemarkController.text.trim(),
      promotionVerdict: _selectedPromotionVerdict,
    );

    final areasList = _coScholasticGrades.entries
        .map((e) => {'area': e.key, 'grade': e.value})
        .toList();

    final okCo = await _schoolService.saveCoScholastic(
      studentId: sid,
      examType: _selectedExam,
      areas: areasList,
    );

    if (!mounted) return;
    setState(() => _isSavingNarrative = false);

    if (okMeta && okCo) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Report Card remarks & co-scholastic grades saved for ${student['name'] ?? sid}!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_schoolService.lastMarksError ??
              'Could not save remarks. Please try again.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearAllMarks() {
    setState(() {
      for (final c in _marksControllers.values) {
        c.clear();
      }
    });
  }

  // ──────────────────────────────────────────────
  // CALCULATIONS & HELPERS
  // ──────────────────────────────────────────────
  double get _computedClassAverage {
    final values = _marksControllers.entries
        .map((entry) =>
            (double.tryParse(entry.value.text.trim()) ?? 0) +
            (double.tryParse(
                    _internalMarksControllers[entry.key]?.text.trim() ?? '') ??
                0))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int get _gradedCount {
    return _marksControllers.values
        .where((c) =>
            c.text.trim().isNotEmpty && double.tryParse(c.text.trim()) != null)
        .length;
  }

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

  @override
  void dispose() {
    _scholasticScrollController.dispose();
    _coScholasticScrollController.dispose();
    for (final c in _marksControllers.values) {
      c.dispose();
    }
    for (final c in _internalMarksControllers.values) {
      c.dispose();
    }
    for (final c in _remarksControllers.values) {
      c.dispose();
    }
    _maxMarksController.dispose();
    _teacherRemarkController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isInitialising) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Text('Assessment & Marks Entry',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: _buildLoadingSkeleton(),
      );
    }

    if (!_isStaff) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          title: const Text('Assessment & Marks Entry',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_outlined,
                    size: 54, color: Color(0xFFEF4444)),
                const SizedBox(height: 14),
                const Text(
                  'Teacher & Administrator Access Required',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Students and parents view finalized report cards via the Report Card portal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => context.go('/school/report-card'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Report Card'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
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
                'Assessment & Marks Entry',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
              ),
              Text(
                'CBSE Academic Year 2026-27 • ${_selectedExam} Session',
                style:
                    const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle:
                    TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: [
                  Tab(text: '1. Subject Marks Ledger'),
                  Tab(text: '2. Co-Scholastic & Remarks'),
                ],
              ),
            ),
          ),
          actions: [
            if (_isAdminRole)
              IconButton(
                tooltip: 'Bulk CSV Upload',
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                onPressed: () => context.push('/school/marks-csv-admin'),
              ),
            IconButton(
              tooltip: 'Preview Report Cards',
              icon: const Icon(Icons.description_outlined, size: 20),
              onPressed: () => context.push('/school/report-card'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _errorMessage != null && _classes.isEmpty
            ? _buildErrorView()
            : TabBarView(
                children: [
                  _buildScholasticTab(),
                  _buildCoScholasticTab(),
                ],
              ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: SCHOLASTIC SUBJECT MARKS LEDGER
  // ──────────────────────────────────────────────
  Widget _buildScholasticTab() {
    return Column(
      children: [
        _buildSelectionHeader(),
        _buildStatsSummaryRibbon(),
        _buildBatchActionToolBar(),
        Expanded(
          child: _isLoadingStudents
              ? _buildLoadingSkeleton()
              : _errorMessage != null
                  ? _buildErrorView()
                  : _buildStudentMarksList(),
        ),
        _buildBottomSaveDock(),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              // Class Picker
              Expanded(
                flex: 4,
                child: _buildDropdownChip<Map<String, dynamic>>(
                  label: 'Class',
                  value: _selectedClass,
                  items: _classes,
                  itemLabel: (c) =>
                      c['name']?.toString() ?? c['id']?.toString() ?? '',
                  onChanged: (v) {
                    setState(() => _selectedClass = v);
                    _loadSubjectsAndStudents();
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Subject Picker
              Expanded(
                flex: 5,
                child: _buildDropdownChip<Map<String, dynamic>>(
                  label: 'Subject',
                  value: _selectedSubject,
                  items: _subjects,
                  itemLabel: (s) =>
                      s['name']?.toString() ?? s['id']?.toString() ?? '',
                  onChanged: (v) {
                    setState(() => _selectedSubject = v);
                    _loadExistingMarks();
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Exam Session Picker
              Expanded(
                flex: 5,
                child: _buildDropdownChip<String>(
                  label: 'Exam Session',
                  value: _selectedExam,
                  items: _examSessions,
                  itemLabel: (e) => e,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedExam = v);
                      _loadExistingMarks();
                      if (_selectedStudentForNarrative != null) {
                        _loadStudentNarrative(_selectedStudentForNarrative!);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              _buildNewAssessmentButton(),
            ],
          ),
          const SizedBox(height: 10),
          if (_isTeacherRole && _isMarksLocked)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                    'Submitted to administration — marks are locked for teachers.',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB45309))),
              ),
            ),
          Row(
            children: [
              // Max Marks Config
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Max Marks: ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B))),
                    SizedBox(
                      width: 44,
                      height: 28,
                      child: TextField(
                        controller: _maxMarksController,
                        readOnly: _isTeacherRole && _isMarksLocked,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A)),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF0F172A))),
                        ),
                        onSubmitted: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            setState(() => _maxMarks = parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Search Filter
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Filter student by name or roll…',
                      hintStyle:
                          TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 16, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Teachers can name their own assessment (class test, unit test, …)
  /// without asking the admin to create a report-card session first.
  Widget _buildNewAssessmentButton() {
    return Tooltip(
      message: 'New assessment (Class Test, Unit Test …)',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _addCustomAssessment,
        child: Container(
          width: 40,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Icon(Icons.add_rounded,
              size: 18, color: Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Future<void> _addCustomAssessment() async {
    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New assessment',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Name it e.g. "Class Test 1" or "Periodic Test 3". Marks are saved '
              'under this name for the selected class and subject, and students '
              'can pick the same name in their report card.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Assessment name',
                hintText: 'Class Test 1',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Use this name'),
          ),
        ],
      ),
    );
    final name = (entered ?? '').trim();
    controller.dispose();
    if (name.isEmpty || !mounted) return;
    setState(() {
      if (!_examSessions.any((e) => e.toLowerCase() == name.toLowerCase())) {
        _examSessions = [..._examSessions, name];
      }
      _selectedExam = name;
    });
    await _loadExistingMarks();
  }

  Widget _buildDropdownChip<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: Color(0xFF64748B)),
          hint: Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildStatsSummaryRibbon() {
    final avg = _computedClassAverage;
    final total = _students.length;
    final graded = _gradedCount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _buildStatPill('Graded', '$graded / $total', const Color(0xFF0F172A),
              const Color(0xFFF1F5F9)),
          const SizedBox(width: 8),
          _buildStatPill(
              'Class Average',
              '${avg.toStringAsFixed(1)} / $_maxMarks',
              const Color(0xFF2563EB),
              const Color(0xFFEFF6FF)),
          const SizedBox(width: 8),
          _buildStatPill(
              'Average %',
              '${total == 0 ? "0" : ((avg / _maxMarks) * 100).toStringAsFixed(0)}%',
              const Color(0xFF10B981),
              const Color(0xFFECFDF5)),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.85))),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchActionToolBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          Text(
            'STUDENT LIST (${_filteredStudents.length})',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Color(0xFF64748B)),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _students.isEmpty
                ? null
                : () {
                    final studentRows = <Map<String, dynamic>>[];
                    for (int i = 0; i < _students.length; i++) {
                      final s = _students[i];
                      final sid = s['id']?.toString() ?? '';
                      final obtStr = _marksControllers[sid]?.text.trim() ?? '';
                      final obt = double.tryParse(obtStr) ?? 0.0;
                      final pct = _maxMarks > 0 ? (obt / _maxMarks) * 100 : 0.0;
                      final grade =
                          SchoolService.calculateCbseGrade(pct)['grade'];
                      final remark = _remarksControllers[sid]?.text.trim();

                      studentRows.add({
                        'rank': i + 1,
                        'roll_number': s['roll_number'] ?? '-',
                        'name': s['name'] ?? 'Student',
                        'marks_obtained': obt,
                        'total_marks': _maxMarks,
                        'percentage': pct,
                        'grade': grade,
                        'remarks': remark ?? '',
                      });
                    }

                    final cName =
                        _selectedClass?['name']?.toString() ?? 'Class';
                    SchoolExportService.exportGradebookExcel(
                      context: context,
                      className: cName,
                      examType: _selectedExam,
                      teacherName: 'Faculty',
                      students: studentRows,
                      classAverage: _computedClassAverage > 0 && _maxMarks > 0
                          ? (_computedClassAverage / _maxMarks) * 100
                          : 0.0,
                    );
                  },
            icon: const Icon(Icons.file_download_outlined, size: 14),
            label: const Text('Export Excel',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _clearAllMarks,
            icon: const Icon(Icons.clear_all_rounded, size: 14),
            label: const Text('Clear',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMarksList() {
    final list = _filteredStudents;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text('No students found for this class',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scholasticScrollController,
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return _buildStudentMarksRow(s, index);
      },
    );
  }

  Widget _buildStudentMarksRow(Map<String, dynamic> student, int index) {
    final sid =
        student['username']?.toString() ?? student['id']?.toString() ?? '';
    final roll = student['roll_number']?.toString() ??
        '${student['roll'] ?? (index + 1)}';
    final name = student['name']?.toString() ??
        student['username']?.toString() ??
        'Student';
    final ctrl = _marksControllers[sid] ?? TextEditingController();
    final internalCtrl =
        _internalMarksControllers[sid] ?? TextEditingController(text: '0');
    final remarkCtrl = _remarksControllers[sid] ?? TextEditingController();
    final readOnly = _isTeacherRole && _isMarksLocked;

    final markVal = double.tryParse(ctrl.text.trim());
    final pct =
        (markVal != null && _maxMarks > 0) ? (markVal / _maxMarks) * 100 : null;
    final gradeInfo =
        pct != null ? SchoolService.calculateCbseGrade(pct) : null;

    Color gradeBg = const Color(0xFFF1F5F9);
    Color gradeColor = const Color(0xFF64748B);
    if (gradeInfo != null) {
      if (pct! >= 75) {
        gradeBg = const Color(0xFFECFDF5);
        gradeColor = const Color(0xFF10B981);
      } else if (pct >= 50) {
        gradeBg = const Color(0xFFEFF6FF);
        gradeColor = const Color(0xFF2563EB);
      } else if (pct >= 33) {
        gradeBg = const Color(0xFFFFFBEB);
        gradeColor = const Color(0xFFD97706);
      } else {
        gradeBg = const Color(0xFFFEF2F2);
        gradeColor = const Color(0xFFEF4444);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          // Roll No Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                roll,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and ID
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
                Text(
                  sid,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Grade and % pill
          if (gradeInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: gradeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gradeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${gradeInfo['grade']} • ${pct!.toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: gradeColor),
              ),
            )
          else
            const Text('—',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),

          const SizedBox(width: 12),

          // Theory marks input
          Container(
            width: 72,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: ctrl,
              readOnly: readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                hintText: '0.0',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          Text('/$_maxMarks',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),

          const SizedBox(width: 8),
          // Internal assessment is captured separately and rolled into the
          // submitted total for the report card.
          Container(
            width: 52,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: internalCtrl,
              readOnly: readOnly,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                hintText: 'IA',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Text('/$_internalMaxMarks',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),

          const SizedBox(width: 8),
          // Remark toggle button
          IconButton(
            icon: Icon(
              remarkCtrl.text.trim().isNotEmpty
                  ? Icons.chat_bubble_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 16,
              color: remarkCtrl.text.trim().isNotEmpty
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
            ),
            tooltip: 'Add remark',
            onPressed: readOnly
                ? null
                : () => _showStudentRemarkSheet(sid, name, remarkCtrl),
          ),
        ],
      ),
    );
  }

  void _showStudentRemarkSheet(
      String sid, String name, TextEditingController ctrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rate_review_outlined,
                    color: Color(0xFF0F172A), size: 20),
                const SizedBox(width: 8),
                Text('Remark for $name',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              autofocus: true,
              decoration: InputDecoration(
                hintText:
                    'e.g. Needs practice in trigonometry, commendable effort…',
                hintStyle:
                    const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {});
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSaveDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                    '$_gradedCount of ${_students.length} Marks Entered',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${_selectedSubject?['name'] ?? ''} • $_selectedExam',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSavingMarks || (_isTeacherRole && _isMarksLocked)
                  ? null
                  : _saveMarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isSavingMarks
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(
                  _isSavingMarks
                      ? 'Saving Marks…'
                      : _isTeacherRole
                          ? (_isMarksLocked
                              ? 'Submitted to Admin'
                              : 'Submit Marks to Admin')
                          : 'Save Changes',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: CO-SCHOLASTIC & TEACHER REMARKS
  // ──────────────────────────────────────────────
  Widget _buildCoScholasticTab() {
    return ListView(
      controller: _coScholasticScrollController,
      primary: false,
      padding: const EdgeInsets.all(16),
      children: [
        // Guidance Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.stars_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CBSE Co-Scholastic & Narrative Assessment',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E40AF)),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Grades entered here populate Part 2 (Co-Scholastic) and Class Teacher Remarks directly on the official student report card.',
                      style:
                          TextStyle(fontSize: 11.5, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Student Selector Dropdown
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
              const Text('Select Student for Narrative Assessment',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569))),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: () {
                      if (_selectedStudentForNarrative == null ||
                          _students.isEmpty) return null;
                      final sId = _selectedStudentForNarrative!['id'] ??
                          _selectedStudentForNarrative!['username'];
                      try {
                        return _students.firstWhere(
                          (s) => (s['id'] ?? s['username']) == sId,
                        );
                      } catch (_) {
                        return _students.first;
                      }
                    }(),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    items: _students.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(
                          '${s['name'] ?? s['username']} (Roll: ${s['roll_number'] ?? '—'})',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A)),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedStudentForNarrative = v);
                        _loadStudentNarrative(v);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Co-Scholastic Areas
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
              const Text('Co-Scholastic 3-Point Scale (A, B, C)',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              ..._coScholasticGrades.keys.map((area) {
                final currentGrade = _coScholasticGrades[area] ?? 'A';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          area,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937)),
                        ),
                      ),
                      Row(
                        children: ['A', 'B', 'C'].map((g) {
                          final isSel = currentGrade == g;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _coScholasticGrades[area] = g),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isSel
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Narrative Remark & Promotion Verdict
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
              const Text('Class Teacher Narrative Remark',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              TextField(
                controller: _teacherRemarkController,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'e.g. Shows exceptional dedication and analytical aptitude. Active participant in classroom seminars.',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Promotion Verdict (End of Term)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _promotionVerdictOptions
                            .contains(_selectedPromotionVerdict)
                        ? _selectedPromotionVerdict
                        : _normalizePromotionVerdict(_selectedPromotionVerdict),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(
                          value: 'Promoted',
                          child: Text('Promoted to Next Higher Grade',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981)))),
                      DropdownMenuItem(
                          value: 'Promoted with Grace',
                          child: Text('Promoted with Grace / Concession',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD97706)))),
                      DropdownMenuItem(
                          value: 'Eligible for Compartment',
                          child: Text('Eligible for Compartment / Retest',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444)))),
                      DropdownMenuItem(
                          value: 'Detained',
                          child: Text('Detained in Current Grade',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF991B1B)))),
                    ],
                    onChanged: (v) {
                      if (v != null)
                        setState(() => _selectedPromotionVerdict = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isSavingNarrative ? null : _saveNarrative,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isSavingNarrative
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                      _isSavingNarrative
                          ? 'Saving Narrative…'
                          : 'Save Remarks & Co-Scholastic',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // SKELETON & ERROR
  // ──────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      primary: false,
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (ctx, i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 10),
            Text(_errorMessage ?? 'Failed to load data',
                style:
                    const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _classes.isEmpty ? _init : _loadSubjectsAndStudents,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
