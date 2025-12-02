import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/teacher_service.dart';

class MakeAnnouncementScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String teacherId;
  final String year;
  final String section;

  const MakeAnnouncementScreen({
    super.key,
    required this.subject,
    required this.teacherId,
    required this.year,
    required this.section,
  });

  @override
  State<MakeAnnouncementScreen> createState() => _MakeAnnouncementScreenState();
}

class _MakeAnnouncementScreenState extends State<MakeAnnouncementScreen> {
  final _teacherService = TeacherService();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _priority = 'Normal';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _makeAnnouncement() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _teacherService.makeAnnouncement(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        priority: _priority,
        subjectId: widget.subject['subject_id'] ?? widget.subject['course_id'],
        teacherId: widget.teacherId,
        year: widget.year,
        section: widget.section,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Announcement sent successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
          _titleController.clear();
          _messageController.clear();
          setState(() => _priority = 'Normal');
        } else {
          throw Exception('Failed to send announcement');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send announcement: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Color _getPriorityColor() {
    switch (_priority) {
      case 'High':
        return AppTheme.error;
      case 'Normal':
        return AppTheme.teacherPrimary;
      case 'Low':
        return AppTheme.mediumGray;
      default:
        return AppTheme.teacherPrimary;
    }
  }

  IconData _getPriorityIcon() {
    switch (_priority) {
      case 'High':
        return Icons.priority_high;
      case 'Normal':
        return Icons.notifications_outlined;
      case 'Low':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
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
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.teacherPrimary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.campaign_outlined,
                                  color: AppTheme.teacherPrimary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'New Announcement',
                                style:
                                    AppTheme.h4.copyWith(color: AppTheme.dark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'Announcement Title',
                              hintText: 'e.g., Important Update',
                              prefixIcon: Icon(Icons.title_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _priority,
                            decoration: InputDecoration(
                              labelText: 'Priority',
                              prefixIcon: Icon(
                                _getPriorityIcon(),
                                color: _getPriorityColor(),
                              ),
                            ),
                            items: ['High', 'Normal', 'Low']
                                .map((priority) => DropdownMenuItem(
                                      value: priority,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: priority == 'High'
                                                  ? AppTheme.error
                                                  : priority == 'Normal'
                                                      ? AppTheme.teacherPrimary
                                                      : AppTheme.mediumGray,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(priority),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _priority = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _messageController,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Message',
                              hintText: 'Enter your announcement message...',
                              prefixIcon: Icon(Icons.message_outlined),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.info.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.info,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This announcement will be sent to all students in Year ${widget.year} Section ${widget.section}',
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _makeAnnouncement,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.teacherPrimary,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor:
                                    AppTheme.teacherPrimary.withOpacity(0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send_outlined),
                                        SizedBox(width: 8),
                                        Text(
                                          'Send Announcement',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.teacherGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Make Announcement',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.subject['subject_name'] ?? widget.subject['course_name']} • Year ${widget.year} ${widget.section}',
                      style: AppTheme.h3.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
