- **Current Step in Execution Plan:** `Step ADM4: Reports Second Half + Excel (Completed) -> Moving to Step ADM5 (New Features Suite: N3, N4, N5, N8, N9, N10, N11, N12, N13, N14)`
- **Status:** Step ADM4 (Reports Second Half + Excel: AD-R07 to AD-R14 + UDISE Excel) completed with 100% verification against live Supabase. Implemented all 14 multi-sheet Excel (.xlsx) workbooks adhering strictly to the dual-sheet standard (Summary + Data + Totals + Admin_<CODE>_<YYYYMMDD>.xlsx filename). Integrated Excel export action buttons across the dashboard analytics cards, Approvals Desk modal, and Reports Hub UDISE+ and Morning Briefing tabs. Verified live DB tables for all 14 reports (68 students, 152 fee records, 132 defaulters, 13 fee heads, 6 admissions, 28 teachers, 3 transport routes, 6 library books, 2 grievances, 38 circulars, 6 certificate requests, and audit activity). `dart analyze lib/services/ lib/features/school/` returned 0 issues. Moving to Step ADM5.

---

## Detailed Step & Line Progress Log

### [COMPLETED] Step 0: Sync, Baseline, and Audit (Lines 169-185)
- [x] **Line 172 (Action 1):** `git pull origin main` and record HEAD commit hash (`cece3600f9aa57b3a3e48bc6353df267f6011445`).
- [x] **Line 174 (Action 2):** Run `flutter analyze` and record baseline (888 issues, 0 errors).
- [x] **Line 176 (Action 3):** Create `SCHOOL_PROGRESS.md` at repo root with Steps 0-15 tracker.
- [x] **Line 178 (Action 4):** Audit every file under `lib/features/school/` and `lib/services/school_service.dart`.
- [x] **Line 181 (Action 5):** Compare school coverage against 14-module spec and record gap list.
- [x] **Line 183 (Action 6):** Record college regression baseline for Step 3.
- [x] **Line 184-185 (Verification):** Baseline documented; verified with 0 analyze errors.

---

### [COMPLETED] Step 1: Verify the Live Database and Client Facts (Lines 187-200)
- [x] **Line 190 (Action 1):** Checked all 17 tables via live REST API. All 17 tables exist in the database!
- [x] **Line 193 (Action 2):** Row counts recorded across all 17 tables.
- [x] **Line 195 (Action 3):** Verified all 4 roles exist in database (`sadmin1`, `steacher1`, `sstudent1`, `parent1`).
- [x] **Line 197 (Action 4):** Defaults established per spec: School Name: Shivalik International School (`SHIV-SCH`), Board: CBSE, Hostel/Infirmary: Defer, GPS: App-level live location, Payroll: Reuse college HR via role routing, UDISE+: Standard 38-field compliance.
- [x] **Line 199-200 (Verification):** Written live-DB report in `SCHOOL_PROGRESS.md`, row counts, and defaults documented.

---

### [COMPLETED] Step 2: Establish Module Infrastructure (Lines 202-212)
- [x] **Line 205 (Action 1):** Scaffolded `lib/features/school/` with all 14 module subfolders.
- [x] **Line 207 (Action 2):** Verified `SchoolService` has full CRUD & query methods.
- [x] **Line 209 (Action 3):** Verified clean role switching and routing.
- [x] **Line 211-212 (Verification):** Infrastructure verified, `SCHOOL_PROGRESS.md` updated.

---

### [COMPLETED] Step 3: Zero College Regressions Baseline (Lines 214-232)
- [x] **Line 217 (Action 1):** College ERP routes and files untouched.
- [x] **Line 219 (Action 2):** College core services untouched.
- [x] **Line 221 (Action 3):** Verification checklist passed.
- [x] **Line 223-232 (Verification):** Zero college files modified; 0 college regressions.

---

### [COMPLETED] Step T0: Teacher Dashboard Deep-Dive - Verify-First Baseline Audit
- [x] **Item (a) - Route & Role Guard:** UserRole.teacher exists in `lib/core/security/role_guard.dart` with dedicated permissions. `login_screen.dart` routes `teacher` to `/school/teacher-dashboard` when institution == 'school'. Demo credential: `steacher1` / `password`.
- [x] **Item (b) - Institute Name Source:** `institutes` table exists in Supabase schema (code = 'SHIV-SCH', name = 'Shivalik International School').
- [x] **Item (c) - Circulars Audience Model:** `school_circulars` table has `target_audience TEXT DEFAULT 'all'` ('all', 'parents', 'students', 'teachers') without a dedicated class_id column.
- [x] **Item (d) - Homework Grading Flow:** `school_homework_submissions` table has `teacher_feedback TEXT`, `status` ('submitted', 'returned', 'graded'), and `reviewed_at`.
- [x] **Item (e) - Teacher Leave Flow:** College HR uses `teacher_leaves` tied to `teacher_details`. School ERP has `school_student_leaves` for students; faculty leave uses teacher details flow or standard role-based leave tracking.
- [x] **Item (f) - PTM Booking Storage:** Stored in `school_circulars` with category: 'PTMSlot' and structured pipe-delimited payload (`PTM_SLOT_BOOKING | ...`).
- [x] **Item (g) - Attendance Period Column:** `school_attendance` is a daily date-level register with `UNIQUE(student_id, date)`.
- [x] **Item (h) - Notifications Central System:** Handled via circulars and status checks.

---

### [COMPLETED] Step T1: Real Data Purge (M1, M2, M3, M4)
- [x] **M1 (Attendance KPI Purge):** Eliminated hardcoded `_totalStudents = 42` and `_presentToday = 38`. Dynamic attendance query computes real enrolled count and today's present count from `school_attendance`. If attendance is unrecorded, card displays "Not Marked" with a "Mark Now" badge. On tap, an interactive drill-down modal displays today's absent students with a direct button to open the register.
- [x] **M2 (Schedule Purge):** Completely deleted hardcoded demo fallback timetable (`_todaySchedule = [{'subject': 'Mathematics', 'room': 'Room 201', ...}]`). Now defaults to empty state: "No lectures scheduled for today. Enjoy your preparation time!"
- [x] **M3 (Room 201 Purge):** Removed fake room strings; dynamic resolution from real `room` column or "Classroom / Lab".
- [x] **M4 (Institute Name Purge):** Eliminated hardcoded "Shivalik Public School"; queries `institutes` table by current user's institution code.
- [x] **4-State Lifecycle:** Loading skeleton shimmer, error state with Retry button, empty states, and loaded state.
- [x] **Automated Verification:** Static analysis passed with 0 errors; grep verification confirmed 0 occurrences of fake strings.

---

### [COMPLETED] Step T2: My Students + Search (N1 + M12)
- [x] **Backend Infrastructure (`lib/services/school_service.dart`):**
  - Added `getTeacherAllAssignedClasses(String teacherUsername)`: Consolidates classes where user is designated Class Teacher plus subject faculty classes derived from timetable periods.
  - Added `getStudentsForTeacher(String teacherUsername, {String? classId})`: Strict security filter preventing teachers from peeking at unassigned student records.
  - Added `getStudent360Profile(String studentId)`: Aggregates real attendance %, 15 recent daily scan logs, CBSE 9-point marks, homework submission counts, and leaves.
- [x] **Excel Export Integration (`lib/services/school_export_service.dart`):**
  - Added `exportClassRosterExcel`: Generates official `.xlsx` workbook (T-R02 format) with Summary sheet and Class Roster sheet with totals row.
  - Added `downloadExcel`: Native browser download trigger with MIME type and floating feedback.
- [x] **Teacher Dashboard UI (`lib/features/school/school_teacher_dashboard.dart`):**
  - **My Students Roster Section:** Added prominent section above Academics with real cohort count pill and instant "Excel Roster" export button.
  - **Live Search Bar (M12):** Interactive search by student name, roll number, or admission ID with instant clear button.
  - **Assigned Class Filter Strip:** Horizontal filter chips for "All Classes" and each assigned cohort.
  - **Student Cards Grid:** Modern responsive layout, initials avatar with risk highlighting, name, roll/admission info, class chip, live attendance pill (green >= 75%, red < 75%), and "360° View" action.
  - **Student 360° Profile Modal (N1):** Comprehensive modal dialog (desktop) / bottom sheet (mobile) with 5 tabs: Overview, Attendance Register (with 75% CBSE marker), Scholastic & Marks (CBSE 9-point), Homework Portfolio, Leaves.
- [x] **Parity & Navigation (M11):** Updated faculty navigation drawer with "My Students Roster".
- [x] **Automated Verification:** Ran live database test on Supabase — All tests passed! `dart analyze` returned 0 issues.

---

### [COMPLETED] Step T3: Analytics + My Reports (N2 + N3 + T-R01 to T-R06)
- [x] **Backend Analytics Methods (`lib/services/school_service.dart`):**
  - Added `getTeacherAttendanceTrend(String teacherUsername, {int days = 30})` (T-R01): Computes daily present, total, and percentage across teacher's assigned classes from `school_attendance`, filtering out Sundays.
  - Added `getTeacherClassGradeDistribution(String teacherUsername, {String? classId})` (T-R04): Aggregates marks across all 8 CBSE 9-point evaluation bands (`A1` to `E`), total evaluated, and class mean.
  - Added `getTeacherSubjectAverages(String teacherUsername)` (T-R05): Computes comparative subject performance benchmarks.
  - Added `getTeacherHomeworkCompletionStats(String teacherUsername)` (T-R07): Computes real submission velocity: submitted, late, missing, and completion rate.
- [x] **Multi-Tab Excel Export Integration (`lib/services/school_export_service.dart`):**
  - Added `exportAttendanceTrendExcel` (T-R01), `exportDefaultersExcel` (T-R03), `exportGradebookExcel` (T-R04), and `exportSubjectAveragesExcel` (T-R05).
- [x] **Teacher Dashboard Analytics UI (`lib/features/school/school_teacher_dashboard.dart`):**
  - Built **Class Analytics & Academic Velocity Section (N2)**:
    1. *30-Day Attendance Trajectory (T-R01):* `LineChart` (`fl_chart`) with smooth curve, teal gradient, and dashed red reference line at 75% CBSE Limit.
    2. *CBSE Grade Distribution (T-R04):* `BarChart` (`fl_chart`) displaying evaluated student counts across `A1` to `E`.
    3. *Subject Performance Benchmarks (T-R05):* `BarChart` (`fl_chart`) comparing average score percentages across subjects.
    4. *Homework Completion Velocity (T-R07):* `PieChart` (`fl_chart`) donut chart with center completion % and legend.
  - Header links directly to `/school/reports` with a "My Reports Hub" action button.
  - Added "My Reports & Analytics" to the faculty navigation drawer (M11 parity).
- [x] **Teacher-Scoped Reports Hub (`lib/features/school/reports/school_reports_screen.dart`):**
  - Teacher Role Gate: Hidden admin Fees tab and Principal Morning Briefing, replaced with dedicated **Teacher Attendance & Defaulters tab (T-R01, T-R02, T-R03)**.
  - Class selector strictly limited to teacher's assigned classes.
  - Purged mock data: eliminated `_generateFallbackMarks` and fallback attendance loops.
  - Added `fl_chart` Grade Distribution BarChart and `exportGradebookExcel` button to the Marks & Merit tab.
- [x] **Live Database Automated Verification:** Ran `test_t3.dart` on live Supabase — All tests passed! `dart analyze` returned 0 issues.

---

### [COMPLETED] Step T4: Reports Second Half + Excel (T-R07 to T-R14 + M6/M7/M8 Excel)
- [x] **Backend Methods (`lib/services/school_service.dart`):**
  - Added `gradeHomeworkSubmission({required submissionId, required status, String? feedback})` (M8/N12): Updates status and teacher feedback with reviewed timestamp in `school_homework_submissions`.
  - Added `getTeacherWeeklyWorkload(String teacherUsername)` (T-R12): Day-wise teaching lecture counts, free periods, capacity (48 periods/week), and utilization rate.
  - Added `getTeacherSyllabusVelocity(String teacherUsername)` (T-R09): Aggregates lesson plan coverage across assigned classes (total units, taught count, in-progress, lagging count, completion rate).
- [x] **Excel Export Suite (`lib/services/school_export_service.dart`):**
  - Added `exportHomeworkSubmissionsExcel` (T-R08): Generates workbook with summary metrics and per-student submission register (roll, name, status, submitted time, note, feedback, reviewed date).
  - Added `exportLessonPlanVelocityExcel` (T-R09): Generates curriculum pacing audit workbook (cohort, role, planned units, taught, in-progress, lagging, coverage %, pacing status).
  - Added `exportWeeklyWorkloadExcel` (T-R12): Generates day-wise teaching workload workbook with utilization analysis.
  - Updated `showExportOptionsModal`: Added optional `.xlsx` Excel workbook export tile alongside PDF and CSV.
- [x] **Marks Entry Screen Parity (M6) (`lib/features/school/marks/marks_entry_screen.dart`):**
  - Switched class loading to `getTeacherAllAssignedClasses(username)` to show all classes taught by teacher.
  - Added "Export Excel (T-R04)" action in the batch toolbar generating official CBSE Gradebook workbook.
- [x] **Attendance Screen Parity (M7) (`lib/features/school/attendance/school_attendance_screen.dart`):**
  - Switched class dropdown to `getTeacherAllAssignedClasses(username)` when user is teacher.
  - Added "Monthly Attendance Trajectory" card with `fl_chart` LineChart and 75% CBSE statutory threshold dashed line.
  - Added "Export Excel (T-R01)" button and wired Excel option in `_showExportModal`.
- [x] **Homework Screen Parity (M8) (`lib/features/school/homework/homework_list_screen.dart`):**
  - Updated class loading to prioritize teacher's assigned classes.
  - Redesigned `_showTeacherSubmissions`: Added "Export Excel (T-R08)" action, evaluation status badges (Graded, Needs Revision, Pending), student notes, teacher feedback, and interactive "Grade / Review" dialog with instant live updates.
- [x] **Live Database Automated Verification:** Ran `test_t4.dart` asserting live Supabase data — All tests passed! `dart analyze` returned 0 issues.

---

### [COMPLETED] Step T5: New Features Suite (N4 to N14)
- [x] **Period-Wise Attendance State (N13):**
  - In `Today's Teaching Schedule`: dynamically evaluates whether attendance has been recorded today for each period's class.
  - Renders live status chips: `✓ Marked` (green) or `Pending` (amber) with direct "Take Attendance" quick action.
- [x] **Substitution Desk (N5):**
  - Prominent alert card rendered above schedule when teacher is assigned to cover periods for absent faculty.
  - Displays period, class cohort, room, absent teacher name, and "Acknowledge" button with real status feedback.
- [x] **Upcoming Exam Countdown & Datesheet Banner (N9):**
  - Added exam countdown widget querying `school_exams` where `exam_date >= today`.
  - Shows exam title, date, countdown badge (`IN X DAYS` or `TODAY`), and direct link to examination datesheet.
- [x] **Attention Needed & Early Warning Signals (N8):**
  - Deterministic evaluation detecting: CBSE attendance < 75%, examination failure (< 35% passing mark), or overdue missing homeworks.
  - Interactive cards with risk badges and direct tap opening the Student 360° Profile sheet.
  - Added "Export Excel (T-R03)" button for instant defaulters workbook generation.
- [x] **Homework Grading Queue (N12):**
  - Real-time queue on dashboard listing assignments with unreviewed submissions.
  - Displays cohort name, due date, pending review count, overdue alert, and direct "Grade" button deep-linking to evaluation modal.
- [x] **Weekly Teaching Workload Analyzer (N11):**
  - Segmented toggle on schedule: "Today" vs "Week Load".
  - Renders 6-day load view (Mon–Sat) with lecture counts, free periods, overloaded alert (>= 7 periods), total periods, and utilization % against 48-period weekly capacity.
  - Added "Export Workload Excel (T-R12)" button.
- [x] **Scoped Class Announcements & Parent Messaging (N4):**
  - Dialog allowing teacher to broadcast official notices to parents of assigned classes with priority tag and real delivery logging in `school_circulars`.
- [x] **Faculty Leave Desk (N6):**
  - Modal bottom sheet displaying active and historical faculty leave applications with status pills (Pending, Approved, Rejected).
  - "Apply Leave" dialog with leave type (Casual, Medical, Duty, Earned), date range, and reason.
- [x] **PTM Meeting Slots Desk (N10):**
  - Schedule modal for teacher listing parent-teacher conference appointments (student, parent, date, time slot, agenda) with interactive "Mark Done" / "Confirmed" status toggle.
- [x] **Student Pastoral & Behaviour Notes (N7):**
  - Added 6th dedicated tab in Student 360° Profile sheet: "Behaviour (N7)".
  - Displays commendation, discipline, or academic observation logs.
  - "Log Note" dialog allowing faculty to record pastoral observations in real time.
- [x] **Faculty Inbox & Notifications Center (N14):**
  - Bell icon in dashboard AppBar with unread counter badge.
  - Sliding sheet aggregating substitution duties, grading reminders, and official notices with tap-to-navigate and "Mark all read" capability.
- [x] **Drawer Parity (M11):**
  - Added direct navigation for: Message Class Parents (N4), Faculty Leave Desk (N6), PTM Meeting Slots (N10), Faculty Notifications & Inbox (N14).
- [x] **Live Database Automated Verification:** Ran `test_t5.dart` on live Supabase — All 8 tests passed! `dart analyze` returned 0 issues.

---

### [COMPLETED] Step T6: Modifications Polish & Parity (M5, M9, M10, M11, M13, M14)
- [x] **Lesson Plan Velocity Card on Dashboard (M5):** Added compact Curriculum Pacing & Syllabus Velocity card under Academics section, displaying total planned units, taught units, in-progress units, lagging count, coverage % with progress bar, pacing badge, and direct "Export Velocity Excel (T-R09)" button.
- [x] **Pending Student Leave Approvals Queue (M9):** Added live queue card for class teachers displaying pending student leave requests with one-click "Approve" (green) and "Reject" (red) actions with reviewed feedback.
- [x] **Quick Action Tiles Review (M10):** Verified all action tiles in Daily Operations and Academics route cleanly to their corresponding screens.
- [x] **1:1 Dashboard to Drawer Parity (M11):** Verified all 18 dashboard sections and operations have corresponding entries in the faculty navigation drawer with exact matching nomenclature.
- [x] **4-State Lifecycle Review (M13):** Verified all cards display graceful loading shimmers, error states with retry actions, and informative empty states without fake numbers or hardcoded fallbacks.
- [x] **CBSE Compliance Terminology (M14):** Enforced statutory labels: CBSE Minimum 75.0% Attendance Requirement, CBSE 9-Point Grading Scale (A1 to E), and Term Assessment Cycles across all components.
- [x] **Static Analysis Verification:** `dart analyze lib/services/ lib/features/school/` returned 0 issues.

---

### [COMPLETED] Step T7: Final QA & Production Verification
- [x] **Full E2E Live Database Regression Suite:**
  - 1. Security Scoping: Verified `getTeacherAllAssignedClasses` & `getStudentsForTeacher` correctly bound to teacher credentials (2 classes, 68 students).
  - 2. Student 360° Profile: Verified holistic aggregation with CBSE 9-point scale, attendance %, scan logs, homework portfolio, and leaves.
  - 3. Analytics Engine: Verified 30-day attendance trajectory line and CBSE grade distribution (A1–E) calculation against real live data.
  - 4. Subject Benchmarks & Homework Velocity: Verified comparative subject averages and homework completion velocity stats.
  - 5. Weekly Workload & Syllabus Velocity: Verified 48-period weekly capacity utilization and curriculum pacing audits.
  - 6. Early Warning At-Risk Evaluation & Grading Queue: Verified deterministic CBSE < 75%, exam failure, overdue homework flagging, and pending grading queue.
  - 7. Pastoral Care & Leave Flow Round-Trip: Verified live database record creation and retrieval for pastoral notes (`school_circulars` / Pastoral) and faculty leaves.
  - 8. Actionable Alerts & Notification Center: Verified real-time aggregation of substitution alerts, grading reminders, and circular notices.
  - **Result: 8 of 8 tests passed with code 0 on live Supabase!**
- [x] **Static Analysis Verification:**
  - `dart analyze lib/services/ lib/features/school/` returned **0 errors and 0 issues**.
- [x] **Zero College ERP Regressions:**
  - Verified 0 lines modified in College ERP (`lib/features/college/`, college services, college routes).
- [x] **Production Web Compilation Verification:**
  - Executed `flutter build web --base-href /erp/` to confirm zero Web runtime / bundling errors.
- [x] **Signoff & Ready for Hand-off / Next Dashboard:**
  - Teacher Dashboard (#1) completely finished according to `School-ERP-Teacher-Dashboard-Deep-Dive.md`.

---

### [COMPLETED] Step ADM0: Admin Dashboard Deep-Dive - Verify-First & F1 Gate Audit
- [x] **Item (a) - Live DB `sadmin1` User:** Verified live via Supabase REST API: `username = 'sadmin1'`, `role = 'admin'`, `institute_type = 'school'`. F1 gate cleared.
- [x] **Item (b) - Login Switch & Route Guard:** `login_screen.dart` has `case 'admin':` routing to `/school/admin-dashboard` but lacks explicit `case 'sadmin':` (routed via default). `app_router.dart` lacks redirect guard on `/school/*` routes.
- [x] **Item (c) - `institutes` Schema:** Has basic profile (`id`, `code`, `name`, `type`, `address`, `contact_email`) but lacks statutory fields (`affiliation_no`, `udise_code`, `academic_session`, `fire_noc_no`, etc.), requiring settings store for N5.
- [x] **Item (d) - `school_students` Gender Column:** `gender` column does NOT exist in `school_students`. Strictly enforcing M2 rule: no invented 52%/48% ratios; report "Not recorded" / missing.
- [x] **Item (e) - Teacher Leave Flow:** Stored in `school_circulars` with `category: 'TeacherLeave'` (`applyTeacherLeave` / `getTeacherLeaves`). Admin queue can query pending across all faculty.
- [x] **Item (f) - Fee Refund / Concession Flow:** Recorded directly via `school_fee_payments`. No separate `school_fee_accounts` table.
- [x] **Item (g) - Month-Close Storage:** No month-close table exists. Dynamic evaluation per `school_fee_screen.dart`.
- [x] **Item (h) - Notifications Central System:** No separate `school_notifications` table in Supabase. Dynamic alerts aggregated from operations and circulars.

---

### [COMPLETED] Step ADM1: Real-Data Purge (M1, M2, M3, M12 + Library Fallback)
- [x] **M1 (Dashboard & Briefing KPI Purge):**
  - Purged hardcoded KPI constants (`450`, `68`, `24`, `94.8`, `₹45L`, `₹2.8L`, `3`) from `school_admin_dashboard.dart` and `getPrincipalMorningBriefing()`.
  - Zero mock fallback: when attendance has not been recorded, returns `0.0` with `attendance_marked: false` and renders "Attendance Not Marked Yet" rather than fake 94.8%.
  - When fees or routes are empty, accurately reports 0 rather than fake 45L or 3 buses.
- [x] **M2 (UDISE+ Statutory Data Purge):**
  - Completely purged invented 52%/48% gender split, hardcoded 450 enrolment, fake RTE 45/38 seats, and fake fire NOC (`UK-FS-2026/8911`) from `generateUdisePlusReport()`.
  - Accurately reports real `total_enrolment` from `school_students`, real calculated PTR from real teacher count, and honestly marks missing gender as `Not Recorded in Students Register` and missing fire NOC as `Pending Statutory Upload`. Status displays `INCOMPLETE STATUTORY RECORD`.
- [x] **M3 (Institute Identity):**
  - Shifted static constants to dynamic instance state in `school_admin_dashboard.dart`, pulling genuine school name via `getSchoolInstituteName()` from the `institutes` table (`SHIV-SCH`).
- [x] **M12 (Admissions RTE Metric):**
  - Purged hardcoded string `'38/45 RTE Seats Filled'` in `admissions_screen.dart`, now computing real enrolled count where `quota == 'RTE' || is_rte == true`.
- [x] **Library Screen Fallback Purge:**
  - Deleted `_defaultIssued` hardcoded book issues list with fake October 2026 dates from `school_library_screen.dart`. Empty library issues register now displays authentic 4-state empty view.
- [x] **4-State Lifecycle:**
  - Added full error view in `school_admin_dashboard.dart` with dedicated icon, descriptive error message, and `Retry Connection` action button.
- [x] **Verification:**
  - Grep audit confirmed 0 occurrences of fake fallback constants across all touched files.
  - `dart analyze lib/services/ lib/features/school/` returned **0 issues**.

---

### [COMPLETED] Step ADM2: Approvals Centre + Attention Strip (N2 + M5)
- [x] **Unified Executive Approvals Backend (`lib/services/school_service.dart`):**
  - Built `getUnifiedExecutiveApprovals()` aggregating pending items across admissions under review, certificate requests, faculty leaves, student leaves, and parent grievances.
  - Implemented accurate age computation: calculating exact days pending per request with overdue flagging (> 3 days).
  - Added `updateTeacherLeaveStatus({required circularId, required status, required reviewedBy, remarks})` updating leave status in `school_circulars` and logging audit events.
  - Added `getPendingCertificateRequests()` and `rejectCertificateRequest()` with mandatory remarks.
  - Added `logAuditEvent()` foundation for executive audit trail.
- [x] **Executive Approvals Desk UI (`lib/features/school/school_admin_dashboard.dart`):**
  - Completely overhauled Attention Required strip into the **Executive Approvals Desk & Action Queue**.
  - True mathematical count: sum of all actual pending approvals across all categories plus fee defaulters (no fake counts; 40 defaulters = 40 items).
  - Nominal banner renders only when strictly 0 actions remain.
  - Category pill chips with live counters for Admissions, Certificates, Faculty Leaves, Student Leaves, Fee Overdue, and Grievances.
  - Top Priority items list directly previewing pending requests with age tags (`X d pending`, red highlight if overdue) and quick "Review" triggers.
  - Built interactive review dialogs:
    - `_showReviewTeacherLeaveDialog`: displays full leave details and provides one-click Approve / Reject with mandatory rejection remarks.
    - `_showReviewCertificateDialog`: displays student request and allows immediate authorization/issuance with QR seal or rejection.
    - `_showResolveGrievanceDialog`: replaces hardcoded resolution notes with mandatory administrative resolution remarks input field.
    - `_showUnifiedApprovalsModal`: comprehensive bottom sheet queue with category filter chips, search/status tags, and direct action triggers.
- [x] **Drawer Parity (M11):**
  - Added "Executive Approvals Desk" item in admin drawer with dynamic live badge counter.
- [x] **Automated Live DB Verification:**
  - Ran `test/adm2_test.dart` asserting live Supabase data: verified approvals aggregation, faculty leave approval round-trip, and grievance resolution with audit log. All 3 tests passed!
  - `dart analyze lib/services/ lib/features/school/` returned **0 issues**.

---

### [COMPLETED] Step ADM3: Analytics + Reports First Half (N1 + N6 + N7 + AD-R01 to AD-R06)
- [x] **Institutional Analytics Engines (`lib/services/school_service.dart`):**
  - Built `getAdminEnrolmentTrend()` (AD-R01): computes monthly new student intake and cumulative session progression across April-March academic calendar.
  - Built `getAdminFeeCollectionTrend()` (AD-R02 / N6): computes monthly grouped financial receivables and collections from `school_fee_payments`.
  - Built `getAdminSchoolAttendanceTrend({int days = 30})` (AD-R03): aggregates real campus-wide attendance roll call percentages across the past 30 days (filtering Sundays).
  - Built `getAdminAdmissionFunnel()` (AD-R05 / N7): calculates stage conversion across Inquiries -> Applied -> Scrutiny -> Interaction -> Offers -> Enrolled with conversion rates.
  - Built `getAdminFeeHeadDistribution()` (AD-R04): aggregates collection totals and percentage share across all fee heads.
  - Built `getAdminExamClassPassRates()` (AD-R06): calculates section-wise exam pass rates (>= 33%) and average percentage scores from `school_marks`.
- [x] **Dashboard Institutional Analytics Section UI (`lib/features/school/school_admin_dashboard.dart`):**
  - Integrated `package:fl_chart/fl_chart.dart` (v0.65.0 standard with `tooltipBgColor: const Color(0xFF0F172A)`).
  - Added `_buildInstitutionalAnalyticsHeader`: executive title, live subtitle, and direct navigation link to Reports Hub.
  - Added telemetry summary bar showcasing Class Pass Rates (AD-R06) and Top Fee Head collection share (AD-R04).
  - Built responsive analytics grid (2x2 layout on wide screens, single column on mobile) containing 4 interactive cards:
    1. **30-Day Attendance Trajectory Card**: LineChart with real daily points, 75% CBSE statutory benchmark red dashed line, touch tooltips, compliance summary, and link to Reports Hub.
    2. **Fee Collection vs Pending Dues Card**: Grouped BarChart with green collected rods and amber pending rods across 12 financial months, currency tooltips, and link to Fee Command.
    3. **Session Enrolment Trajectory Card**: LineChart showing cumulative student enrolment intake curve with soft gradient fill, total active badge, and link to Student Directory.
    4. **Admission Intake Funnel Card**: Visual stage conversion progress bars with candidate counts, stage conversion percentages, and RTE quota compliance tag.
  - Wired into `CustomScrollView` between Executive Metrics Grid and Management Domains Matrix.
- [x] **Reports Hub Integration (`lib/features/school/reports/school_reports_screen.dart`):**
  - Replaced hardcoded attendance radar numbers with dynamic class cards from `_allClasses`.
  - Integrated `_buildAdminInstitutionalAnalyticsSection` into Morning Briefing tab:
    - 30-Day Attendance Trajectory LineChart with 75% CBSE compliance line.
    - Class-Wise Examination Pass Rates data table (AD-R06) with evaluated count, passed count, pass % badge, and average score.
    - Fee Head Collections breakdown chips (AD-R04) and Monthly Collections summary (AD-R02).
    - Admission Conversion Progression stage badges (AD-R05).
- [x] **Automated Live DB Verification:**
  - Ran `test_adm3_verification.py` asserting live Supabase data: verified 68 students, 152 fee records (Rs. 303,900 collected, Rs. 1,574,085 pending), 1,000 attendance records, 6 admissions applications, 13 fee heads, and 1,000 exam marks.
  - `dart analyze lib/services/ lib/features/school/` returned **0 issues**.

---

### [COMPLETED] Step ADM4: Reports Second Half + Excel (AD-R07 to AD-R14 + UDISE Excel)
- [x] **14 Multi-Sheet Excel Workbooks in `SchoolExportService` (`lib/services/school_export_service.dart`):**
  - Built strict two-sheet architecture: Sheet 1 `Summary` (Title, metadata filters, audit date, rules, totals) and Sheet 2 `Data` (Full records, data cells, bottom totals row).
  - Standardized filename pattern: `Admin_<CODE>_<YYYYMMDD>.xlsx`.
  - Implemented all 14 official workbooks:
    1. **AD-R01 (`exportAdminEnrolmentExcel`)**: Monthly student intake and cumulative session progression with totals.
    2. **AD-R02 (`exportAdminFeeCollectionsExcel`)**: Monthly collections, pending dues, demand, and collection efficiency percentage with session totals.
    3. **AD-R03 (`exportAdminDefaultersAgeingExcel`)**: Ageing brackets (0-30, 31-60, 61-90, 90+ days), days overdue, student/parent details, and total overdue sums.
    4. **AD-R04 (`exportAdminFeeHeadWiseExcel`)**: Head-wise collection totals, percentage share of revenue, and audited totals.
    5. **AD-R05 (`exportAdminAdmissionFunnelExcel`)**: Pipeline conversion stages (Inquiries -> Applied -> Scrutiny -> Interaction -> Offers -> Enrolled) with RTE counts and conversion rates.
    6. **AD-R06 (`exportAdminExamResultsExcel`)**: Class-wise pass %, students needing support, average scores, and CBSE benchmark verdicts.
    7. **AD-R07 (`exportAdminStaffLoadExcel`)**: Staff directory, assigned subjects, assigned cohorts, weekly instructional periods, and workload balance indicators.
    8. **AD-R08 (`exportAdminTransportExcel`)**: Route-wise boarding count, absent students, telematics GPS status, and safety mismatch alerts.
    9. **AD-R09 (`exportAdminLibraryExcel`)**: Book circulation, borrower roles, issue/due dates, and accrued fine amounts.
    10. **AD-R10 (`exportAdminUdise38FieldExcel`)**: Statutory 38-field national MoE compliance export with origin table mapping and completeness verification verdict.
    11. **AD-R11 (`exportAdminGrievancesExcel`)**: Ticket ID, parent/student names, category, age in days, status, and Principal resolution notes.
    12. **AD-R12 (`exportAdminBroadcastsExcel`)**: Published circulars, audience distribution, categories, urgency level, and delivery channels.
    13. **AD-R13 (`exportAdminApprovalsAgeingExcel`)**: Approvals queue items, categories, pending age in days, and SLA escalation status.
    14. **AD-R14 (`exportAdminAuditTrailExcel`)**: Immutable audit log entries, actors, actions, entity types, IDs, and contextual details.
- [x] **UI Action Button Wiring:**
  - Added Excel export triggers on `school_admin_dashboard.dart` analytics cards: Attendance (AD-R03), Fee Collections (AD-R02), Enrolment (AD-R01), and Admission Funnel (AD-R05).
  - Added Excel export trigger on `school_admin_dashboard.dart` Executive Approvals Desk modal (AD-R13).
  - Added Excel export triggers on `school_reports_screen.dart` Morning Briefing tab for AD-R03, AD-R06, AD-R04, AD-R05, and on the UDISE+ tab for the statutory 38-field export (AD-R10).
- [x] **Automated Live DB Verification:**
  - Ran `test_adm4_verification.py` validating data sources across all 14 reports: 68 students, 152 fee payments, 132 defaulters, 13 fee heads, 6 admissions, 28 teachers in users (10 detailed profiles), 3 bus routes, 6 library books, 2 grievances, 38 circulars, 6 certificate requests, and audit trail logger.
  - `dart analyze lib/services/ lib/features/school/` returned **0 issues**.

