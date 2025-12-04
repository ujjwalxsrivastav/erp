import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditTimetableScreen extends StatefulWidget {
  final Map<String, dynamic> classData;

  const EditTimetableScreen({super.key, required this.classData});

  @override
  State<EditTimetableScreen> createState() => _EditTimetableScreenState();
}

class _EditTimetableScreenState extends State<EditTimetableScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> _timetableByDay = {};
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  late TabController _tabController;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday'
  ];

  final List<Map<String, String>> _timeSlots = [
    {'slot': '1', 'start': '09:00', 'end': '10:30'},
    {'slot': '2', 'start': '10:45', 'end': '12:15'},
    {'slot': '3', 'start': '13:00', 'end': '14:30'},
    {'slot': '4', 'start': '14:45', 'end': '16:15'},
    {'slot': '5', 'start': '16:30', 'end': '17:00'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final subjectsData = await _supabase.from('subjects').select();
      final teachersData = await _supabase.from('teacher_details').select();
      final timetableData = await _supabase
          .from('timetable')
          .select('*, subjects(subject_name), teacher_details(name)')
          .eq('class_id', widget.classData['id']);

      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var day in _days) {
        grouped[day] = timetableData
            .where((t) => t['day_of_week'] == day)
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
        grouped[day]!
            .sort((a, b) => a['start_time'].compareTo(b['start_time']));
      }

      if (mounted) {
        setState(() {
          _subjects = List<Map<String, dynamic>>.from(subjectsData);
          _teachers = List<Map<String, dynamic>>.from(teachersData);
          _timetableByDay = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading timetable: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editSlot(String day, Map<String, String> timeSlot) async {
    final existingEntry = _timetableByDay[day]?.firstWhere(
      (t) => t['time_slot'] == 'Slot ${timeSlot['slot']}',
      orElse: () => {},
    );

    String? selectedSubjectId = existingEntry?['subject_id'];
    String? selectedTeacherId = existingEntry?['teacher_id'];
    String roomNumber = existingEntry?['room_number'] ?? 'Room 101';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$day - Slot ${timeSlot['slot']}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${timeSlot['start']} - ${timeSlot['end']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (existingEntry != null && existingEntry.isNotEmpty)
                          IconButton(
                            onPressed: () async {
                              await _deleteSlot(existingEntry['id']);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject
                          const Text(
                            'Subject',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedSubjectId,
                            decoration: InputDecoration(
                              hintText: 'Select subject',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0891B2),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            items: _subjects.map((subject) {
                              return DropdownMenuItem<String>(
                                value: subject['subject_id'],
                                child: Text(subject['subject_name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedSubjectId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          // Teacher
                          const Text(
                            'Teacher',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: selectedTeacherId,
                            decoration: InputDecoration(
                              hintText: 'Select teacher',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0891B2),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            items: _teachers.map((teacher) {
                              return DropdownMenuItem<String>(
                                value: teacher['teacher_id'],
                                child: Text(teacher['name']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedTeacherId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          // Room
                          const Text(
                            'Room Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: roomNumber,
                            decoration: InputDecoration(
                              hintText: 'Enter room number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0891B2),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            onChanged: (value) {
                              roomNumber = value;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Save Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (selectedSubjectId != null &&
                                selectedTeacherId != null) {
                              await _saveSlot(
                                day: day,
                                timeSlot: timeSlot,
                                subjectId: selectedSubjectId!,
                                teacherId: selectedTeacherId!,
                                roomNumber: roomNumber,
                                existingId: existingEntry?['id'],
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all fields'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0891B2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveSlot({
    required String day,
    required Map<String, String> timeSlot,
    required String subjectId,
    required String teacherId,
    required String roomNumber,
    String? existingId,
  }) async {
    try {
      if (existingId != null) {
        await _supabase.from('timetable').update({
          'subject_id': subjectId,
          'teacher_id': teacherId,
          'room_number': roomNumber,
        }).eq('id', existingId);
      } else {
        await _supabase.from('timetable').insert({
          'class_id': widget.classData['id'],
          'day_of_week': day,
          'time_slot': 'Slot ${timeSlot['slot']}',
          'start_time': timeSlot['start'],
          'end_time': timeSlot['end'],
          'subject_id': subjectId,
          'teacher_id': teacherId,
          'room_number': roomNumber,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Timetable updated'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadData();
    } catch (e) {
      print('Error saving slot: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSlot(dynamic id) async {
    try {
      await _supabase.from('timetable').delete().eq('id', id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Slot deleted'),
          backgroundColor: Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _loadData();
    } catch (e) {
      print('Error deleting slot: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final className = widget.classData['class_name'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timetable',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            Text(
              'Class $className',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF0891B2),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              indicatorColor: const Color(0xFF0891B2),
              indicatorWeight: 3,
              tabs: _days.map((day) => Tab(text: day)).toList(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _days.map((day) => _buildDayView(day)).toList(),
            ),
    );
  }

  Widget _buildDayView(String day) {
    final daySchedule = _timetableByDay[day] ?? [];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _timeSlots.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final timeSlot = _timeSlots[index];
        final entry = daySchedule.firstWhere(
          (t) => t['time_slot'] == 'Slot ${timeSlot['slot']}',
          orElse: () => {},
        );

        return InkWell(
          onTap: () => _editSlot(day, timeSlot),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: entry.isEmpty ? const Color(0xFFF8FAFC) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: entry.isEmpty
                    ? Colors.grey.shade200
                    : const Color(0xFF0891B2).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Time
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        timeSlot['slot']!,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0891B2),
                        ),
                      ),
                      Text(
                        timeSlot['start']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: entry.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No class',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to schedule',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry['subjects']?['subject_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    entry['teacher_details']?['name'] ??
                                        'Unknown',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.room_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  entry['room_number'] ?? 'TBA',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
