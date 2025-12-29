import 'package:flutter/material.dart';
import '../data/lead_status.dart';

/// Lead Status Chip - Color-coded status indicator
class LeadStatusChip extends StatelessWidget {
  final LeadStatus status;
  final bool showIcon;
  final bool compact;

  const LeadStatusChip({
    super.key,
    required this.status,
    this.showIcon = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(LeadStatusHelper.getStatusColor(status));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Text(
              status.emoji,
              style: TextStyle(fontSize: compact ? 12 : 14),
            ),
            SizedBox(width: compact ? 4 : 6),
          ],
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lead Priority Badge
class LeadPriorityBadge extends StatelessWidget {
  final LeadPriority priority;
  final bool showLabel;

  const LeadPriorityBadge({
    super.key,
    required this.priority,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(LeadStatusHelper.getPriorityColor(priority));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(priority.emoji, style: const TextStyle(fontSize: 10)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              priority.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lead Source Badge
class LeadSourceBadge extends StatelessWidget {
  final LeadSource source;

  const LeadSourceBadge({
    super.key,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(source.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            source.label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Status Dropdown for updating lead status
class LeadStatusDropdown extends StatelessWidget {
  final LeadStatus currentStatus;
  final Function(LeadStatus) onStatusChanged;
  final bool showAllStatuses;

  const LeadStatusDropdown({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
    this.showAllStatuses = false,
  });

  @override
  Widget build(BuildContext context) {
    final availableStatuses = showAllStatuses
        ? LeadStatus.values
        : LeadStatusHelper.getNextStatuses(currentStatus);

    return PopupMenuButton<LeadStatus>(
      initialValue: currentStatus,
      onSelected: onStatusChanged,
      itemBuilder: (context) => availableStatuses.map((status) {
        return PopupMenuItem<LeadStatus>(
          value: status,
          child: Row(
            children: [
              Text(status.emoji),
              const SizedBox(width: 8),
              Text(status.label),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LeadStatusChip(
                status: currentStatus, showIcon: true, compact: true),
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

/// Followup Type Selector
class FollowupTypeSelector extends StatelessWidget {
  final FollowupType selectedType;
  final Function(FollowupType) onTypeSelected;

  const FollowupTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: FollowupType.values.map((type) {
        final isSelected = type == selectedType;
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(type.emoji),
              const SizedBox(width: 4),
              Text(type.label),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => onTypeSelected(type),
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        );
      }).toList(),
    );
  }
}
