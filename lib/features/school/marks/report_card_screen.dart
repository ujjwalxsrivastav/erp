import 'package:flutter/material.dart';
import '../../../services/school_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/report_card_pdf.dart';

class ReportCardScreen extends StatefulWidget {
  const ReportCardScreen({super.key});

  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  final _schoolService = SchoolService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _isLoadingCard = false;
  bool _isExportingClass = false;
  int _classExportProgress = 0;
  bool _isAdmin = false;
  bool _isStaff = false;
  String _userRole = 'student';
  String _currentUsername = '';

  List<String> _examSessions = ['Half Yearly', 'Final'];
  String _selectedExam = 'Half Yearly';

  List<Map<String, dynamic>> _classes = [];
  Map<String, dynamic>? _selectedClass;
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedStudent;

  List<Map<String, dynamic>> _marks = [];
  Map<String, dynamic> _analytics = {};
  double _attendance = 0;
  List<Map<String, dynamic>> _coScholastic = [];
  Map<String, dynamic> _meta = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      _currentUsername = await _authService.getCurrentUsername() ?? '';
      _userRole = await _authService.getCurrentUserRole() ?? 'student';
      _isAdmin = _userRole == 'admin' || _userRole == 'sadmin';
      _isStaff = _userRole != 'student' && _userRole != 'parent';
      _examSessions = await _schoolService.getExamSessions();
      if (_examSessions.isNotEmpty) _selectedExam = _examSessions.first;

      if (_isStaff) {
        _classes = await _schoolService.getSchoolClasses();
        _classes = [
          {'id': '__all__', 'name': 'All classes'},
          ..._classes,
        ];
        _selectedClass = _classes.first;
        await _loadStudentsForClass();
      } else {
        await _loadOwnStudent();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    await _loadCard();
  }

  /// Students (and parents) only ever see their own card — never a picker.
  Future<void> _loadOwnStudent() async {
    if (_userRole != 'student' || _currentUsername.isEmpty) return;
    final me = await _schoolService.getSchoolStudentProfile(_currentUsername);
    _selectedStudent = me ??
        {
          'username': _currentUsername,
          'name': _currentUsername,
          'class_name': '',
        };
  }

  Future<void> _loadStudentsForClass() async {
    if (_selectedClass == null) return;
    final isAll = _selectedClass!['id']?.toString() == '__all__';
    try {
      final students = isAll
          ? await _schoolService.getAllSchoolStudents()
          : await _schoolService.getStudentsInClass(
              _selectedClass!['id']?.toString() ?? '',
              className: _selectedClass!['name']?.toString(),
            );
      if (!mounted) return;
      setState(() {
        _students = students;
        final currentId = _selectedStudent?['id']?.toString();
        if (_students.isEmpty) {
          _selectedStudent = null;
        } else {
          _selectedStudent = _students.firstWhere(
            (s) => s['id']?.toString() == currentId,
            orElse: () => _students.first,
          );
        }
      });
    } catch (_) {}
  }

  String get _studentKey =>
      _selectedStudent?['username']?.toString() ??
      _selectedStudent?['id']?.toString() ??
      '';

  Future<void> _loadCard() async {
    final student = _selectedStudent;
    if (student == null || _studentKey.isEmpty) {
      if (mounted) setState(() => _marks = []);
      return;
    }
    setState(() => _isLoadingCard = true);
    final key = _studentKey;
    final marks = await _schoolService.getStudentMarks(
      key,
      examType: _selectedExam,
      studentName: student['name']?.toString(),
    );
    final analytics = _schoolService.buildReportAnalytics(marks);
    final attendance = await _schoolService.getStudentAttendancePercent(key);
    final coScholastic = await _schoolService.getCoScholastic(
      studentId: key,
      examType: _selectedExam,
    );
    final meta = await _schoolService.getReportCardMeta(
      studentId: key,
      examType: _selectedExam,
    );
    if (!mounted) return;
    setState(() {
      _marks = marks;
      _analytics = analytics;
      _attendance = attendance;
      _coScholastic = coScholastic;
      _meta = meta;
      _isLoadingCard = false;
    });
  }

  double get _percentage => (_analytics['percentage'] as num?)?.toDouble() ?? 0;
  String get _overallGrade => (_analytics['grade'] ?? '-').toString();
  int get _totalObtained => (_analytics['obtained'] as num?)?.toInt() ?? 0;
  int get _totalMax => (_analytics['max'] as num?)?.toInt() ?? 0;
  int get _subjectsPassed =>
      (_analytics['subjects_passed'] as num?)?.toInt() ?? 0;

  bool get _isPromoted => _percentage >= 33 && _attendance >= 75;

  String get _teacherRemark {
    final saved = _meta['teacher_remark']?.toString() ?? '';
    if (saved.isNotEmpty) return saved;
    if (_marks.isEmpty) return '';
    if (_percentage >= 80) {
      return 'Very good performance. Deep understanding of core subjects and high diligence.';
    }
    if (_percentage >= 50) {
      return 'Satisfactory. Regular revision and problem-solving practice recommended.';
    }
    return 'Needs substantial improvement and dedicated parent-teacher counselling support.';
  }

  String get _promotionVerdict {
    final saved = _meta['promotion_verdict']?.toString() ?? '';
    if (saved.isNotEmpty) return saved;
    if (_marks.isEmpty) return 'Awaiting result publication';
    return _isPromoted
        ? 'ELIGIBLE FOR PROMOTION (Subject to Final Examination)'
        : 'ACADEMIC RETENTION / REMEDIAL REQUIRED';
  }

  Color get _gradeColor {
    final g = _overallGrade;
    if (g.startsWith('A')) return const Color(0xFF0F766E);
    if (g.startsWith('B')) return const Color(0xFF2563EB);
    if (g.startsWith('C') || g == 'D') return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String get _studentName =>
      _selectedStudent?['name']?.toString() ?? _currentUsername;

  String get _className {
    final fromStudent = _selectedStudent?['class_name']?.toString() ?? '';
    if (fromStudent.isNotEmpty) return fromStudent;
    final c = _selectedClass;
    if (c != null && c['id']?.toString() != '__all__') {
      return _schoolService.classDisplayName(
        classId: c['id']?.toString(),
        className: c['name']?.toString(),
      );
    }
    return '-';
  }

  String get _rollNo => _selectedStudent?['roll_number']?.toString() ?? '-';

  String get _admissionNo =>
      _selectedStudent?['admission_no']?.toString() ?? '-';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Report Card',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _marks.isEmpty ? null : _downloadPdf,
            tooltip: 'Download Report Card',
          ),
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              onPressed: _marks.isEmpty ? null : _showEditRemarkDialog,
              tooltip: 'Edit Remarks (Admin)',
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingSkeleton() : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedStudent == null) {
      return _buildEmptyState(
        _isStaff
            ? 'No students found. Add students from Admissions to generate report cards.'
            : 'Your student profile could not be linked to a report card. Please contact the school office.',
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: _loadCard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_isStaff) ...[
            _buildStaffPickers(),
            const SizedBox(height: 12),
          ],
          if (_isAdmin &&
              _selectedClass != null &&
              _selectedClass!['id']?.toString() != '__all__') ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isExportingClass || _students.isEmpty
                    ? null
                    : _downloadClassReportCards,
                icon: _isExportingClass
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _isExportingClass
                      ? 'Preparing $_classExportProgress/${_students.length} report cards...'
                      : 'Download all ${_students.length} report cards',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildExamTabs(),
          const SizedBox(height: 16),
          if (_isLoadingCard)
            _buildCardSkeleton()
          else if (_marks.isEmpty)
            _buildEmptyState(
              'No $_selectedExam results published yet for $_studentName.',
            )
          else ...[
            _buildOverallBanner(),
            const SizedBox(height: 16),
            _buildPromotionVerdictCard(),
            const SizedBox(height: 16),
            _buildSummaryMetrics(),
            const SizedBox(height: 16),
            _buildAnalyticsSection(),
            const SizedBox(height: 16),
            _buildRemarksCard(),
            const SizedBox(height: 20),
            _buildSectionHeader(
                'Scholastic Subjects', '${_marks.length} Subjects'),
            const SizedBox(height: 10),
            ..._marks.map(_buildSubjectRow),
            const SizedBox(height: 20),
            _buildCoScholasticSection(),
            const SizedBox(height: 20),
            _buildGradingScaleCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildStaffPickers() {
    return Row(
      children: [
        Expanded(
          child: _buildSelector<Map<String, dynamic>>(
            label: 'Class',
            items: _classes,
            itemLabel: (c) => c['name']?.toString() ?? '',
            value: _selectedClass,
            onChanged: (c) async {
              if (c == null) return;
              setState(() => _selectedClass = c);
              await _loadStudentsForClass();
              await _loadCard();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSelector<Map<String, dynamic>>(
            label: 'Student',
            items: _students,
            itemLabel: (s) {
              final name = s['name'] ?? s['username'] ?? '';
              final cls = s['class_name']?.toString() ?? '';
              return cls.isEmpty ? '$name' : '$name · $cls';
            },
            value: _selectedStudent,
            onChanged: (s) async {
              if (s == null) return;
              setState(() => _selectedStudent = s);
              await _loadCard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExamTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: _examSessions.map((exam) {
          final selected = exam == _selectedExam;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                if (selected) return;
                setState(() => _selectedExam = exam);
                await _loadCard();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      selected ? const Color(0xFF0F766E) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  exam,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverallBanner() {
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Roll No: $_rollNo',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _className,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _studentName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'CBSE Affiliated · Session ${SchoolService.reportCardAcademicYear} · $_selectedExam Examination',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12),
                ),
                const SizedBox(height: 14),
                Text(
                  '$_totalObtained / $_totalMax',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900),
                ),
                Text(
                  '${_percentage.toStringAsFixed(1)}% • Grade: $_overallGrade (GP: ${_analytics['grade_point']})',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
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
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _overallGrade,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'CBSE GRADE',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 8,
                        letterSpacing: 0.8),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isPromoted ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: _isPromoted ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(
            _isPromoted ? Icons.military_tech_rounded : Icons.warning_rounded,
            color: _isPromoted ? Colors.green.shade700 : Colors.red.shade700,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promotion Recommendation',
                  style: TextStyle(
                      fontSize: 11,
                      color: _isPromoted
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _promotionVerdict,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _isPromoted
                        ? const Color(0xFF065F46)
                        : Colors.red.shade900,
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
        _metricTile('Attendance', '${_attendance.toStringAsFixed(1)}%',
            Icons.check_circle_outline, const Color(0xFF0F766E)),
        const SizedBox(width: 10),
        _metricTile('Subjects Passed', '$_subjectsPassed/${_marks.length}',
            Icons.fact_check_outlined, const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        _metricTile('Grade Point', '${_analytics['grade_point'] ?? '-'}',
            Icons.star_border_rounded, const Color(0xFF7C3AED)),
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
            Text(val,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style:
                    const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection() {
    final strongest = _analytics['strongest'] as Map<String, dynamic>?;
    final weakest = _analytics['weakest'] as Map<String, dynamic>?;
    final breakdown = (_analytics['breakdown'] as List<dynamic>?) ?? [];

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
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 20, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              const Text('Result Analytics',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
              const Spacer(),
              Text(_selectedExam,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _analyticsTile(
                  'Strongest',
                  strongest == null
                      ? '-'
                      : '${strongest['subject']} · ${(strongest['percentage'] as num).toStringAsFixed(0)}%',
                  const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _analyticsTile(
                  'Needs Focus',
                  weakest == null
                      ? '-'
                      : '${weakest['subject']} · ${(weakest['percentage'] as num).toStringAsFixed(0)}%',
                  const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Subject-wise performance',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          ...breakdown.map((row) {
            final m = row as Map<String, dynamic>;
            final pct = (m['percentage'] as num).toDouble();
            final grade = m['grade']?.toString() ?? '';
            final color = pct >= 81
                ? const Color(0xFF0F766E)
                : pct >= 61
                    ? const Color(0xFF2563EB)
                    : pct >= 33
                        ? const Color(0xFFD97706)
                        : const Color(0xFFDC2626);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      m['subject']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155)),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text('${pct.toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 24,
                    child: Text(grade,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _analyticsTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
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
              Text('Class Teacher Remark',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _teacherRemark.isEmpty ? '-' : _teacherRemark,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B))),
        Text(trailing,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildSubjectRow(Map<String, dynamic> m) {
    final subject = m['subject']?.toString() ?? 'Subject';
    final obtained =
        ((m['marks_obtained'] ?? m['obtained'] ?? 0) as num).toInt();
    final total = ((m['total_marks'] ?? m['total'] ?? 100) as num).toInt();
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
                    Text(subject,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 2),
                    Text(
                      'Score: $obtained/$total  •  ${pct.toStringAsFixed(0)}%  •  GP: ${gradeInfo['point']}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(grade,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: gradeColor)),
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
              'Co-Scholastic & Life Skills (A, B, C)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            if (_coScholastic.isEmpty)
              const Text('Co-scholastic grades have not been published yet.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
            else
              ..._coScholastic.map((cs) {
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
                            cs['grade']?.toString() ?? '-',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                                fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cs['area']?.toString() ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            if ((cs['descriptor']?.toString() ?? '')
                                .isNotEmpty)
                              Text(cs['descriptor'].toString(),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
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
          const Text('CBSE 9-Point Grading Scale Reference',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B))),
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
          Text(label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          DropdownButton<T>(
            value: items.contains(value) ? value : null,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w600),
            items: items
                .map((i) => DropdownMenuItem(
                    value: i,
                    child:
                        Text(itemLabel(i), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf() async {
    if (_selectedStudent == null) return;
    try {
      await ReportCardPdf.share(
        studentName: _studentName,
        studentUsername: _studentKey,
        className: _className,
        rollNo: _rollNo,
        admissionNo: _admissionNo,
        examType: _selectedExam,
        academicYear: SchoolService.reportCardAcademicYear,
        marks: _marks,
        analytics: _analytics,
        attendancePct: _attendance,
        coScholastic: _coScholastic,
        teacherRemark: _teacherRemark,
        promotionVerdict: _promotionVerdict,
        isPromoted: _isPromoted,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate report card PDF: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _downloadClassReportCards() async {
    final selectedClass = _selectedClass;
    if (!_isAdmin ||
        selectedClass == null ||
        selectedClass['id']?.toString() == '__all__' ||
        _students.isEmpty) {
      return;
    }

    setState(() {
      _isExportingClass = true;
      _classExportProgress = 0;
    });

    try {
      final className = _schoolService.classDisplayName(
        classId: selectedClass['id']?.toString(),
        className: selectedClass['name']?.toString(),
      );
      final cards = <Map<String, dynamic>>[];
      for (final student in _students) {
        final username = (student['username'] ?? '').toString();
        final studentId = (username.isNotEmpty
                ? username
                : student['id']?.toString() ?? '')
            .trim();
        if (studentId.isEmpty) continue;

        final studentName = (student['name'] ?? username).toString();
        final marks = await _schoolService.getStudentMarks(
          studentId,
          examType: _selectedExam,
          studentName: studentName,
        );
        final analytics = _schoolService.buildReportAnalytics(marks);
        final attendance =
            await _schoolService.getStudentAttendancePercent(studentId);
        final coScholastic = await _schoolService.getCoScholastic(
          studentId: studentId,
          examType: _selectedExam,
        );
        final meta = await _schoolService.getReportCardMeta(
          studentId: studentId,
          examType: _selectedExam,
        );
        final percentage =
            (analytics['percentage'] as num?)?.toDouble() ?? 0;
        final isPromoted = percentage >= 33 && attendance >= 75;
        final teacherRemark =
            (meta['teacher_remark']?.toString() ?? '').isNotEmpty
                ? meta['teacher_remark'].toString()
                : percentage >= 80
                    ? 'Very good performance. Deep understanding of core subjects and high diligence.'
                    : percentage >= 50
                        ? 'Satisfactory. Regular revision and problem-solving practice recommended.'
                        : 'Needs substantial improvement and dedicated parent-teacher counselling support.';
        final promotionVerdict =
            (meta['promotion_verdict']?.toString() ?? '').isNotEmpty
                ? meta['promotion_verdict'].toString()
                : isPromoted
                    ? 'ELIGIBLE FOR PROMOTION (Subject to Final Examination)'
                    : 'ACADEMIC RETENTION / REMEDIAL REQUIRED';

        cards.add({
          'student_name': studentName,
          'student_username': studentId,
          'roll_no': student['roll_number']?.toString() ?? '-',
          'admission_no': student['admission_no']?.toString() ?? '-',
          'marks': marks,
          'analytics': analytics,
          'attendance_pct': attendance,
          'co_scholastic': coScholastic,
          'teacher_remark': teacherRemark,
          'promotion_verdict': promotionVerdict,
          'is_promoted': isPromoted,
        });
        if (mounted) {
          setState(() => _classExportProgress = cards.length);
        }
      }

      if (cards.isEmpty) {
        throw Exception('No valid students were found in this class.');
      }
      await ReportCardPdf.shareClass(
        students: cards,
        className: className,
        examType: _selectedExam,
        academicYear: SchoolService.reportCardAcademicYear,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate class report cards: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingClass = false;
          _classExportProgress = 0;
        });
      }
    }
  }

  Future<void> _showEditRemarkDialog() async {
    final remarkCtrl = TextEditingController(text: _teacherRemark);
    final verdictCtrl = TextEditingController(text: _promotionVerdict);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Remarks · $_selectedExam',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: remarkCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Class Teacher Remark',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: verdictCtrl,
                decoration: const InputDecoration(
                  labelText: 'Promotion Verdict',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final ok = await _schoolService.saveReportCardMeta(
      studentId: _studentKey,
      examType: _selectedExam,
      teacherRemark: remarkCtrl.text.trim(),
      promotionVerdict: verdictCtrl.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Remarks saved.'
            : _schoolService.lastMarksError ?? 'Could not save remarks.'),
        backgroundColor: ok ? const Color(0xFF0F766E) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) await _loadCard();
  }

  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.description_outlined,
            size: 56, color: Color(0xFF94A3B8)),
        const SizedBox(height: 12),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      ],
    );
  }

  Widget _buildCardSkeleton() {
    Widget box(double height) => Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
        );
    return Column(
      children: [
        box(180),
        const SizedBox(height: 16),
        box(220),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
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
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
