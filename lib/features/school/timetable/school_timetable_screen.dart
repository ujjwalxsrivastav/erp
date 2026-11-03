import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class SchoolTimetableScreen extends StatefulWidget {
  final String? initialClassId;
  const SchoolTimetableScreen({super.key, this.initialClassId});

  @override
  State<SchoolTimetableScreen> createState() => _SchoolTimetableScreenState();
}

class _SchoolTimetableScreenState extends State<SchoolTimetableScreen>
    with SingleTickerProviderStateMixin {
  final SchoolService _service = SchoolService();
  late TabController _tabController;

  // Timetable State
  String _selectedClassId = 'cls-10a';
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
  List<String> _absentTeachers = ['mrs_gupta'];
  List<Map<String, dynamic>> _uncoveredPeriods = [];
  List<Map<String, dynamic>> _substitutionLogs = [];
  bool _isLoadingSubstitutions = false;
  List<String> _allTeachers = [];

  // Syllabus / Lesson Plan State
  List<Map<String, dynamic>> _lessonPlans = [];
  Map<String, dynamic>? _syllabusSummary;
  bool _isLoadingSyllabus = false;

  final List<Color> _subjectPalette = [
    const Color(0xFF0F766E), // Teal
    const Color(0xFF2563EB), // Blue
    const Color(0xFF7C3AED), // Purple
    const Color(0xFFD97706), // Amber
    const Color(0xFFDC2626), // Red
    const Color(0xFF059669), // Emerald
    const Color(0xFF4F46E5), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialClassId != null && widget.initialClassId!.isNotEmpty) {
      _selectedClassId = widget.initialClassId!;
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 1) _loadSubstitutionData();
        if (_tabController.index == 2) _loadSyllabusData();
      }
    });

    _loadClassesAndTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClassesAndTimetable() async {
    setState(() {
      _isLoadingTimetable = true;
      _timetableError = null;
    });

    try {
      final classes = await _service.getSchoolClasses();
      _classes = classes.isNotEmpty
          ? classes
          : [
              {'id': 'cls-10a', 'name': 'Class 10', 'section': 'A'},
              {'id': 'cls-9a', 'name': 'Class 9', 'section': 'A'},
              {'id': 'cls-10b', 'name': 'Class 10', 'section': 'B'},
            ];

      final entries = await _service.getTimetableForClass(
        _selectedClassId,
        day: _selectedDay,
      );

      _allTeachers = await _service.getSchoolTeachersList();

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

  Future<void> _loadSubstitutionData() async {
    setState(() => _isLoadingSubstitutions = true);
    try {
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
      if (mounted) setState(() => _isLoadingSubstitutions = false);
    }
  }

  Future<void> _loadSyllabusData() async {
    setState(() => _isLoadingSyllabus = true);
    try {
      var plans = await _service.getLessonPlans(classId: _selectedClassId);
      if (plans.isEmpty) {
        // Seed initial lesson plans if none exist yet
        await _service.submitLessonPlan(
          classId: _selectedClassId,
          subject: 'Mathematics',
          teacherUsername: 'steacher1',
          chapter: 'Chapter 4',
          topic: 'Quadratic Equations',
          plannedDate: '2026-11-10',
          objective: 'Solve quadratic equations using quadratic formula & factoring.',
        );
        await _service.submitLessonPlan(
          classId: _selectedClassId,
          subject: 'Science',
          teacherUsername: 'mrs_gupta',
          chapter: 'Chapter 6',
          topic: 'Life Processes',
          plannedDate: '2026-11-08',
          objective: 'Understand human digestive and circulatory systems.',
        );
        plans = await _service.getLessonPlans(classId: _selectedClassId);
      }

      final summary = await _service.getSyllabusCoverageReport(_selectedClassId);

      if (mounted) {
        setState(() {
          _lessonPlans = plans;
          _syllabusSummary = summary;
          _isLoadingSyllabus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSyllabus = false);
    }
  }

  Color _getSubjectColor(String subject) {
    final hash = subject.codeUnits.fold(0, (acc, c) => acc + c);
    return _subjectPalette[hash % _subjectPalette.length];
  }

  // ===== DIALOGS & ACTIONS =====

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

    String selectedDay = isEdit ? existingSlot['day'] ?? _selectedDay : _selectedDay;
    String selectedTeacher = isEdit
        ? existingSlot['teacher_username'] ?? 'steacher1'
        : (_allTeachers.isNotEmpty ? _allTeachers.first : 'steacher1');

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
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _days
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text(d)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setSheetState(() => selectedDay = v);
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: _allTeachers
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t)))
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
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
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
                                  content: Text('Timetable slot saved successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadClassesAndTimetable();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
                                backgroundColor: Colors.red.shade700,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                        child: Text(
                          isEdit ? 'Update Slot' : 'Publish Slot (Clash Checked)',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
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
    final day = uncovered['day']?.toString() ?? _selectedDay;
    final period = int.tryParse(uncovered['period']?.toString() ?? '1') ?? 1;
    final subject = uncovered['subject']?.toString() ?? '';
    final classId = uncovered['class_id']?.toString() ?? _selectedClassId;
    final origTeacher = uncovered['teacher_username']?.toString() ?? '';
    final room = uncovered['room']?.toString() ?? 'Room 101';
    final time = '${uncovered['start_time']} - ${uncovered['end_time']}';

    final available = await _service.getAvailableSubstitutes(
      day: day,
      period: period,
      preferredSubject: subject,
    );

    if (!mounted) return;

    String? chosenSubstitute = available.isNotEmpty ? available.first['username'] : null;
    final notesCtrl = TextEditingController(text: 'Morning coverage assignment');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.swap_horiz, color: Colors.amber.shade800),
                  ),
                  const SizedBox(width: 12),
                  const Text('Assign Substitute', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Period $period ($time) • $classId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Subject: $subject • Room: $room', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Absent Teacher: $origTeacher', style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Recommended Substitute:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (available.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('No free teachers in this slot!', style: TextStyle(color: Colors.red, fontSize: 13)),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: chosenSubstitute,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: available.map((s) {
                        final isOver = s['isOverloaded'] == true;
                        return DropdownMenuItem<String>(
                          value: s['username'],
                          child: Text(
                            '${s['username']} (Load: ${s['currentLoad']}/5)${isOver ? ' [Capped]' : ' [Free]'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isOver ? Colors.orange.shade800 : Colors.black87,
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: chosenSubstitute == null
                      ? null
                      : () async {
                          try {
                            await _service.assignSubstitution(
                              day: day,
                              period: period,
                              classId: classId,
                              subject: subject,
                              originalTeacher: origTeacher,
                              substituteTeacher: chosenSubstitute!,
                              room: room,
                              time: time,
                              notes: notesCtrl.text.trim(),
                              assignedBy: 'Academic Head',
                            );
                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Assigned $chosenSubstitute! Instant alert issued.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _loadSubstitutionData();
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: const Text('Assign & Notify', style: TextStyle(color: Colors.white)),
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
        text: DateTime.now().add(const Duration(days: 3)).toIso8601String().split('T')[0]);
    final objectiveCtrl = TextEditingController(
        text: 'Identify AP patterns and calculate nth terms using formula.');
    final resourcesCtrl = TextEditingController(
        text: 'NCERT Textbook, Digital Smart Board, GeoGebra Simulation');
    String selectedSubject = 'Mathematics';
    String selectedTeacher = 'steacher1';

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
                    const Text('Create Lesson Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: dateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Target Date',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: objectiveCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Pedagogical Learning Objectives',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: resourcesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Resources & Equipment',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                              content: Text('Lesson plan submitted & approved!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadSyllabusData();
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Save Lesson Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== TAB 1: TIMETABLE GRID =====

  Widget _buildTimetableTab() {
    if (_isLoadingTimetable) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_timetableError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_timetableError!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadClassesAndTimetable,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Class & Day Filter Header
        Container(
          color: const Color(0xFF0F766E),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            children: [
              // Class Selector Row
              Row(
                children: [
                  const Icon(Icons.school, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Text('Class:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClassId,
                          dropdownColor: const Color(0xFF0F766E),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          items: _classes.map((c) {
                            final name = '${c['name']} - ${c['section']}';
                            return DropdownMenuItem<String>(
                              value: c['id']?.toString() ?? 'cls-10a',
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedClassId = v);
                              _loadClassesAndTimetable();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.white),
                    tooltip: 'Add Timetable Slot',
                    onPressed: () => _showAddEditSlotDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Day Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _days.map((day) {
                    final isSelected = day == _selectedDay;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDay = day);
                        _loadClassesAndTimetable();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          day.substring(0, 3),
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
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
                      Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No timetable periods scheduled for $_selectedDay',
                          style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showAddEditSlotDialog(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Period Slot', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _periods.length,
                  itemBuilder: (context, index) {
                    final p = _periods[index];
                    final periodNum = p['period']?.toString() ?? '${index + 1}';
                    final subject = p['subject']?.toString() ?? 'Subject';
                    final teacher = p['teacher_username']?.toString() ?? 'Teacher';
                    final room = p['room']?.toString() ?? 'Room';
                    final startTime = p['start_time']?.toString() ?? '';
                    final endTime = p['end_time']?.toString() ?? '';
                    final subjectColor = _getSubjectColor(subject);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border(left: BorderSide(color: subjectColor, width: 4)),
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
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: subjectColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                'P$periodNum',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      teacher,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.meeting_room_outlined, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      room,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: subjectColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  startTime.isNotEmpty ? '$startTime - $endTime' : 'Regular',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subjectColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _showAddEditSlotDialog(existingSlot: p),
                                    child: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () async {
                                      final id = p['id']?.toString();
                                      if (id != null) {
                                        await _service.deleteTimetableEntry(id);
                                        _loadClassesAndTimetable();
                                      }
                                    },
                                    child: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                                  ),
                                ],
                              ),
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

  // ===== TAB 2: MORNING SUBSTITUTION COVERAGE =====

  Widget _buildSubstitutionTab() {
    if (_isLoadingSubstitutions) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Absent Teachers Selector Header
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_off, color: Colors.red, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Morning Absent / Leave Roster',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text('Uncovered periods will automatically prompt smart substitute recommendations',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allTeachers.map((teacher) {
                    final isAbsent = _absentTeachers.contains(teacher);
                    return FilterChip(
                      label: Text(teacher),
                      selected: isAbsent,
                      selectedColor: Colors.red.shade100,
                      labelStyle: TextStyle(
                        color: isAbsent ? Colors.red.shade900 : Colors.black87,
                        fontWeight: isAbsent ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
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
        ),
        const SizedBox(height: 18),

        // Uncovered Periods Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Uncovered Periods Today',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _uncoveredPeriods.isEmpty ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_uncoveredPeriods.length} Pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _uncoveredPeriods.isEmpty ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_uncoveredPeriods.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'All periods covered! No teacher absences or all substitutions assigned.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF065F46)),
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

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDone ? Colors.green.shade300 : Colors.red.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDone ? Colors.green.shade50 : Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'P$period',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDone ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$subject • $classId',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 3),
                          Text('Absent: $teacher | Room: $room',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDone ? Colors.grey.shade300 : const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: isDone ? null : () => _showSubstituteAssignDialog(uncovered),
                      child: Text(
                        isDone ? 'Arranged' : 'Assign',
                        style: TextStyle(
                          color: isDone ? Colors.grey.shade700 : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 24),
        // Substitution History Log
        const Text(
          'Substitution Audit Log (Instant Alerts Issued)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 10),

        if (_substitutionLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No substitution logs recorded yet.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ),
          )
        else
          ..._substitutionLogs.take(5).map((log) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline, color: Color(0xFF0F766E)),
                title: Text('${log['substitute_teacher']} assigned for ${log['original_teacher']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('P${log['period']} • ${log['class_id']} • ${log['date']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                trailing: Chip(
                  label: const Text('Logged', style: TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: const Color(0xFF0F766E),
                  padding: EdgeInsets.zero,
                ),
              ),
            );
          }),
      ],
    );
  }

  // ===== TAB 3: LESSON PLANS & SYLLABUS TRACKING =====

  Widget _buildSyllabusTab() {
    if (_isLoadingSyllabus) {
      return const Center(child: CircularProgressIndicator());
    }

    final summary = _syllabusSummary ?? {};
    final coveragePct = (summary['coveragePct'] as num?)?.toDouble() ?? 50.0;
    final isLagging = summary['isLagging'] == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Syllabus Coverage Dashboard Card
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Syllabus Coverage Progress',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('${coveragePct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isLagging ? Colors.red : const Color(0xFF0F766E),
                        )),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (coveragePct / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    color: isLagging ? Colors.red : const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 12),
                if (isLagging)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            summary['laggingAlert'] ?? 'Coverage is lagging behind schedule!',
                            style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Class $_selectedClassId is on track for term examinations.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Lesson Plans Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Curriculum Units & Lesson Plans',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: _showAddLessonPlanDialog,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Add Plan', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_lessonPlans.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Center(
              child: Text('No lesson plans submitted yet.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ..._lessonPlans.map((plan) {
            final isTaught = plan['status'] == 'Taught';
            final id = plan['id']?.toString() ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${plan['chapter']}: ${plan['topic']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isTaught ? Colors.green.shade100 : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            plan['status'] ?? 'Approved',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isTaught ? Colors.green.shade800 : Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Teacher: ${plan['teacher']} • Target: ${plan['planned_date']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if ((plan['objective'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Learning Objective: ${plan['objective']}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isTaught)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F766E),
                              side: const BorderSide(color: Color(0xFF0F766E)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              await _service.updateLessonPlanStatus(id, 'Taught');
                              _loadSyllabusData();
                            },
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Mark as Taught', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('School Timetable & Coverage',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month, size: 20), text: 'Timetable Grid'),
            Tab(icon: Icon(Icons.swap_horiz, size: 20), text: 'Morning Coverage'),
            Tab(icon: Icon(Icons.menu_book, size: 20), text: 'Syllabus Tracker'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimetableTab(),
          _buildSubstitutionTab(),
          _buildSyllabusTab(),
        ],
      ),
    );
  }
}
