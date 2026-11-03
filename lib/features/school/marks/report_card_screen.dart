import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';

class ReportCardScreen extends StatefulWidget {
  const ReportCardScreen({super.key});

  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  String _userRole = 'student';
  String _currentUsername = '';

  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;

  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;

  final List<String> _exams = [
    'Mid Term',
    'Unit Test 1',
    'Unit Test 2',
    'Half Yearly',
    'Annual',
  ];
  String _selectedExam = 'Mid Term';

  List<Map<String, dynamic>> _marks = [];
  double _studentAttendance = 94.5;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      _currentUsername = await _authService.getCurrentUsername() ?? '';
      _userRole = await _authService.getCurrentUserRole() ?? 'student';

      _classes = await _schoolService.getSchoolClasses();
      if (_classes.isNotEmpty) {
        _selectedClass = _classes.first;
      }

      await _loadStudentsForSelectedClass();
    } catch (e) {
      print('ReportCardScreen _initData error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentsForSelectedClass() async {
    if (_selectedClass == null) return;
    try {
      final classId = _selectedClass!['id']?.toString() ?? 'cls-10a';
      final students = await _schoolService.getStudentsInClass(classId);

      if (mounted) {
        setState(() {
          _students = students;
          if (_students.isNotEmpty) {
            if (_userRole == 'student' && _currentUsername.isNotEmpty) {
              final match = _students.firstWhere(
                (s) => s['username'] == _currentUsername,
                orElse: () => _students.first,
              );
              _selectedStudent = match;
            } else {
              _selectedStudent = _students.first;
            }
          } else {
            _selectedStudent = null;
          }
        });
        await _loadMarks();
      }
    } catch (e) {
      print('ReportCardScreen _loadStudents error: $e');
    }
  }

  Future<void> _loadMarks() async {
    if (_selectedStudent == null) return;
    final studentId = _selectedStudent!['username'] ?? _selectedStudent!['id'] ?? 'sstudent1';

    try {
      final marks = await _schoolService.getStudentMarks(studentId.toString(), examType: _selectedExam);
      final att = await _schoolService.getStudentAttendancePercent(studentId.toString());

      if (mounted) {
        setState(() {
          _marks = marks;
          _studentAttendance = att;
        });
      }
    } catch (e) {
      print('ReportCardScreen _loadMarks error: $e');
    }
  }

  int get _totalObtained => _marks.fold<int>(
        0,
        (sum, m) => sum + ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num).toInt(),
      );

  int get _totalMax => _marks.fold<int>(
        0,
        (sum, m) => sum + ((m['total'] ?? m['total_marks'] ?? 50) as num).toInt(),
      );

  double get _percentage => _totalMax > 0 ? (_totalObtained / _totalMax) * 100 : 0.0;

  String get _overallGrade {
    final p = _percentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B+';
    if (p >= 60) return 'B';
    if (p >= 50) return 'C';
    if (p >= 40) return 'D';
    return 'F';
  }

  Color get _gradeColor {
    final p = _percentage;
    if (p >= 80) return const Color(0xFF10B981);
    if (p >= 60) return const Color(0xFF3B82F6);
    if (p >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String get _teacherRemark {
    final p = _percentage;
    if (p >= 90) return 'Outstanding academic performance. Keep up the brilliant work!';
    if (p >= 80) return 'Very good performance. Consistent focus and enthusiasm shown.';
    if (p >= 70) return 'Good progress. Has strong potential to achieve top grades.';
    if (p >= 50) return 'Satisfactory. Regular revision and problem practice recommended.';
    return 'Needs substantial improvement and dedicated parent-teacher support.';
  }

  @override
  Widget build(BuildContext context) {
    final isStudentOrParent = _userRole == 'student' || _userRole == 'parent';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Report Card', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _showPrintPreviewDialog,
            tooltip: 'Print / Preview',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report Card link generated for sharing!'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            tooltip: 'Share Report Card',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downloading official PDF Report Card...'),
                  backgroundColor: Color(0xFFFF6B6B),
                ),
              );
            },
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B)))
          : RefreshIndicator(
              color: const Color(0xFFFF6B6B),
              onRefresh: _loadMarks,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Controls: Class, Student, Exam selector
                    if (!isStudentOrParent) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildSelector<Map<String, dynamic>>(
                              label: 'Class',
                              items: _classes,
                              itemLabel: (c) => c['name'] ?? '',
                              value: _selectedClass,
                              onChanged: (c) {
                                if (c != null) {
                                  setState(() => _selectedClass = c);
                                  _loadStudentsForSelectedClass();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSelector<Map<String, dynamic>>(
                              label: 'Student',
                              items: _students,
                              itemLabel: (s) => s['name'] ?? s['username'] ?? '',
                              value: _selectedStudent,
                              onChanged: (s) {
                                if (s != null) {
                                  setState(() => _selectedStudent = s);
                                  _loadMarks();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: _buildSelector<String>(
                            label: 'Exam Session',
                            items: _exams,
                            itemLabel: (e) => e,
                            value: _selectedExam,
                            onChanged: (e) {
                              if (e != null) {
                                setState(() => _selectedExam = e);
                                _loadMarks();
                              }
                            },
                          ),
                        ),
                        if (isStudentOrParent && _selectedStudent != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Student', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedStudent!['name'] ?? _currentUsername,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Student Overall Score Banner
                    _buildOverallBanner(),

                    const SizedBox(height: 20),

                    // Key Summary Metrics
                    _buildSummaryMetrics(),

                    const SizedBox(height: 20),

                    // Teacher Remarks & Conduct
                    _buildRemarksCard(),

                    const SizedBox(height: 20),

                    // Subject Performance Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subject-wise Evaluation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          '${_marks.length} Subjects',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_marks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No marks uploaded for this exam session yet.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ),
                      )
                    else
                      ..._marks.map((m) => _buildSubjectRow(m)),

                    const SizedBox(height: 24),

                    // Grading Key
                    _buildGradingScaleCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallBanner() {
    final studentName = _selectedStudent?['name'] ?? _currentUsername;
    final className = _selectedClass?['name'] ?? _selectedStudent?['class_name'] ?? 'Class 10-A';
    final rollNo = _selectedStudent?['roll_number'] ?? _selectedStudent?['roll_no'] ?? '12';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradeColor, _gradeColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _gradeColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Roll No: $rollNo',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      className,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  studentName,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$_selectedExam • Academic Year 2026-27',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  '$_totalObtained / $_totalMax',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_percentage.toStringAsFixed(1)}% • Grade: $_overallGrade • ${_percentage >= 40 ? "PROMOTED / PASSED" : "NEEDS RETEST"}',
                  style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _overallGrade,
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'GRADE',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 9, letterSpacing: 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    return Row(
      children: [
        _metricTile('Attendance', '${_studentAttendance.toStringAsFixed(1)}%', Icons.check_circle_outline, const Color(0xFF10B981)),
        const SizedBox(width: 10),
        _metricTile('Subjects Passed', '${_marks.where((m) => ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num) >= 20).length}/${_marks.length}', Icons.fact_check_outlined, const Color(0xFF3B82F6)),
        const SizedBox(width: 10),
        _metricTile('Status', _percentage >= 40 ? 'Passed' : 'Needs Retest', Icons.military_tech_outlined, _percentage >= 40 ? const Color(0xFF10B981) : Colors.red),
      ],
    );
  }

  Widget _metricTile(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              val,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemarksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text(
                'Class Teacher Remarks & Behavior',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _teacherRemark,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(Map<String, dynamic> m) {
    final subject = m['subject']?.toString() ?? 'Subject';
    final obtained = ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num).toInt();
    final total = ((m['total'] ?? m['total_marks'] ?? 50) as num).toInt();
    final pct = total > 0 ? (obtained / total) : 0.0;
    final grade = m['grade']?.toString() ?? _calculateGrade(pct * 100);

    Color gradeColor;
    if (grade.contains('+') || grade == 'A') {
      gradeColor = const Color(0xFF10B981);
    } else if (grade == 'B') {
      gradeColor = const Color(0xFF3B82F6);
    } else if (grade == 'C') {
      gradeColor = const Color(0xFFF59E0B);
    } else {
      gradeColor = const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Score: $obtained out of $total  •  ${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  grade,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: gradeColor),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$obtained/$total',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingScaleCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grading System Reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _GradePill(label: 'A+ (90-100%)', color: Color(0xFF10B981)),
              _GradePill(label: 'A (80-89%)', color: Color(0xFF10B981)),
              _GradePill(label: 'B+ (70-79%)', color: Color(0xFF3B82F6)),
              _GradePill(label: 'B (60-69%)', color: Color(0xFF3B82F6)),
              _GradePill(label: 'C (50-59%)', color: Color(0xFFF59E0B)),
              _GradePill(label: 'D (40-49%)', color: Color(0xFFF59E0B)),
              _GradePill(label: 'F (<40%)', color: Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelector<T>({
    required String label,
    required List<T> items,
    required String Function(T) itemLabel,
    required T? value,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
          DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, fontWeight: FontWeight.w600),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(itemLabel(i), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _calculateGrade(double pct) {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  void _showPrintPreviewDialog() {
    final studentName = _selectedStudent?['name'] ?? _currentUsername;
    final className = _selectedClass?['name'] ?? 'Class 10-A';
    final rollNo = _selectedStudent?['roll_number'] ?? '12';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // School Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.school, color: Color(0xFFFF6B6B), size: 32),
                    SizedBox(width: 8),
                    Text(
                      'SHIVALIK INTERNATIONAL SCHOOL',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Affiliated to CBSE • School Code: 84021\nOFFICIAL ACADEMIC PROGRESS REPORT',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.3),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Student Meta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Roll No: $rollNo • Class: $className', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Exam: $_selectedExam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Session: 2026-27', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Marks Table
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300),
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade100),
                      children: const [
                        Padding(padding: EdgeInsets.all(6), child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Max', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Obt', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: EdgeInsets.all(6), child: Text('Grade', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                    ..._marks.map((m) {
                      final s = m['subject']?.toString() ?? '';
                      final obt = ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num).toInt();
                      final tot = ((m['total'] ?? m['total_marks'] ?? 50) as num).toInt();
                      final g = m['grade']?.toString() ?? '';
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(6), child: Text(s, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('$tot', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(6), child: Text('$obt', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          Padding(padding: const EdgeInsets.all(6), child: Text(g, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      );
                    }),
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade50),
                      children: [
                        const Padding(padding: EdgeInsets.all(6), child: Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(6), child: Text('$_totalMax', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(6), child: Text('$_totalObtained', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(padding: const EdgeInsets.all(6), child: Text(_overallGrade, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Percentage: ${_percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Attendance: ${_studentAttendance.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 24),

                // Signatures
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Column(
                      children: [
                        Text('___________________', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('Class Teacher', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('___________________', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('Principal', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Now'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sent to printer!'), backgroundColor: Colors.green),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B6B),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  final String label;
  final Color color;
  const _GradePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
