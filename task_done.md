- **Current Step in Execution Plan:** `Step PAR7: Final E2E QA, Live DB Regression, & Production Verification`
- **Status:** Step PAR6 is 100% complete and verified. Per-Child Reports Hub & Excel (PN5, PAR-R01 to PAR-R14) built with all 14 official dual-sheet Excel exports, interactive graph inspection, multi-child dynamic scoping, and drawer/overview wiring. Zero analyze issues. Commencing Step PAR7. Dual-ERP isolation fully intact.

---

## Detailed Step & Line Progress Log

### [COMPLETED] Step PAR6: Per-Child Reports Hub & Excel (PN5, PAR-R01 to PAR-R14)
- [x] **Excel Export Engine (`lib/services/school_export_service.dart`):**
  - Built all 14 official per-child Excel workbooks conforming to dual-sheet standard (`Summary` + `Data` with reconciliation totals row) and strict naming format `Parent_<parentUsername>_<CODE>_<YYYYMMDD>.xlsx`:
    1. `PAR-R01`: Attendance Trend (30-day daily points + monthly summary).
    2. `PAR-R02`: Attendance Register (Date-wise P/A/L/Excused records + summary).
    3. `PAR-R03`: CBSE Statutory 75% Attendance Warning Audit (Rule 13.2 examination compliance & shortage days).
    4. `PAR-R04`: Marks Trend (Exam-to-exam progression across Half Yearly & Final).
    5. `PAR-R05`: Subject-Wise Performance & Focus Breakdown (Subject averages, marks obtained, percentage, and faculty remarks).
    6. `PAR-R06`: CBSE Holistic Progress Card (HPC) Summary (Domain scores, rank, and Principal validation).
    7. `PAR-R07`: Homework Completion & Diary Audit (Submission ledger, due dates, statuses, feedback).
    8. `PAR-R08`: Statutory Fee Statement & Ledger Breakdown (12-Month April-March schedule, fee heads, late fees).
    9. `PAR-R09`: Fee Receipts & Reconciled Payments History (Receipt numbers, payment modes, bank transaction IDs).
    10. `PAR-R10`: Student Leave Applications Log (Category, dates, days count, decision status).
    11. `PAR-R11`: Parent-Teacher Meeting (PTM) Appointment Register (Faculty member, dates, slots, agendas, status).
    12. `PAR-R12`: Parent Grievance Dossier & Resolution Audit (Ticket IDs, categories, descriptions, leadership replies).
    13. `PAR-R13`: Transport Attendance & Commute Safety Telematics (RFID stop verification, morning pickup, campus gate scan, afternoon drop).
    14. `PAR-R14`: Monthly Progress Pack (Master 5-sheet comprehensive pack: Executive Summary, Attendance Velocity, Academics & HPC, Homework Diary, Fee Ledger).
- [x] **Parent Reports Hub UI (`school_parent_dashboard.dart`):**
  - Implemented `_showParentReportsHubModal()` bottom sheet with sibling switcher (PM14: switches child and updates report numbers synchronously).
  - 14 categorized report cards with code pills, descriptive summaries, "Chart View" action buttons (`fl_chart` modal view), and "Download Excel (.xlsx)" triggers.
  - Overview Tab surfaces dedicated "My Reports Hub (14 Official Excel Packs)" card with direct trigger.
  - Drawer entry "My Reports & Analytics" opens `_showParentReportsHubModal()`.
- [x] **Automated Verification:**
  - `dart analyze lib/services/school_export_service.dart lib/features/school/parent/` returned 0 issues (0 errors, 0 warnings, 0 deprecations).
  - Zero College ERP lines touched.

---

### [COMPLETED] Step PAR5: Financial & Administrative Lifecycle (PN6, PM6, PN7, PN8, PM4, PM7)
- [x] **Database Schema & RLS (`database/school_parent_admin_lifecycle.sql`):**
  - Created DDL with RLS policies for:
    1. `school_ptm_bookings` (PN7 & PM4: PTM Appointments, teacher slots, date, status lifecycle).
    2. `school_parent_grievances` (PN8: ticket tracking, status timeline, administration reply).
- [x] **PM6 (Fee Screen Scoping & Multi-Child Switcher):**
  - Updated `SchoolFeeScreen` (`school_fee_screen.dart`) to accept `studentId` route parameter.
  - Updated `app_router.dart` `/school/fees` route to extract `studentId` query parameter.
  - When accessed by parent role, dynamically resolves linked children from `parent_student_links` (verified 13 children for `parent1`).
  - Added Sibling Switcher Bar at the top of the Fee Screen schedule tab allowing seamless per-child ledger inspection.
  - Updated parent dashboard fee triggers to pass active child ID (`/school/fees?studentId=<id>`).
- [x] **PN7 & PM4 (PTM Manager & Authentic Availability):**
  - Added DatePicker to `_showBookPtmModal` allowing parents to select authentic meeting dates.
  - Populates teachers from live subject teacher directory.
  - Added Cancel Appointment action on confirmed PTM appointments in Tab 6.
  - Updated `bookPtmSlot`, `cancelPtmBooking`, and `getPtmBookings` in `school_service.dart` to dual-write and union with legacy rows for 100% data preservation.
- [x] **PN8 (Grievance Tracker with Lifecycle & Reopen):**
  - Built `_showGrievancesDeskModal()` displaying filed tickets with status badges (`SUBMITTED`, `IN REVIEW`, `RESOLVED`).
  - Displays leadership resolution notes and "Reopen Ticket" button on resolved tickets.
  - Added "+ File New Grievance" action button opening complaint composer dialog.
  - Wired Tab 6 "Principal Grievance" and Drawer "Parent Grievance Desk" to the tracker modal.
  - Updated `fileParentComplaint`, `getParentComplaints`, and `reopenParentComplaint` in `school_service.dart`.
- [x] **PM7 (Leave Form Hardening):**
  - Eradicated hardcoded fallback student and class IDs.
  - Added guard check requiring an active linked child.
  - Added doctor certificate notes handling for medical leaves.
- [x] **Automated Verification:**
  - Live Supabase verified 2 parent complaints (including `TKT-892104`), 1 PTM booking, and 13 linked students for `parent1`.
  - `dart analyze lib/services/school_service.dart lib/features/school/parent/ lib/features/school/fee/ lib/routes/` returned 0 issues.
  - Zero College ERP lines touched.

---

### [COMPLETED] Step PAR4: Communication Hub (PN1, PN2, PN9, PM3, PM11)
- [x] **Database Schema & RLS (`database/school_parent_comms_setup.sql`):**
  - Created DDL with RLS policies for:
    1. `school_teacher_messages` (PN1: class announcements and broadcasts).
    2. `school_notifications` (PN2: live event feed and real alerts).
    3. `school_parent_teacher_messages` (PN9: 1:1 direct messaging threads).
    4. `school_parent_preferences` (PM12: notification toggles).
- [x] **PN1 (Messages & Announcements Inbox):**
  - Added `getParentMessagesInbox({required parentUsername, childId, classId})` in `school_service.dart`.
  - Integrates both direct teacher messages, class notices published from teacher dashboard (`CLASS_ANNOUNCEMENT` format in `school_circulars`), and administrative school circulars.
  - Implemented `_showMessagesInboxModal()` with two clean tabs: "Broadcasts & Notices" and "1:1 Teacher Threads".
  - Overview Tab displays dynamic "Messages & Teacher Broadcasts" section with top 3 unread items and deep-link triggers.
- [x] **PN2 & PM3 (Real Dynamic Live Alerts):**
  - Added `getParentLiveAlerts({required parentUsername, required studentId, classId, className})` synthesizing real events from live DB records:
    - Real Attendance status (Absence alert or Approved Excused Leave notice).
    - Real Fee Dues (Outstanding balance alert with due date).
    - Real Homework (Latest assignment alert with subject and due date).
    - Real Circulars & Safety Notices.
  - Eradicated all hardcoded alert copy (PM3). If all checks pass, displays serene emerald all-clear confirmation.
  - Built `_buildLiveAlertsCard()` on Overview Tab and `_showLiveAlertsModal()` bottom sheet with direct module navigation buttons.
- [x] **PN9 (1:1 Direct Teacher Messaging Thread):**
  - Added `sendMessageToTeacher(...)` and `getParentTeacherThread(...)` in `school_service.dart`.
  - Built direct message composer dialog `_showComposeTeacherMessageModal()`.
  - Added prominent "Message Class Teacher" button in Tab 6 (Teachers & PTM) and in the Messages Inbox modal Tab 2.
- [x] **PM11 (Circulars Dashboard Integration):**
  - Circulars unified into the parent communication feed and filterable inside the inbox.
  - AppBar mail icon dynamically displays badge count of unread items and opens the messages modal.
  - Drawer entries for "Messages & Teacher Inbox" and "Live Safety Alerts" display live badges and trigger modals.
- [x] **Automated Verification:**
  - Live Supabase verified real Class Notices from `steacher1` for Class 10-A, real Principal notices, real PTM booking notices.
  - `dart analyze lib/services/school_service.dart lib/features/school/parent/` returned 0 issues (0 errors, 0 warnings, 0 deprecations).
  - Zero College ERP lines touched.

---

### [COMPLETED] Step PAR3: Daily Student Operations (PN3, PN4, PN12, PM9, PM14)
- [x] **PN3 (Daily Homework Diary):**
  - Integrated `getChildHomeworkDiary({required className, section, required studentId, classId})` querying real `school_homework` and `school_homework_submissions`.
  - Added "Today's Homework Diary" section to Overview Tab with dynamic subject badges, due dates, submission statuses (SUBMITTED / PENDING / OVERDUE), and teacher feedback.
  - Implemented `_showHomeworkDiaryModal` full bottom sheet with empty states, feedback banners, and deep-link button to `/school/homework`.
- [x] **PN4 (Attendance Detail, 30-Day Trajectory & CBSE Statutory Warning):**
  - Integrated `getChildAttendanceTrajectory(studentId, {days = 30})` evaluating live `school_attendance` records.
  - Built CBSE Statutory <75% Attendance Warning Banner on Overview Tab with dynamic alert card, shortage days count, and direct drill-down tap.
  - Implemented `_showAttendanceDrillDownModal` featuring 30-Day Trajectory `fl_chart: LineChart` with 75.0% red dashed statutory threshold line (`FlLine`), interactive tooltips (`LineTouchTooltipData`), and mini statistics grid (working days, present, absent, late/excused).
- [x] **PN12 (Upcoming Exam Countdown Widget):**
  - Integrated `getChildUpcomingExamCountdown({required className})` querying published assessment cycles from `school_exam_sessions`.
  - Overview Tab surfaces real upcoming exam badge with dynamic cycle title and term assessment status.
- [x] **PM9 (KPI Cards Drill-Down Modals):**
  - Card 1 (Attendance) -> `_showAttendanceDrillDownModal()` with interactive trajectory graph.
  - Card 2 (Fees Due) -> `_showFeeDrillDownModal()` itemizing annual dues, reconciled payments, pending amount, and statutory fee heads breakdown with online pay CTA.
  - Card 3 (Homework Due) -> `_showHomeworkDiaryModal()`.
  - Card 4 (Summative Grade) -> `_showOfficialHpcModal()`.
- [x] **PM14 (Robust Multi-Child Dynamic Switching):**
  - Switching children updates all child data synchronously: `_metrics`, `_attendanceData`, `_scholasticData`, `_transportData`, `_feeLedger`, `_timetableData`, `_leaves`, `_homeworkDiary`, `_attendanceTrajectory`, and `_examCountdown`.
  - Child switcher strip displays child initials, class name, and section with smooth animation.
- [x] **Automated Verification:**
  - Live Supabase query confirmed 11 real homework records in Class 10 and 2 attendance records for `sstudent1`.
  - `dart analyze lib/services/school_service.dart lib/features/school/parent/` returned 0 issues (0 errors, 0 warnings, 0 deprecations).
  - Zero College ERP lines touched.

---

### [COMPLETED] Step PAR2: Design Parity & Drawer/Profile (PM8, PM12, PM13)
- [x] **PM8 (Design Parity & Light Theme Overhaul):**
  - Eliminated blur orbs and heavy glass panels.
  - Implemented Slate-50 canvas (`#F8FAFC`), pure white cards, hairline borders (`#E2E8F0`), deep ink `#0F172A` typography, and refined `#DB2777` pink accents.
  - Updated AppBar with notifications badge and profile trigger.
- [x] **PM12 (18-Entry Navigation Drawer & Profile Settings):**
  - Overhauled navigation drawer to 18 structured entries matching PM12: Core & Comms, Daily Operations & Academics, Account & Settings.
  - Implemented `_showProfileAndSettingsModal`: parent profile header, linked children counter, notification preference switches (absence alerts, homework alerts, fee dues, PTM reminders, emergency circulars), and "Report Incorrect Child Link" flow.
  - Implemented `_showMyChildrenModal`: per-child cards with relation tag, admission number, roll number, and instant switching.
  - Implemented `_showMaterialsSheet`: LMS study materials modal with authentic download actions and empty state.
- [x] **PM13 (4-State Standard & Touch Targets):**
  - Built comprehensive shimmer skeleton screen in `_buildLoadingState` (skeleton switcher, hero card, 4 KPI cards, and schedule).
  - Ensured 48dp minimum touch targets across all interactive buttons and tiles.
- [x] **Automated Verification:**
  - `dart analyze lib/services/school_service.dart lib/features/school/parent/` returned 0 issues (0 errors, 0 warnings, 0 deprecations).
  - Zero College ERP lines touched.

---

### [COMPLETED] Step PAR1: Real-Data Purge & Privacy Fix (PM1, PM2, PM10, PM5, PM7)
- [x] **PM2 (Privacy Fix in `getParentChildren`):** Eradicated `.limit(2)` leak when `parent_student_links` has no rows for a parent. Unlinked parents receive strictly an empty list `[]` — zero exposure of stranger students.
- [x] **PM1 & PM10 (Metrics & Child Hero Identity Purge):**
  - Purged hardcoded constants (`Praveen Sharma`, `Aarav Sharma`, `SCH2026-10A`, `92.5`, `94.2`, `A1 (94%)`, `A2 (86%)`, `cls-9a/cls-10a` guess, `sstudent1`) from `school_parent_dashboard.dart`.
  - Empty state `_buildNoChildrenLinkedState` implemented with "+ Request Child Link" dialog when no child is linked.
- [x] **PM5 (LMS-Lite URL Fallback Purge):** Purged `notes.pdf` URL fallback and fake study materials in `getStudyMaterials()`. When no materials are uploaded, returns authentic empty list `[]`.
- [x] **PM7 (Leave Form Fallback Purge):** Purged `'sstudent1'`, `'cls-10a'`, and fake 'Self-Certified' document string from leave form dialog.
- [x] **Transport & Timetable Fallbacks Purged:** Purged fake `UK-07-PA-1024`, `Mohan Singh`, `Anita Verma`, and `Rajpur Road` fallbacks across safety pulse card and Tab 4. Bus card hides or displays clean unassigned state when student has no bus route.
- [x] **Automated Verification:**
  - Live Supabase test confirmed `parent1` gets 13 authentic linked children, unlinked parent gets 0 children.
  - Grep audit confirmed ZERO occurrences of all 15 forbidden constants in `school_parent_dashboard.dart`.
  - `dart analyze lib/services/school_service.dart lib/features/school/parent/` returned 0 issues.
  - Zero College ERP lines touched.

---

### [COMPLETED] Step PAR0: Parent Dashboard Deep-Dive - Verify-First Baseline Audit
- [x] **Item (a) - `getParentChildren` No-Link & Privacy Audit:** Live DB verified: `parent_student_links` has 14 links. Code audit revealed that when `links.isEmpty`, `school_service.dart` ran `_supabase.from('school_students').select().limit(2)`, leaking 2 stranger student records. Massive privacy hole confirmed for eradication in PAR1.
- [x] **Item (b) - Fee Screen Scoping:** `school_fee_screen.dart` loads by `targetUser = username` without child context, defaulting to `sstudent1`. Confirmed need for child route parameter and child switcher in parent fee flow (PM6).
- [x] **Item (c) - Circulars Audience & Category Storage:** Confirmed audience is `All/Students/Parents/Teachers` (no class targeting). Confirmed `school_circulars` used for PTM bookings (`PTMSlot`), complaints (`ParentComplaint`), and legacy student leaves (`StudentLeave`).
- [x] **Item (d) - Proposed Tables Audit:** Tested `school_teacher_messages`, `school_notifications`, `school_ptm_bookings`, `school_parent_grievances`, `school_parent_teacher_messages`, `school_link_requests`, `school_parent_preferences` — all returned 404 (do not exist yet). Dedicated SQL schema with RLS needed.
- [x] **Item (e) - Live Transport Availability:** `school_transport` verified with 3 active Dehradun routes (Route 1 UK-07-PA-1024, Route 2 UK-07-PA-2048, Route 3 UK-07-PA-3096).
- [x] **Item (f) - Step 10 Records Live Verification:** Verified PTM booking `e6d6759b`, grievance ticket `TKT-892104` (`3d9dff76`), and 7 student leaves in `school_circulars`.
- [x] **Item (g) - PN10 Behaviour Notes Decision:** Default set to OFF (visible only to teacher + admin) per policy. No parent view created unless explicitly requested.
- [x] **Static Analysis & College ERP:** 0 code modified in PAR0. Clean baseline.

---

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

---

### [COMPLETED] Step ADM5: New Features Suite (N3, N4, N5, N8, N9, N10, N11, N12, N13, N14)
- [x] **DDL & RLS Setup (`database/school_admin_suite_setup.sql`):**
  - Table `school_settings`: statutory profiles, CBSE affiliation, RTE quota seats, Fire NOC & Sanitation validity dates with authenticated SELECT and admin write policies.
  - Table `school_audit_log`: immutable audit log (actor_username, action, entity_type, entity_id, old_value, new_value, details) with authenticated insert and admin-only read RLS policies.
- [x] **Backend Services in `lib/services/school_service.dart`:**
  - `getSchoolSettings()`: retrieves active institutional settings with fallback to defaults.
  - `saveSchoolSettings(settings, {required actorUsername})`: saves statutory configuration and automatically generates an immutable audit log entry.
  - `getAuditLog({limit = 50})`: parses recent administrative actions and changes.
  - `getStaffDirectory()`: joins `users` (role=teacher, institute_type=school) and `teacher_details` with workload indicators.
  - `searchInstitutionalEntities(query)`: concurrent search across students, faculty, circulars, and admissions.
- [x] **UI Modals and Widgets in `lib/features/school/school_admin_dashboard.dart`:**
  - **N5 (Institute Statutory Settings):** Form dialog for school profile, CBSE affiliation, RTE quota, Fire NOC & Sanitation validity dates; updates state & logs audit event on submit.
  - **N4 (Institutional Audit Trail):** Modal with AD-R14 Excel export, actor badges, action tags, and timestamped activity list.
  - **N3 (Staff Oversight):** Directory modal with real faculty list, search filter, AD-R07 Excel export, and link to `/admin/manage-users`.
  - **N8 & N9 (Operational Command Strip):** Responsive layout with Examination Oversight Card (active cycles & pass rate telemetry) and Transport Fleet Safety Command (active bus fleet & safety mismatches count).
  - **N10 (Parent Grievance Centre):** Modal with 48h SLA indicators, resolution dialog with mandatory notes requirement, and AD-R11 Excel export.
  - **N12 (Universal Institutional Search):** Real-time search across students, staff, circulars, and admissions with direct navigation on selection.
  - **N13 (Broadcast & Circulars Hub):** Circulars modal with class targeting and AD-R12 Excel export.
  - **N14 (Executive Notifications Inbox):** Dynamic alerts gathered from admissions, certificates, teacher leaves, grievances, and fee defaulters with one-tap action routing.
  - Drawer and Quick Actions 1:1 parity with direct triggers for all new executive tools.
- [x] **Automated Live Supabase Verification:**
  - Ran `test_adm5.py`: staff directory (23 school teachers, 10 detailed profiles), universal search round-trip, settings save and audit log generation verified against live DB.
  - `dart analyze lib/services/ lib/features/school/` returned **0 issues**.

---

### [COMPLETED] Step ADM6: Modifications Polish & Parity (M6, M7, M8, M9, M10, M11, M13, M14)
- [x] **M6 (Command Matrix Dynamic Count & Parity):**
  - Updated matrix header count to `'15 Operational Modules'`.
  - Added live badges across modules: admissions pending (`_pendingAdmissionsCount`), certificates pending (`_pendingCertificatesCount`), fee defaulters overdue (`_defaultersCount`), transport fleet (`_activeTransportRoutes`), and notices (`_recentCirculars.length`).
  - Drawer, Matrix, and Quick Action sheet 1:1 module parity.
- [x] **M7 (Route Guard on Leadership Routes):**
  - Configured GoRouter redirect guard in `lib/routes/app_router.dart` for `/school/admin-dashboard`.
  - Enforces `institute_type == 'school'` and `role IN ('admin', 'sadmin')`, safely redirecting unauthorized users to their respective portals or login screen.
- [x] **M8 (Explicit sadmin Login Case):**
  - Updated `lib/features/auth/login_screen.dart` to explicitly match `role == 'sadmin'` and route directly to `/school/admin-dashboard`.
  - Verified live DB row for `sadmin1` user exists with `role = 'admin'` and `institute_type = 'school'`.
- [x] **M9 & M11 (KPI Drill-downs & Fee Semantics):**
  - Implemented interactive bottom sheet drill-down modals:
    - `_showStudentsDrillDown`: attendance percentage breakdown, cohort counts, and links to attendance and reports.
    - `_showStaffOversightModal`: opens faculty directory, workload indicators, and user management link.
    - `_showFeeDrillDown`: clearly separates Today's collections (`_feeCollectedToday`) from cumulative Session Total Dues (`_feePendingDues`), with direct AD-R03 Excel ageing export.
    - `_showTransportDrillDown`: displays active fleet routes, safety mismatch telemetry, and direct AD-R08 Excel transport export.
- [x] **M10 & M14 (4-State Lifecycle & Touch Targets):**
  - 4-state lifecycle (skeleton loading, loaded data, empty state with CTA, error state with Retry button).
  - Ensured 48dp minimum touch targets across all interactive cards and action buttons.
- [x] **M13 (Staff & User Management Link):**
  - Explicit parameter `/admin/manage-users/school` in Command Matrix and Staff Oversight modal.
- [x] **Automated Live Supabase Verification:**
  - Ran `test_adm6.py` verifying `sadmin1` credentials in `users`, 152 fee records with paid vs pending sums, and 3 active transport routes.
  - `dart analyze lib/services/ lib/features/school/ lib/routes/ lib/features/auth/` returned **0 issues**.

---

### [COMPLETED] Step ADM7: Final QA, Live DB Regression, & Production Verification
- [x] **E2E Live DB Regression Suite (`test_adm7_qa.py`):**
  - Authenticated and verified `sadmin1` user in `users` (`role = 'admin'`, `institute_type = 'school'`).
  - Verified institutional settings (`Shivalik International School`, CBSE #3530124, 2025-2026, Fire NOC expiry 2027-12-31).
  - Verified real entity datasets with 0 fake constants: 68 enrolled students, 23 faculty in `users`, 152 fee transactions, 6 admission candidates, 3 bus routes, 6 library titles, 40 circular notices.
  - Verified Executive Approvals Desk queue: 1 pending admission, 0 pending certificates, 7 pending leaves, 2 open parent grievances.
  - Verified immutable audit trail: 3 logged administrative events.
- [x] **Static Analysis Verification:**
  - `dart analyze lib/services/ lib/features/school/ lib/routes/ lib/features/auth/` returned **0 issues** (0 errors, 0 warnings).
  - 0 compile errors across the entire codebase.
- [x] **Dual-ERP Isolation Guarantee:**
  - Zero modifications to College ERP files (`lib/features/college/`, college services, college tables, `/admin/manage-users` route).
- [x] **Deep-Dive Milestone Status:**
  - **School ERP Admin Dashboard Deep-Dive (ADM0 to ADM7): 100% COMPLETE.**

