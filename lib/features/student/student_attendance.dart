// Student Attendance Screen
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class StudentAttendance extends StatelessWidget {
  const StudentAttendance({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/student/dashboard'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, size: 100, color: AppTheme.success),
            const SizedBox(height: 20),
            Text(
              'Attendance Screen',
              style: AppTheme.h3.copyWith(color: AppTheme.dark),
            ),
            const SizedBox(height: 10),
            Text(
              'Coming Soon!',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.mediumGray),
            ),
          ],
        ),
      ),
    );
  }
}
