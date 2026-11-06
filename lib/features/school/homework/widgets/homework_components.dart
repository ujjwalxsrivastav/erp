import 'package:flutter/material.dart';

class HomeworkCard extends StatelessWidget {
  const HomeworkCard({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.children,
    super.key,
  });

  final String title;
  final String status;
  final Color statusColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  SubmissionStatusChip(label: status, color: statusColor),
                ],
              ),
              ...children,
            ],
          ),
        ),
      );
}

class SubmissionStatusChip extends StatelessWidget {
  const SubmissionStatusChip({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text(label),
        labelStyle: TextStyle(color: color),
        side: BorderSide(color: color.withValues(alpha: .4)),
      );
}

class GradeFeedbackPanel extends StatelessWidget {
  const GradeFeedbackPanel({
    this.grade,
    this.feedback,
    super.key,
  });

  final String? grade;
  final String? feedback;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (grade != null && grade!.isNotEmpty) 'Grade: $grade',
      if (feedback != null && feedback!.isNotEmpty) 'Feedback: $feedback',
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(lines.join('\n')),
    );
  }
}
