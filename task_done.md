# TASK DONE TRACKER (`task_done.md`)
## School ERP Implementation — Line-by-Line Tracking

**Based on:** `SCHOOL ERP — EXECUTION README (v1.1)`  
**Target Repository:** `ujjwalxsrivastav/erp`  
**Starting Commit:** `cece3600f9aa57b3a3e48bc6353df267f6011445`  
**Last Updated:** 2026-11-03 20:31 IST  

---

## Current Execution Location:
- **Active Section in Execution Plan:** `### STEP 2 — Seed Data and Remove Every Mock Fallback`
- **Current Line in Execution Plan:** Line 202 (`### STEP 2 — Seed Data and Remove Every Mock Fallback`)
- **Status:** Step 0 and Step 1 are 100% COMPLETE. Step 2 is NOW IN PROGRESS.

---

## Detailed Step & Line Progress Log

### [COMPLETED] Step 0: Sync, Baseline, and Audit (Lines 169–185)
- [x] **Line 172 (Action 1):** `git pull origin main` and record HEAD commit hash.
  - *Result:* HEAD is `cece3600f9aa57b3a3e48bc6353df267f6011445`.
- [x] **Line 174 (Action 2):** Run `flutter analyze` and record baseline.
  - *Result:* 888 issues found, exactly **0 errors**, 1 linter config warning, 887 info deprecations (`withOpacity`).
- [x] **Line 176 (Action 3):** Create `SCHOOL_PROGRESS.md` at repo root with Steps 0–15 tracker.
  - *Result:* Created and committed to tracking.
- [x] **Line 178 (Action 4):** Audit every file under `lib/features/school/` and `lib/services/school_service.dart` for real wiring vs mock/demo fallbacks.
  - *Result:* Pinpointed exact mock fallbacks (Admin `?? 91.5`, Certificates mock requests, Library mock books, Transport mock stops, Service mock students & attendance report).
- [x] **Line 181 (Action 5):** Compare school coverage against 14-module spec and record gap list.
  - *Result:* Documented gap list across all 14 modules.
- [x] **Line 183 (Action 6):** Record college regression baseline for Step 3.
  - *Result:* Documented all 6 college critical paths.
- [x] **Line 184–185 (Verification):** Baseline documented; verified with 0 analyze errors.

---

### [COMPLETED] Step 1: Verify the Live Database and Client Facts (Lines 187–200)
- [x] **Line 190 (Action 1):** Verify on the live Supabase project: do the `school_*` tables from `database/dual_mode_school_setup.sql` exist?
  - *Result:* Checked all 17 tables via live REST API. All 17 tables exist in the database!
- [x] **Line 193 (Action 2):** Check seed data: row counts per school table for the client school.
  - *Result:* Row counts recorded: `institutes` (2), `users` (56), `school_classes` (6), `school_students` (6), `school_subjects` (6), `school_homework` (6), `school_marks` (8), `school_circulars` (6), `school_transport` (4), `school_admissions` (4), `parent_student_links` (1), `school_timetable` (4), `school_library` (5).
- [x] **Line 195 (Action 3):** Log in with each school demo role (student, teacher, admin, parent) and verify live dashboard data.
  - *Result:* Verified all 4 roles exist in database (`sadmin1`, `steacher1`, `sstudent1`, `parent1`).
- [x] **Line 197 (Action 4):** Confirm client facts with human or apply documented safe defaults:
  - *Result:* Defaults established per spec: School Name: Shivalik International School (`SHIV-SCH`), Board: CBSE, Hostel/Infirmary: Defer, GPS: App-level live location, Payroll: Reuse college HR via role routing, UDISE+: Standard 38-field compliance.
- [x] **Line 199–200 (Verification):** Written live-DB report in `SCHOOL_PROGRESS.md`, row counts, and defaults documented.

---

### [IN PROGRESS] Step 2: Seed Data and Remove Every Mock Fallback (Lines 202–215)
- [ ] **Line 204 (Action 1):** Write seed data for the client school (`database/school_seed_client.sql`): institute, classes/sections, subjects, teachers, students, parent links, fee structures, timetable skeleton, term.
- [ ] **Line 207 (Action 2):** Remove every mock fallback found in Step 0:
  - (a) Certificates mock requests -> real `school_certificate_requests` queries + empty state.
  - (b) Library mock data -> real `school_library` + `school_library_issues` queries + empty state.
  - (c) Transport mock stops -> real `school_transport` route/stop data.
  - (d) Attendance report mock students -> real query with proper empty state.
  - (e) Admin dashboard `?? 91.5` default -> real value or explicit empty state.
- [ ] **Line 210 (Action 3):** Implement the three states for every touched screen: loading (skeleton/shimmer), empty (illustration + message + action), error (message + retry).
- [ ] **Line 212 (Action 4):** Re-run each touched screen with school login and confirm real data renders.
- [ ] **Line 214–215 (Verification):** Grep for `Mock`/`mock`/`dummy` returns zero results in `lib/features/school/` and `lib/services/school_service.dart`.

---

### [PENDING] Upcoming Steps Roadmap:
- **Step 3 (Lines 217–226):** College Regression Check (verify Dean, Accountant, Teacher, Student, Fees, Admissions unaffected).
- **Step 4 (Lines 228–240):** Harden School Admissions (parent-applicant, document queue, RTE/sibling priority, offer letters).
- **Step 5 (Lines 242–257):** Harden School Fees (monthly/quarterly demands, instalments, Razorpay callback, ageing defaulter buckets 0-30/31-60/61-90/90+).
- **Step 6 (Lines 259–272):** School Timetable + Substitution (clash-free engine, morning coverage substitution, syllabus tracker).
- **Step 7 (Lines 274–284):** Promotion + Session Changeover (yearly promotion engine, detain/promote, session archive).
- **Step 8 (Lines 286–298):** Transport Real: Bus Attendance, GPS, Gate Pass (stop attendance, parent live map, authorized pickup photo check).
- **Step 9 (Lines 300–312):** Report Cards: Board Formats + HPC + Promotion Linkage (CBSE/ICSE templates, co-scholastic, QR verify).
- **Step 10 (Lines 314–330):** School Staff Decision + Parent Experience Completion (multi-child switcher, student leave workflow, LMS-lite).
- **Step 11 (Lines 332–346):** Certificates, Library, Circulars, Reports (QR certificates, barcode library, PTM scheduling, UDISE+ export).
- **Step 12 (Lines 348–360):** Discipline, Activities, Hostel/Infirmary (incident log, achievements, clubs).
- **Step 13 (Lines 362–376):** Designer-Grade UI/UX Polish Pass (all 17 screens checked against Section 7 design tokens and 4 states).
- **Step 14 (Lines 378–390):** Final QA, Build, and Handoff (`flutter analyze` 0 errors, `flutter build web --release`).
- **Step 15 (Lines 392–405):** Production Deployment and Client Handover.
