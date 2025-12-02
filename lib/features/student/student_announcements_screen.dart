import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/student_service.dart';

class StudentAnnouncementsScreen extends StatefulWidget {
  final String studentId;

  const StudentAnnouncementsScreen({
    super.key,
    required this.studentId,
  });

  @override
  State<StudentAnnouncementsScreen> createState() =>
      _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState
    extends State<StudentAnnouncementsScreen> {
  final _studentService = StudentService();
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String _filterPriority = 'All';
  final List<String> _priorities = ['All', 'High', 'Normal', 'Low'];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);

    try {
      final announcements =
          await _studentService.getAnnouncements(widget.studentId);

      if (mounted) {
        setState(() {
          _announcements = announcements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading announcements: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAnnouncements {
    if (_filterPriority == 'All') return _announcements;
    return _announcements.where((announcement) {
      return announcement['priority'] == _filterPriority;
    }).toList();
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'High':
        return AppTheme.error;
      case 'Normal':
        return AppTheme.warning;
      case 'Low':
        return AppTheme.success;
      default:
        return AppTheme.mediumGray;
    }
  }

  IconData _getPriorityIcon(String? priority) {
    switch (priority) {
      case 'High':
        return Icons.priority_high;
      case 'Normal':
        return Icons.info_outline;
      case 'Low':
        return Icons.low_priority;
      default:
        return Icons.announcement_outlined;
    }
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
              _buildAppBar(),
              _buildPriorityFilter(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredAnnouncements.isEmpty
                        ? _buildEmptyState()
                        : _buildAnnouncementsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Announcements',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_filteredAnnouncements.length} announcements',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnnouncements,
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityFilter() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _priorities.length,
        itemBuilder: (context, index) {
          final priority = _priorities[index];
          final isSelected = priority == _filterPriority;
          final color = _getPriorityColor(priority);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (priority != 'All')
                    Icon(
                      _getPriorityIcon(priority),
                      size: 16,
                      color: isSelected ? Colors.white : color,
                    ),
                  if (priority != 'All') const SizedBox(width: 4),
                  Text(priority),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _filterPriority = priority);
              },
              backgroundColor: Colors.white,
              selectedColor: color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.dark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              elevation: isSelected ? 4 : 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 80,
            color: AppTheme.lightGray,
          ),
          const SizedBox(height: 16),
          Text(
            'No announcements',
            style: AppTheme.h3.copyWith(color: AppTheme.mediumGray),
          ),
          const SizedBox(height: 8),
          Text(
            _filterPriority == 'All'
                ? 'No announcements posted yet'
                : 'No $_filterPriority priority announcements',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return RefreshIndicator(
      onRefresh: _loadAnnouncements,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: _filteredAnnouncements.length,
        itemBuilder: (context, index) {
          final announcement = _filteredAnnouncements[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildAnnouncementCard(announcement),
          );
        },
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final priority = announcement['priority'] ?? 'Normal';
    final priorityColor = _getPriorityColor(priority);
    final priorityIcon = _getPriorityIcon(priority);
    final subjectName = announcement['subjects']?['subject_name'] ?? 'General';
    final teacherName = announcement['teacher_details']?['name'] ?? 'Unknown';
    final createdAt = announcement['created_at'] != null
        ? DateTime.parse(announcement['created_at'])
        : null;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with priority badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(priorityIcon, color: priorityColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: priorityColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$priority Priority',
                        style: AppTheme.caption.copyWith(
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subjectName,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            announcement['title'] ?? 'Untitled Announcement',
            style: AppTheme.h4.copyWith(color: AppTheme.dark),
          ),
          const SizedBox(height: 12),

          // Message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: priorityColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Text(
              announcement['message'] ?? 'No message',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.dark,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Footer with teacher and date
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                teacherName,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: AppTheme.mediumGray),
              const SizedBox(width: 4),
              Text(
                createdAt != null
                    ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt)
                    : 'Unknown date',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.mediumGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
