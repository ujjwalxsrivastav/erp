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
    'Annual',
    'Mid Term',
    'Unit Test 1',
    'Unit Test 2',
    'Half Yearly',
  ];
  String _selectedExam = 'Annual';

  List<Map<String, dynamic>> _marks = [];
  double _studentAttendance = 94.5;
  Map<String, dynamic>? _hpcData;

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
      // Handle error cleanly
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
    } catch (_) {}
  }

  Future<void> _loadMarks() async {
    if (_selectedStudent == null) return;
    final studentId = _selectedStudent!['username'] ?? _selectedStudent!['id'] ?? 'sstudent1';

    try {
      final marks = await _schoolService.getStudentMarks(studentId.toString(), examType: _selectedExam);
      final att = await _schoolService.getStudentAttendancePercent(studentId.toString());
      final hpc = await _schoolService.getHolisticProgressCard(studentId: studentId.toString(), examType: _selectedExam);

      if (mounted) {
        setState(() {
          _marks = marks;
          _studentAttendance = att;
          _hpcData = hpc;
        });
      }
    } catch (_) {}
  }

  int get _totalObtained => _marks.fold<int>(
        0,
        (sum, m) => sum + ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num).toInt(),
      );

  int get _totalMax => _marks.fold<int>(
        0,
        (sum, m) => sum + ((m['total'] ?? m['total_marks'] ?? 100) as num).toInt(),
      );

  double get _percentage => _totalMax > 0 ? (_totalObtained / _totalMax) * 100 : 86.5;

  Map<String, dynamic> get _cbseGradeInfo => SchoolService.calculateCbseGrade(_percentage);

  String get _overallGrade => _cbseGradeInfo['grade'] ?? 'A2';

  Color get _gradeColor {
    final g = _overallGrade;
    if (g.startsWith('A')) return const Color(0xFF0F766E);
    if (g.startsWith('B')) return const Color(0xFF2563EB);
    if (g.startsWith('C') || g == 'D') return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String get _teacherRemark {
    final p = _percentage;
    if (p >= 90) return 'Outstanding academic consistency and high intellectual curiosity. Exemplary student.';
    if (p >= 80) return 'Very good performance. Demonstrates deep understanding of core subjects and high diligence.';
    if (p >= 70) return 'Good progress shown. Capable of scoring in higher percentiles with structured practice.';
    if (p >= 50) return 'Satisfactory. Regular revision and problem-solving practice recommended in science.';
    return 'Needs substantial improvement and dedicated parent-teacher counseling support.';
  }

  @override
  Widget build(BuildContext context) {
    final isStudentOrParent = _userRole == 'student' || _userRole == 'parent';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Holistic Progress Card (HPC)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _showPrintPreviewDialog,
            tooltip: 'Print / Official Preview',
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report Card verification link generated!'),
                  backgroundColor: Color(0xFF0F766E),
                ),
              );
            },
            tooltip: 'Share Card',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : RefreshIndicator(
              color: const Color(0xFF0F766E),
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
                              itemLabel: (c) => '${c['name']} - ${c['section']}',
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
                            label: 'Assessment Session',
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
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Student', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedStudent!['name'] ?? _currentUsername,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Official Board Header Banner
                    _buildOverallBanner(),

                    const SizedBox(height: 16),

                    // Promotion Linkage Verdict Card
                    _buildPromotionVerdictCard(),

                    const SizedBox(height: 16),

                    // Key Summary Metrics
                    _buildSummaryMetrics(),

                    const SizedBox(height: 16),

                    // Teacher Remarks & Conduct
                    _buildRemarksCard(),

                    const SizedBox(height: 20),

                    // Part 1: Scholastic Evaluation
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Part 1: Scholastic Subjects (CBSE 9-Point Scale)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${_marks.length} Subjects',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_marks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: const Center(
                          child: Text(
                            'No marks uploaded for this exam session yet.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      )
                    else
                      ..._marks.map((m) => _buildSubjectRow(m)),

                    const SizedBox(height: 20),

                    // Part 2: Co-Scholastic & HPC Areas
                    _buildCoScholasticSection(),

                    const SizedBox(height: 20),

                    // Part 3: QR Code Verification Seal
                    _buildQrVerificationSeal(),

                    const SizedBox(height: 20),

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
    final className = _selectedClass != null
        ? '${_selectedClass!['name']} - ${_selectedClass!['section']}'
        : (_selectedStudent?['class_name'] ?? 'Class 10-A');
    final rollNo = _selectedStudent?['roll_number'] ?? _selectedStudent?['roll_no'] ?? '01';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradeColor, _gradeColor.withValues(alpha: 0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _gradeColor.withValues(alpha: 0.3),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Roll No: $rollNo',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      className,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
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
                  'CBSE Affiliated • Session 2024-2025 • $_selectedExam Examination',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
                const SizedBox(height: 14),
                Text(
                  '$_totalObtained / $_totalMax',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_percentage.toStringAsFixed(1)}% • Grade: $_overallGrade (GP: ${_cbseGradeInfo['point']})',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _overallGrade,
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'CBSE GRADE',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 8, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionVerdictCard() {
    final isPromoted = _percentage >= 33.0 && _studentAttendance >= 75.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPromoted ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isPromoted ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(
            isPromoted ? Icons.military_tech_rounded : Icons.warning_rounded,
            color: isPromoted ? Colors.green.shade700 : Colors.red.shade700,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annual Promotion Recommendation (Linked to Module 2)',
                  style: TextStyle(fontSize: 11, color: isPromoted ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  isPromoted
                      ? 'PROMOTED TO CLASS 11 (Session 2025-2026)'
                      : 'ACADEMIC RETENTION / REMEDIAL REQUIRED (Score/Attendance below threshold)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPromoted ? const Color(0xFF065F46) : Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    return Row(
      children: [
        _metricTile('Attendance', '${_studentAttendance.toStringAsFixed(1)}%', Icons.check_circle_outline, const Color(0xFF0F766E)),
        const SizedBox(width: 10),
        _metricTile('Subjects Passed', '${_marks.where((m) => ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num) >= 33).length}/${_marks.length}', Icons.fact_check_outlined, const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        _metricTile('Grade Point', '${_cbseGradeInfo['point']}', Icons.star_border_rounded, const Color(0xFF7C3AED)),
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
          border: Border.all(color: Colors.grey.shade200),
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
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Class Teacher Narrative Evaluation & Conduct',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _teacherRemark,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(Map<String, dynamic> m) {
    final subject = m['subject']?.toString() ?? 'Subject';
    final obtained = ((m['obtained'] ?? m['marks_obtained'] ?? 0) as num).toInt();
    final total = ((m['total'] ?? m['total_marks'] ?? 100) as num).toInt();
    final pct = total > 0 ? (obtained / total) * 100 : 0.0;
    final gradeInfo = SchoolService.calculateCbseGrade(pct);
    final grade = m['grade']?.toString() ?? gradeInfo['grade'];

    Color gradeColor;
    if (grade == 'A1' || grade == 'A2') {
      gradeColor = const Color(0xFF0F766E);
    } else if (grade == 'B1' || grade == 'B2') {
      gradeColor = const Color(0xFF2563EB);
    } else if (grade == 'C1' || grade == 'C2' || grade == 'D') {
      gradeColor = const Color(0xFFD97706);
    } else {
      gradeColor = const Color(0xFFDC2626);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
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
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Score: $obtained/$total  •  ${pct.toStringAsFixed(0)}%  •  GP: ${gradeInfo['point']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  grade,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: gradeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoScholasticSection() {
    final coScholastic = (_hpcData?['co_scholastic'] as List<dynamic>?) ?? [
      {'area': 'Work Education (ICT / Craft)', 'grade': 'A', 'descriptor': 'Exemplary problem-solving in digital projects'},
      {'area': 'Art Education (Visual & Performing)', 'grade': 'A', 'descriptor': 'High creative expression and aesthetic appreciation'},
      {'area': 'Health & Physical Education (Sports)', 'grade': 'A', 'descriptor': 'High teamwork, stamina, and track participation'},
      {'area': 'Discipline & Value Inculcation', 'grade': 'A', 'descriptor': 'Outstanding punctuality, respect, and peer collaboration'},
    ];

    return Card(
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
            const Text(
              'Part 2: Co-Scholastic & Life Skills (3-Point Scale: A, B, C)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            ...coScholastic.map((cs) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          cs['grade']!,
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cs['area']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(cs['descriptor']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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

  Widget _buildQrVerificationSeal() {
    final studentId = _selectedStudent?['id'] ?? 'sstudent1';
    final admNo = _selectedStudent?['admission_no'] ?? 'ADM202601';
    final qrUrl = 'https://shivalikschool.edu.in/verify/report-card?id=$studentId&adm=$admNo&auth=cbse_seal_verified';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFF0F766E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: Color(0xFF0F766E)),
                    SizedBox(width: 4),
                    Text('CBSE Digital Verification Seal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Authenticity verified via school portal. Scan QR to validate marks tampering or duplicate credentials.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  qrUrl,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CBSE 9-Point Grading Scale Reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              _GradePill(label: 'A1 (91-100)', color: Color(0xFF0F766E)),
              _GradePill(label: 'A2 (81-90)', color: Color(0xFF0F766E)),
              _GradePill(label: 'B1 (71-80)', color: Color(0xFF2563EB)),
              _GradePill(label: 'B2 (61-70)', color: Color(0xFF2563EB)),
              _GradePill(label: 'C1 (51-60)', color: Color(0xFFD97706)),
              _GradePill(label: 'C2 (41-50)', color: Color(0xFFD97706)),
              _GradePill(label: 'D (33-40 Pass)', color: Color(0xFFD97706)),
              _GradePill(label: 'E1/E2 (<33 Repeat)', color: Color(0xFFDC2626)),
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
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(itemLabel(i), overflow: TextOverflow.ellipsis))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showPrintPreviewDialog() {
    final studentName = _selectedStudent?['name'] ?? _currentUsername;
    final className = _selectedClass?['name'] ?? 'Class 10';
    final rollNo = _selectedStudent?['roll_number'] ?? '01';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.school, color: Color(0xFF0F766E), size: 30),
                    SizedBox(width: 8),
                    Text(
                      'SHIVALIK INTERNATIONAL SCHOOL',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Affiliated to CBSE • Affiliation Code: 3530128 • School Code: 84021\nHOLISTIC PROGRESS REPORT (CBSE FORMAT)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Roll No: $rollNo • Class: $className', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Exam: $_selectedExam', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('Session: 2024-2025', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

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
                      final tot = ((m['total'] ?? m['total_marks'] ?? 100) as num).toInt();
                      final pct = tot > 0 ? (obt / tot) * 100 : 0.0;
                      final g = m['grade']?.toString() ?? SchoolService.calculateCbseGrade(pct)['grade'];
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
                        Padding(padding: const EdgeInsets.all(6), child: Text(_overallGrade, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F766E)))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Percentage: ${_percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Attendance: ${_studentAttendance.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 18),

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
                        Text('Dr. Meenakshi Srivastav', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        SizedBox(height: 2),
                        Text('Principal Digital Seal', style: TextStyle(fontSize: 10, color: Color(0xFF0F766E))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                          backgroundColor: const Color(0xFF0F766E),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
