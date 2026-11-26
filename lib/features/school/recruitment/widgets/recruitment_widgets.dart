import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

/// Shared visual language for the school-only recruitment screens.
class RecruitmentColors {
  static const navy = Color(0xFF0F172A);
  static const navySoft = Color(0xFF1E293B);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFDBEAFE);
  static const sky = Color(0xFF0EA5E9);
  static const green = Color(0xFF059669);
  static const greenSoft = Color(0xFFD1FAE5);
  static const amber = Color(0xFFD97706);
  static const amberSoft = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEE2E2);
  static const slate = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const surface = Color(0xFFF8FAFC);
}

String recruitmentStatusLabel(String? status) {
  final value = (status ?? 'unknown').replaceAll('_', ' ');
  return value.isEmpty
      ? 'Unknown'
      : value
          .split(' ')
          .map((w) => w.isEmpty
              ? w
              : '${w.substring(0, 1).toUpperCase()}${w.substring(1)}')
          .join(' ');
}

Color recruitmentStatusColor(String? status) {
  switch (status) {
    case 'published':
    case 'documents_verified':
    case 'verified':
    case 'completed':
    case 'selected':
    case 'enrolled':
      return RecruitmentColors.green;
    case 'interview_scheduled':
    case 'scheduled':
    case 'documents_pending':
      return RecruitmentColors.blue;
    case 'closed':
    case 'rejected':
    case 'cancelled':
    case 'no_show':
      return RecruitmentColors.red;
    case 'interview_completed':
    case 'pending':
      return RecruitmentColors.amber;
    default:
      return RecruitmentColors.slate;
  }
}

class RecruitmentStatusChip extends StatelessWidget {
  final String? status;
  final bool compact;

  const RecruitmentStatusChip({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = recruitmentStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        recruitmentStatusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: color,
        ),
      ),
    );
  }
}

class RecruitmentSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;
  final Color accent;

  const RecruitmentSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.action,
    this.accent = RecruitmentColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RecruitmentColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(
              children: [
                Icon(icon, size: 17, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: RecruitmentColors.navy,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          const Divider(height: 1, color: RecruitmentColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class RecruitmentEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const RecruitmentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RecruitmentColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RecruitmentColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: RecruitmentColors.slate),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: RecruitmentColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: RecruitmentColors.slate),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: RecruitmentColors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration recruitmentFieldDecoration(
  String label, {
  IconData? icon,
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 19),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: RecruitmentColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: RecruitmentColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: RecruitmentColors.blue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: RecruitmentColors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: RecruitmentColors.red, width: 2),
    ),
  );
}

String recruitmentDate(dynamic value) {
  if (value == null) return 'Not set';
  final dt = DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return DateFormat('dd MMM yyyy').format(dt);
}

String recruitmentDateTime(dynamic value) {
  if (value == null) return 'Not scheduled';
  final dt = DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
}

void showRecruitmentMessage(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? RecruitmentColors.red : RecruitmentColors.navy,
    ),
  );
}

/// Amber note used for "admin only" or "read only" hints.
class RecruitmentNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const RecruitmentNotice({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = RecruitmentColors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small labelled stat used on the board header.
class RecruitmentStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const RecruitmentStat({
    super.key,
    required this.value,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

/// Standard app bar used by the recruitment screens.
AppBar recruitmentAppBar(String title, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: RecruitmentColors.navy,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    actions: actions,
  );
}

/// Reusable gradient header.
class RecruitmentHero extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> stats;
  final Widget? trailing;

  const RecruitmentHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon = Icons.work_outline_rounded,
    this.stats = const [],
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RecruitmentColors.navy, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF93C5FD), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF93C5FD),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFCBD5E1),
              height: 1.4,
            ),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 26),
                  stats[i],
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard padded page body.
class RecruitmentBody extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;

  const RecruitmentBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 32),
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: RecruitmentColors.blue,
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
      ),
    );
  }
}

/// Convenience text style helpers.
const kRecruitmentTitle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: RecruitmentColors.navy,
);

const kRecruitmentBody = TextStyle(
  fontSize: 12,
  color: RecruitmentColors.navySoft,
  height: 1.4,
);

const kRecruitmentCaption = TextStyle(
  fontSize: 10.5,
  color: RecruitmentColors.slate,
  height: 1.35,
);

/// Theme-aware accent for admin-only UI.
Color get recruitmentAdminAccent => AppTheme.adminPrimary;
