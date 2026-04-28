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
import '../debug/database_debug_screen.dart';
// Lead Management imports
import '../features/leads/screens/dean_dashboard.dart';
import '../features/leads/screens/counsellor_dashboard.dart';
import '../features/leads/screens/lead_detail_screen.dart';
import '../features/leads/screens/lead_capture_screen.dart';
import '../features/leads/screens/counsellor_profile_screen.dart';
// Admission Flow imports
import '../features/admission/screens/temp_student_dashboard.dart';
import '../features/admission/screens/offer_letter_screen.dart';
import '../features/admission/screens/dead_admissions_screen.dart';
import '../features/admission/screens/hostel_management_screen.dart';
import '../features/admission/screens/transport_management_screen.dart';
// Hostel Module imports
import '../features/hostel/screens/warden_dashboard.dart';
import '../features/hostel/screens/student_hostel_screen.dart';
// Transport Module imports
import '../features/transport/screens/transport_dashboard.dart';
import '../features/transport/screens/student_transport_screen.dart';
import '../features/transport/screens/conductor_dashboard.dart';
import '../features/transport/screens/conductor_attendance_screen.dart';
// Finance Module imports
import '../features/finance/screens/accountant_dashboard.dart';

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
    GoRoute(
      path: '/debug',
      builder: (context, state) => const DatabaseDebugScreen(),
    ),
    // ============================================================================
    // LEAD MANAGEMENT ROUTES
    // ============================================================================
    GoRoute(
      path: '/leads/dean',
      builder: (context, state) {
        final username =
            state.uri.queryParameters['username'] ?? 'admissiondean1';
        return DeanDashboard(username: username);
      },
    ),
    GoRoute(
      path: '/leads/counsellor',
      builder: (context, state) {
        final username = state.uri.queryParameters['username'] ?? 'counsellor1';
        return CounsellorDashboard(username: username);
      },
    ),
    GoRoute(
      path: '/leads/detail/:id',
      builder: (context, state) {
        final leadId = state.pathParameters['id'] ?? '';
        final username = state.uri.queryParameters['username'] ?? 'unknown';
        return LeadDetailScreen(leadId: leadId, username: username);
      },
    ),
    GoRoute(
      path: '/leads/counsellor-profile/:id',
      builder: (context, state) {
        final counsellorId = state.pathParameters['id'] ?? '';
        return CounsellorProfileScreen(counsellorId: counsellorId);
      },
    ),
    GoRoute(
      path: '/leads/capture',
      builder: (context, state) => const LeadCaptureScreen(),
    ),
    // ============================================================================
    // ADMISSION FLOW ROUTES
    // ============================================================================
    GoRoute(
      path: '/temp-student-dashboard',
      builder: (context, state) {
        final tempId = state.uri.queryParameters['tempId'] ?? '';
        return TempStudentDashboard(tempId: tempId);
      },
    ),
    GoRoute(
      path: '/offer-letter/:tempId',
      builder: (context, state) {
        final tempId = state.pathParameters['tempId'] ?? '';
        return OfferLetterScreen(tempId: tempId);
      },
    ),
    GoRoute(
      path: '/dead-admissions',
      builder: (context, state) {
        final counsellorId = state.uri.queryParameters['counsellor'];
        return DeadAdmissionsScreen(counsellorId: counsellorId);
      },
    ),
    GoRoute(
      path: '/hostel-management',
      builder: (context, state) => const HostelManagementScreen(),
    ),
    GoRoute(
      path: '/transport-management',
      builder: (context, state) => const TransportManagementScreen(),
    ),
    // ============================================================================
    // HOSTEL MODULE ROUTES
    // ============================================================================
    GoRoute(
      path: '/warden-dashboard',
      builder: (context, state) => const WardenDashboard(),
    ),
    GoRoute(
      path: '/student/hostel',
      builder: (context, state) {
        final studentId = state.uri.queryParameters['studentId'] ?? '';
        return StudentHostelScreen(studentId: studentId);
      },
    ),
    // ============================================================================
    // TRANSPORT MODULE ROUTES
    // ============================================================================
    GoRoute(
      path: '/transport-dashboard',
      builder: (context, state) => const TransportDashboard(),
    ),
    GoRoute(
      path: '/student/transport',
      builder: (context, state) {
        final studentId = state.uri.queryParameters['studentId'] ?? '';
        final studentName = state.uri.queryParameters['studentName'] ?? 'Student';
        return StudentTransportScreen(studentId: studentId, studentName: studentName);
      },
    ),
    GoRoute(
      path: '/conductor-dashboard',
      builder: (context, state) => const ConductorDashboard(),
    ),
    GoRoute(
      path: '/conductor-attendance',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ConductorAttendanceScreen(
          bus: extra['bus'] ?? {},
          conductorUsername: extra['conductorUsername'] ?? '',
        );
      },
    ),
    // ============================================================================
    // FINANCE MODULE ROUTES
    // ============================================================================
    GoRoute(
      path: '/accountant-dashboard',
      builder: (context, state) => const AccountantDashboard(),
    ),
  ],
);
