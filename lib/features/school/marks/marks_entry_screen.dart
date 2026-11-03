import 'package:flutter/material.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  String _selectedClass = 'Class 10-A';
  String _selectedSubject = 'Mathematics';
  String _selectedExam = 'Unit Test 1';

  final List<String> _classes = ['Class 9-A', 'Class 10-A', 'Class 10-B'];
  final List<String> _subjects = ['Mathematics', 'Science', 'English', 'Hindi'];
  final List<String> _exams = ['Unit Test 1', 'Unit Test 2', 'Mid Term', 'Half Yearly', 'Annual'];

  final List<Map<String, dynamic>> _students = [
    {'id': 'SCH001', 'name': 'Aarav Sharma', 'roll': '01', 'marks': TextEditingController()},
    {'id': 'SCH002', 'name': 'Priya Patel', 'roll': '02', 'marks': TextEditingController()},
    {'id': 'SCH003', 'name': 'Rohan Gupta', 'roll': '03', 'marks': TextEditingController()},
    {'id': 'SCH004', 'name': 'Sneha Singh', 'roll': '04', 'marks': TextEditingController()},
    {'id': 'SCH005', 'name': 'Vikram Kumar', 'roll': '05', 'marks': TextEditingController()},
  ];

  int _totalMarks = 50;

  @override
  void dispose() {
    for (var s in _students) {
      (s['marks'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  void _saveMarks() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marks saved successfully!'),
        backgroundColor: Color(0xFF8B5CF6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Marks Entry', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _saveMarks,
            icon: const Icon(Icons.save, color: Colors.white, size: 20),
            label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF8B5CF6),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown('Class', _classes, _selectedClass, (v) => setState(() => _selectedClass = v!))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildFilterDropdown('Subject', _subjects, _selectedSubject, (v) => setState(() => _selectedSubject = v!))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown('Exam', _exams, _selectedExam, (v) => setState(() => _selectedExam = v!))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Text('Out of: ', style: TextStyle(color: Colors.white, fontSize: 13)),
                            Expanded(
                              child: TextFormField(
                                initialValue: '$_totalMarks',
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (v) => setState(() => _totalMarks = int.tryParse(v) ?? 50),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            student['roll'] as String,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student['name'] as String,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                            ),
                            Text(
                              student['id'] as String,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: student['marks'] as TextEditingController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '-- / $_totalMarks',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFFF3E8FF),
                          ),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
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

  Widget _buildFilterDropdown(String label, List<String> items, String value, void Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF8B5CF6),
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        items: items.map((i) => DropdownMenuItem(
          value: i,
          child: Text(i, style: const TextStyle(color: Colors.white)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

