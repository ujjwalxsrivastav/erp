import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';

class SchoolAttendanceScreen extends StatefulWidget {
  const SchoolAttendanceScreen({super.key});

  @override
  State<SchoolAttendanceScreen> createState() => _SchoolAttendanceScreenState();
}

class _SchoolAttendanceScreenState extends State<SchoolAttendanceScreen> {
  final _authService = AuthService();
  String? _role;
  String _selectedClass = 'Class 10-A';

  final List<String> _classes = ['Class 6-A', 'Class 7-A', 'Class 8-A', 'Class 9-A', 'Class 10-A', 'Class 10-B'];

  final List<Map<String, dynamic>> _students = [
    {'id': 'SCH001', 'name': 'Aarav Sharma', 'roll': '01', 'status': 'present'},
    {'id': 'SCH002', 'name': 'Priya Patel', 'roll': '02', 'status': 'absent'},
    {'id': 'SCH003', 'name': 'Rohan Gupta', 'roll': '03', 'status': 'present'},
    {'id': 'SCH004', 'name': 'Sneha Singh', 'roll': '04', 'status': 'present'},
    {'id': 'SCH005', 'name': 'Vikram Kumar', 'roll': '05', 'status': 'late'},
    {'id': 'SCH006', 'name': 'Ananya Verma', 'roll': '06', 'status': 'present'},
    {'id': 'SCH007', 'name': 'Mohit Joshi', 'roll': '07', 'status': 'present'},
    {'id': 'SCH008', 'name': 'Kavya Nair', 'roll': '08', 'status': 'absent'},
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await _authService.getCurrentUserRole();
    if (mounted) setState(() => _role = role);
  }

  int get _presentCount => _students.where((s) => s['status'] == 'present').length;
  int get _absentCount => _students.where((s) => s['status'] == 'absent').length;
  int get _lateCount => _students.where((s) => s['status'] == 'late').length;

  @override
  Widget build(BuildContext context) {
    final isTeacher = _role == 'teacher' || _role == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isTeacher)
            TextButton.icon(
              onPressed: _saveAttendance,
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
              color: Color(0xFF10B981),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip('Present', _presentCount, const Color(0xFFECFDF5), const Color(0xFF10B981)),
                    _buildStatChip('Absent', _absentCount, const Color(0xFFFEE2E2), const Color(0xFFEF4444)),
                    _buildStatChip('Late', _lateCount, const Color(0xFFFEF3C7), const Color(0xFFF59E0B)),
                    _buildStatChip('Total', _students.length, Colors.white.withOpacity(0.2), Colors.white),
                  ],
                ),
                const SizedBox(height: 12),
                if (isTeacher)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedClass,
                      dropdownColor: const Color(0xFF10B981),
                      underline: const SizedBox.shrink(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      isExpanded: true,
                      items: _classes.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(color: Colors.white)),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedClass = v!),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _students.length,
              itemBuilder: (context, index) => _buildStudentCard(_students[index], isTeacher),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8))),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student, bool isTeacher) {
    final status = student['status'] as String;
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'present':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        break;
      case 'late':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.watch_later;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                student['roll'] as String,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: statusColor),
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
          if (isTeacher)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusButton(student, 'present', const Color(0xFF10B981), Icons.check),
                const SizedBox(width: 6),
                _buildStatusButton(student, 'absent', const Color(0xFFEF4444), Icons.close),
                const SizedBox(width: 6),
                _buildStatusButton(student, 'late', const Color(0xFFF59E0B), Icons.watch_later_outlined),
              ],
            )
          else
            Icon(statusIcon, color: statusColor, size: 28),
        ],
      ),
    );
  }

  Widget _buildStatusButton(Map<String, dynamic> student, String status, Color color, IconData icon) {
    final isSelected = student['status'] == status;
    return GestureDetector(
      onTap: () => setState(() => student['status'] = status),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
      ),
    );
  }

  void _saveAttendance() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attendance saved: $_presentCount present, $_absentCount absent, $_lateCount late'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

