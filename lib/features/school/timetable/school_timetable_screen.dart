import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../services/auth_service.dart';
import '../../../services/school_service.dart';
import 'widgets/timetable_components.dart';

class SchoolTimetableScreen extends StatefulWidget {
  final String? initialClassId;
  const SchoolTimetableScreen({super.key, this.initialClassId});

  @override
  State<SchoolTimetableScreen> createState() => _SchoolTimetableScreenState();
}

class _SchoolTimetableScreenState extends State<SchoolTimetableScreen>
    with SingleTickerProviderStateMixin {
  final SchoolService _service = SchoolService();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Role & student context
  bool _isStudent = false;
  bool _isParent = false;
  bool _isTeacher = false;
  bool _canEdit = false;
  bool _isRoleLoaded = false;
  String _studentClassLabel = '';
  String _selectedStudentUsername = '';
  List<Map<String, dynamic>> _parentChildren = [];

  // Timetable State
  String _selectedClassId = '';
  String _selectedClassLabel = '';
  String _selectedDay = 'Monday';
  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _periods = [];
  bool _isLoadingTimetable = true;
  String? _timetableError;

  // Substitution State
  final List<String> _absentTeachers = [];
  List<Map<String, dynamic>> _uncoveredPeriods = [];
  List<Map<String, dynamic>> _substitutionLogs = [];
  String? _substitutionError;
  bool _isLoadingSubstitutions = false;
  List<String> _allTeachers = [];

  // Syllabus / Lesson Plan State
  List<Map<String, dynamic>> _lessonPlans = [];
  Map<String, dynamic>? _syllabusSummary;
  bool _isLoadingSyllabus = false;
  String? _syllabusError;

  final List<Color> _subjectPalette = [
    const Color(0xFF2563EB), // Blue
    const Color(0xFF059669), // Emerald
    const Color(0xFF7C3AED), // Violet
    const Color(0xFFD97706), // Amber
    const Color(0xFFDC2626), // Rose/Red
    const Color(0xFF0284C7), // Sky
    const Color(0xFF4F46E5), // Indigo
  ];

  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _primary = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    // Default 3 tabs for admin/teacher; will re-sync to 1 if student
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);

    final todayWeekday = DateFormat('EEEE').format(DateTime.now());
    if (_days.contains(todayWeekday)) {
      _selectedDay = todayWeekday;
    }

    if (widget.initialClassId != null && widget.initialClassId!.isNotEmpty) {
      _selectedClassId = widget.initialClassId!;
    }
    _init();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1) _loadSubstitutionData();
      if (_tabController.index == 2) _loadSyllabusData();
    }
  }

  /// Anyone may fail to load their own routine (no class assigned, network
  /// hiccup, …). Without a guard the whole screen would sit on the spinner
  /// forever, so failures surface as a message with a retry.
  Future<void> _init() async {
    try {
      await _loadRoleAndTimetable();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRoleLoaded = true;
        _isLoadingTimetable = false;
        _timetableError = 'Could not load your timetable: $error';
      });
    }
  }

  Future<void> _loadRoleAndTimetable() async {
    final role = await _authService.getCurrentUserRole();
    if (!mounted) return;

    final isStudent = role == 'student' || role == 'sstudent' || role == 'parent' || role == 'sparent';
    final isParent = role == 'parent' || role == 'sparent';
    final isTeacher = role == 'teacher' || role == 'steacher' || role == 'class_teacher';
    final canEdit = role == 'admin' || role == 'sadmin';

    // Synchronize tab controller length based on role
    final requiredLength = isStudent ? 1 : (isTeacher ? 2 : 3);
    if (_tabController.length != requiredLength) {
      _tabController.removeListener(_handleTabSelection);
      _tabController.dispose();
      _tabController = TabController(length: requiredLength, vsync: this);
      _tabController.addListener(_handleTabSelection);
    }

    setState(() {
      _isStudent = isStudent;
      _isParent = isParent;
      _isTeacher = isTeacher;
      _canEdit = canEdit;
      _isRoleLoaded = true;
    });

    // Students: resolve their OWN class from the backend — no class picker.
    if (_isStudent) {
      final username = await _authService.getCurrentUsername() ?? '';
      final children = _isParent ? await _service.getParentChildren(username) : <Map<String, dynamic>>[];
      final profile = _isParent
          ? (children.isEmpty ? null : children.first)
          : await _service.getSchoolStudentProfile(username);
      if (profile != null) {
        final classId = profile['class_id']?.toString();
        final className = profile['class_name']?.toString() ?? '';
        if (mounted) {
          setState(() {
            _studentClassLabel = className;
            _selectedStudentUsername = profile['username']?.toString() ?? '';
            _parentChildren = children;
            if (classId != null && classId.isNotEmpty)
              _selectedClassId = classId;
            _selectedClassLabel = className;
          });
        }
      }
      if (_selectedClassId.isEmpty && _studentClassLabel.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoadingTimetable = false;
            _timetableError = 'Your class is not assigned yet. '
                'Please contact the school office.';
          });
        }
        return;
      }
      await _loadTimetableOnly();
      return;
    }

    _loadClassesAndTimetable();
  }

  /// Students only need the routine grid — no class list involved.
  Future<void> _loadTimetableOnly() async {
    setState(() {
      _isLoadingTimetable = true;
      _timetableError = null;
    });
    try {
      final username = await _authService.getCurrentUsername() ?? '';
      final entries = await _service.getMyTimetable(
        username: username,
        studentUsername: _isParent ? _selectedStudentUsername : null,
        day: _selectedDay,
      );
      if (mounted) {
        setState(() {
          _periods = entries;
          _isLoadingTimetable = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _timetableError = 'Failed to load timetable: $e';
          _isLoadingTimetable = false;
        });
      }
    }
  }

  /// Day change / refresh — students skip the class-list fetch entirely so
  /// their auto-resolved class id is never overwritten.
  Future<void> _reloadTimetable() {
    return _isStudent ? _loadTimetableOnly() : _loadClassesAndTimetable();
  }

  Future<void> _loadClassesAndTimetable() async {
    setState(() {
      _isLoadingTimetable = true;
      _timetableError = null;
    });

    try {
      final username = await _authService.getCurrentUsername() ?? '';
      final classes = _isTeacher
          ? await _service.getTeacherAllAssignedClasses(username)
          : await _service.getSchoolClasses();
      _classes = classes.map((c) => <String, dynamic>{
        ...c,
        'id': c['class_id'] ?? c['id'],
        'name': c['class_name'] ?? c['name'] ?? c['class_id'] ?? c['id'],
      }).where((c) => (c['id']?.toString() ?? '').isNotEmpty).toList();

      // Never offer the same class twice (guard against duplicate backend rows)
      final seen = <String>{};
      _classes =
          _classes.where((c) => seen.add(c['id']?.toString() ?? '')).toList();

      if (_classes.isEmpty) {
        if (mounted) setState(() {
          _periods = [];
          _isLoadingTimetable = false;
        });
        return;
      }

      // The selected class id must exist in the list, or the dropdown crashes.
      final ids = _classes.map((c) => c['id']?.toString() ?? '').toSet();
      if (!ids.contains(_selectedClassId)) {
        _selectedClassId = _classes.first['id']?.toString() ?? _selectedClassId;
      }
      _syncSelectedClassLabel();

      final selected = _classes.firstWhere(
        (c) => (c['id']?.toString() ?? '') == _selectedClassId,
        orElse: () => <String, dynamic>{},
      );
      final entries = await _service.getTimetableForClass(
        _selectedClassId,
        day: _selectedDay,
        className: selected['name']?.toString(),
      );
      final scopedEntries = _isTeacher
          ? entries.where((row) =>
              row['teacher_username']?.toString().toLowerCase() == username.toLowerCase()).toList()
          : entries;

      _allTeachers = _isTeacher ? [] : await _service.getSchoolTeachersList();

      if (mounted) {
        setState(() {
          _periods = scopedEntries;
          _isLoadingTimetable = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _timetableError = 'Failed to load timetable: $e';
          _isLoadingTimetable = false;
        });
      }
    }
  }

  /// Keep the header label in sync with the selected class row.
  void _syncSelectedClassLabel() {
    final match = _classes
        .where((c) => (c['id']?.toString() ?? '') == _selectedClassId)
        .toList();
    if (match.isNotEmpty) {
      final c = match.first;
      _selectedClassLabel =
          c['name']?.toString() ?? c['id']?.toString() ?? _selectedClassId;
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSubstitutionData() async {
    setState(() {
      _isLoadingSubstitutions = true;
      _substitutionError = null;
    });
    try {
      if (_isTeacher) {
        final username = await _authService.getCurrentUsername() ?? '';
        final requests = await _service.getSubstitutionRequests(
          teacherUsername: username,
          date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
        if (mounted) setState(() {
          _substitutionLogs = requests;
          _uncoveredPeriods = [];
          _isLoadingSubstitutions = false;
        });
        return;
      }
      final uncovered = await _service.getUncoveredPeriods(
        day: _selectedDay,
        absentTeachers: _absentTeachers,
      );
      final logs = await _service.getSubstitutionLogs();

      if (mounted) {
        setState(() {
          _uncoveredPeriods = uncovered;
          _substitutionLogs = logs;
          _isLoadingSubstitutions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _substitutionError = 'Substitution data could not be loaded.';
        _isLoadingSubstitutions = false;
      });
    }
  }

  Future<void> _respondToSubstitution(
      Map<String, dynamic> request, bool accept) async {
    final id = request['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await _service.respondToSubstitution(circularId: id, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept ? 'Substitution accepted.' : 'Substitution declined.'),
      ));
      await _loadSubstitutionData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not respond to offer: $error')),
      );
    }
  }

  Future<void> _loadSyllabusData() async {
    setState(() {
      _isLoadingSyllabus = true;
      _syllabusError = null;
    });
    try {
      final plans = await _service.getLessonPlans(classId: _selectedClassId);
      final summary =
          await _service.getSyllabusCoverageReport(_selectedClassId);

      if (mounted) {
        setState(() {
          _lessonPlans = plans;
          _syllabusSummary = summary;
          _isLoadingSyllabus = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() {
        _syllabusError = 'Syllabus data could not be loaded: $error';
        _isLoadingSyllabus = false;
      });
    }
  }

  Color _getSubjectColor(String subject) {
    final hash = subject.codeUnits.fold(0, (acc, c) => acc + c);
    return _subjectPalette[hash % _subjectPalette.length];
  }

  // ==========================================
  // DIALOGS & ACTIONS
  // ==========================================

  void _showAddEditSlotDialog({Map<String, dynamic>? existingSlot}) {
    final isEdit = existingSlot != null;
    final periodCtrl = TextEditingController(
        text: isEdit ? existingSlot['period'].toString() : '1');
    final startCtrl = TextEditingController(
        text: isEdit ? existingSlot['start_time'] ?? '' : '08:00 AM');
    final endCtrl = TextEditingController(
        text: isEdit ? existingSlot['end_time'] ?? '' : '08:45 AM');
    final subjectCtrl = TextEditingController(
        text: isEdit ? existingSlot['subject'] ?? '' : 'Mathematics');
    final roomCtrl = TextEditingController(
        text: isEdit ? existingSlot['room'] ?? '' : 'Room 101');

    String selectedDay =
        isEdit ? existingSlot['day'] ?? _selectedDay : _selectedDay;
    String selectedTeacher = isEdit
        ? existingSlot['teacher_username']?.toString() ?? ''
        : (_allTeachers.isNotEmpty ? _allTeachers.first : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Timetable Slot' : 'Add Timetable Slot',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: _muted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedDay,
                            decoration: InputDecoration(
                              labelText: 'Day',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: _days
                                .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d,
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null)
                                setSheetState(() => selectedDay = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: periodCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Period (1-8)',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startCtrl,
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              hintText: '08:00 AM',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endCtrl,
                            decoration: InputDecoration(
                              labelText: 'End Time',
                              hintText: '08:45 AM',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        hintText: 'e.g. Mathematics',
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedTeacher,
                            decoration: InputDecoration(
                              labelText: 'Teacher',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            items: _allTeachers
                                .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t,
                                        style: const TextStyle(fontSize: 13))))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setSheetState(() => selectedTeacher = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: roomCtrl,
                            decoration: InputDecoration(
                              labelText: 'Room',
                              hintText: 'Room 101',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final periodNum = int.tryParse(periodCtrl.text) ?? 1;
                          try {
                            await _service.saveTimetableEntry(
                              id: isEdit ? existingSlot['id'] : null,
                              classId: _selectedClassId,
                              day: selectedDay,
                              period: periodNum,
                              startTime: startCtrl.text.trim(),
                              endTime: endCtrl.text.trim(),
                              subject: subjectCtrl.text.trim(),
                              teacherUsername: selectedTeacher,
                              room: roomCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Timetable slot saved & published!'),
                                  backgroundColor: Color(0xFF059669),
                                ),
                              );
                              _loadClassesAndTimetable();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Error: ${e.toString().replaceAll('Exception: ', '')}'),
                                backgroundColor: const Color(0xFFDC2626),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        child: Text(
                          isEdit
                              ? 'Update Slot'
                              : 'Publish Slot (Clash Checked)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubstituteAssignDialog(Map<String, dynamic> uncovered) async {
    final periodId = uncovered['id']?.toString() ?? '';
    final day = uncovered['day']?.toString() ?? _selectedDay;
    final period = int.tryParse(uncovered['period']?.toString() ?? '1') ?? 1;
    final subject = uncovered['subject']?.toString() ?? '';
    final classId = uncovered['class_id']?.toString() ?? _selectedClassId;
    final origTeacher = uncovered['teacher_username']?.toString() ?? '';
    final room = uncovered['room']?.toString() ?? '';
    final time = '${uncovered['start_time'] ?? ''} - ${uncovered['end_time'] ?? ''}';

    final available = await _service.getAvailableSubstitutes(
      day: day,
      period: period,
      preferredSubject: subject,
    );

    if (!mounted) return;

    String? chosenSubstitute =
        available.isNotEmpty ? available.first['username'] : null;
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: _primary, size: 22),
                  SizedBox(width: 8),
                  Text('Assign Substitute',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Period $period ($time) • $classId',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _ink)),
                        const SizedBox(height: 3),
                        Text('Subject: $subject • Room: $room',
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                        const SizedBox(height: 3),
                        Text('Absent Teacher: $origTeacher',
                            style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Select Recommended Substitute:',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: _ink)),
                  const SizedBox(height: 6),
                  if (available.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No free teachers in this slot!',
                          style: TextStyle(
                              color: Color(0xFFDC2626), fontSize: 12)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: chosenSubstitute,
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: available.map((s) {
                        final isOver = s['isOverloaded'] == true;
                        return DropdownMenuItem<String>(
                          value: s['username'],
                          child: Text(
                            '${s['username']} (Load: ${s['currentLoad']}/5)${isOver ? ' [Capped]' : ' [Free]'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isOver ? const Color(0xFFD97706) : _ink,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setDialogState(() => chosenSubstitute = v);
                      },
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                      labelText: 'Instructions / Notes',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: _muted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: chosenSubstitute == null
                      ? null
                      : () async {
                          try {
                            await _service.assignSubstitute(
                              absentTeacherUsername: origTeacher,
                              periodId: periodId,
                              substituteUsername: chosenSubstitute!,
                              notes: notesCtrl.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Assigned $chosenSubstitute! Instant alert issued.'),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                              _loadSubstitutionData();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: const Color(0xFFDC2626)),
                            );
                          }
                        },
                  child: const Text('Assign & Notify'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddLessonPlanDialog() {
    final chapterCtrl = TextEditingController(text: 'Chapter 5');
    final topicCtrl = TextEditingController(text: 'Arithmetic Progressions');
    final dateCtrl = TextEditingController(
        text: DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String()
            .split('T')[0]);
    final objectiveCtrl = TextEditingController(
        text: 'Identify AP patterns and calculate nth terms using formula.');
    final resourcesCtrl = TextEditingController(
        text: 'NCERT Textbook, Digital Smart Board, GeoGebra Simulation');
    String selectedSubject = 'Mathematics';
    String selectedTeacher = _allTeachers.isNotEmpty ? _allTeachers.first : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Create Lesson Plan',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 20, color: _muted),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: chapterCtrl,
                        decoration: InputDecoration(
                          labelText: 'Chapter / Unit',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: dateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Target Date',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: topicCtrl,
                  decoration: InputDecoration(
                    labelText: 'Topic Title',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: objectiveCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Pedagogical Learning Objectives',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: resourcesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Resources & Equipment',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      try {
                        await _service.submitLessonPlan(
                          classId: _selectedClassId,
                          subject: selectedSubject,
                          teacherUsername: selectedTeacher,
                          chapter: chapterCtrl.text.trim(),
                          topic: topicCtrl.text.trim(),
                          plannedDate: dateCtrl.text.trim(),
                          objective: objectiveCtrl.text.trim(),
                          resources: resourcesCtrl.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Lesson plan submitted & approved!'),
                              backgroundColor: Color(0xFF059669),
                            ),
                          );
                          _loadSyllabusData();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: const Color(0xFFDC2626)),
                        );
                      }
                    },
                    child: const Text('Save Lesson Plan',
                        style: TextStyle(fontWeight: FontWeight.w700)),
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
  // TAB 1: TIMETABLE GRID
  // ==========================================

  Widget _buildTimetableTab() {
    if (_isLoadingTimetable) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_timetableError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(_timetableError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: _muted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _reloadTimetable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isTeacher && _classes.isEmpty) {
      return Center(
        child: const Text('No classes are allotted to your account.'),
      );
    }

    return Column(
      children: [
        // Class & Day Control Strip
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Selector Row
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: _primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  if (_isStudent)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                color: _muted, size: 13),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Enrolled Section: $_studentClassLabel',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _classes.any((c) =>
                                    (c['id']?.toString() ?? '') ==
                                    _selectedClassId)
                                ? _selectedClassId
                                : null,
                            hint: Text(
                                _selectedClassLabel.isEmpty
                                    ? (_selectedClassId.isEmpty
                                        ? 'Select class'
                                        : _selectedClassId)
                                    : _selectedClassLabel,
                                style:
                                    const TextStyle(fontSize: 13, color: _ink)),
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: _muted),
                            style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            isExpanded: true,
                            items: _classes.map((c) {
                              final name = c['name']?.toString() ??
                                  c['id']?.toString() ??
                                  'Unknown';
                              return DropdownMenuItem<String>(
                                value: c['id']?.toString(),
                                child:
                                    Text(name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedClassId = v);
                                _syncSelectedClassLabel();
                                _loadClassesAndTimetable();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_periods.length} Periods',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569)),
                    ),
                  ),
                  if (_canEdit) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          color: _primary),
                      tooltip: 'Add Period Slot',
                      onPressed: () => _showAddEditSlotDialog(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Day Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _days.map((day) {
                    final isSelected = day == _selectedDay;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDay = day);
                        _reloadTimetable();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? _primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? _primary : _border,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          day,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _muted,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Period List
        Expanded(
          child: _periods.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      Text('No classes scheduled for $_selectedDay',
                          style: const TextStyle(
                              fontSize: 13,
                              color: _muted,
                              fontWeight: FontWeight.w500)),
                      if (_canEdit) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showAddEditSlotDialog(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Period Slot'),
                        ),
                      ],
                    ],
                  ),
                )
              : PeriodGrid(
                  itemCount: _periods.length,
                  itemBuilder: (context, index) {
                    final p = _periods[index];
                    final periodNum = p['period']?.toString() ?? '${index + 1}';
                    final subject = p['subject']?.toString() ?? 'Subject';
                    final teacher =
                        p['teacher_username']?.toString() ?? 'Teacher';
                    final room = p['room']?.toString() ?? 'Room';
                    final startTime = p['start_time']?.toString() ?? '';
                    final endTime = p['end_time']?.toString() ?? '';
                    final subjectColor = _getSubjectColor(subject);

                    return PeriodCell(
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: subjectColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                'P$periodNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: subjectColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded,
                                        size: 13, color: _muted),
                                    const SizedBox(width: 4),
                                    Text(
                                      teacher,
                                      style: const TextStyle(
                                          fontSize: 11.5, color: _muted),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.meeting_room_outlined,
                                        size: 13, color: _muted),
                                    const SizedBox(width: 3),
                                    Text(
                                      room,
                                      style: const TextStyle(
                                          fontSize: 11.5, color: _muted),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  startTime.isNotEmpty
                                      ? '$startTime - $endTime'
                                      : 'Regular',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _ink,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_canEdit) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _showAddEditSlotDialog(
                                          existingSlot: p),
                                      child: const Icon(Icons.edit_outlined,
                                          size: 16, color: _muted),
                                    ),
                                    const SizedBox(width: 10),
                                    InkWell(
                                      onTap: () async {
                                        final id = p['id']?.toString();
                                        if (id != null) {
                                          await _service
                                              .deleteTimetableEntry(id);
                                          _reloadTimetable();
                                        }
                                      },
                                      child: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: Color(0xFFEF4444)),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: MORNING SUBSTITUTION COVERAGE
  // ==========================================

  Widget _buildSubstitutionTab() {
    if (_isLoadingSubstitutions) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_isTeacher) {
      if (_substitutionError != null) {
        return Center(child: Text(_substitutionError!));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Substitution offers', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_substitutionLogs.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No substitution assignments for today.'),
            ))
          else
            ..._substitutionLogs.map((row) {
              final status = row['status']?.toString() ?? 'Assigned';
              final responseActions = status == 'Assigned'
                  ? Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Accept substitution',
                          onPressed: () => _respondToSubstitution(row, true),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                        ),
                        IconButton(
                          tooltip: 'Decline substitution',
                          onPressed: () => _respondToSubstitution(row, false),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                        ),
                      ],
                    )
                  : Chip(label: Text(status));
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text('${row['subject'] ?? 'Substitution'} · Period ${row['period']}'),
                  subtitle: Text('${row['class_id']} · ${row['time']} · Room ${row['room']}'),
                  trailing: responseActions,
                ),
              );
            }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SubstitutionBanner(
          message: _absentTeachers.isEmpty
              ? 'No absences selected. Uncovered periods will appear only when a staff absence is marked.'
              : '${_absentTeachers.length} staff absence(s) selected for coverage.',
        ),
        // Absent Teachers Selector Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
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
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_off_rounded,
                        color: Color(0xFFDC2626), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Teacher Leave & Absence Roster',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _ink)),
                        Text(
                            'Tap absent teachers to calculate substitution slots',
                            style: TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allTeachers.map((teacher) {
                  final isAbsent = _absentTeachers.contains(teacher);
                  return FilterChip(
                    label: Text(teacher),
                    selected: isAbsent,
                    selectedColor: const Color(0xFFFEE2E2),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                        color: isAbsent ? const Color(0xFFFCA5A5) : _border),
                    labelStyle: TextStyle(
                      color: isAbsent ? const Color(0xFF991B1B) : _ink,
                      fontWeight: isAbsent ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11.5,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _absentTeachers.add(teacher);
                        } else {
                          _absentTeachers.remove(teacher);
                        }
                      });
                      _loadSubstitutionData();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Uncovered Periods Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Uncovered Periods Today',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _uncoveredPeriods.isEmpty
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_uncoveredPeriods.length} Pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _uncoveredPeriods.isEmpty
                      ? const Color(0xFF065F46)
                      : const Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_uncoveredPeriods.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF059669), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All periods covered! No teacher absences or all substitutions assigned.',
                    style: TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12, color: _ink),
                  ),
                ),
              ],
            ),
          )
        else
          ..._uncoveredPeriods.map((uncovered) {
            final period = uncovered['period'];
            final subject = uncovered['subject'];
            final teacher = uncovered['teacher_username'];
            final classId = uncovered['class_id'];
            final room = uncovered['room'];
            final isDone = uncovered['is_substituted'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: isDone
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        'P$period',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDone
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$subject • $classId',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _ink)),
                        const SizedBox(height: 2),
                        Text('Absent: $teacher • Room: $room',
                            style:
                                const TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDone ? const Color(0xFF059669) : _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showSubstituteAssignDialog(uncovered),
                    child: Text(isDone ? 'Reassign' : 'Assign',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 18),

        // Substitution Audit Logs
        const Text(
          'Recent Substitution Log',
          style:
              TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 8),

        if (_substitutionLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: Text('No substitution logs recorded yet.',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ),
          )
        else
          ..._substitutionLogs.take(5).map((log) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${log['substitute_teacher']} assigned for ${log['original_teacher']}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _ink)),
                        Text(
                            'P${log['period']} • ${log['class_id']} • ${log['date']}',
                            style:
                                const TextStyle(fontSize: 11, color: _muted)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Logged',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569))),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // TAB 3: LESSON PLANS & SYLLABUS TRACKING
  // ==========================================

  Widget _buildSyllabusTab() {
    if (_isLoadingSyllabus) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_syllabusError != null) {
      return Center(child: Text(_syllabusError!, textAlign: TextAlign.center));
    }

    final summary = _syllabusSummary ?? {};
    final hasSyllabusData = summary['hasData'] == true;
    final coveragePct = (summary['coveragePct'] as num?)?.toDouble() ?? 0.0;
    final isLagging = summary['isLagging'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Syllabus Coverage Dashboard Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Syllabus Coverage Progress',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink)),
                  Text('${coveragePct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isLagging
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                      )),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (coveragePct / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: isLagging
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 10),
              if (isLagging)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          summary['laggingAlert'] ??
                              'Coverage is lagging behind schedule!',
                          style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasSyllabusData)
                Text(
                  'Class $_selectedClassId is on track for board examinations.',
                  style: const TextStyle(color: _muted, fontSize: 11),
                )
              else
                Text(summary['laggingAlert']?.toString() ?? 'No syllabus data available.',
                    style: const TextStyle(color: _muted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lesson Plans Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Curriculum Units & Lesson Plans',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                  onPressed: () => context
                      .push('/school/lesson-plans?classId=$_selectedClassId'),
                  icon: const Icon(Icons.auto_stories_rounded, size: 14),
                  label: const Text('Open 5E Studio',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                  onPressed: _showAddLessonPlanDialog,
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text('Add Plan',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_lessonPlans.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: Text('No lesson plans submitted yet.',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ),
          )
        else
          ..._lessonPlans.map((plan) {
            final isTaught = plan['status'] == 'Taught';
            final id = plan['id']?.toString() ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${plan['chapter']}: ${plan['topic']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTaught
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          plan['status'] ?? 'Approved',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color:
                                isTaught ? const Color(0xFF059669) : _primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Teacher: ${plan['teacher']} • Target Date: ${plan['planned_date']}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  if ((plan['objective'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Learning Objective: ${plan['objective']}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ],
                  if (!isTaught) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF059669),
                          side: const BorderSide(color: Color(0xFF059669)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          minimumSize: const Size(60, 26),
                        ),
                        onPressed: () async {
                          await _service.updateLessonPlanStatus(id, 'Taught');
                          _loadSyllabusData();
                        },
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: const Text('Mark as Taught',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==========================================
  // BUILD METHOD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    if (!_isRoleLoaded) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text('Timetable & Routine',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
        ),
        body: const Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isStudent
                  ? (_isParent ? 'Child Class Routine' : 'My Class Routine')
                  : (_isTeacher ? 'My Teaching Timetable' : 'Timetable Management'),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: _ink),
            ),
            const Text(
              'School timetable',
              style: TextStyle(
                  fontSize: 11, color: _muted, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        actions: [
          if (_isParent && _parentChildren.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Choose child',
              icon: const Icon(Icons.family_restroom_rounded),
              initialValue: _selectedStudentUsername,
              onSelected: (username) async {
                final child = _parentChildren.firstWhere(
                    (row) => row['username']?.toString() == username);
                setState(() {
                  _selectedStudentUsername = username;
                  _studentClassLabel = child['class_name']?.toString() ?? '';
                  _selectedClassId = child['class_id']?.toString() ?? '';
                });
                await _loadTimetableOnly();
              },
              itemBuilder: (context) => _parentChildren.map((child) {
                final username = child['username']?.toString() ?? '';
                return PopupMenuItem<String>(
                  value: username,
                  child: Text(child['name']?.toString() ?? username),
                );
              }).toList(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20, color: _muted),
            tooltip: 'Reload',
            onPressed: _reloadTimetable,
          ),
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => _showAddEditSlotDialog(),
                style: TextButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded,
                    size: 16, color: Colors.white),
                label: const Text('Add Slot',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
        bottom: _isStudent
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: _ink,
                    unselectedLabelColor: _muted,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                    tabs: _isTeacher
                        ? const [Tab(text: 'My Routine'), Tab(text: 'Substitution')]
                        : const [
                            Tab(text: 'Routine Grid'),
                            Tab(text: 'Coverage'),
                            Tab(text: 'Syllabus Tracker'),
                          ],
                  ),
                ),
              ),
      ),
      body: _isStudent
          ? _buildTimetableTab()
          : TabBarView(
              controller: _tabController,
              children: _isTeacher
                  ? [_buildTimetableTab(), _buildSubstitutionTab()]
                  : [
                      _buildTimetableTab(),
                      _buildSubstitutionTab(),
                      _buildSyllabusTab(),
                    ],
            ),
    );
  }
}
