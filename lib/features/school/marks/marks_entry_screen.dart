import 'package:flutter/material.dart';
import '../../../services/school_service.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  final _schoolService = SchoolService();

  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _students = [];

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;
  String _selectedExam = 'Unit Test 1';

  static const List<String> _examTypes = [
    'Unit Test 1',
    'Unit Test 2',
    'Mid Term',
    'Final Term',
    'Assignment',
  ];

  // Map<studentId, TextEditingController>
  final Map<String, TextEditingController> _marksControllers = {};
  int _maxMarks = 50;
  final _maxMarksController = TextEditingController(text: '50');

  bool _isInitialising = true;
  bool _isLoadingStudents = false;
  bool _isSaving = false;

  double? _classAverage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final classes = await _schoolService.getSchoolClasses();
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _selectedClass = classes.isNotEmpty ? classes.first : null;
      _isInitialising = false;
    });
    if (_selectedClass != null) {
      await _loadSubjectsAndStudents();
    }
  }

  Future<void> _loadSubjectsAndStudents() async {
    final classId = _selectedClass?['id']?.toString();
    if (classId == null) return;

    setState(() => _isLoadingStudents = true);

    final subjects = await _schoolService.getSchoolSubjects(classId: classId);
    final students = await _schoolService.getStudentsByClass(classId);

    if (!mounted) return;

    // Dispose old controllers
    for (final c in _marksControllers.values) {
      c.dispose();
    }
    _marksControllers.clear();

    for (final s in students) {
      final sid = s['id']?.toString() ?? s['username']?.toString() ?? '';
      _marksControllers[sid] = TextEditingController();
    }

    setState(() {
      _subjects = subjects;
      _selectedSubject = subjects.isNotEmpty ? subjects.first : null;
      _students = students;
      _isLoadingStudents = false;
      _classAverage = null;
    });

    await _loadExistingMarks();
  }

  Future<void> _loadExistingMarks() async {
    final classId = _selectedClass?['id']?.toString();
    final subject = _selectedSubject?['name']?.toString() ??
        _selectedSubject?['id']?.toString();
    if (classId == null || subject == null) return;

    final existing = await _schoolService.getMarksByClassSubjectExam(
      classId: classId,
      subject: subject,
      examType: _selectedExam,
    );

    if (!mounted) return;

    for (final m in existing) {
      final sid = m['student_id']?.toString() ?? '';
      final obtained = m['obtained_marks']?.toString() ?? m['marks']?.toString() ?? '';
      if (_marksControllers.containsKey(sid)) {
        _marksControllers[sid]!.text = obtained;
      }
      // Also read max marks from DB if present
      final max = m['max_marks'];
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
  }

  Future<void> _saveMarks() async {
    // Validate
    bool hasError = false;
    for (final s in _students) {
      final sid = s['id']?.toString() ?? s['username']?.toString() ?? '';
      final text = _marksControllers[sid]?.text.trim() ?? '';
      if (text.isEmpty) continue; // empty = not entered yet, skip
      final val = int.tryParse(text);
      if (val == null) {
        hasError = true;
        break;
      }
      if (val > _maxMarks || val < 0) {
        hasError = true;
        break;
      }
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid marks. Each must be a number between 0 and $_maxMarks.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final classId = _selectedClass?['id']?.toString() ?? '';
    final subject = _selectedSubject?['name']?.toString() ??
        _selectedSubject?['id']?.toString() ?? '';

    final marksList = <Map<String, dynamic>>[];
    for (final s in _students) {
      final sid = s['id']?.toString() ?? s['username']?.toString() ?? '';
      final text = _marksControllers[sid]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final val = int.tryParse(text);
      if (val == null) continue;
      marksList.add({
        'student_id': sid,
        'class_id': classId,
        'subject': subject,
        'exam_type': _selectedExam,
        'obtained_marks': val,
        'max_marks': _maxMarks,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    if (marksList.isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No marks entered to save.'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await _schoolService.saveMarks(marksList);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      // Calculate class average
      final total = marksList.fold<int>(0, (sum, m) => sum + (m['obtained_marks'] as int));
      final avg = total / marksList.length;
      setState(() => _classAverage = avg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Marks saved! Class average: ${avg.toStringAsFixed(1)} / $_maxMarks'),
          backgroundColor: const Color(0xFF8B5CF6),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save marks. Please try again.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _marksControllers.values) {
      c.dispose();
    }
    _maxMarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Assessment & Marks Entry',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF7C3AED)],
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveMarks,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6D28D9),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6D28D9)),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Marks',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: _isInitialising
          ? _buildLoadingSkeleton()
          : Column(
              children: [
                // ── Filter Header ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4C1D95), Color(0xFF6D28D9), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterDropdown<Map<String, dynamic>>(
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFilterDropdown<Map<String, dynamic>>(
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
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFilterDropdown<String>(
                              label: 'Exam Type',
                              value: _selectedExam,
                              items: _examTypes,
                              itemLabel: (e) => e,
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedExam = v);
                                  _loadExistingMarks();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Text('Out of: ',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 13)),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _maxMarksController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: (v) => setState(() =>
                                          _maxMarks = int.tryParse(v) ?? 50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Class average banner
                      if (_classAverage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bar_chart,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Class Average: ${_classAverage!.toStringAsFixed(1)} / $_maxMarks  '
                                '(${((_classAverage! / _maxMarks) * 100).toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Student List ──
                Expanded(
                  child: _isLoadingStudents
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF8B5CF6)))
                      : _students.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 64, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No students found for this class.',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _students.length,
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                final sid = student['id']?.toString() ??
                                    student['username']?.toString() ??
                                    '';
                                final roll = student['roll_number']?.toString() ??
                                    student['roll']?.toString() ??
                                    '${index + 1}';
                                final name = student['name']?.toString() ??
                                    student['full_name']?.toString() ??
                                    'Student ${index + 1}';
                                final studentId =
                                    student['student_id']?.toString() ??
                                        student['username']?.toString() ??
                                        sid;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                          color:
                                              Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3))
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF3E8FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            roll,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF8B5CF6)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1F2937)),
                                            ),
                                            Text(
                                              studentId,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: TextFormField(
                                          controller: _marksControllers[sid],
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration: InputDecoration(
                                            hintText: '-- / $_maxMarks',
                                            hintStyle: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade400),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF8B5CF6),
                                                  width: 2),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 10),
                                            filled: true,
                                            fillColor: const Color(0xFFF3E8FF),
                                          ),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF8B5CF6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF7C3AED),
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        hint: Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        items: items
            .map((i) => DropdownMenuItem<T>(
                  value: i,
                  child: Text(itemLabel(i),
                      style: const TextStyle(color: Colors.white)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
