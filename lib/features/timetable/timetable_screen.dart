import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/timetable_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  final _timetableService = TimetableService();
  late TabController _tabController;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday'
  ];
  Map<String, List<Map<String, dynamic>>> _weekTimetable = {};
  bool _isLoading = true;
  int _currentDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentDayIndex = _getCurrentDayIndex();
    _tabController =
        TabController(length: 5, vsync: this, initialIndex: _currentDayIndex);
    _loadTimetable();
  }

  int _getCurrentDayIndex() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    if (weekday >= 1 && weekday <= 5) {
      return weekday - 1; // 0-4 for Mon-Fri
    }
    return 0; // Default to Monday on weekends
  }

  Future<void> _loadTimetable() async {
    final timetable = await _timetableService.getWeekTimetable();
    if (mounted) {
      setState(() {
        _weekTimetable = timetable;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('Timetable'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/student-dashboard'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _days.map((day) => Tab(text: day)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _days.map((day) => _buildDaySchedule(day)).toList(),
            ),
    );
  }

  Widget _buildDaySchedule(String day) {
    final schedule = _weekTimetable[day] ?? [];

    if (schedule.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schedule.length,
      itemBuilder: (context, index) {
        final classItem = schedule[index];
        return _buildClassCard(classItem, index);
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classItem, int index) {
    // This legacy route may receive either `timetable` rows with nested
    // relations or the newer flat `school_timetable` rows.  Relations can be
    // null when a subject/teacher was removed, so never dereference them.
    final subjectData = classItem['subjects'];
    final teacherData = classItem['teacher_details'];
    final subject = subjectData is Map
        ? (subjectData['subject_name']?.toString() ??
            classItem['subject']?.toString() ??
            'Subject')
        : (classItem['subject']?.toString() ?? 'Subject');
    final teacher = teacherData is Map
        ? (teacherData['name']?.toString() ??
            classItem['teacher_username']?.toString() ??
            'Teacher TBA')
        : (classItem['teacher_username']?.toString() ?? 'Teacher TBA');
    final startTime = classItem['start_time']?.toString() ?? 'Time TBA';
    final endTime = classItem['end_time']?.toString() ?? '';
    final room = classItem['room_number']?.toString() ??
        classItem['room']?.toString() ??
        'Room TBA';
    final timeSlot = classItem['time_slot']?.toString() ??
        (classItem['period'] == null
            ? 'Class'
            : 'Period ${classItem['period']}');

    // Color scheme based on index
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Time indicator
          Container(
            width: 6,
            height: 132,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          timeSlot,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                endTime.isEmpty
                                    ? startTime
                                    : '$startTime - $endTime',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          teacher,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.room_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          room,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
