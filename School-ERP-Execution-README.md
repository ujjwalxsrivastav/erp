# SCHOOL ERP — EXECUTION README (for Claude / the Implementing Agent)
## Finish the School Vertical Inside the Existing College ERP Repository

**Repository:** `ujjwalxsrivastav/erp` (Flutter + Supabase, Riverpod + GoRouter)
**Starting HEAD (verify in Step 0):** `origin/main` at or after `cece360` ("chore: ignore unused variable in leave_service", 3 Nov 2026).
**Companion spec:** `School-ERP-Modules-and-Workflows.md` (14 school modules, workflows, roadmap) and `University-ERP-Workflow-Blueprint.md` (college spec). This README is the execution plan; the companion spec is the product requirement. If they conflict, this README's Step 0 audit decides, and you record the decision in `SCHOOL_PROGRESS.md`.
**Audience:** An AI coding agent (Claude) working inside this repository, possibly across multiple sessions with usage limits. This README is written so that any agent can start, stop, and resume without losing work. Read the whole README once before writing any code, then execute strictly step by step.

---

## 1. MISSION (What "Done" Means)

Build the **school vertical (K-12, Pre-Primary to Class 12)** inside the **same repository** as the existing college ERP, because an urgent school client needs it now.

"Done" means ALL of the following:
1. A school user (student, teacher, admin, parent) can log in and complete their full daily journey end to end on real data: admission → class/section → timetable → attendance → homework → marks → report card → fees → transport → library → certificates → reports.
2. Every mock/demo fallback in school code is removed or placed behind an explicit, default-OFF demo flag. The client demo runs on real seeded data, never on hardcoded lists.
3. The college vertical keeps working exactly as before. No college screen, route, table, or flow regresses.
4. Every school screen passes the UI/UX standard in Section 7 (designer-grade, no exceptions).
5. `flutter analyze` is clean (no new errors; pre-existing errors, if any, are listed in `SCHOOL_PROGRESS.md` and untouched), and the app builds for web.
6. `SCHOOL_PROGRESS.md` shows every step DONE with its verification evidence, or the final message contains the HANDOFF block from Section 6.

**Out of scope (do NOT build unless a later step explicitly says so):** A separate school app, a separate repository, a separate Supabase project, GPS hardware integration beyond the app-level live-location flow in Step 9, and any change to college business rules.

## 2. NON-NEGOTIABLE RULES (Violating Any of These Fails the Step)

1. **College keeps working.** Never change the behaviour of a college screen, route, or table. College tables are read-only for school work. If shared core code must change, run the college regression check in Step 3 first and record the result.
2. **School data lives in `school_*` tables only** (see Section 3). Never write school records into college tables, and never mix the two in one query without an explicit `institute_type` filter.
3. **Money and marks are append-only.** Fees, payments, marks, and results are never edited in place or deleted. Corrections use a reversal/correction record with an audit entry.
4. **Maker-checker.** The role that creates a record (fee structure, marks entry, payroll input) must never be the role that approves it.
5. **RLS on every new table.** Every new Supabase table ships with Row Level Security enabled and policies for its roles before its screen is marked DONE. No screen ships on an RLS-disabled table.
6. **No secrets in code.** Never commit `.env`, keys, passwords, or tokens. `.env` stays gitignored. Use only the existing `flutter_dotenv` pattern.
7. **No hardcoded demo data in the final build.** Mock lists, `?? 91.5`-style fallback constants, and "mock stops" are defects, not features. Replace them with real queries plus proper empty states (see Step 2).
8. **One step = one verifiable unit.** Never start Step N+1 until Step N's verification passes and its checkpoint is written. Never leave the app in a non-building state at the end of a step.
9. **UI/UX bar (Section 7) applies to every screen you touch.** A functionally correct but visually unfinished screen is NOT done.
10. **Checkpoint discipline (Section 6).** After every step: verify, commit, update `SCHOOL_PROGRESS.md`. If you must stop, write the HANDOFF block. No exceptions.

## 3. STARTING TRUTH — READ THIS BEFORE YOU TOUCH ANYTHING (Verified 3 Nov 2026)

The school vertical **already exists in this repository**. A teammate built it and it was merged to `origin/main` on 3 Nov 2026 (~20:03 IST, merge `6083b77`, including `ae9f177 "feat(school): complete all school modules with real workflows, library, certificates, report cards, transport, and reports hub"`). Do NOT rebuild it from scratch. Your job is: **audit it, remove its demo fallbacks, fill its gaps against the 14-module spec, harden it, polish it to designer grade, and prove it end to end.**

### 3.1 What already exists (on `origin/main`, verified by file listing)

**School screens — `lib/features/school/` (17 screens):**
- Dashboards: `school_admin_dashboard.dart`, `school_student_dashboard.dart`, `school_teacher_dashboard.dart`, `parent/school_parent_dashboard.dart`
- `admissions/admissions_screen.dart`, `attendance/school_attendance_screen.dart`, `certificates/school_certificates_screen.dart`, `circulars/circulars_screen.dart`, `fee/school_fee_screen.dart`, `homework/homework_list_screen.dart`, `homework/upload_homework_screen.dart`, `library/school_library_screen.dart`, `marks/marks_entry_screen.dart`, `marks/report_card_screen.dart`, `reports/school_reports_screen.dart`, `timetable/school_timetable_screen.dart`, `transport/transport_screen.dart`

**School service layer — `lib/services/school_service.dart`** (~40 real Supabase methods, including): `getSchoolStudentDetails`, `getSchoolClasses`, `getStudentsInClass` / `getStudentsByClass`, `getSchoolSubjects`, `getSchoolStats`, `getTeacherDetails`, `getTeacherTimetable`, `getTeacherClasses`, `getPendingHomeworkToGrade`, `hasMarkedAttendanceToday`, `getStudentAttendancePercent`, `getPendingHomeworkCount`, `getNextExam`, `getAttendance` / `markAttendance` / `getAttendanceReport` / `getAttendanceSummary`, `getHomework` / `createHomework` / `updateHomeworkStatus` / `getHomeworkStats`, `getMarksByClassSubjectExam` / `getStudentMarks` / `saveMarks` / `getMarksReport`, `getStudentFees` / `getPendingFees` / `recordFeePayment` / `getFeeReport` / `getFeeCollectionReport`, `getCirculars` / `createCircular` / `deleteCircular`, `getSchoolNotices`, `getTransportRoutes`, `getStudentTransport`, `getAdmissions` / `submitAdmission`.

**School database — `database/dual_mode_school_setup.sql`:** `institutes`, `school_classes`, `school_homework`, `school_attendance`, `school_marks`, `school_circulars`, `school_transport`, `school_admissions`, `parent_student_links`, `school_timetable`, `school_library`, `school_library_issues`, `school_certificate_requests`, `school_students`, `school_fee_payments`, `school_subjects`, plus `users.institute_type` (`'college'` default, `'school'` for school users).

**Dual-mode routing (already wired):** Login reads `users.institute_type` and routes school users to `/school/*` dashboards (student/teacher/admin/parent) and college users to college dashboards. School routes exist for every screen above under `/school/*` in `lib/routes/app_router.dart`. Demo school accounts are shown on the login screen (for example, school student, school teacher, school admin usernames) — use the credentials shown there, or your own test accounts; never invent passwords.

### 3.2 What is known to be demo/mock (your Step 0 audit must confirm the full list)

- `certificates/school_certificates_screen.dart` — contains "Mock requests".
- `library/school_library_screen.dart` — contains "Mock library data (fallback)".
- `transport/transport_screen.dart` — contains "mock stops based on route name".
- `school_service.dart` — contains "Standard mock students for rich demo if DB not seeded" and a mock list inside the attendance report path.
- `school_admin_dashboard.dart` — defaults `attendance_today` to `91.5` when the value is missing.
- **Unknown from the repository alone (Step 1 must verify live):** whether `dual_mode_school_setup.sql` has actually been applied to the live Supabase project, whether school tables contain real seed data, and whether the school demo accounts can log in and see real data. A SQL file in the repo is NOT proof that it was applied.

### 3.3 College side (reference for copy/adapt — do not modify behaviour)

201 Dart files. College features: `leads` (admission CRM), `admission` (5-step admission form), `finance` (fee structures, demands, receipts, reports), `fees` (payment receipts, student fees screens), `examination` (COE: forms, eligibility, hall tickets, evaluation, results), `hr` (recruitment, appraisal, exit), `leave`, `timetable` + `services/timetable_service.dart` + `services/arrangement_service.dart` (substitution), `transport`, `hostel`, `student`, `teacher`, `hod`, `admin` (users, institute setup, certificates, No-Dues), `notices`, `dashboard`.
Shared core (reuse as-is): `core/theme/app_theme.dart` (ERP palette: blue `#2563EB`, emerald `#059669`, violet `#7C3AED`, ink `#0F172A`, slate `#475569`, background `#F8FAFC`), `core/widgets/` (`glass_card.dart`, `gradient_button.dart`, `error_handler.dart`), `core/config/`, `core/security/`, `services/supabase_service.dart`, `services/auth_service.dart`, `services/cache_manager.dart` + `enhanced_cache_manager.dart`, `services/offline_service.dart`, `services/session_service.dart`, `services/staff_pdf_service.dart`, `services/events_service.dart`. Dependencies already in `pubspec.yaml`: `supabase_flutter`, `flutter_riverpod`, `go_router`, `pdf` + `printing`, `qr_flutter`, `barcode_widget`, `fl_chart`, `razorpay_flutter`, `table_calendar`, `syncfusion_flutter_calendar`, `shimmer`, `lottie`, `animations`, `badges`, `cached_network_image`, `image_picker`, `file_picker`, `excel`, `csv`, `http`, `url_launcher`, `flutter_svg`.

### 3.4 Architecture decisions (fixed — do not redesign)

1. **Dual-mode, one app, one repo, one Supabase project.** Mode is decided per user by `users.institute_type`. Never split the app or the repo.
2. **School code lives under `lib/features/school/` and school logic goes through `lib/services/school_service.dart`.** Extend that service; do not create a second parallel school service layer.
3. **School routes live under `/school/*`.** College routes are untouched.
4. **School tables are `school_*` plus `parent_student_links` and `institutes`.** College tables are never written by school code.
5. **Shared core is shared.** Theme, widgets, auth, Supabase client, caching/offline, security, and PDF/QR helpers are reused as-is. School-specific UI is built from the same tokens and widgets, not from a second design system.
6. **One school client first, multi-school ready.** Every school table that belongs to a school carries an institute/school identifier (use the existing `instituteId` parameter pattern in `school_service.dart`). Do not build a multi-tenant admin UI in this plan; just keep the data model ready for it.

---

## 4. REUSE MAP — WHAT TO COPY, WHAT TO ADAPT, WHAT TO BUILD NEW

Read this table before Step 4. "Copy" always means: copy the pattern/implementation into the school context (or reference it directly when it is shared core), then apply the listed changes. Never copy a file and leave college terminology, college table names, or college flows inside school code.

### 4.1 COPY AS-IS (shared core — reference directly, do not duplicate)

| Item | Source | School usage |
|---|---|---|
| Theme tokens + typography | `core/theme/app_theme.dart` | Use for all school screens. Extend only via Section 7 tokens, in the same file, with school accent tokens clearly marked. |
| Shared widgets | `core/widgets/` (glass card, gradient button, error handler) | Use for all school screens. New school widgets go in `lib/features/school/widgets/` and follow the same style. |
| Supabase client + auth | `services/supabase_service.dart`, `services/auth_service.dart` | Use as-is. School login already routes via `institute_type`. |
| Cache / offline / session | `services/cache_manager.dart`, `enhanced_cache_manager.dart`, `services/offline_service.dart`, `services/session_service.dart` | Use as-is for school screens that need offline reads. |
| Security helpers | `core/security/` | Use as-is. Never bypass them for school screens. |
| PDF / QR / charts | `pdf`, `printing`, `qr_flutter`, `barcode_widget`, `fl_chart` (already in `pubspec.yaml`) | Use for report cards, receipts, ID cards, and reports. |
| Payment dependency | `razorpay_flutter` (already in `pubspec.yaml`) | Wire it into school fee payment (Step 6) following the college `fees/payment_receipt_screen.dart` pattern. |
| Events + notices patterns | `services/events_service.dart`, `features/notices/` | Reference for school circulars/notices; school already has `getCirculars`/`getSchoolNotices`. |

### 4.2 COPY + ADAPT (copy the college implementation, then make these exact changes)

| College source | School target | Changes required after copying |
|---|---|---|
| `features/admission/` (5-step form, lead → enrolment) | `features/school/admissions/` | Replace programme/semester with class/section. Replace student-applicant with parent-applicant (parent fills the form, parent OTP login). Add: sibling priority, RTE quota flag, previous-school TC/report card upload, interaction scheduling. Remove: entrance merit lists, counselling rounds, seat matrix by programme. Keep: document verification queue (`Verified / Rejected / Re-upload`), duplicate check (parent mobile + child DOB), offer + deadline + waitlist auto-offer. |
| `features/finance/` + `features/fees/` (structures, demands, receipts, defaulter) | `features/school/fee/` | Replace semester demand with monthly/quarterly demand. Add: instalment plans, sibling discount rule, staff-child discount rule, RTE as government receivable (NOT a discount — see spec Module 7). Keep: demand lock, sequential receipts, cheque-bounce handling, ageing buckets, NEFT-only refunds. Change fee heads to school heads (Tuition, Transport, Hostel, Activity, Exam, Caution, One-time Admission). |
| `features/examination/` (COE: eligibility, evaluation, results) | `features/school/marks/` | Replace semester/CGPA/backlog/revaluation with term/unit-test/Half-Yearly/Annual + board-format report card + HPC. Remove: dummy-number secrecy, evaluator allocation, revaluation workflow. Keep: marks entry validation (max marks, AB = absent), verify-and-lock workflow (teacher → class teacher/Academic Head → Principal unlock only), result analysis. Add: co-scholastic entry (attendance, discipline, activities, sports, arts, values) and board grading-scale templates (CBSE/ICSE/State, configurable, never hard-coded). |
| `features/timetable/` + `services/timetable_service.dart` + `services/arrangement_service.dart` | `features/school/timetable/` | Replace programme/department grid with class/section period grid. Keep: clash detection, teacher load caps, room/lab handling. Add: substitution engine + morning coverage check (absent teacher → suggested substitute → instant notification → period log). This is a school daily-critical flow; the college substitution pattern is the starting point, not an optional extra. |
| `features/transport/` | `features/school/transport/` | Keep: route/stop/vehicle/driver master, allotment with capacity, route-wise fee. Add (new, see 4.3): bus attendance per stop, parent pickup/drop alerts, live GPS view, gate pass + pickup verification. Remove the mock stops implementation entirely. |
| `features/hostel/` | School hostel (only if the client school has a hostel — confirm in Step 1; default: defer to Phase 2) | Same bed/room logic, but with parent (not student) as the applicant and parent SMS on gate pass/night-out. Do not build it speculatively; Step 1 decides. |
| `features/hr/` + `features/leave/` | School staff (Step 11 decision) | Keep: employee master, leave rules, payroll + statutory pattern. Change: school roles (teacher, attendant, driver, nurse, warden) instead of college roles; teaching vs non-teaching leave config; substitution linkage (leave → morning coverage). If the client does not need school payroll in this release, reuse college HR screens via role routing instead of building school HR screens, and record that decision. |
| `features/admin/` (users, institute setup, certificates, No-Dues) | `features/school/` admin + certificates | Keep: user management, certificate issue register with QR verification, No-Dues parallel workflow (Library/Transport/Finance). Change: certificate types to school types (TC/Bonafide/Character/Study); TC original issued once, duplicate requires affidavit + fee + Principal approval. |
| `features/student/` + `features/teacher/` dashboards | `features/school/` dashboards | Already exist as school dashboards. Adapt (do not re-copy): replace college widgets (CGPA, semester, backlog) with school widgets (attendance %, pending homework, next exam, fee due, bus status, report card). |

### 4.3 BUILD NEW (does not exist in college or school code — build from the spec)

| New item | Spec reference | Notes |
|---|---|---|
| GPS live tracking + parent map view for buses | School spec Module 8 | App-level live location from the driver app + parent map view. No hardware integration in this plan. |
| Gate pass + pickup verification (photo/ID check against authorised persons list) | School spec Module 8 | Safety-critical. Never shortcut. Authorised persons come from `parent_student_links` + a pickup-persons list you add. |
| Promotion + session changeover | School spec Module 2 | Promotion list (Promoted/Detained/Result Awaited) → Principal approval → changeover (next class/section, new fee structure link, old session archived). Does not exist as a school screen today. |
| Substitution morning coverage screen for school | School spec Module 3 | Distinct from the timetable screen: a morning checklist (absent teachers → uncovered periods → suggested substitutes → assign → notify). |
| UDISE+ export | School spec Part 5 | Export student/teacher/school data in the prescribed format. Confirm the exact format from the client's affiliation requirement in Step 1; do not guess field lists. |
| Discipline + activities + counselling log | School spec Module 13 | Discipline log with parent acknowledgement; confidential counselling log (role-restricted); clubs/sports/houses; achievements. |
| Infirmary log | School spec Module 10 | Only if the client school has a nurse/infirmary (confirm in Step 1; default: defer). |
| Seed data + demo removal | Sections 3.2, 5 (Step 2) | Real seed data for the client school (classes, subjects, teachers, students, fee structures) + removal of every mock fallback. |
| Parent experience completion | School spec Module 12 | Multi-child switching (verify `parent_student_links` wiring), instant alerts (attendance, homework, fee due, bus), PTM booking, complaint tracking. The parent dashboard exists; this step makes it complete and polished. |

### 4.4 AFTER COPYING, THESE CHANGES ARE MANDATORY (checklist — verify each one)

- [ ] No college table names in school queries (`students`, `marks_year*`, `fee_payments` are college tables — school queries use `school_*` tables only).
- [ ] No college terminology in school UI: no "programme", "semester", "CGPA", "backlog", "COE", "dean", "HOD" (school uses "class", "section", "term", "report card", "Principal", "Academic Head", "class teacher").
- [ ] No student-applicant flow: school admission, homework, fees, transport, and pickup flows address the **parent** as the acting user (except age-appropriate student views for senior classes).
- [ ] Fee demand cycle is monthly/quarterly, not semester-based.
- [ ] Grading scales are templates (CBSE/ICSE/State/custom), selected per school, never hard-coded numbers in a screen.
- [ ] Every copied screen passes the Section 7 UI/UX checklist (copying a college screen's layout is not enough — it must be re-polished to the school design standard).
- [ ] Every copied service method is routed through `school_service.dart` (or a clearly-named school service you add and register in the same pattern) — no direct college-service calls from school screens for school data.

### 4.5 MODULE COVERAGE MATRIX — All 14 Spec Modules Mapped to Steps (Audit This First)

Every module from `School-ERP-Modules-and-Workflows.md` must be traceable to at least one step below. If a module has no step, the plan is incomplete — stop and fix the plan before coding.

| # | Spec Module | Covered By Steps | Status in This Plan |
|---|---|---|---|
| 1 | Admissions & Front Office | Step 4 (admissions); Step 11 (PTM scheduling) | Harden (screens exist) |
| 2 | Student Information System (SIS Core) | Step 2 (seed/master), Step 7 (promotion/changeover), Step 11 (certificates) | Harden + build promotion |
| 3 | Timetable, Lesson Planning, Substitution | Step 6 | Harden timetable + substitution; build lesson plans |
| 4 | Attendance & Leave | Steps 2, 10 (student leave), 13; staff leave in Step 10 | Harden + build student leave |
| 5 | Homework, Assignments, LMS-lite | Step 10 (homework journey + LMS-lite build), Step 13 | Harden homework; build LMS-lite |
| 6 | Examination & Report Cards | Step 9 | Harden |
| 7 | Fees & Finance | Step 5 (fees; accounting depth conditional in Step 5) | Harden fees; accounting conditional |
| 8 | Transport & Safety | Step 8 | Build real (GPS, gate pass) + remove mocks |
| 9 | Library | Step 11 | Harden (remove mocks) |
| 10 | Hostel, Infirmary, Cafeteria | Step 12 (all three conditional on Step 1) | Conditional build / defer |
| 11 | HR & Payroll (Staff) | Step 10 (decision: build or reuse college HR) | Conditional |
| 12 | Communication & Parent/Student Portals | Step 10 (parent journey), Step 11 (circulars/PTM) | Harden |
| 13 | Discipline, Activities, Events | Step 12 | Build |
| 14 | Admin, RBAC, Multi-school | Steps 0, 3, 14 (RLS, dual-mode, regression) + Section 2 rules | Enforced by rules + checks (no separate build step) |
| — | Reports, Analytics, Compliance (spec Part 5) | Step 11 (reports hub, UDISE+ export) | Harden |
| — | Production deployment | Step 15 (new) | Build (hosting, UAT sign-off, handover) |

---

## 5. EXECUTION PLAN — NUMBERED STEPS (Execute Strictly In Order)

**General rule for every step:** (1) Read the step fully. (2) Do the actions. (3) Run the step's verification. (4) If verification fails, fix it before moving on — never carry a failing step forward. (5) Commit with message `school: Step N — <title>` (or record the change set if committing is not available in your session). (6) Update `SCHOOL_PROGRESS.md` (Section 6) and append the checkpoint line. (7) Only then start the next step.

### STEP 0 — Sync, Baseline, and Audit (no feature code yet)
**Objective:** Work from the true latest state and know exactly what is real vs demo.
**Actions:**
1. `git pull origin main` and record the HEAD commit hash in `SCHOOL_PROGRESS.md`. If the local clone is behind (it was at `1652552` while `origin/main` is at `cece360` or later), pull first — never work from a stale clone.
2. Run `flutter analyze` and record the baseline: total errors/warnings, and whether any are pre-existing (list them; do not fix unrelated pre-existing errors in this plan unless a step requires it).
3. Create `SCHOOL_PROGRESS.md` at the repo root using the template in Section 6. Fill in Steps 0–15 as `TODO`.
4. Audit every file under `lib/features/school/` and `lib/services/school_service.dart`: for each screen, record (a) real Supabase wiring, (b) mock/demo fallback, or (c) shell/UI-only. Grep for `Mock`, `mock`, `TODO`, `dummy`, `?? ` fallback constants, and hardcoded lists. Produce the definitive mock list (starting from Section 3.2 and extending it).
5. Compare school coverage against the 14-module spec and record the gap list (which spec items have no school screen, which screens are thin).
6. Record the college regression baseline: which college logins/flows you will re-check in Step 3.
**Verification:** `SCHOOL_PROGRESS.md` exists with HEAD hash, analyze baseline, full mock list, and gap list. `flutter analyze` output is saved or quoted in the progress file.
**Done when:** The audit is complete and written down. No code changed except `SCHOOL_PROGRESS.md`.

### STEP 1 — Verify the Live Database and Client Facts (no app code yet)
**Objective:** Replace assumptions with verified facts about the live backend and the client school.
**Actions:**
1. Verify on the live Supabase project (Table Editor or SQL Editor): do the `school_*` tables from `database/dual_mode_school_setup.sql` exist? If any are missing, apply the SQL file (paste it as one batch in the SQL Editor, as Supabase has no file import) and re-verify. Record which tables existed vs were newly created.
2. Check seed data: does each school table contain real rows for the client school (at least: 1 institute, classes, subjects, teachers, students, fee structures)? Record row counts per table.
3. Log in with each school demo role (student, teacher, admin, parent) and record: does login succeed, does the correct `/school/*` dashboard open, and does it show real data or empty/mock data?
4. Confirm with the human (Ujjwal) ONLY these client facts, in one message, before Step 2: (a) the client school's name, board (CBSE/ICSE/State), and classes offered; (b) whether the school has a hostel, infirmary, and GPS-equipped buses; (c) whether school payroll is in scope for this release; (d) the UDISE+ format requirement, if any. Do not invent any of these. If the human does not answer, proceed with the defaults recorded here (hostel: defer; infirmary: defer; GPS: app-level live location only; payroll: reuse college HR via role routing; UDISE+: build the export from the standard field set and mark it "verify with client" in the progress file).
**Verification:** A written live-DB report in `SCHOOL_PROGRESS.md`: table existence, row counts, login test results per role, and the four client facts (confirmed or defaulted).
**Done when:** You know exactly what the backend contains and what the client needs. No app code changed.

### STEP 2 — Seed Data and Remove Every Mock Fallback
**Objective:** The app runs on real data; demo fallbacks disappear.
**Actions:**
1. Write seed data for the client school (from Step 1 facts): institute, classes/sections, subjects, teachers, students with parent links, fee structures, timetable skeleton, and at least one term. Use a single seed SQL file `database/school_seed_client.sql` (new file, committed) so the seed is repeatable. Never seed by hand-editing app code.
2. Remove every mock fallback found in Step 0: certificates mock requests → real `school_certificate_requests` queries; library mock data → real `school_library` + `school_library_issues` queries; transport mock stops → real `school_transport` route/stop data; attendance report mock students → real query with a proper empty state; admin dashboard `?? 91.5` default → real value or an explicit "no data yet" state.
3. For every screen you touch, implement the three states: **loading** (skeleton/shimmer, never a blank screen), **empty** (illustration + plain-language message + the one action that fixes it, for example "Add first student"), **error** (plain-language message + retry button, never a raw exception).
4. Re-run each touched screen with a school login and confirm real data renders.
**Verification:** Grep for `Mock`/`mock`/`dummy` in `lib/features/school/` and `lib/services/school_service.dart` returns zero results (except a clearly-marked, default-OFF demo flag if one is intentionally kept — if kept, document it). Each touched screen is manually opened in loading, empty, and error states (or the states are demonstrated by temporarily emptying the query in a test run and restoring it).
**Done when:** No mock fallback remains in school code, and seed data renders on every school dashboard.

### STEP 3 — College Regression Check (protect the existing product)
**Objective:** Prove the school merge and your changes did not break college.
**Actions:**
1. Log in with college demo roles (for example, Dean/admission, accountant, HR, teacher, student — use the credentials shown on the login screen) and click through: college dashboard, admission/lead flow, fee screens, examination screens, HR screens, timetable.
2. Run `flutter analyze` and compare against the Step 0 baseline: no new errors.
3. Verify dual-mode routing still works: a college user lands on college dashboards, a school user lands on `/school/*` dashboards, and neither sees the other's data (spot-check one query per side).
**Verification:** A regression note in `SCHOOL_PROGRESS.md` listing each college flow checked and its result (pass/fail). Any failure is fixed in this step before proceeding — a failing college flow blocks all later steps.
**Done when:** College works as before, dual-mode routing is proven, and analyze shows no new errors.

### STEP 4 — Harden School Admissions (copy-adapt from college admission)
**Objective:** A complete, parent-facing admission flow (spec Module 1).
**Actions:**
1. Audit `features/school/admissions/` against Section 4.2 (admission row) and the spec: parent-applicant form, document upload, verification queue (`Verified / Rejected / Re-upload`), sibling priority, RTE flag, interaction scheduling, offer + deadline + waitlist auto-offer, duplicate check (parent mobile + child DOB).
2. Copy the missing pieces from college `features/admission/` (verification queue pattern, duplicate-check pattern, offer/deadline logic), adapting terminology and tables per Section 4.4.
3. Wire the flow end to end: application → verification → offer → fee confirmation → Student Master creation (`school_students`) + parent link (`parent_student_links`) + class/section allotment + ID card data.
4. Apply the Section 7 UI/UX checklist to every admissions screen you touch.
**Verification:** Create one test admission end to end with a school admin login: application submitted → verified → offered → fee confirmed → student appears in the class roster, the parent login works, and the fee ledger shows the first demand. Record the test admission ID (test data only) in the progress file.
**Done when:** The end-to-end admission test passes on real tables, with no college terminology in the UI.

### STEP 5 — Harden School Fees (copy-adapt from college finance/fees)
**Objective:** A complete school fee flow (spec Module 7) with real money handling.
**Actions:**
1. Audit `features/school/fee/` against Section 4.2 (fees row): fee structures by class/category, demand generation (monthly/quarterly), instalments, sibling/staff-child/RTE rules, collection (online + counter), receipts, refunds, defaulter list.
2. Copy the missing pieces from college `features/finance/` + `features/fees/` (demand lock, sequential receipts, cheque-bounce handling, ageing buckets, NEFT-only refund rule), adapting per Section 4.4. RTE must be implemented as a government receivable, never as a discount.
3. Wire Razorpay (already a dependency) into school fee payment following the college receipt pattern: success callback → auto-receipt + ledger credit (`school_fee_payments`) + bank posting; failure/pending → no receipt, retry link, reconciliation flag.
4. Build the defaulter view (ageing 0–30/31–60/61–90/90+ days) and the late-fee rule (flat/per-day/percentage with cap and grace period, all configurable, never hard-coded).
5. School accounting beyond fees (budget, purchase-lite, audit pack): confirm scope in Step 1. Default for this release = fee ledger + receipts + defaulter + basic reports; full budget/P2P only if the client confirms, otherwise record it DEFERRED (college finance patterns remain available as reference).
6. Apply the Section 7 UI/UX checklist to every fee screen you touch.
**Verification:** End-to-end money test on real tables (test data only): raise a demand → pay online (test mode) and at counter (test entry) → receipts generated with sequential numbers → ledger balances correct → one refund processed NEFT-only with prior dues adjusted → defaulter list shows the correct ageing. Record test receipt numbers in the progress file. Money values use DECIMAL/paise, never float.
**Done when:** The money test passes, receipts are sequential, and no fee screen shows mock data.

### STEP 6 — School Timetable + Substitution (copy-adapt from college timetable)
**Objective:** Clash-free timetables and a morning coverage workflow (spec Module 3).
**Actions:**
1. Audit `features/school/timetable/` against the spec: class/section period grid, teacher/subject/room mapping, clash detection, teacher load caps, lab batch splits.
2. Copy the missing timetable logic from college `features/timetable/` + `services/timetable_service.dart` (clash detection, load caps), adapting to class/section.
3. Build the substitution morning coverage screen (new): pull absent/leave teachers (from leave data) → list uncovered periods → suggest substitutes (free period + subject familiarity + load balance) → Academic Head assigns → substitute receives instant notification → assignment recorded in the period log → monthly substitution report.
4. Copy the substitution pattern from college `services/arrangement_service.dart` as the starting point; adapt role names and tables to school.
5. Build lesson plans and syllabus tracking (new for school): teacher creates a weekly/monthly plan (topic, resources, linked homework) → Academic Head approves → plan visible to parents/students; coverage dashboard (planned vs actually taught, derived from the period log) alerts the Academic Head on lagging topics.
6. Apply the Section 7 UI/UX checklist to every timetable/substitution screen you touch.
**Verification:** Generate a test timetable with a deliberate clash (same teacher, same period, two classes) and confirm the system reports it before publish. Then mark a teacher absent, open the morning coverage screen, assign a substitute, and confirm the notification path and period log entry. Record both test results.
**Done when:** Clash detection blocks a bad publish, and the morning coverage flow works end to end.

### STEP 7 — Promotion + Session Changeover (build new)
**Objective:** The yearly promotion loop (spec Module 2) that no school screen currently provides.
**Actions:**
1. Build the promotion list generator: from final results + the attendance rule, produce `Promoted / Detained / Result Awaited` per class, with class teacher verification and Principal approval.
2. Build the changeover action: approved promotions move students to the next class/section, link the new fee structure, and archive the old session. Data is never deleted.
3. Handle edge cases explicitly: detained students (parent notice + counsellor task auto-created), transfer-in students (previous TC verified), mid-year joiners (no promotion record for the prior term — show "Joined mid-session").
4. Apply the Section 7 UI/UX checklist to the promotion screens.
**Verification:** Run a test changeover on test data: a class of test students promotes correctly, one detained student is held with a parent notice created, and the old session remains readable (archived, not deleted). Record the test class and counts.
**Done when:** The test changeover passes and the archive is provably intact.

### STEP 8 — Transport Real: Bus Attendance, GPS, Gate Pass (build new + remove mocks)
**Objective:** Transport becomes a real safety system (spec Module 8), not a mock.
**Actions:**
1. Replace the mock stops implementation with real `school_transport` route/stop data and per-stop bus attendance (boarded/alighted) from the driver flow.
2. Build the parent live view: bus location on a map + estimated arrival + pickup/drop alerts (app-level live location from the driver side; no hardware integration in this plan).
3. Build gate pass + pickup verification: parent requests a gate pass → class teacher + security approve → security verifies the pickup person's photograph/ID against the pre-registered authorised persons list → exit logged with time and verifier. If the person is not on the list, Principal approval is mandatory. No shortcut path may exist in the UI.
4. Add vehicle document expiry alerts (registration, insurance, fitness) and driver/attendant verification status from HR data.
5. Apply the Section 7 UI/UX checklist to every transport screen you touch.
**Verification:** End-to-end transport test on test data: a test route with stops → a test student assigned → bus attendance marked at two stops → parent view shows the journey → a gate pass issued and verified at the gate → an expired vehicle document raises an alert. Record the test route and results.
**Done when:** No mock stops remain, the journey is visible to the parent, and gate pass verification cannot be bypassed in the UI.

### STEP 9 — Report Cards: Board Formats + HPC + Promotion Linkage (harden)
**Objective:** Report cards the client school can actually issue (spec Module 6).
**Actions:**
1. Audit `features/school/marks/` (marks entry + report card screens) against the spec: term setup, marks entry validation, verify-and-lock workflow, co-scholastic entry, board grading-scale templates, HPC composition, QR verification, Principal digital signature.
2. Implement board-format templates as configuration (CBSE/ICSE/State/custom selected per school — confirm the client's board from Step 1). No grading numbers hard-coded in any screen.
3. Implement HPC composition: marks + grades + attendance + co-scholastic areas (activities, sports, arts, values) + teacher remarks.
4. Link results to promotion (Step 7): final results feed the promotion list under the configured pass/fail/detention rules.
5. Apply the Section 7 UI/UX checklist to marks and report card screens.
**Verification:** Generate one test report card end to end (test student, test term, test marks including one co-scholastic area) in the client's board format with QR verification, and confirm it feeds the promotion list correctly. Record the test student and card details.
**Done when:** A board-correct, QR-verifiable report card generates from real marks and links to promotion.

### STEP 10 — School Staff Decision + Parent Experience Completion
**Objective:** Close the two remaining user-facing gaps: staff handling and the parent journey (spec Modules 11 + 12).
**Actions:**
1. **Staff decision (from Step 1 facts):** If school payroll is in scope, build school staff screens by adapting college HR/leave patterns (school roles: teacher, attendant, driver, nurse, warden; teaching vs non-teaching leave config; leave → morning coverage linkage). If payroll is out of scope, reuse college HR screens via role routing, record that decision in `SCHOOL_PROGRESS.md`, and do not build duplicate HR screens.
2. **Parent experience:** Verify and complete the parent journey on real data: multi-child switching via `parent_student_links`; instant alerts (attendance, homework, fee due, bus); homework pending list; fee pay + receipts; report cards; timetable; bus view; PTM booking; complaint tracking. Fix every broken link or empty view you find; a parent dashboard that shows a widget with no data behind it is a defect.
3. Build the student leave workflow (new for school): parent applies via the app (medical certificate where applicable) → class teacher → Academic Head approves → attendance record updated with an audit entry.
4. Build LMS-lite (new for school): study material library organised by class (visible only to that class) + online tests/quizzes (MCQ auto-checked) with configurable weightage into assessments.
5. Apply the Section 7 UI/UX checklist to every parent-facing screen (this is the client-visible surface — hold it to the highest bar in this plan).
**Verification:** A parent-journey test with a test parent linked to two test children: switch between children, pay a fee, see attendance + homework + report card + bus status for each child, book a PTM slot, and file a complaint. Record the test parent and results per child.
**Done when:** The two-child parent journey passes end to end with no dead widgets.

### STEP 11 — Certificates, Library, Circulars, Reports (harden to real data)
**Objective:** Finish the remaining school screens so none runs on demo data (spec Modules 2, 9, 12, Part 5).
**Actions:**
1. **Certificates:** Replace mock requests with real `school_certificate_requests` flow: request → pre-checks (status, discipline, No-Dues: Library/Transport/Finance) → fee where applicable → Admin verify → Principal digital sign → unique serial + QR verification page → Issue Register entry. TC original issued once; duplicate requires affidavit + fee + Principal approval.
2. **Library:** Replace mock data with real `school_library` + `school_library_issues` flow: catalogue with barcodes → issue/return with class-wise limits → due reminders → late fines auto-posted to the fee ledger → reservations queue → No-Dues linkage.
3. **Circulars/notices:** Verify `getCirculars`/`getSchoolNotices` wiring end to end (create → target audience → deliver → delivery status). Add PTM scheduling if missing (slot booking against teacher availability + parent confirmation + reminders).
4. **Reports hub:** Verify `school_reports_screen.dart` end to end on real data: Principal morning dashboard (attendance %, collections vs dues, admission pipeline, transport status, teacher absence + substitution status, pending homework, open complaints); UDISE+ export (from Step 1 format facts; if the format is unconfirmed, build the export from the standard field set and mark it "VERIFY WITH CLIENT" in the progress file); audit pack basics (fee register, attendance register).
5. Apply the Section 7 UI/UX checklist to every screen you touch.
**Verification:** One real end-to-end test per area (certificate issued with QR, book issued + returned late with fine posted, circular delivered to a class, reports dashboard rendering real numbers, UDISE+ export file generated). Record each test result.
**Done when:** No screen in this step runs on mock data, and the reports hub shows real numbers.

### STEP 12 — Discipline, Activities, Hostel/Infirmary (only what Step 1 confirmed)
**Objective:** Build only the confirmed add-ons (spec Modules 10, 13). Do not build speculative modules.
**Actions:**
1. Build discipline + activities ONLY as confirmed: discipline log with parent acknowledgement; confidential counselling log (role-restricted); clubs/sports/houses enrolment; achievements. Conduct remarks link to report cards; sensitive details stay role-restricted.
2. Build hostel ONLY if Step 1 confirmed a hostel: bed/room logic adapted from college `features/hostel/` with parent as applicant and parent SMS on gate pass/night-out.
3. Build infirmary ONLY if Step 1 confirmed an infirmary: visit log, serious-case parent alert, hospital referral note, vaccination/health camp records, all with parental consent.
4. Build cafeteria ONLY if Step 1 confirmed it: meal plans / coupons / prepaid wallet → daily consumption log → monthly billing (Finance) → dietary notes (allergies) passed to the kitchen.
5. If any of these were deferred in Step 1, write "DEFERRED — <reason>" in `SCHOOL_PROGRESS.md` and skip it. Do not build it anyway.
6. Apply the Section 7 UI/UX checklist to every screen you touch.
**Verification:** For each built item, one real end-to-end test (discipline entry → parent acknowledgement; club enrolment → achievement; hostel bed allotment if built; infirmary visit if built). Deferred items are listed as deferred, not as done.
**Done when:** Every confirmed add-on passes its test, and every deferred add-on is explicitly recorded as deferred.

### STEP 13 — Designer-Grade UI/UX Polish Pass (all school screens)
**Objective:** Every school screen meets Section 7 with no exceptions. This step is not optional polish; it is a gate.
**Actions:**
1. Walk every `/school/*` screen in route order and apply the full Section 7 checklist. Fix: hardcoded colours/sizes (move to tokens), inconsistent card/button styles, missing loading/empty/error states, overflow on small screens, clipped text, low-contrast text, touch targets below 48dp, inconsistent spacing (snap to the 8pt grid), placeholder text, and dead widgets.
2. Unify: one card style, one button hierarchy (primary/secondary/text), one app bar pattern, one empty-state pattern, one error pattern, one date/number/currency format (Indian format, ₹, DD-MMM-YYYY).
3. Check the parent app screens twice — they are the client-visible surface and the demo surface.
4. Re-run `flutter analyze` and the Step 3 college regression spot-check (polish must not break function).
**Verification:** A screen-by-screen polish table in `SCHOOL_PROGRESS.md` (screen → issues found → fixed → re-checked). Every row must read fixed/re-checked before this step is DONE. If a screen cannot be checked (for example, it needs a role you cannot log in as), record it as UNCHECKED with the reason — never as done.
**Done when:** The polish table has no open rows and no UNCHECKED rows without a recorded reason and a follow-up owner (the human).

### STEP 14 — Final QA, Build, and Handoff
**Objective:** Prove the whole school vertical and hand it over cleanly.
**Actions:**
1. Run the full click-through script: school admin, teacher, student, and parent journeys end to end on real (test) data, in route order, covering every `/school/*` screen at least once.
2. Run `flutter analyze` (must show no new errors vs Step 0 baseline) and build for web (`flutter build web --release`). Record both outputs.
3. Verify RLS: confirm every new/changed school table has RLS enabled with role policies (list tables + policies in the progress file). Verify no school screen reads a table without RLS.
4. Verify no mock/demo data remains (repeat the Step 2 grep) and no college regression (repeat the Step 3 spot-check).
5. Write the final status in `SCHOOL_PROGRESS.md`: every step DONE with evidence, plus a short "Known limitations" list (anything deferred, anything needing the client's confirmation, anything untested and why).
6. If everything passes, proceed to Step 15 (production deployment). If anything fails, fix it in this step or, if you must stop, write the HANDOFF block (Section 6) instead of claiming completion.
**Verification:** Analyze output, web build output, RLS table list, mock grep output, and the completed progress file — all recorded.
**Done when:** QA and build pass and Step 15 is ready to begin, or the HANDOFF block accurately describes what is left.

### STEP 15 — Production Deployment and Client Handover (new — this step makes it production-ready)
**Objective:** The client school can use the product in production, with sign-off.
**Actions:**
1. Deploy the web release build to the production host (hosting provider + custom domain + SSL — confirm the provider and domain with the human first; never deploy to a provider the human has not approved).
2. Mobile apps ONLY if the client needs them (confirm in Step 1; default: web first): Play Store internal track or direct APK distribution, with the same school login and data.
3. Supabase production checks: RLS re-verified on every school table; automated backups enabled; test data handled per the Appendix C decision (deleted or clearly marked, as the human directs).
4. Monitoring enabled: crash reporting and basic analytics on the production build, with alerts routed to the human (not to the client school).
5. Client UAT sign-off: walk the client school through every journey (admin, teacher, student, parent) on production data and record sign-off per journey in `SCHOOL_PROGRESS.md`. Any UAT failure returns to the relevant step — it does not ship as a "known issue" without the human's explicit approval.
6. Handover pack: admin guide (how to add classes, teachers, students, fee structures), demo/training accounts list, `SCHOOL_PROGRESS.md` final state, and a post-launch support window agreed with the human.
**Verification:** Production URL live with SSL; UAT checklist signed per journey; test-data decision recorded; monitoring confirmed working.
**Done when:** The client can use the product in production and has signed off, or the HANDOFF block accurately states what blocks deployment.

### COMMANDS REFERENCE (run from the repo root)
- Sync: `git pull origin main` — then `git rev-parse HEAD` (record the hash).
- Baseline check: `flutter analyze` (record errors/warnings; compare per step).
- Run (web): `flutter run -d chrome` (or the project's documented run command).
- Release build (web): `flutter build web --release`.
- Mock grep: search `lib/features/school/` and `lib/services/school_service.dart` for `Mock`, `mock`, `dummy`, `TODO`, `lorem` (must return zero in the final build, except a documented default-OFF demo flag).
- Supabase verification: Table Editor for table existence and row counts; SQL Editor for targeted checks (for example, `select count(*) from school_students;`). Supabase has no file import — paste SQL as one batch.

---

## 6. CHECKPOINT AND RESUME PROTOCOL (Read Carefully — This Is How Multi-Agent Handoff Works)

### 6.1 The progress file (single source of truth for completion)
File: `SCHOOL_PROGRESS.md` at the repo root (created in Step 0). It contains:
- Header: repo HEAD hash, start date, current agent session note (optional), and the LIVE-DB report pointer (Step 1).
- A checklist table with one row per step:

| Step | Title | Status | Commit / Change Set | Verified How | Notes |
|---|---|---|---|---|---|
| 0 | Sync, Baseline, Audit | DONE / IN PROGRESS / TODO | (commit hash or "uncommitted: <files>") | (command output or test result) | (blockers, decisions, defaults) |
| 1 | ... | ... | ... | ... | ... |

- Status values only: `TODO`, `IN PROGRESS`, `DONE`, `DEFERRED` (with reason, Step 12 only), `BLOCKED` (with blocker + what unblocks it).
- A "Decisions" section: every judgement call you made (for example, "Step 1: hostel deferred — client school has no hostel per human confirmation"), with the step number.
- A "Known limitations" section (filled in Step 14, updated whenever a limitation is found).
- A "HANDOFF" section at the top (empty until needed — see 6.3).

### 6.2 After every step (mandatory, no exceptions)
1. Run the step's verification. If it fails, fix it. Do not proceed with a failing step.
2. Commit with message `school: Step N — <title>` (if committing is unavailable in your session, record the exact changed files instead).
3. Update the step's row to `DONE` with the commit/change set and the verification evidence (command output summary or test result, not just "tested OK").
4. Append a checkpoint line at the end of the file: `CHECKPOINT: Step N complete — <one-line evidence> — <date/time>`.
5. Only then begin the next step.

### 6.3 When you must stop (usage limit reached, session ending, or blocked)
Follow these rules in order. This is the mechanism that lets the next agent resume exactly where you stopped.
1. **Finish the current atomic step if you can do so safely.** If the current step's verification can pass with a small, safe change, do it and checkpoint it. Never rush a half-finished step into DONE.
2. **If the current step cannot be finished, leave the code in a building state.** `flutter analyze` must show no new errors vs the Step 0 baseline. Set the current step's status to `IN PROGRESS` with a note stating exactly what is done and what is not. Never mark a half-finished step DONE.
3. **Write the HANDOFF block** at the top of `SCHOOL_PROGRESS.md` (replacing any older HANDOFF block) AND as your final message. Use this exact template, filled in completely:

```
HANDOFF — SCHOOL ERP EXECUTION
LAST COMPLETED STEP (full and final): Step N — <title>
  Evidence: <verification output or test result proving Step N is done>
  Commit / change set: <hash or file list>
NEXT STEP: Step N+1 — <title>
  First three actions:
  1. <exact action>
  2. <exact action>
  3. <exact action>
REMAINING STEPS: <list all remaining step numbers and titles>
CURRENT STATE:
  Branch/HEAD: <branch + commit hash>
  Files changed since last checkpoint: <list>
  Pending verifications: <list, or "none">
  Blockers: <list, or "none">
  Live DB state: <school tables present, seed state, demo logins tested>
  Decisions made: <list, or "none">
DO NOT REDO: Steps 0–N (all marked DONE in SCHOOL_PROGRESS.md).
RESUME INSTRUCTION: Read this README + SCHOOL_PROGRESS.md, verify Step N using its verification command, then begin Step N+1. Do not redo DONE steps. If Step N's verification fails, fix Step N first and record the fix.
```

4. **Do not claim completion you have not proven.** If Step 14 is not fully verified, you are NOT done — you are handing off. Say so plainly.
5. **Do not start a new step you cannot finish.** If you have very little capacity left, prefer writing an accurate HANDOFF block over starting new code.

### 6.4 When you are the resuming agent (you received a HANDOFF block)
1. Read this README in full, then read `SCHOOL_PROGRESS.md` in full, including the HANDOFF block.
2. Verify the LAST COMPLETED STEP using its verification command or test. If it passes, proceed. If it fails, fix that step first, record the fix in the progress file (with the note "fixed on resume"), and only then proceed.
3. Begin at NEXT STEP. Never redo DONE steps. Never change DONE steps' files except to fix a verification failure (recorded as above).
4. Replace the HANDOFF block with your own updated block when you stop, or delete it when the plan completes (Step 14).
5. If the progress file and the code disagree (for example, a step marked DONE but its files are missing), trust the code, mark the step `IN PROGRESS` with a note explaining the discrepancy, and fix it. Record the correction.

---

## 7. UI/UX STANDARD — "DESIGNED BY A 50-YEAR-EXPERIENCED DESIGNER" (Concrete Rules, Not Vague Advice)

A screen is NOT done until it passes every rule below. "It works" is not enough. The client judges the product by what they see, and the parent app is the product's face.

### 7.1 Design tokens (single source of truth — no exceptions)
- **Colours:** Use only tokens from `core/theme/app_theme.dart`. Base palette: blue `#2563EB` (primary), emerald `#059669` (success), violet `#7C3AED` (accent), ink `#0F172A` (headings), slate `#475569` (body/secondary), background `#F8FAFC`. If a school accent is needed, add it as a named token in the same file (for example, `schoolAccent`) — never as a hardcoded hex in a screen.
- **Typography:** One font family for the app. One scale, used consistently: display (dashboards/headers), title (screen titles), body (content), caption (secondary/meta). Never invent a new size for one screen. Headings are ink; body text is slate; never use pure black (`#000000`) for text.
- **Spacing:** 8pt grid. All padding, margins, gaps, and radii are multiples of 4 (4/8/12/16/24/32). No arbitrary numbers.
- **Radius and elevation:** One radius scale (cards, buttons, inputs, sheets) and one elevation scale (cards restrained, dialogs/modals elevated, no heavy shadows on every element). Cards: consistent padding, one border or one soft shadow — never both heavily.
- **Icons:** One icon set, one size per context (app bar, list, button). Icons always have a text label or tooltip where meaning is not obvious.

### 7.2 Every screen must handle four states (no exceptions)
1. **Loading:** Skeleton/shimmer matching the final layout. Never a blank screen, never a bare spinner floating on white.
2. **Empty:** Illustration or icon + one plain-language sentence explaining why it is empty + the ONE action that fixes it (for example, "No students yet — Add first student"). Never an empty list with no explanation.
3. **Error:** Plain-language message stating what went wrong + a Retry button. Never a raw exception, stack trace, or technical code.
4. **Offline:** If cached data exists, show it with a clear "Offline — showing saved data" indicator. If not, show the error state with retry. Never a crash or an infinite loader.

### 7.3 Interaction and readability rules
- **Touch targets:** Minimum 48dp for every tappable element (buttons, list rows, icons, checkboxes).
- **Contrast:** Body text at least 4.5:1 against its background. Never light-grey text on white for anything the user must read.
- **Text scaling:** Layouts must not break when the user increases system font size. No fixed-height text containers that clip.
- **One primary action per screen.** The main action is visually dominant; secondary actions are quiet. Never two competing primary buttons.
- **Hierarchy:** Title > content > secondary/meta, on every screen, without exception. The most important number or action is the largest and highest-contrast element.
- **Forms:** Labels above inputs (never placeholder-only), inline validation with plain-language errors, keyboard-safe (no field hidden behind the keyboard), and a visible submit state (disabled while submitting, success confirmation after).
- **Lists and tables:** Consistent row height, aligned columns, numbers right-aligned, currency in Indian format with ₹, dates as DD-MMM-YYYY. Long lists paginate or lazily load — never freeze on thousands of rows.
- **Motion:** 200–300ms transitions, purposeful only (screen change, expand/collapse, success feedback). No gratuitous animation, no animation that delays a task.
- **Responsive:** Every school screen must work at phone width, tablet width, and desktop width. No horizontal overflow, no clipped text, no unreachable buttons at any width. Admin dashboards may use wider layouts on desktop but must degrade gracefully to tablet/phone.

### 7.4 Visual QA checklist (apply to every screen in Step 13, and to every screen you touch in earlier steps)
- [ ] Alignment: all elements sit on the 8pt grid; nothing is 1–2px off from its neighbours.
- [ ] Consistency: this screen's cards, buttons, app bar, and empty/error states match the rest of the app exactly.
- [ ] Hierarchy: the eye lands on the most important element first.
- [ ] No overflow: no clipped text, no cut-off buttons, no horizontal scroll on phone width.
- [ ] No placeholder content: no lorem ipsum, no "Test", no mock names in the final build.
- [ ] Real data rendering: numbers formatted, dates formatted, names complete (no "null" anywhere in the UI).
- [ ] States: loading, empty, error, and offline states all verified (see 7.2).
- [ ] Accessibility: contrast checked, touch targets checked, text scaling checked.
- [ ] One primary action, clearly dominant.
- [ ] The screen looks intentional — like a designer chose every spacing, colour, and size deliberately, not like defaults were accepted.

### 7.5 Definition of Done for UI (per screen)
A screen is UI-DONE only when: all 7.4 boxes are checked, the screen was opened at phone + tablet widths, all four states (7.2) were observed, and the result is recorded in `SCHOOL_PROGRESS.md` (Step 13 table). A screen that was "eyeballed once" is not UI-DONE.

---

## 8. SAFETY AND HYGIENE RULES

1. **Never break college.** See Section 2, rule 1, and Step 3. If a shared-core change is needed, prove college still works before and after.
2. **Never edit college tables.** School code queries `school_*` tables (plus `parent_student_links`, `institutes`, and `users.institute_type` reads) only.
3. **Never commit secrets.** `.env` stays gitignored. If you find a secret committed anywhere, stop and report it to the human — do not "fix" it by pushing a deletion (history still contains it; the human must rotate it).
4. **Never delete data.** No `DELETE` without a documented reason, an approval in the progress file, and a backup/export first. Prefer status changes and archiving.
5. **Never invent client facts.** School name, board, classes, hostel/infirmary/GPS/payroll scope, and UDISE+ format come from Step 1 (human-confirmed or explicitly defaulted). If a fact is missing, record it as an assumption in the progress file and choose the safest default.
6. **Never claim a verification you did not run.** "Tested OK" without the command output or test result is not evidence. Record outputs.
7. **Never rewrite history.** No force-push, no rebase of shared branches. Append commits only.
8. **Never leave a step half-verified.** A step is DONE only with its verification evidence in the progress file.

---

## APPENDIX A — REPO MAP (Verified on `origin/main`, 3 Nov 2026)

- App entry: `lib/main.dart` → `lib/routes/app_router.dart` (GoRouter) → splash → login → role/institute dashboard.
- Shared core: `lib/core/theme/app_theme.dart`, `lib/core/widgets/`, `lib/core/config/`, `lib/core/security/`, `lib/core/utils/`.
- Shared services: `lib/services/` (see Section 3.3 for the full list; school logic goes through `lib/services/school_service.dart`).
- College features: `lib/features/` — `admin/`, `admission/`, `auth/`, `dashboard/`, `examination/`, `fees/`, `finance/`, `hod/`, `hostel/`, `hr/`, `leads/`, `leave/`, `notices/`, `splash/`, `student/`, `teacher/`, `timetable/`, `transport/` (+ `lib/debug/`).
- School features: `lib/features/school/` — `admissions/`, `attendance/`, `certificates/`, `circulars/`, `fee/`, `homework/`, `library/`, `marks/`, `parent/`, `reports/`, `timetable/`, `transport/`, plus `school_admin_dashboard.dart`, `school_student_dashboard.dart`, `school_teacher_dashboard.dart`.
- School routes (`/school/*`): `student-dashboard`, `teacher-dashboard`, `admin-dashboard`, `parent-dashboard`, `homework`, `homework/upload`, `attendance`, `marks-entry`, `report-card`, `timetable`, `circulars`, `transport`, `fees`, `admissions`, `reports`, `library`, `certificates`.
- School SQL: `database/dual_mode_school_setup.sql` (tables listed in Section 3.1). College SQL: `run karwade/01–08` (already applied to the live college project; do not re-apply blindly).
- Existing repo docs (reference only; do not confuse with this README): `README.md` (college app readme), `COMPLETE_ERP_IMPLEMENTATION_PLAN.md`, `CHECKLIST.md`, and the many `*_SUMMARY.md` / `*_COMPLETE.md` notes from earlier work. This execution README is a separate file, delivered alongside the school spec, and is the only document that governs this plan's execution.

## APPENDIX B — SCHOOL SERVICE METHOD INDEX (Extend, Don't Duplicate)

`lib/services/school_service.dart` already provides (see Section 3.1 for the full list): student details, classes, students by class, subjects, school stats, teacher details/timetable/classes, pending homework counts, attendance marking/reporting/summary/percentages, homework CRUD + stats, marks entry/reporting, fees (student fees, pending fees, record payment, fee reports, collection reports), circulars/notices CRUD, transport routes, student transport, admissions list/submit. When you need a new school query, add a method here (or in a clearly-named school service file following the same pattern) — never query Supabase directly from a screen for school data that belongs in this layer, and never call a college service for school data.

## APPENDIX C — DEMO ACCOUNTS AND TEST DATA

- Use the demo accounts shown on the login screen (school student, school teacher, school admin, and parent accounts) or test accounts you create. Never invent passwords; never share real user passwords.
- All end-to-end tests in Steps 4–11 use clearly-marked TEST data (test students, test fees, test routes). Record test IDs in `SCHOOL_PROGRESS.md` so test data can be identified and cleaned up before client handover. Test data must never be presented to the client as real data.
- Before client handover (after Step 14), confirm with the human whether test data should be deleted from the live project, and record the answer.

---
*End of Execution README v1.1 (v1.1 adds: Section 4.5 module coverage matrix, Step 15 production deployment, and explicit sub-items — lesson plans, LMS-lite, cafeteria, accounting scope, student leave). Start at Step 0. Do not skip steps. Do not skip checkpoints. If you must stop, write the HANDOFF block.*
