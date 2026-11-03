import 'package:flutter/material.dart';
import '../config/erp_config.dart';
import '../theme/app_theme.dart';

class ModeBadge extends StatelessWidget {
  final ERPMode mode;
  final bool compact;

  const ModeBadge({super.key, required this.mode, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isSchool = mode == ERPMode.school;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSchool
              ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)]
              : [AppTheme.studentPrimary, AppTheme.studentLight],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSchool ? Icons.school_rounded : Icons.account_balance_rounded,
            size: compact ? 10 : 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isSchool ? 'SCHOOL' : 'COLLEGE',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
