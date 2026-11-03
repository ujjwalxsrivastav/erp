import 'package:flutter/material.dart';

class ReportCardScreen extends StatefulWidget {
  const ReportCardScreen({super.key});

  @override
  State<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends State<ReportCardScreen> {
  String _selectedStudent = 'Aarav Sharma';
  String _selectedExam = 'Mid Term';

  final List<String> _students = ['Aarav Sharma', 'Priya Patel', 'Rohan Gupta'];
  final List<String> _exams = ['Unit Test 1', 'Unit Test 2', 'Mid Term', 'Half Yearly', 'Annual'];

  final List<Map<String, dynamic>> _marks = [
    {'subject': 'Mathematics', 'obtained': 45, 'total': 50, 'grade': 'A+'},
    {'subject': 'Science', 'obtained': 38, 'total': 50, 'grade': 'B+'},
    {'subject': 'English', 'obtained': 42, 'total': 50, 'grade': 'A'},
    {'subject': 'Hindi', 'obtained': 40, 'total': 50, 'grade': 'A'},
    {'subject': 'Social Studies', 'obtained': 35, 'total': 50, 'grade': 'B'},
    {'subject': 'Computer', 'obtained': 48, 'total': 50, 'grade': 'A+'},
  ];

  int get _totalObtained => _marks.fold(0, (sum, m) => sum + (m['obtained'] as int));
  int get _totalMax => _marks.fold(0, (sum, m) => sum + (m['total'] as int));
  double get _percentage => (_totalObtained / _totalMax) * 100;
  String get _overallGrade {
    final p = _percentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B+';
    if (p >= 60) return 'B';
    if (p >= 50) return 'C';
    return 'D';
  }

  Color get _gradeColor {
    final p = _percentage;
    if (p >= 80) return const Color(0xFF10B981);
    if (p >= 60) return const Color(0xFF3B82F6);
    if (p >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Report Card', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFFF6B6B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
            tooltip: 'Share Report Card',
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildDropdown('Student', _students, _selectedStudent, (v) => setState(() => _selectedStudent = v!))),
                const SizedBox(width: 12),
                Expanded(child: _buildDropdown('Exam', _exams, _selectedExam, (v) => setState(() => _selectedExam = v!))),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_gradeColor, _gradeColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _gradeColor.withOpacity(0.3),
                    blurRadius: 15,
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
                        Text(
                          _selectedStudent,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_selectedExam • Class 10-A',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_totalObtained / $_totalMax',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_percentage.toStringAsFixed(1)}% • Overall Grade: $_overallGrade',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _overallGrade,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Subject-wise Performance',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 12),
            ..._marks.map((m) => _buildSubjectRow(m)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectRow(Map<String, dynamic> m) {
    final obtained = m['obtained'] as int;
    final total = m['total'] as int;
    final pct = (obtained / total);
    final grade = m['grade'] as String;

    Color gradeColor;
    if (grade.contains('+')) {
      gradeColor = const Color(0xFF10B981);
    } else if (grade == 'A' || grade == 'B') {
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m['subject'] as String,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.1),
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
              value: pct,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, void Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w500),
        items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

