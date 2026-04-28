import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/transport_service.dart';

class ConductorAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  final String conductorUsername;

  const ConductorAttendanceScreen({
    super.key,
    required this.bus,
    required this.conductorUsername,
  });

  @override
  State<ConductorAttendanceScreen> createState() =>
      _ConductorAttendanceScreenState();
}

class _ConductorAttendanceScreenState extends State<ConductorAttendanceScreen> {
  final _service = TransportService();
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  Map<String, bool> _attendance = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final students = await _service.getBusStudents(widget.bus['id']);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final records = await _service.getAttendanceForDate(widget.bus['id'], dateStr);

    final Map<String, bool> attMap = {};
    for (var r in records) {
      attMap[r['student_id']] = r['is_present'] == true;
    }

    // Default to true (Present) if not marked
    for (var s in students) {
      if (!attMap.containsKey(s['student_id'])) {
        attMap[s['student_id']] = true;
      }
    }

    if (mounted) {
      setState(() {
        _allStudents = students;
        _filteredStudents = students;
        _attendance = attMap;
        _loading = false;
      });
      _filterStudents(_searchQuery);
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        final q = query.toLowerCase();
        _filteredStudents = _allStudents.where((s) {
          final name = (s['student_name'] ?? '').toLowerCase();
          final id = (s['student_id'] ?? '').toLowerCase();
          return name.contains(q) || id.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _toggleStudent(String studentId, bool val) async {
    setState(() => _attendance[studentId] = val);
    
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final studentName = _allStudents.firstWhere((s) => s['student_id'] == studentId)['student_name'];
    
    await _service.markAttendance(
      busId: widget.bus['id'],
      dateStr: dateStr,
      studentId: studentId,
      studentName: studentName,
      isPresent: val,
      conductorUsername: widget.conductorUsername,
    );
  }

  Future<void> _markAll(bool isPresent) async {
    setState(() => _loading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    List<String> presentIds = [];
    List<String> absentIds = [];

    for (var s in _filteredStudents) {
      final id = s['student_id'];
      _attendance[id] = isPresent;
      if (isPresent) presentIds.add(id);
      else absentIds.add(id);
    }

    await _service.markBulkAttendance(
      busId: widget.bus['id'],
      dateStr: dateStr,
      presentStudentIds: presentIds,
      absentStudentIds: absentIds,
      conductorUsername: widget.conductorUsername,
    );

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD97706),
            surface: Color(0xFF1E2D3D),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendance.values.where((v) => v).length;
    final totalCount = _allStudents.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF92400E),
        title: const Text('Digital Register'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD97706)))
          : Column(
              children: [
                _buildHeader(presentCount, totalCount),
                _buildSearchBar(),
                _buildBulkActions(),
                Expanded(
                  child: _filteredStudents.isEmpty
                      ? const Center(
                          child: Text('No students found.',
                              style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (ctx, i) => _buildStudentTile(_filteredStudents[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(int present, int total) {
    final dateStr = DateFormat('EEEE, MMM d').format(_selectedDate);
    final pct = total == 0 ? 0.0 : present / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _selectDate,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Bus #${widget.bus['bus_number']}',
                    style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Attendance', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('$present / $total Present',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50, height: 50,
                    child: CircularProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white10,
                      color: pct > 0.5 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      strokeWidth: 6,
                    ),
                  ),
                  Text('${(pct * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search student name or ID...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF1E2D3D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _filterStudents,
      ),
    );
  }

  Widget _buildBulkActions() {
    // Only show if today or past
    if (_selectedDate.isAfter(DateTime.now())) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAll(true),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Mark All Present'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                foregroundColor: const Color(0xFF10B981),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAll(false),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Mark All Absent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
                foregroundColor: const Color(0xFFEF4444),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(Map<String, dynamic> student) {
    final id = student['student_id'];
    final name = student['student_name'];
    final isPresent = _attendance[id] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPresent ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isPresent ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
          child: Text(name[0].toUpperCase(), style: TextStyle(color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(id, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: Switch(
          value: isPresent,
          activeColor: const Color(0xFF10B981),
          inactiveThumbColor: const Color(0xFFEF4444),
          inactiveTrackColor: const Color(0xFFEF4444).withOpacity(0.3),
          onChanged: _selectedDate.isAfter(DateTime.now()) ? null : (val) => _toggleStudent(id, val),
        ),
      ),
    );
  }
}
