import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/lead_model.dart';
import '../data/lead_status.dart';
import 'lead_status_chip.dart';

/// Lead Card - Displays lead information with quick actions
class LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback? onTap;
  final VoidCallback? onAssign;
  final VoidCallback? onStatusUpdate;
  final bool showAssignButton;
  final bool showQuickActions;
  final bool isCompact;

  const LeadCard({
    super.key,
    required this.lead,
    this.onTap,
    this.onAssign,
    this.onStatusUpdate,
    this.showAssignButton = false,
    this.showQuickActions = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      elevation: lead.priority == LeadPriority.high ? 4 : 2,
      shadowColor: lead.priority == LeadPriority.high
          ? Colors.red.withOpacity(0.3)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: lead.priority == LeadPriority.high
            ? const BorderSide(color: Colors.red, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              _buildHeader(context),

              SizedBox(height: isCompact ? 8 : 12),

              // Contact Info
              _buildContactInfo(),

              if (!isCompact) ...[
                const SizedBox(height: 12),

                // Course & Location
                _buildCourseLocation(),

                const SizedBox(height: 12),

                // Status & Actions Row
                _buildActionsRow(context),
              ],

              // Follow-up reminder if applicable
              if (lead.needsFollowupToday || lead.isFollowupOverdue)
                _buildFollowupReminder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Priority indicator
        if (lead.priority == LeadPriority.high)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 16)),
          )
        else
          CircleAvatar(
            radius: isCompact ? 18 : 22,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              lead.studentName.isNotEmpty
                  ? lead.studentName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: isCompact ? 14 : 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

        const SizedBox(width: 12),

        // Name and source
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead.studentName,
                style: TextStyle(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  LeadSourceBadge(source: lead.source),
                  const SizedBox(width: 8),
                  Text(
                    lead.timeSinceCreation,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Status chip
        LeadStatusChip(
          status: lead.status,
          compact: isCompact,
        ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Row(
      children: [
        Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          lead.phone,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        if (lead.email != null) ...[
          const SizedBox(width: 16),
          Icon(Icons.email, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              lead.email!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCourseLocation() {
    return Row(
      children: [
        // Course
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school, size: 14, color: Colors.blue.shade700),
              const SizedBox(width: 4),
              Text(
                lead.preferredCourse,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Location
        if (lead.city != null || lead.state != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  [lead.city, lead.state].where((e) => e != null).join(', '),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionsRow(BuildContext context) {
    return Row(
      children: [
        // Priority badge
        LeadPriorityBadge(priority: lead.priority),

        const Spacer(),

        // Quick action buttons
        if (showQuickActions) ...[
          // Call button
          _QuickActionButton(
            icon: Icons.phone,
            color: Colors.green,
            tooltip: 'Call',
            onPressed: () => _makeCall(lead.phone),
          ),
          const SizedBox(width: 8),

          // WhatsApp button
          _QuickActionButton(
            icon: Icons.chat,
            color: Colors.teal,
            tooltip: 'WhatsApp',
            onPressed: () => _openWhatsApp(lead.phone),
          ),
          const SizedBox(width: 8),

          // Update status button
          if (onStatusUpdate != null)
            _QuickActionButton(
              icon: Icons.update,
              color: Colors.blue,
              tooltip: 'Update Status',
              onPressed: onStatusUpdate!,
            ),
        ],

        // Assign button (for Dean)
        if (showAssignButton && onAssign != null) ...[
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Assign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFollowupReminder() {
    final isOverdue = lead.isFollowupOverdue;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOverdue ? Colors.red.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            size: 18,
            color: isOverdue ? Colors.red : Colors.amber.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            isOverdue ? 'Follow-up overdue!' : 'Follow-up scheduled for today',
            style: TextStyle(
              color: isOverdue ? Colors.red : Colors.amber.shade800,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makeCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // Remove any non-numeric characters
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final formattedPhone =
        cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

    final uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Quick Action Button
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Compact Lead Tile for lists
class LeadTile extends StatelessWidget {
  final Lead lead;
  final VoidCallback? onTap;

  const LeadTile({
    super.key,
    required this.lead,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Color(LeadStatusHelper.getStatusColor(lead.status))
            .withOpacity(0.2),
        child: Text(
          lead.studentName.isNotEmpty ? lead.studentName[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(LeadStatusHelper.getStatusColor(lead.status)),
          ),
        ),
      ),
      title: Text(
        lead.studentName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${lead.preferredCourse} • ${lead.phone}'),
      trailing: LeadStatusChip(
        status: lead.status,
        showIcon: false,
        compact: true,
      ),
    );
  }
}
