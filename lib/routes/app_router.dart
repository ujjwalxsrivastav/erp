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
import '../features/finance/screens/fee_head_management_screen.dart';
import '../features/finance/screens/chart_of_accounts_screen.dart';
import '../features/finance/screens/journal_entry_screen.dart';
import '../features/finance/screens/receipt_management_screen.dart';
import '../features/finance/screens/student_ledger_screen.dart';
import '../features/finance/screens/scholarship_management_screen.dart';
import '../features/finance/screens/financial_reports_screen.dart';
import '../features/finance/screens/audit_log_screen.dart';
import '../features/finance/screens/financial_year_screen.dart';
// Examination (COE) Module imports
import '../features/examination/screens/coe_dashboard.dart';
import '../features/examination/screens/exam_sessions_screen.dart';
import '../features/examination/screens/result_management_screen.dart';
import '../features/examination/screens/tabulation_screen.dart';
import '../features/examination/screens/revaluation_screen.dart';
import '../features/examination/screens/student_hall_ticket_screen.dart';
import '../features/examination/screens/student_result_screen.dart';
// Admin Workflow imports (No-Dues, Certificates, Grievance)
import '../features/admin/screens/nodues_management_screen.dart';
import '../features/admin/screens/certificate_management_screen.dart';
import '../features/admin/screens/grievance_management_screen.dart';
// HR Workflow imports (Recruitment, Appraisal, Exit)
import '../features/hr/screens/recruitment_screen.dart';
import '../features/hr/screens/appraisal_screen.dart';
import '../features/hr/screens/exit_management_screen.dart';
// Finance Extension imports (Budget, Purchase, Grants)
import '../features/finance/screens/budget_management_screen.dart';
import '../features/finance/screens/purchase_management_screen.dart';
import '../features/finance/screens/grant_management_screen.dart';
// Teacher Lifecycle + Payroll imports
import '../features/hr/screens/hiring_pipeline_screen.dart';
import '../features/hr/screens/onboarding_screen.dart';
import '../features/hr/screens/subject_allotment_screen.dart';
import '../features/hr/screens/payroll_runs_screen.dart';
import '../features/hr/screens/my_payslips_screen.dart';
// Superadmin + User Management imports
import '../features/admin/screens/institute_setup_screen.dart';
import '../features/admin/screens/manage_users_screen.dart';
import '../features/admin/screens/manage_timetable_screen.dart';
// Fee Insights import
import '../features/finance/screens/fee_insights_screen.dart';
// Admission Flow imports
import '../features/leads/screens/lead_capture_form_screen.dart';
import '../features/leads/screens/admission_form_screen.dart';
import '../features/leads/screens/admission_review_screen.dart';

// School imports
import '../features/school/school_student_dashboard.dart';
import '../features/school/school_teacher_dashboard.dart';
import '../features/school/school_admin_dashboard.dart';
import '../features/school/parent/school_parent_dashboard.dart';
import '../features/school/homework/homework_list_screen.dart';
import '../features/school/homework/add_homework_screen.dart';
import '../features/school/leave/student_leave_screen.dart';
import '../features/school/attendance/school_attendance_screen.dart';
import '../features/school/marks/marks_csv_upload_screen.dart';
import '../features/school/marks/marks_entry_screen.dart';
import '../features/school/marks/report_card_screen.dart';
import '../features/school/timetable/school_timetable_screen.dart';
import '../features/school/circulars/circulars_screen.dart';
import '../features/school/transport/transport_screen.dart';
import '../features/school/fee/school_fee_screen.dart';
import '../features/school/admissions/admissions_screen.dart';
import '../features/school/reports/school_reports_screen.dart';
import '../features/school/library/school_library_screen.dart';
import '../features/school/certificates/school_certificates_screen.dart';
import '../features/school/promotion/school_promotion_screen.dart';
import '../features/school/examination/school_examination_screen.dart';
import '../features/school/academics/school_lesson_plan_screen.dart';
import '../features/school/payroll/school_payroll_screen.dart';
import '../features/school/payroll/school_my_payslips_screen.dart';
import '../features/school/living/school_living_screen.dart';
import '../features/school/alumni/school_alumni_screen.dart';
import '../features/school/inventory/school_inventory_screen.dart';
import '../features/school/activities/school_activities_screen.dart';
import '../features/school/discipline/school_discipline_screen.dart';
import '../features/school/admin/school_multi_admin_screen.dart';
import '../features/school/library/school_library_deep_screen.dart';
import '../features/school/admin/school_permission_matrix_screen.dart';
import '../features/school/ai/school_ai_assistant_screen.dart';
import '../features/school/calendar/school_academic_calendar_screen.dart';
import '../features/school/admin/school_masters_screen.dart';
import '../services/auth_service.dart';

/// Route permission mappings for School ERP (Deny-by-default access control)
const _schoolAdminRoles = {'admin', 'sadmin', 'principal', 'superadmin'};
const _schoolStaffRoles = {'admin', 'sadmin', 'principal', 'superadmin', 'teacher', 'steacher'};
const _schoolAccountantRoles = {'admin', 'sadmin', 'principal', 'superadmin', 'accountant'};
const _allSchoolRoles = {
  'admin', 'sadmin', 'principal', 'superadmin',
  'teacher', 'steacher',
  'student', 'sstudent',
  'parent', 'sparent',
  'warden', 'nurse', 'conductor', 'librarian', 'alumni', 'staff', 'accountant',
};

final Map<String, Set<String>> _schoolRoutePermissions = {
  // Admin only
  '/school/admin-dashboard': _schoolAdminRoles,
  '/school/admissions': _schoolAdminRoles,
  '/school/admissions/apply': _schoolAdminRoles,
  '/school/promotion': _schoolAdminRoles,
  '/school/multi-admin': {'admin', 'sadmin', 'superadmin'},
  '/school/permissions': {'admin', 'sadmin', 'superadmin'},
  '/school/masters': _schoolAdminRoles,
  '/school/payroll': _schoolAccountantRoles,

  // Staff (Teacher + Admin)
  '/school/teacher-dashboard': _schoolStaffRoles,
  '/school/marks-entry': _schoolStaffRoles,
  '/school/marks/csv': _schoolStaffRoles,
  '/school/attendance': _schoolStaffRoles,
  '/school/homework/add': _schoolStaffRoles,
  '/school/lesson-plans': _schoolStaffRoles,
  '/school/examination': _schoolStaffRoles,
  '/school/discipline': _schoolStaffRoles,
  '/school/inventory': _schoolStaffRoles,
  '/school/reports': _schoolStaffRoles,
  '/school/my-payslips': {..._schoolStaffRoles, 'staff', 'accountant'},

  // Student specific
  '/school/student-dashboard': {'student', 'sstudent', ..._schoolAdminRoles},

  // Parent specific
  '/school/parent-dashboard': {'parent', 'sparent', ..._schoolAdminRoles},

  // Shared / Multi-role (views adapt based on role)
  '/school/ai-tools': _allSchoolRoles,
  '/school/chatbot': _allSchoolRoles,
  '/school/homework': _allSchoolRoles,
  '/school/leave': _allSchoolRoles,
  '/school/report-card': _allSchoolRoles,
  '/school/timetable': _allSchoolRoles,
  '/school/circulars': _allSchoolRoles,
  '/school/transport': {..._allSchoolRoles, 'conductor'},
  '/school/fees': {'parent', 'sparent', 'student', 'sstudent', ..._schoolAccountantRoles},
  '/school/library': {..._allSchoolRoles, 'librarian'},
  '/school/library-deep': {..._allSchoolRoles, 'librarian'},
  '/school/certificates': _allSchoolRoles,
  '/school/living': {..._allSchoolRoles, 'warden', 'nurse'},
  '/school/alumni': {..._allSchoolRoles, 'alumni'},
  '/school/activities': _allSchoolRoles,
  '/school/calendar': _allSchoolRoles,
  '/school/academic-calendar': _allSchoolRoles,
};

final router = GoRouter(
  redirect: (context, state) async {
    final path = state.uri.path;

    if (path.startsWith('/school')) {
      final authService = AuthService();
      final isLoggedIn = await authService.isLoggedIn();
      if (!isLoggedIn) return '/login';

      final instType = (await authService.getCurrentInstituteType() ?? '').toLowerCase().trim();
      final rawRole = (await authService.getCurrentUserRole() ?? '').toLowerCase().trim();
      final normalizedRole = rawRole.startsWith('s') &&
              (rawRole == 'steacher' || rawRole == 'sstudent' || rawRole == 'sparent' || rawRole == 'sadmin')
          ? rawRole.substring(1)
          : rawRole;

      // College users attempting to access school routes are bounced to their portal
      if (instType != 'school') {
        if (normalizedRole == 'teacher') return '/teacher-dashboard';
        if (normalizedRole == 'student') return '/student-dashboard';
        if (normalizedRole == 'parent') return '/parent-dashboard';
        if (normalizedRole == 'admin' || normalizedRole == 'principal' || normalizedRole == 'superadmin') {
          return '/admin-dashboard';
        }
        return '/login';
      }

      String getHomeDashboard() {
        if (normalizedRole == 'admin' || normalizedRole == 'principal' || normalizedRole == 'superadmin') {
          return '/school/admin-dashboard';
        } else if (normalizedRole == 'teacher') {
          return '/school/teacher-dashboard';
        } else if (normalizedRole == 'student') {
          return '/school/student-dashboard';
        } else if (normalizedRole == 'parent') {
          return '/school/parent-dashboard';
        } else if (normalizedRole == 'warden') {
          return '/warden-dashboard';
        } else if (normalizedRole == 'conductor') {
          return '/conductor-dashboard';
        }
        return '/login';
      }

      // Root path /school redirect
      if (path == '/school' || path == '/school/') {
        return getHomeDashboard();
      }

      // Deny-by-default route check
      final allowedRoles = _schoolRoutePermissions[path];
      if (allowedRoles == null) {
        final home = getHomeDashboard();
        return (path == home) ? null : home;
      }

      final hasAccess = allowedRoles.contains(rawRole) || allowedRoles.contains(normalizedRole);
      if (!hasAccess) {
        final home = getHomeDashboard();
        return (path == home) ? null : home;
      }
    }
    return null;
  },
  routes: [
    // ===== COMMON =====
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),

    // ===== COLLEGE - STUDENT =====
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

    // ===== COLLEGE - TEACHER =====
    GoRoute(
      path: '/teacher-dashboard',
      builder: (context, state) => const TeacherDashboardScreen(),
    ),
    GoRoute(
      path: '/teacher-profile',
      builder: (context, state) => const TeacherProfileScreen(),
    ),

    // ===== COLLEGE - ADMIN / HR / HOD =====
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
      builder: (context, state) =>
          AddUserScreen(institution: state.uri.queryParameters['institution']),
    ),
    GoRoute(
      path: '/admin/add-teacher',
      builder: (context, state) => const AddTeacherScreen(),
    ),
    GoRoute(
      path: '/admin/add-student',
      builder: (context, state) => const AddStudentScreen(),
    ),

    // ===== SHARED =====
    GoRoute(
      path: '/timetable',
      builder: (context, state) => const TimetableScreen(),
    ),

    // ===== SCHOOL - STUDENT =====
    GoRoute(
      path: '/school/student-dashboard',
      builder: (context, state) => const SchoolStudentDashboard(),
    ),

    // ===== SCHOOL - TEACHER =====
    GoRoute(
      path: '/school/teacher-dashboard',
      builder: (context, state) => const SchoolTeacherDashboard(),
    ),
    GoRoute(
      path: '/school/homework',
      builder: (context, state) => const HomeworkListScreen(),
    ),
    GoRoute(
      path: '/school/homework/add',
      builder: (context, state) => const AddHomeworkScreen(),
    ),
    GoRoute(
      path: '/school/leave',
      builder: (context, state) => const StudentLeaveScreen(),
    ),
    GoRoute(
      path: '/school/attendance',
      builder: (context, state) => const SchoolAttendanceScreen(),
    ),
    GoRoute(
      path: '/school/marks-entry',
      builder: (context, state) => const MarksEntryScreen(),
    ),
    GoRoute(
      path: '/school/marks/csv',
      builder: (context, state) => const MarksCsvUploadScreen(),
    ),
    GoRoute(
      path: '/school/report-card',
      builder: (context, state) => const ReportCardScreen(),
    ),
    GoRoute(
      path: '/school/timetable',
      builder: (context, state) => const SchoolTimetableScreen(),
    ),

    // ===== SCHOOL - ADMIN =====
    GoRoute(
      path: '/school/admin-dashboard',
      builder: (context, state) => const SchoolAdminDashboard(),
    ),
    GoRoute(
      path: '/school/circulars',
      builder: (context, state) => const CircularsScreen(),
    ),
    GoRoute(
      path: '/school/transport',
      builder: (context, state) => const TransportScreen(),
    ),
    GoRoute(
      path: '/school/fees',
      builder: (context, state) {
        final studentId = state.uri.queryParameters['studentId'];
        return SchoolFeeScreen(studentId: studentId);
      },
    ),
    GoRoute(
      path: '/school/admissions',
      builder: (context, state) => const AdmissionsScreen(),
    ),
    GoRoute(
      path: '/school/reports',
      builder: (context, state) => const SchoolReportsScreen(),
    ),
    GoRoute(
      path: '/school/library',
      builder: (context, state) => const SchoolLibraryScreen(),
    ),
    GoRoute(
      path: '/school/certificates',
      builder: (context, state) => const SchoolCertificatesScreen(),
    ),
    GoRoute(
      path: '/school/promotion',
      builder: (context, state) => const SchoolPromotionScreen(),
    ),
    GoRoute(
      path: '/school/examination',
      builder: (context, state) => const SchoolExaminationScreen(),
    ),
    GoRoute(
      path: '/school/lesson-plans',
      builder: (context, state) {
        final classId = state.uri.queryParameters['classId'];
        final subject = state.uri.queryParameters['subject'];
        return SchoolLessonPlanScreen(
          initialClassId: classId,
          initialSubject: subject,
        );
      },
    ),
    GoRoute(
      path: '/school/payroll',
      builder: (context, state) => const SchoolPayrollScreen(),
    ),
    GoRoute(
      path: '/school/my-payslips',
      builder: (context, state) => const SchoolMyPayslipsScreen(),
    ),
    GoRoute(
      path: '/school/living',
      builder: (context, state) => const SchoolLivingScreen(),
    ),
    GoRoute(
      path: '/school/alumni',
      builder: (context, state) => const SchoolAlumniScreen(),
    ),
    GoRoute(
      path: '/school/inventory',
      builder: (context, state) => const SchoolInventoryScreen(),
    ),
    GoRoute(
      path: '/school/activities',
      builder: (context, state) => const SchoolActivitiesScreen(),
    ),
    GoRoute(
      path: '/school/discipline',
      builder: (context, state) => const SchoolDisciplineScreen(),
    ),
    GoRoute(
      path: '/school/multi-admin',
      builder: (context, state) => const SchoolMultiAdminScreen(),
    ),
    GoRoute(
      path: '/school/library-deep',
      builder: (context, state) => const SchoolLibraryDeepScreen(),
    ),
    GoRoute(
      path: '/school/permissions',
      builder: (context, state) => const SchoolPermissionMatrixScreen(),
    ),
    GoRoute(
      path: '/school/ai-tools',
      builder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        int initialTab = 0;
        if (tabParam == 'chatbot' || tabParam == '3') {
          initialTab = 3;
        } else if (tabParam == 'questions' || tabParam == '1') {
          initialTab = 1;
        } else if (tabParam == 'feedback' || tabParam == '2') {
          initialTab = 2;
        }
        return SchoolAiAssistantScreen(initialTab: initialTab);
      },
    ),
    GoRoute(
      path: '/school/chatbot',
      builder: (context, state) => const SchoolAiAssistantScreen(initialTab: 3),
    ),
    GoRoute(
      path: '/school/calendar',
      builder: (context, state) => const SchoolAcademicCalendarScreen(),
    ),
    GoRoute(
      path: '/school/academic-calendar',
      builder: (context, state) => const SchoolAcademicCalendarScreen(),
    ),
    GoRoute(
      path: '/school/masters',
      builder: (context, state) => const SchoolMastersScreen(),
    ),

    // ===== SCHOOL - PARENT =====
    GoRoute(
      path: '/school/parent-dashboard',
      builder: (context, state) => const SchoolParentDashboard(),
    ),

    // ===== DEBUG =====
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
    GoRoute(
      path: '/finance/fee-heads',
      builder: (context, state) => const FeeHeadManagementScreen(),
    ),
    GoRoute(
      path: '/finance/chart-of-accounts',
      builder: (context, state) => const ChartOfAccountsScreen(),
    ),
    GoRoute(
      path: '/finance/journal-entries',
      builder: (context, state) => const JournalEntryScreen(),
    ),
    GoRoute(
      path: '/finance/receipts',
      builder: (context, state) => const ReceiptManagementScreen(),
    ),
    GoRoute(
      path: '/finance/student-ledger',
      builder: (context, state) => const StudentLedgerScreen(),
    ),
    GoRoute(
      path: '/finance/scholarships',
      builder: (context, state) => const ScholarshipManagementScreen(),
    ),
    GoRoute(
      path: '/finance/reports',
      builder: (context, state) => const FinancialReportsScreen(),
    ),
    GoRoute(
      path: '/finance/audit-logs',
      builder: (context, state) => const AuditLogScreen(),
    ),
    GoRoute(
      path: '/finance/financial-year',
      builder: (context, state) => const FinancialYearScreen(),
    ),
    GoRoute(
      path: '/finance/budgets',
      builder: (context, state) => const BudgetManagementScreen(),
    ),
    GoRoute(
      path: '/finance/purchase',
      builder: (context, state) => const PurchaseManagementScreen(),
    ),
    GoRoute(
      path: '/finance/grants',
      builder: (context, state) => const GrantManagementScreen(),
    ),

    // ============================================================================
    // EXAMINATION (COE) MODULE ROUTES
    // ============================================================================
    GoRoute(
      path: '/examination',
      builder: (context, state) => const COEDashboard(),
    ),
    GoRoute(
      path: '/examination/sessions',
      builder: (context, state) => const ExamSessionsScreen(),
    ),
    GoRoute(
      path: '/examination/results',
      builder: (context, state) => const ResultManagementScreen(),
    ),
    GoRoute(
      path: '/examination/tabulation',
      builder: (context, state) => const TabulationScreen(),
    ),
    GoRoute(
      path: '/examination/revaluation',
      builder: (context, state) => const RevaluationScreen(),
    ),
    GoRoute(
      path: '/student/hall-ticket',
      builder: (context, state) {
        final studentId = state.uri.queryParameters['studentId'] ?? '';
        return StudentHallTicketScreen(studentId: studentId);
      },
    ),
    GoRoute(
      path: '/student/results',
      builder: (context, state) {
        final studentId = state.uri.queryParameters['studentId'] ?? '';
        return StudentResultScreen(studentId: studentId);
      },
    ),

    // ============================================================================
    // ADMIN WORKFLOW ROUTES
    // ============================================================================
    GoRoute(
      path: '/admin/nodues',
      builder: (context, state) => const NoDuesManagementScreen(),
    ),
    GoRoute(
      path: '/admin/certificates',
      builder: (context, state) => const CertificateManagementScreen(),
    ),
    GoRoute(
      path: '/admin/grievances',
      builder: (context, state) => const GrievanceManagementScreen(),
    ),

    // ============================================================================
    // HR WORKFLOW ROUTES
    // ============================================================================
    GoRoute(
      path: '/hr/recruitment',
      builder: (context, state) => const RecruitmentScreen(),
    ),
    GoRoute(
      path: '/hr/appraisal',
      builder: (context, state) => const AppraisalScreen(),
    ),
    GoRoute(
      path: '/hr/exit-management',
      builder: (context, state) => const ExitManagementScreen(),
    ),

    // ============================================================================
    // TEACHER LIFECYCLE + PAYROLL ROUTES
    // ============================================================================
    GoRoute(
      path: '/hr/hiring-pipeline',
      builder: (context, state) => const HiringPipelineScreen(),
    ),
    GoRoute(
      path: '/hr/onboarding',
      builder: (context, state) => const EmployeeOnboardingScreen(),
    ),
    GoRoute(
      path: '/hr/payroll-runs',
      builder: (context, state) => const PayrollRunsScreen(),
    ),
    GoRoute(
      path: '/hod/subject-allotment',
      builder: (context, state) => const SubjectAllotmentScreen(),
    ),
    GoRoute(
      path: '/teacher/my-payslips',
      builder: (context, state) {
        final username = state.uri.queryParameters['username'] ?? '';
        return MyPayslipsScreen(username: username);
      },
    ),

    // ============================================================================
    // SUPERADMIN + USER MANAGEMENT ROUTES
    // ============================================================================
    GoRoute(
      path: '/admin/institute-setup',
      builder: (context, state) => const InstituteSetupScreen(),
    ),
    GoRoute(
      path: '/admin/manage-users',
      builder: (context, state) => ManageUsersScreen(
        initialInstitution: state.uri.queryParameters['institution'] ??
            'school',
      ),
    ),
    GoRoute(
      path: '/admin/manage-users/:institution',
      builder: (context, state) => ManageUsersScreen(
        initialInstitution: state.pathParameters['institution'] ?? 'school',
      ),
    ),
    GoRoute(
      path: '/admin/timetable',
      builder: (context, state) => ManageTimetableScreen(
        initialClassId: state.uri.queryParameters['classId'],
        initialDay: state.uri.queryParameters['day'],
      ),
    ),
    GoRoute(
      path: '/finance/fee-insights',
      builder: (context, state) => const FeeInsightsScreen(),
    ),

    // ============================================================================
    // ADMISSION FLOW ROUTES
    // ============================================================================
    GoRoute(
      path: '/leads/capture-form',
      builder: (context, state) => const LeadCaptureFormScreen(),
    ),
    GoRoute(
      path: '/admissions/apply',
      builder: (context, state) {
        final leadId = state.uri.queryParameters['leadId'];
        final leadName = state.uri.queryParameters['leadName'];
        return AdmissionFormScreen(leadId: leadId, leadName: leadName);
      },
    ),
    GoRoute(
      path: '/admissions/review',
      builder: (context, state) => const AdmissionReviewScreen(),
    ),
  ],
);
