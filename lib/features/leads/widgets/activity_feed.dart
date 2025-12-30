import 'package:flutter/material.dart';
import '../services/lead_service.dart';

/// Activity Feed Widget - Shows real-time lead activities
class ActivityFeedWidget extends StatefulWidget {
  final String? counsellorId;
  final int limit;
  final bool showHeader;
  final VoidCallback? onRefresh;

  const ActivityFeedWidget({
    super.key,
    this.counsellorId,
    this.limit = 20,
    this.showHeader = true,
    this.onRefresh,
  });

  @override
  State<ActivityFeedWidget> createState() => _ActivityFeedWidgetState();
}

class _ActivityFeedWidgetState extends State<ActivityFeedWidget> {
  final LeadService _leadService = LeadService();
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);

    final activities = await _leadService.getActivityFeed(
      counsellorId: widget.counsellorId,
      limit: widget.limit,
    );

    setState(() {
      _activities = activities;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timeline, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Activity Feed',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    _loadActivities();
                    widget.onRefresh?.call();
                  },
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _activities.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No recent activity'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadActivities,
                      child: ListView.builder(
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          return ActivityFeedCard(activity: _activities[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

/// Single Activity Card
class ActivityFeedCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityFeedCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final changeType = activity['change_type'] as String? ?? '';
    final oldStatus = activity['old_status'] as String?;
    final newStatus = activity['new_status'] as String? ?? '';
    final studentName = activity['student_name'] as String? ?? 'Unknown';
    final phone = activity['phone'] as String? ?? '';
    final course = activity['preferred_course'] as String? ?? '';
    final counsellorName = activity['counsellor_name'] as String?;
    final changedBy = activity['changed_by'] as String? ?? '';
    final notes = activity['notes'] as String?;
    final priority = activity['priority'] as String? ?? 'normal';
    final createdAt =
        DateTime.tryParse(activity['created_at'] as String? ?? '');

    // Determine icon and color based on change type
    IconData icon;
    Color color;
    String actionText;

    switch (changeType) {
      case 'status_change':
        icon = Icons.swap_horiz;
        color = Colors.blue;
        actionText = oldStatus != null
            ? '$oldStatus → $newStatus'
            : 'Status: $newStatus';
        break;
      case 'assignment':
        icon = Icons.person_add;
        color = Colors.green;
        actionText = 'Assigned to ${counsellorName ?? changedBy}';
        break;
      case 'auto_assignment':
        icon = Icons.auto_fix_high;
        color = Colors.teal;
        actionText = 'Auto-assigned to ${counsellorName ?? 'counsellor'}';
        break;
      case 'transfer':
        icon = Icons.swap_calls;
        color = Colors.orange;
        actionText = 'Transferred';
        break;
      case 'note':
        icon = Icons.note_add;
        color = Colors.purple;
        actionText = 'Note added';
        break;
      case 'created':
        icon = Icons.fiber_new;
        color = Colors.indigo;
        actionText = 'New lead created';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        actionText = changeType;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student name and priority
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          studentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (priority == 'high')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '🔴 HIGH',
                            style: TextStyle(fontSize: 10, color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Phone and course
                  Text(
                    '$phone • $course',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  // Action
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      actionText,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Notes
                  if (notes != null && notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '"$notes"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Changed by and time
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          changedBy,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(createdAt),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }
}
