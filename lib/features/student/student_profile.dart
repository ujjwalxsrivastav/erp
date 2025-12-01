// Student Profile Screen
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class StudentProfile extends StatelessWidget {
  const StudentProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/student/dashboard'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 100, color: AppTheme.studentPrimary),
            const SizedBox(height: 20),
            Text(
              'Profile Screen',
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
