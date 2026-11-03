import 'package:flutter/material.dart';

class SchoolTimetableScreen extends StatefulWidget {
  const SchoolTimetableScreen({super.key});

  @override
  State<SchoolTimetableScreen> createState() => _SchoolTimetableScreenState();
}

class _SchoolTimetableScreenState extends State<SchoolTimetableScreen> {
  String _selectedDay = 'Monday';
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  final Map<String, List<Map<String, dynamic>>> _timetable = {
    'Monday': [
      {'period': '1', 'time': '08:00 - 09:00', 'subject': 'Mathematics', 'teacher': 'Mr. Sharma', 'room': '201'},
      {'period': '2', 'time': '09:00 - 10:00', 'subject': 'Science', 'teacher': 'Mrs. Gupta', 'room': '102'},
      {'period': '3', 'time': '10:15 - 11:15', 'subject': 'English', 'teacher': 'Ms. Verma', 'room': '301'},
      {'period': '4', 'time': '11:15 - 12:15', 'subject': 'Hindi', 'teacher': 'Mr. Singh', 'room': '201'},
      {'period': 'BREAK', 'time': '12:15 - 13:00', 'subject': 'Lunch Break', 'teacher': '', 'room': ''},
      {'period': '5', 'time': '13:00 - 14:00', 'subject': 'Social Studies', 'teacher': 'Mr. Kumar', 'room': '101'},
      {'period': '6', 'time': '14:00 - 15:00', 'subject': 'Computer', 'teacher': 'Ms. Nair', 'room': 'Lab'},
    ],
    'Tuesday': [
      {'period': '1', 'time': '08:00 - 09:00', 'subject': 'English', 'teacher': 'Ms. Verma', 'room': '301'},
      {'period': '2', 'time': '09:00 - 10:00', 'subject': 'Mathematics', 'teacher': 'Mr. Sharma', 'room': '201'},
      {'period': '3', 'time': '10:15 - 11:15', 'subject': 'Hindi', 'teacher': 'Mr. Singh', 'room': '201'},
      {'period': '4', 'time': '11:15 - 12:15', 'subject': 'Computer', 'teacher': 'Ms. Nair', 'room': 'Lab'},
      {'period': 'BREAK', 'time': '12:15 - 13:00', 'subject': 'Lunch Break', 'teacher': '', 'room': ''},
      {'period': '5', 'time': '13:00 - 14:00', 'subject': 'Science', 'teacher': 'Mrs. Gupta', 'room': '102'},
      {'period': '6', 'time': '14:00 - 15:00', 'subject': 'Art', 'teacher': 'Mr. Roy', 'room': 'Art Room'},
    ],
  };

  final List<Color> _colors = [
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFF8B5CF6),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF06B6D4),
    const Color(0xFFFF6B6B),
  ];

  final Map<String, Color> _subjectColors = {};
  int _colorIdx = 0;

  Color _getSubjectColor(String subject) {
    if (!_subjectColors.containsKey(subject)) {
      _subjectColors[subject] = _colors[_colorIdx % _colors.length];
      _colorIdx++;
    }
    return _subjectColors[subject]!;
  }

  @override
  Widget build(BuildContext context) {
    final periods = _timetable[_selectedDay] ?? _timetable['Monday']!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Timetable', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0F766E),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: _days.map((day) {
                  final isSelected = day == _selectedDay;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        day.substring(0, 3),
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final p = periods[index];
                final isBreak = p['period'] == 'BREAK';

                if (isBreak) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lunch_dining, size: 16, color: Colors.grey.shade500),
                        const SizedBox(width: 8),
                        Text(
                          '${p['time']} — Lunch Break',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                final subjectColor = _getSubjectColor(p['subject'] as String);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(left: BorderSide(color: subjectColor, width: 4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: subjectColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            p['period'] as String,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subjectColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['subject'] as String,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p['teacher']} • Room ${p['room']}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: subjectColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          p['time'] as String,
                          style: TextStyle(fontSize: 11, color: subjectColor, fontWeight: FontWeight.w600),
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
}

