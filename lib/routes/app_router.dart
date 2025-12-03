import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/student_dashboard.dart';
import '../features/dashboard/teacher_dashboard.dart';
import '../features/dashboard/admin_dashboard.dart';
import '../features/dashboard/hr_dashboard.dart';
import '../features/dashboard/hod_dashboard.dart';
import '../features/student/student_profile_screen.dart';
import '../features/student/student_subjects_screen.dart';
import '../features/student/student_exam_schedule_screen.dart';
import '../features/student/student_library.dart';
import '../features/student/student_notice_screen.dart';
import '../features/student/coming_soon_screen.dart';
import '../features/teacher/teacher_profile_screen.dart';
import '../features/timetable/timetable_screen.dart';
import '../features/admin/add_user_screen.dart';
import '../features/admin/add_teacher_screen.dart';
import '../features/admin/add_student_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/student-dashboard',
      builder: (context, state) => const StudentDashboard(),
    ),
    GoRoute(
      path: '/student-profile',
      builder: (context, state) => const StudentProfileScreen(),
    ),
    GoRoute(
      path: '/student/dashboard',
      builder: (context, state) => const StudentDashboard(),
    ),
    GoRoute(
      path: '/student/subjects',
      builder: (context, state) => const StudentSubjectsScreen(),
    ),
    GoRoute(
      path: '/student/exam-schedule',
      builder: (context, state) => const StudentExamScheduleScreen(),
    ),
    GoRoute(
      path: '/student/library',
      builder: (context, state) => const StudentLibraryScreen(),
    ),
    GoRoute(
      path: '/student/notice',
      builder: (context, state) => const StudentNoticeScreen(),
    ),
    GoRoute(
      path: '/student/clubs',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Clubs & Activities',
        subtitle: 'Join clubs, participate in events, and connect with peers.',
        icon: Icons.groups,
        primaryColor: Color(0xFFF59E0B),
        secondaryColor: Color(0xFFEF4444),
      ),
    ),
    GoRoute(
      path: '/student/settings',
      builder: (context, state) => const ComingSoonScreen(
        title: 'Settings',
        subtitle: 'Customize your preferences and manage your account.',
        icon: Icons.settings,
        primaryColor: Color(0xFF6B7280),
        secondaryColor: Color(0xFF4B5563),
      ),
    ),
    GoRoute(
      path: '/timetable',
      builder: (context, state) => const TimetableScreen(),
    ),
    GoRoute(
      path: '/teacher-dashboard',
      builder: (context, state) => const TeacherDashboardScreen(),
    ),
    GoRoute(
      path: '/teacher-profile',
      builder: (context, state) => const TeacherProfileScreen(),
    ),
    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => const AdminDashboard(),
    ),
    GoRoute(
      path: '/hr-dashboard',
      builder: (context, state) => const HRDashboard(),
    ),
    GoRoute(
      path: '/hod-dashboard',
      builder: (context, state) => const HODDashboard(),
    ),
    GoRoute(
      path: '/admin/add-user',
      builder: (context, state) => const AddUserScreen(),
    ),
    GoRoute(
      path: '/admin/add-teacher',
      builder: (context, state) => const AddTeacherScreen(),
    ),
    GoRoute(
      path: '/admin/add-student',
      builder: (context, state) => const AddStudentScreen(),
    ),
  ],
);
