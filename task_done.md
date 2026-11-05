- **Current Step in Execution Plan:** `Step T5: New Features Implementation (N13, N5, N8, N12, N4, N7, N6, N10, N9, N11, N14)`
- **Status:** Step T4 (Reports Second Half + Excel Suite) completed with 100% verification. Added `gradeHomeworkSubmission`, `getTeacherWeeklyWorkload` (T-R12), and `getTeacherSyllabusVelocity` (T-R09) to `SchoolService`. Built official Excel `.xlsx` exporters in `SchoolExportService` for homework submissions (T-R08), lesson plan velocity (T-R09), and weekly workload (T-R12). Updated `marks_entry_screen.dart` (M6) with class parity and Excel export, `school_attendance_screen.dart` (M7) with assigned classes scoping, `fl_chart` attendance trend line chart with 75% CBSE limit, and Excel register export, and `homework_list_screen.dart` (M8) with per-submission evaluation modal and Excel export. Verified with live automated tests and `dart analyze` (0 issues). Moving to Step T5 (New Teacher Dashboard Features).

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
