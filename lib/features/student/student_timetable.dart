import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';

class StudentTimetable extends StatefulWidget {
  const StudentTimetable({super.key});

  @override
  State<StudentTimetable> createState() => _StudentTimetableState();
}

class _StudentTimetableState extends State<StudentTimetable>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _studentService = StudentService();

  late TabController _tabController;
  Map<String, List<Map<String, dynamic>>> _timetableByDay = {};
  bool _isLoading = true;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    // Set current day as default
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1; // Monday = 0
    if (currentDayIndex < _days.length) {
      _tabController.index = currentDayIndex;
    }
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    try {
      final username = await _authService.getCurrentUsername();
      if (username != null) {
        final timetable = await _studentService.getTimetable(username);

        // Group by day and sort by start_time (ascending)
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (final day in _days) {
          grouped[day] = [];
        }

        for (final entry in timetable) {
          final day = entry['day_of_week'] as String?;
          if (day != null && grouped.containsKey(day)) {
            grouped[day]!.add(entry);
          }
        }

        // Sort each day's classes by start_time (ascending - Slot 1 first)
        for (final day in _days) {
          grouped[day]!.sort((a, b) {
            final timeA = a['start_time'] as String? ?? '00:00';
            final timeB = b['start_time'] as String? ?? '00:00';
            return timeA.compareTo(timeB);
          });
        }

        if (mounted) {
          setState(() {
            _timetableByDay = grouped;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading timetable: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getSlotColor(int index) {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Orange
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.background, AppTheme.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: _days.map((day) {
                          final classes = _timetableByDay[day] ?? [];
                          return _buildDaySchedule(day, classes);
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: AppTheme.studentGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Timetable',
                      style: AppTheme.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weekly class schedule',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          gradient: AppTheme.studentGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.mediumGray,
        labelStyle: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: AppTheme.bodyMedium,
        tabs: _days.map((day) => Tab(text: day.substring(0, 3))).toList(),
      ),
    );
  }

  Widget _buildDaySchedule(String day, List<Map<String, dynamic>> classes) {
    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.studentPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.weekend,
                size: 64,
                color: AppTheme.studentPrimary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No classes on $day',
              style: AppTheme.h4.copyWith(color: AppTheme.dark),
            ),
            const SizedBox(height: 8),
            Text(
              'Enjoy your free day!',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final classData = classes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildClassCard(classData, index),
        );
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData, int index) {
    final subject = classData['subjects'] as Map<String, dynamic>?;
    final teacher = classData['teacher_details'] as Map<String, dynamic>?;
    final startTime = classData['start_time'] as String? ?? '';
    final endTime = classData['end_time'] as String? ?? '';
    final room = classData['room_number'] as String? ?? 'TBD';
    final slotColor = _getSlotColor(index);

    return GlassCard(
      child: Row(
        children: [
          // Time slot indicator
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [slotColor, slotColor.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Slot ${index + 1}',
                  style: AppTheme.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  startTime.substring(0, 5),
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'to',
                  style: AppTheme.caption.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  endTime.substring(0, 5),
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject?['subject_name'] ?? 'Unknown Subject',
                  style: AppTheme.h5.copyWith(color: AppTheme.dark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 16, color: AppTheme.mediumGray),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        teacher?['name'] ?? 'TBA',
                        style: AppTheme.bodySmall
                            .copyWith(color: AppTheme.mediumGray),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: AppTheme.mediumGray),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.mediumGray),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
