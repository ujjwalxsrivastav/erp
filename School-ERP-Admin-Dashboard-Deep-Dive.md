# School ERP — Admin (sadmin) Dashboard Deep-Dive (Enterprise Upgrade)

## Dashboard #2 — Admin / sadmin (Teacher ke baad, pehle Admin)

**Status:** Analysis document — isme koi code change nahi hai. Ye file Gemini ko di jayegi, Gemini isko line-by-line execute karega.
**Repo state (verified, analysis ke waqt):** `origin/main` = `7cce8af` — "Enterprise NEP 2020 Lesson Plan Studio". Local clone (`~/workspace/erp`, main `1652552`) stale hai, isliye analysis `origin/main` ke archive se ki gayi hai, local clone se nahi. Analysis ke baad repo mein koi change nahi kiya gaya hai.
**Scope lock:** Is document ka kaam SIRF admin (sadmin) dashboard aur admin se jude oversight tak hai. Teacher dashboard iska hissa nahi hai (Teacher Deep-Dive alag document hai, Dashboard #1 — poora ho chuka hai). Student aur Parent dashboards bhi is document mein nahi banenge — unka number Part F mein roadmap ke roop mein hai.
**Ye document Core Modules README ko replace nahi karta.** Admin / HR / Admission / Fees / Reports / Excel Import wala kaam (Core Modules README, Steps 1–8) alag track hai. **HR module is document mein dobara nahi banega** — school HR ka poora module (onboarding, directory, allotment, leave, exit) Core Modules README ka hissa hai. Is document mein HR sirf **admin oversight** tak hai (directory dekhna, leave approvals ka queue, allotment ka view) — aur jahan HR module abhi maujood nahi hai, wahan ye document sirf **link/placeholder** banayega, HR ka kaam nahi karega. Jahan dono overlap karte hain (Excel standard, Reports), wahan isi document mein Core Modules wala standard reuse hoga — doosra standard invent nahi hoga.
**Step 13.1 ka overhaul dobara nahi hoga.** Admin dashboard ka minimalist command-center redesign (Slate-50 canvas, Morning Pulse, approvals queue, 4-domain matrix, circular modal, UDISE+ sheet, grievance tool) Step 13.1 mein ho chuka hai aur `dart analyze` clean hai. Is document ka kaam us design ko **gehrana** hai — data sachha karna, analytics + Excel jodna, approvals poore karna — redesign nahi karna.

---

## 0. Kaise padhna hai (How to Read)

- **Part A — YE YE HAI:** Aaj admin dashboard mein kya-kya maujood hai, file aur route ke saath. Har cheez repo se verify ki gayi hai — koi feature "hai" nahi kaha gaya jab tak file mein nahi dikha.
- **Part B — KAMI KYUN HAI:** Enterprise feel kyun nahi aa raha — seedhi baat, saboot ke saath.
- **Part C — YE YE KARNE JA RAHA HUN:** Do hisse — **C1 NEW (extra)** aur **C2 MODIFY (isi mein badlav)**. Har feature mein likha hai: kya hai, kyun chahiye, kahan dikhega, data kahan se aayega, aur uska graph/Excel kya hoga.
- **Part D — Reports catalogue:** Admin ki har report — graph + Excel, dono ke saath. Koi report sirf list nahi hogi.
- **Part E — Gemini execution plan:** Steps, verification, checkpoint, hard rules.
- **Part F — Dashboard-by-dashboard roadmap:** Admin ke baad ka order.
- **VERIFY-FIRST ka matlab:** Execution ke waqt pehle file/table dhoondhni hai. Agar cheez pehle se maujood nikli to dobara nahi banani — sirf dashboard se link/queue banana hai. Agar nahi mili to hi nayi banani hai.

## 0.1 Non-negotiables (har step par laagu)

1. **College ERP kabhi nahi tootega.** Sirf `lib/features/school/` + `lib/services/school_service.dart` + `school_*` tables + nayi `school_*` tables chhoo sakte hain. College screens, college tables, college routes — zero touch. (`/admin/manage-users` college ka screen hai — usme koi badlav nahi, sirf us tak sahi link rahega.)
2. **Koi fake/mock/invented data nahi.** Koi number, list ya schedule haath se nahi likha jayega. Data na mile to empty state dikhega ("koi data nahi"), kabhi jhootha number nahi. Ye rule UDISE+ sheet par **khaas taur par** laagu hai — statutory data mein andaza bilkul nahi chalega.
3. **Har nayi table par RLS.** Bina RLS ke koi table live nahi jayegi. Admin poora school dekh sakta hai — par har action ka audit log banega (kisne, kab, kya kiya).
4. **Har step ke baad verification + commit + CHECKPOINT.** Bina verification ke agla step nahi. Har step ka commit message: `admin-dash: ADM<n> — <title>`.
5. **Deploy pipeline ka note:** 4 Nov 2026 ko GitHub Pages deploy 4 baar fail hua tha (workflow 'Deploy Flutter Web to GitHub Pages'). Isliye Gemini har step ke baad `flutter analyze` + `flutter build web` locally chalayega aur result CHECKPOINT mein likhega. Push karna Maalik ka faisla hai — Gemini khud push karke pipeline par nahi chhodega jab tak Maalik na kahe.
6. **Payroll is document ka hissa nahi hai** (Maalik ke faisle par pending hai — Core Modules mein bhi deferred hai).
7. **HR module is document mein nahi banega.** Admin oversight (directory view, leave queue, allotment view) is document mein hai; HR ka poora module Core Modules README mein hai.
8. **Fee ka paisa admin ka kaam hai, par maker-checker rule yahin se laagu hoga.** Refund, concession aur fee-head badlav jaise money actions par maker-checker (ek banaye, doosra approve kare) Core Modules ke hisaab se chalega — is document mein sirf un approvals ka queue dashboard par aayega.

## 0.2 Dashboard-by-dashboard roadmap (poori picture)

| # | Dashboard | Aaj ki haalat (verified) | Is deep-dive mein |
|---|---|---|---|
| 1 | **Teacher** (`/school/teacher-dashboard`) | Deep-dive poora ho chuka hai (Teacher Deep-Dive MD) — 14 NEW + 14 MODIFY + 14 reports | Ho gaya — Gemini execution pending |
| 2 | **Admin / sadmin** (`/school/admin-dashboard`) | Step 13.1 mein command-center overhaul ho chuka hai; data mein fallback numbers hain, analytics + Excel nahi hai, approvals adhoore hain | **YE DOCUMENT — poora deep-dive** |
| 3 | Parent (`/school/parent-dashboard`) | Multi-child switcher, live metrics, PTM booking, grievance tickets maujood hain (Step 10) | Baad mein — order Maalik ke next call par |
| 4 | Student (`/school/student-dashboard`) | Step 13.2 mein light-theme overhaul ho chuka hai (passport card, KPI tiles, schedule timeline) | Baad mein — order Maalik ke next call par |

## 0.3 Benchmark — tagde level ke school ERP mein principal/admin command center kaisa hota hai

Leading school ERPs (ScoolsPRO, ScholarERP, EduSaaS-class platforms) ke admin/principal dashboards mein ye cheezein **standard** hain — inhi se compare karke is document ki kami list bani hai:

- **Live institutional KPIs** — enrolment, attendance, fee collection, staff strength — har number ka source hota hai aur tap karne par detail khulti hai; koi number haath se nahi likha hota.
- **Unified approvals centre** — admissions, certificates, staff leave, fee concessions, lesson scrutiny — ek queue, har item par age (kitne din se pending hai) aur ek-tap approve/reject with notes.
- **Fee analytics** — collection trend, head-wise breakup, defaulter ageing buckets, month-close status — graph + Excel.
- **Statutory compliance centre** — UDISE+ / board reporting ke liye har field ka real source, missing-field checklist, aur ek-click Excel export. Compliance sheet mein andaze wale number kabhi nahi hote.
- **Staff oversight** — directory, allotment, leave balance, workload — principal ko har teacher ka load ek jagah dikhta hai.
- **Audit trail** — har sensitive action (approve, refund, certificate issue, data change) ka log: kisne, kab, kya kiya.
- **Alerts & safety** — transport incidents, attendance dips, fee default spikes — dashboard par signal, screen ke andar detail.

Inme se humare system mein screens aur modules **maujood** hain — par admin dashboard ka data fallback numbers se bhara hai, UDISE+ sheet andaze par chalti hai, approvals sirf 3 type ke hain, aur analytics, Excel, audit trail aur staff oversight **nahi** hain. Wahi gap is document mein bhara ja raha hai.

---

## Part A — YE YE HAI (Existing admin features, repo-verified)

### A1. Admin dashboard shell

- **File:** `lib/features/school/school_admin_dashboard.dart` (1,863 lines)
- **Route:** `/school/admin-dashboard` — `lib/routes/app_router.dart` mein plain `GoRoute` hai, **koi role guard nahi** (redirect/guard ke liye grep khaali aaya). Login switch hi ekmatra gate hai (A10 dekho).
- **Header (SliverAppBar):** Dark ink header — school naam, affiliation, session/term, "Principal / Institutional Admin: <username>", date, Refresh, UDISE+ button, Action button, aur floating "Quick Action" button. **Gap (pehle se note):** school naam `'Shivalik International School'`, affiliation `'CBSE #3530124'`, session `'2025-2026'`, term `'Term II'` — chaaron **haath se likhe constants** hain (Modify M3).
- **Layout order:** Attention Required strip → "Principal's Morning Pulse" header + Live Sync badge → 4 KPI tiles → 4-domain Command Matrix → Institutional Feed (circulars) → Quick Action sheet (FAB + Action button) → UDISE+ modal → Grievances modal → dark Drawer.
- **Loading state:** Sirf beech mein `CircularProgressIndicator` — koi skeleton nahi. **Error state: nahi hai** — `_loadData` ka `catch (_)` khaali hai, fail hone par dashboard chupchaap fallback numbers dikhata hai (Modify M10).
- **Admin ka naam:** `_adminName` default `'Principal'` hai, phir `getCurrentUsername()` se username set hota hai — **display name nahi** (teacher dashboard `getTeacherDisplayName` use karta hai; admin ke liye aisa koi method call nahi hai).

### A2. Morning Pulse — 4 KPI tiles (dikhte real hain, par fallback se bhare hain)

Data `Future.wait` se 6 service calls se aata hai: `getSchoolStats(null)`, `getPrincipalMorningBriefing()`, `getAdmissions()`, `getCirculars()`, `getDefaultersWithAgeing()`, `getParentComplaints()`. Har call par `.catchError` hai jo khaali result deta hai — phir har number par `??` fallback lagta hai:

| Tile | Real source (jab service chale) | Fallback (jab service fail ya khaali) | Haalat |
|---|---|---|---|
| Enrolled Students — total + `% Present Today` + `N Active Sections` | `school_students` count + aaj ki `school_attendance` se % | `450` students, `94.8%` attendance, `24` sections | **Fallback fake hai** |
| Faculty & Staff — total + `100% On-Duty` + `PTR: 18:1 (RTE Compliant)` | `users` table (role=teacher, institute_type=school) se count | `68` teachers; subtitle aur PTR **hamesha haath se likhe** hain | **Subtitle + PTR hamesha fake hain** |
| Fee Collections — total + pending + defaulters count | `school_fee_payments` se paid/pending ka yog | `₹45,00,000` collected, `₹2,80,000` pending | **Fallback fake hai** |
| Transport Fleet — routes + `100% Vehicles Active` + `0 Safety Incident Alerts` | `school_transport` rows ki ginti | `3` routes; subtitle aur incidents **hamesha haath se likhe** hain | **Subtitle + incidents hamesha fake hain** |

**Do-layer problem (sabse important):** Fallback sirf dashboard par nahi hai — `getPrincipalMorningBriefing()` ke andar bhi wahi numbers hain: attendance na mark hui ho to `94.8` hi return hota hai (`totalMarked > 0 ? ... : 94.8`), aur `catch` block poora fake briefing return karta hai (450 students, ₹45L, ₹2.8L, 3 buses, 1 complaint). Matlab service fail ho to dashboard ko pata hi nahi chalta ki data fake hai — do jagah fallback hai, dono hatane honge (Modify M1).
**Ek aur semantics gap:** `_feeCollectedToday` naam "aaj" kehta hai, par briefing `school_fee_payments` ki **poori lifetime** paid amount ka yog karti hai — aaj ka collection nahi. Tile par "Fee Collections" likha hai, isliye galat label nahi dikhta, par variable aur logic ka matlab galat hai (Modify M11).

### A3. Attention Required strip — approvals queue (sirf 3 type ke items)

- **Kya hai:** Agar pending admissions, defaulters ya open grievances hon to laal strip dikhti hai — "Action Required • Executive Approvals Queue" — har type ka ek chip (Admissions Under Review → Scrutinize, Fee Defaulters → Inspect, Parent Grievances Open → Review). Kuch na ho to hara "All Institutional Operations Nominal • 0 Pending Executive Approvals" strip.
- **Gap 1 — count ka hisaab galat hai:** Badge mein total `pendingAdmissions + (defaulters>0 ? 1 : 0) + complaints` joda jata hai — matlab 40 defaulters hon to bhi **1** gina jata hai. Count jhootha hai (Modify M5).
- **Gap 2 — queue adhoori hai:** Isme **nahi** aate — teacher leave requests, lesson plans pending scrutiny, certificate requests, transport safety mismatches, fee refund/concession approvals. Admin ko approvals ke liye 6 screens ghoomni padti hain (New N2).
- **Gap 3 — umar nahi dikhti:** Chip par ye nahi likha ki item kitne din se pending hai (SLA/age) — enterprise approvals mein ye basic hai (New N2).

### A4. Institutional Command Matrix — 4 domains (header kehta hai 13, modules 15 hain)

- **Kya hai:** 4 domain categories, har ek mein module list (title + ek line desc + icon + route + kabhi badge):
  - **Academic & Curriculum Operations (6):** Lesson Plan & 5E Studio (NEP 2020 badge), Timetable & Substitutions, Homework & Assignments, Examination Controller (Conduct Live badge), CBSE Holistic Report Card, Session Rollover & Promotion.
  - **Student Administration & Enrollment (4):** Admissions Management Hub (pending count badge), Daily Attendance Register, Certificates & No Dues, User & Role Access Control → `/admin/manage-users`.
  - **Finance, Fleet & Infrastructure (3):** Fee Accounts & Cashier Desk (defaulters count badge), Transport & GPS Fleet, Digital Library & Catalog.
  - **Statutory Compliance & Communications (2):** UDISE+ & Institutional Reports, Official Circulars & Broadcasts.
- **Gap 1 — gintee galat hai:** Header mein likha hai `'13 Operational Modules'`, par list mein **15** modules hain (6+4+3+2). Chhoti baat hai, par enterprise dashboard par galat gintee nahi chalti (Modify M6).
- **Gap 2 — module ki haalat nahi dikhti:** Har module sirf naam + desc hai — us module mein aaj kya pending hai (jaise kitne certificates pending hain, kitne transport mismatches hain) ye nahi dikhta. Sirf 2 modules par count badge hai (admissions, fees) — baaki par nahi (Modify M6).
- **Gap 3 — "User & Role Access Control" college screen par le jaata hai:** Route `/admin/manage-users` hai, jo college ka `ManageUsersScreen` hai (`initialInstitution` default `'school'`). Matlab sadmin users dekhne ke liye school context se bahar chala jaata hai — aur school ka koi staff directory screen maujood hi nahi hai (Fix Pack A ka HR gap — is document mein sirf oversight, N3 dekho).

### A5. Institutional Feed + Publish Circular modal

- **Kya hai:** Dashboard par recent 5 circulars ki feed (title, category, date, audience, urgent flag). "Publish" button se modal khulta hai: Title, Category (Academic/General/Events/Administrative), Audience (All/Parents/Teachers/Students), Content, Urgent checkbox → `createCircular()` se `school_circulars` mein save, phir `_loadData` refresh.
- **Gap 1 — audience class-wise nahi hai:** Audience sirf role-based hai (All/Parents/Teachers/Students) — kisi **ek class** ko circular nahi bheja ja sakta. Teacher Deep-Dive ke N4 (class announcements) ke liye yehi audience model extend karna hoga (New N13).
- **Gap 2 — author haath se likha hai:** Har circular par `'author': 'Principal Office'` fix likha jata hai — kisne publish kiya, ye record nahi hota (New N4 audit trail ke saath).
- **Gap 3 — circulars screen par teacher bhi publish kar sakta hai:** `circulars_screen.dart` mein `canPublish = role == 'admin' || role == 'teacher'` hai — teacher bhi sabko circular bhej sakta hai. Admin ke liye approval flow nahi hai (New N13 mein teacher-message approval queue).

### A6. UDISE+ Statutory Compliance Sheet (modal) — andaze par chalti hai

- **Kya hai:** AppBar ke UDISE+ button aur Quick Action se modal khulta hai: `generateUdisePlusReport()` se data, rows — UDISE School Code, Academic Year, PTR, Total Enrolment, Boys/Girls Split, RTE 25% Quota Seats, Sanitation & RO Water, Fire Safety NOC, Status Indicator — aur "Open Reports Hub" button.
- **Gap (sabse serious — statutory data mein andaza):** Service ke andar ye sab **haath se likha** hai: UDISE code `'05010100123'`, boys = total ka **52%** aur girls = **48%** (gender split invent kiya gaya hai — DB mein gender se count nahi hota), total enrolment fallback `450`, RTE quota seats `45`, RTE enrolled `38`, PTR `'18:1'`, sanitation `'Functional RO Water Filtration System Certified'`, toilets `'Compliant (8 Boys, 8 Girls, 2 CWSN accessible)'`, fire NOC `'Valid (Ref: UK-FS-2026/8911)'`, status `'COMPLIANT & STATUTORY READY'`. Modal mein bhi wahi fallbacks dobara lage hain (boys `234`, girls `216`, RTE `38/45`). Matlab aaj UDISE+ sheet **statutory document hone ka daava karke andaze wale numbers dikha rahi hai** (Modify M2).
- **Gap 2 — koi export nahi:** Modal se UDISE+ ka Excel/PDF export nahi hota — sirf "Open Reports Hub" button hai. Reports hub ke UDISE+ tab mein 38-field export hai, par dashboard modal se seedha export nahi hota (New N11).

### A7. Parent Grievances modal — resolve hota hai, par bina asal notes ke

- **Kya hai:** Grievances `school_circulars` table mein `category = 'ParentComplaint'` ke roop mein store hote hain (koi alag grievance table nahi hai). Modal mein open complaints ki list, har ek par "Resolve" button → `resolveParentComplaint(complaintId, resolutionNotes: 'Reviewed & Resolved by Principal')` — phir refresh.
- **Gap 1 — resolution notes haath se likhe hain:** Har resolve par wahi ek line `'Reviewed & Resolved by Principal'` save hoti hai — admin asal mein kya kiya, ye likh hi nahi sakta (Modify M4).
- **Gap 2 — na category, na SLA, na parent ko jawab:** Complaint ki category, kab aayi, kitne din se khuli hai, aur parent ko kya jawab gaya — kuch nahi dikhta (New N10).
- **Gap 3 — sirf "open" dikhte hain:** Resolved complaints ka history dashboard se nahi dikhta (New N10).

### A8. Quick Action sheet (FAB + Action button) — 7 actions

Scrutinize NEP 2020 Lesson Plans → `/school/lesson-plans`; Conduct/Schedule Examination → `/school/examination`; Publish Official Circular → publish modal; Record Counter Fee Payment → `/school/fees`; Scrutinize Pending Admissions → `/school/admissions`; Issue Transfer/Bonafide Certificate → `/school/certificates`; Inspect Statutory UDISE+ Sheet → UDISE modal. **Gap:** Isme **staff leave approve, teacher allotment, session rollover, reports export, settings** — koi entry nahi hai (Modify M6 ke saath parity).

### A9. Drawer — 4 categories, 15 entries + Command Center

ACADEMICS & CURRICULUM (Lesson Plans, Examination, Timetable, Homework, Report Cards, Promotion), STUDENT ADMINISTRATION (Admissions, Attendance, Certificates, Staff & User Management → `/admin/manage-users`), FINANCE & OPERATIONS (Fees, Transport, Library), GOVERNANCE & STATUTORY (Reports Hub & UDISE+, Circulars), Sign Out. **Gap:** Drawer mein **koi Settings entry nahi hai** (koi institute settings screen maujood hi nahi hai — New N5), aur **koi HR/Staff entry nahi hai** (school staff screen maujood nahi hai — N3 boundary note).

### A10. Login routing + sadmin (verified — Fix Pack F1 ka hissa)

- **File:** `lib/features/auth/login_screen.dart` (~line 72–93): `institute_type` `users` row se aata hai, missing ho to default `'college'` hai. `institute_type == 'school'` ho to role switch: student → `/school/student-dashboard`, teacher → `/school/teacher-dashboard`, admin → `/school/admin-dashboard`, parent → `/school/parent-dashboard`, **default → `/school/admin-dashboard`**.
- **'sadmin' ka koi case nahi hai.** Matlab sadmin1 ka role agar `'sadmin'` hai to default case se admin dashboard par pahunchta hai; agar role `'admin'` hai to case se pahunchta hai. Dono haalat mein shart sirf ek hai — live `users` row mein `institute_type = 'school'` hona chahiye, nahi to college dashboard par chala jayega. Ye live row ki jaanch Fix Pack A (F0/F1) ka kaam hai — is document ka ADM0 usi ko gate banata hai (Part E).
- **Demo login:** Login screen par 'School Admin' demo credential `sadmin1` dikhta hai (line ~370).

### A11. Module oversight (admin kya-kya control karta hai — screens skim ki gayi hain)

| Module | Screen (lines) | Admin ko kya milta hai |
|---|---|---|
| Admissions | `admissions_screen.dart` (1,971) | 5 tabs: Pipeline, New Intake Form, Document Scrutiny, Entrance & Interaction, Prospect Leads. Pipeline metrics: Total, Under Scrutiny, Interaction/Test, Offer Letters, Enrolled. RTE/Sibling tags, KYC status, test score, dossier view. **Gap:** '38/45 RTE Seats Filled' metric haath se likha hai (Modify M12). |
| Fees | `school_fee_screen.dart` (2,032) | 5 tabs: Fee Heads & Policy (admin create/edit/delete fee heads), Student Accounts, Defaulters & Ageing, Academic Schedule Apr–Mar (5th due date, ₹100 auto late fine), Receipts & History. Counter payment + PDF receipt. |
| Reports Hub | `reports_screen.dart` (2,687) | Tabs: Morning Briefing, Fees (admin-only), Marks & Merit, Homework, UDISE+ (38-field export). Exports: Attendance PDF/CSV, Pending Fees PDF/CSV, Class Results PDF/CSV — **koi .xlsx nahi**. |
| Certificates | `school_certificates_screen.dart` (1,053) | Requests & Status + Apply tabs; No-Dues pre-checks (Library/Finance/Transport), serial + QR, Principal signature. |
| Circulars | `circulars_screen.dart` (499) | List + publish (admin ya teacher); category chips; loading/error/empty states. |
| Promotion | `school_promotion_screen.dart` (811) | Register & Changeover (candidates, promoted/detained/awaited counts — real) + Session Archives; Principal authorization seal. |
| Transport | `transport_screen.dart` (1,433) | Trip Attendance (shift toggle, route/stop, KPI ribbon), Safety Mismatches, Routes & Fleet Master. |
| Library | `school_library_screen.dart` (1,144) | Books + Issued + Overdue tabs; issue/return; **Gap:** table khaali ho to `_defaultIssued` naam ki haath se likhi list dikhti hai (Oct 2026 ki dates ke saath) — ek aur fallback (Modify M1). |
| Examination | `school_examination_screen.dart` (1,879) | 5 tabs: Sessions, Date Sheet, Admit Cards, Halls & Seating, Marks & Results; session metrics (total/ongoing/scheduled/results published). |
| Timetable | `school_timetable_screen.dart` (1,787) | Week view, substitution coverage desk, syllabus tracker. |

### A12. Admin ke liye maujood service methods (`lib/services/school_service.dart`, ~6,900 lines)

`getSchoolStats`, `getPrincipalMorningBriefing`, `generateUdisePlusReport`, `getAdmissions`, `getCirculars`, `createCircular`, `getDefaultersWithAgeing`, `getParentComplaints`, `resolveParentComplaint`, `getTransportRoutes`, `getSchoolClasses` (fallback 6-A…12-A — neeche A13), `getTeacherNames`, `getTeacherDailyLoad`, `getSubstitutionLogs`. **Maujood nahi hain (grep se verify kiya — koi method nahi mila):** `getStaffList`, `getTeacherLeaves`, `getPendingCertificateRequests`, `getAuditLog`, `getSessionInfo` — matlab staff list, teacher leave approvals, certificate queue aur audit trail ke liye **koi service method hi nahi hai**.

### A13. Tables + data-integrity notes

Maujood tables: `school_students`, `school_teachers`, `school_classes`, `school_subjects`, `school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_exam_sessions`, `school_report_card_meta`, `school_student_leaves`, `school_admissions`, `school_fee_accounts`, `school_fee_items`, `school_fee_payments`, `school_fee_receipts`, `school_circulars`, `school_certificate_requests`, `school_library`, `school_library_issues`, `school_timetable`, `school_transport`, `institutes`, `parent_student_links`.
**Do data-integrity baatein (service code mein comment ke saath likhi hain):** (a) `getSchoolClasses` mein fallback list `Class 6-A … Class 12-Science` (ids `cls-6a` … `cls-12a`) return hoti hai jab `school_classes` table khaali ho ya query fail ho — Fix Pack A (F6) mein ye purge hona hai, is document mein ADM1 usi ko pakadta hai. (b) Class identity mili-juli hai — `school_classes` mein UUID ids aur `name = 'Class 10'` (section NULL), jabki students/timetable/attendance mein `class_id = 'cls-10a'` / `class_name = 'Class 10-A'` — isliye service mein alias-matching logic hai. Admin ka class master (New N5 ke saath) isi ko saaf karega.

---

## Part B — KAMI KYUN HAI (enterprise feel kyun nahi aa raha)

Seedhi baat — Step 13.1 ne dashboard ko **dikhe mein** enterprise bana diya hai, par **data aur kaam** abhi bhi demo-level hain:

1. **Sabse bada kaaran — do-layer jhootha data.** Dashboard ke KPI par fallback numbers hain (450 students, 68 teachers, ₹45L, 94.8%), aur unke peeche service mein bhi wahi fallback hain — briefing fail ho to bhi wahi numbers aate hain. Jis dashboard ka pehla number hi andaze par ho, us par principal bharosa nahi karega. Enterprise system mein number ka source hota hai, aur data na mile to "data nahi mila" likha hota hai — jhootha number nahi.
2. **UDISE+ sheet andaze par chalti hai.** Statutory document mein boys 52% / girls 48% invent kiya gaya hai, RTE seats, NOC, sanitation — sab haath se likha hai. Board/audit ke saamne aisi sheet pesh nahi ki ja sakti. Ye is document ki sabse serious kami hai.
3. **Koi chart nahi.** `fl_chart` dependency maujood hai, par school vertical mein ek bhi chart render nahi hota. Fee collection ka trend, admission funnel, attendance trend — sab sirf number ya list hai.
4. **Koi Excel nahi.** `excel` package maujood hai, par school mein ek bhi `.xlsx` export nahi banta. Reports hub mein PDF/CSV hai — par principal ko board, audit aur apne record ke liye Excel chahiye hota hai.
5. **Approvals sirf 3 type ke hain.** Admissions, defaulters, grievances — iske alawa teacher leave, lesson scrutiny, certificates, transport incidents, fee refunds — koi queue nahi. Aur jo 3 hain, unme bhi count ka hisaab galat hai (40 defaulters = 1 item).
6. **Staff oversight nahi hai.** School ka koi staff directory nahi hai, teacher leave approvals dashboard par nahi aate, allotment ka view nahi hai — aur "Staff & User Management" dabane par sadmin college ke users screen par chala jaata hai.
7. **Institute ki settings hi nahi hain.** School ka naam, affiliation, session, term, UDISE code, RTE quota — sab code mein constants hain. Admin inhe badal hi nahi sakta.
8. **Grievance resolve karna dikhawa hai.** Resolve dabane par har baar wahi ek line save hoti hai — asal mein kya kiya, ye likhne ki jagah hi nahi hai. Parent ko jawab bhi nahi jaata.
9. **Audit trail nahi hai.** Kisne admission approve kiya, kisne certificate issue kiya, kisne fee refund kiya — iska koi log nahi hai. Enterprise system mein har sensitive action ka hisaab hota hai.
10. **Route guard nahi hai.** `/school/admin-dashboard` seedha khul jata hai — router mein koi role check nahi hai. Login switch hi ekmatra gate hai, aur usme 'sadmin' ka case hi nahi hai.
11. **Dashboard par exam, transport safety aur library ki koi khabar nahi.** Examination screen mein session metrics hain, transport mein safety mismatches hain, library mein overdue hain — par dashboard par inka koi signal nahi aata. Principal ko ye jaanne ke liye har screen kholni padti hai.
12. **Chhoti galtiyan bharosa todti hain.** Header kehta hai '13 Operational Modules' jabki list mein 15 hain; fee tile ka variable kehta hai "aaj ka collection" jabki number poori lifetime ka hai; library khaali ho to Oct 2026 ki haath se likhi issued-books list dikhti hai. Ye teeno chhoti cheezein milkar system ko "demo" jaisa feel deti hain.

---

## Part C — YE YE KARNE JA RAHA HUN

### C1. NEW (extra) features — pehle nahi the, ab banenge

Har feature mein: **kya hai / kyun / kahan dikhega / data kahan se / graph-Excel**.

#### N1. Admin Analytics section (dashboard par charts)

- **Kya hai:** Morning Pulse ke neeche ek naya "School Analytics" section — 4 charts: (a) enrolment trend — session mein mahine-wise students (line chart); (b) fee collection vs dues — mahine-wise collected vs pending (grouped bar chart); (c) attendance trend — poore school ki din-wise % pichhle 30 din (line chart); (d) admission funnel — enquiry → application → scrutiny → interaction → offer → enrolled (funnel/bar chart). Har chart par tap → uski poori report (Part D).
- **Kyun:** Yehi wo cheez hai jo command center ko "enterprise" banati hai — principal ko ek nazar mein pata chale ki school kidhar ja raha hai, bina 5 screens ghoome.
- **Kahan dikhega:** Dashboard par KPI grid ke neeche, Command Matrix se pehle.
- **Data kahan se:** `school_students`, `school_fee_payments`, `school_attendance`, `school_admissions` — sab maujood. Aggregation `school_service.dart` mein naye methods se hogi (ek method per chart, testable).
- **Graph/Excel:** Charts `fl_chart` se (school mein pehla asli use — teacher dashboard ke saath share hoga). Har chart ke saath **Excel export** button (Part D: AD-R01, AD-R02, AD-R03, AD-R05).

#### N2. Unified Approvals Centre — ek queue, saare approvals

- **Kya hai:** Dashboard par ek "Approvals Centre" — ek hi queue mein saare pending approvals: admissions under review, certificate requests, teacher leave requests, lesson plans pending scrutiny, fee refund/concession requests (maker-checker ke hisaab se), transport safety mismatches. Har item par: type, naam, kab se pending hai (age — jaise "3 din se pending"), aur ek-tap approve/reject **asal notes ke saath** (notes likhna mandatory hoga reject par, optional approve par).
- **Kyun:** Aaj approvals 3 type ke hain aur 6 screens mein bante hue hain. Enterprise admin ka kaam hi approvals hain — unka ek centre hona chahiye, warna cheezein atak jaati hain aur pata bhi nahi chalta.
- **Kahan dikhega:** Attention strip ki jagah — strip ko is centre mein upgrade karna hai (top pending 5 + "View all" → approvals screen). Drawer mein "Approvals Centre" entry.
- **Data kahan se:** `school_admissions`, `school_certificate_requests`, `school_student_leaves` (student leave — class teacher approve karta hai, par admin ko oversight chahiye), teacher leave + lesson scrutiny + fee refunds — **VERIFY-FIRST:** inke tables/methods dhoondhne hain (teacher leave ka flow Core Modules HR se aayega; scrutiny lesson plan screen mein hai; refund/concession fee screen mein hai). Jiska source na mile, uska queue item us step mein **nahi** banega — CHECKPOINT mein "pending on <source>" likhna hai, invent nahi karna.
- **Graph/Excel:** Approvals ageing report — bar chart (pending days buckets) + Excel (AD-R13).

#### N3. Staff oversight (directory + allotment view + leave queue) — LINK ONLY, HR dobara nahi

- **Kya hai:** Admin ke liye staff ka ek oversight view: (a) staff directory — naam, role, subjects, classes (read-only list + search); (b) class/subject allotment ka view — kis teacher ko kaunsi class/subject mili hai; (c) teacher leave requests ka queue (approve/reject — Core Modules HR ke rules se); (d) teacher workload — hafte ke periods per teacher (bar chart).
- **Kyun:** Aaj admin ko ye jaanne ke liye college ke users screen par jaana padta hai, aur wahan bhi allotment/leave nahi dikhta. Principal ko apne staff ka poora picture ek jagah chahiye.
- **Kahan dikhega:** Command Matrix mein "Staff & User Management" tile ke andar — pehle directory + allotment view, phir HR module banne par uska link. Drawer entry wahi rahegi.
- **Data kahan se — BOUNDARY RULE:** **HR module is document mein nahi banega.** Directory ka data `users` (role=teacher, institute_type=school) + `school_teachers` se aayega (dono maujood hain). Allotment ka data timetable/lesson tables se (VERIFY-FIRST). Leave approvals aur onboarding/exit **Core Modules HR** ka kaam hai — is document mein unke liye sirf **placeholder link** banega ("HR module — Core Modules track mein ban raha hai") — koi leave form, koi onboarding flow is document mein nahi banega.
- **Graph/Excel:** Staff load report — bar chart + Excel (AD-R07); directory ka Excel export (AD-R07 family).

#### N4. Audit trail / activity log (kisne, kab, kya kiya)

- **Kya hai:** Har sensitive action ka log: admission approve/reject, certificate issue, fee refund/concession, circular publish, grievance resolve, UDISE+ export, settings change, user role change. Har entry: kaun (username), kab (timestamp), kya (action + record id + pehle/ baad ka value jahan laagu ho). Admin log ko filter kar sake (action type, user, date range) aur Excel mein nikaal sake.
- **Kyun:** Bina audit trail ke enterprise system nahi hota — dispute ho, audit ho ya galti ho, to "kisne kiya tha" ka jawab hona chahiye. Aaj iska koi record nahi hai.
- **Kahan dikhega:** Dashboard par "Recent Activity" ki chhoti list (aakhri 10 actions) + drawer mein "Audit Trail" entry → poora log screen.
- **Data kahan se:** **Nayi table** `school_audit_log` (id, actor_username, action, entity_type, entity_id, old_value, new_value, created_at) + RLS (sirf admin padh sake; likhna sirf service layer se). Har money/approval action ke step mein log likhna **mandatory** hoga — alag se bada system nahi, har feature ke andar ek line.
- **Graph/Excel:** Activity report — list + Excel (AD-R14). Graph nahi — log ki report nahi hoti.

#### N5. Institute settings (school profile + session + masters)

- **Kya hai:** Admin ke liye settings screen: (a) school profile — naam, affiliation no/board, UDISE code, address, contact; (b) academic session — current session, term, session start/end dates; (c) RTE quota — total seats, enrolled (real count se); (d) statutory records — fire NOC (number + expiry date), sanitation certificate (status + expiry) — **dates ke saath, taaki expiry se pehle alert aaye**; (e) class master — classes/sections ki list (school_classes se, deactivation rule ke saath — students hon to block).
- **Kyun:** Aaj ye sab code mein constants hain — admin inhe badal hi nahi sakta. Multi-institute system mein har school ki apni profile honi chahiye, aur UDISE+ sheet ko yahin se apna data lena chahiye (Modify M2/M3 ka doosra hissa).
- **Kahan dikhega:** Drawer mein "Institute Settings" entry + dashboard header ke paas settings icon. Settings change par **audit log** (N4) banega aur purana value bhi record hoga.
- **Data kahan se:** `institutes` table maujood hai — pehle dekho usme kya columns hain (VERIFY-FIRST). Jo field na ho (jaise NOC expiry, RTE seats) uske liye **nayi table** `school_settings` (key-value ya structured row, institute_id ke saath) + RLS (sirf admin likh sake). Class master `school_classes` se — **nayi table nahi**; class identity wali gadbad (UUID vs `cls-10a`) ko yahin saaf karna hai — har class ka ek hi canonical id hoga, alias mapping service mein rahega.
- **Graph/Excel:** Settings ki report nahi hoti. Par NOC expiry alerts dashboard par aayenge (N14).

#### N6. Fee analytics (collection, heads, defaulters, month close)

- **Kya hai:** Admin ke liye fee ka analytics section: (a) collection trend — mahine-wise collected vs pending (bar chart); (b) head-wise breakup — kaunse fee head se kitna aaya (donut chart); (c) defaulters ageing — 0–30 / 31–60 / 61–90 / 90+ din ke buckets (bar chart, `getDefaultersWithAgeing` se); (d) month-close status — kaunsa mahina close hua, kaunsa khula hai (Core Modules ke month-close rule se).
- **Kyun:** Aaj admin ko sirf do numbers dikhte hain (collected/pending) — trend, head aur ageing ke liye fee screen ke andar jaana padta hai, aur wahan bhi chart nahi hai. Principal ko fee ki sehat ek nazar mein chahiye.
- **Kahan dikhega:** Dashboard par analytics section ke andar (N1 ke saath) + fee screen ke upar summary strip.
- **Data kahan se:** `school_fee_payments`, `school_fee_items`, `school_fee_receipts` — sab maujood. Month-close ka status Core Modules ke D8 rule se aayega (VERIFY-FIRST: month-close table/flag maujood hai ya nahi — na ho to is document mein sirf status display banega, close ka flow Core Modules mein rahega).
- **Graph/Excel:** Charts `fl_chart` se; har view ka **Excel export** (AD-R02, AD-R03, AD-R04).

#### N7. Admission funnel analytics

- **Kya hai:** Admission pipeline ka funnel: enquiries → applications → scrutiny → interaction/test → offer → fee confirm → enrolled — har stage par count aur conversion % (bar/funnel chart). Saath mein RTE quota ka real fill (kitni seats, kitni bhari — DB se) aur source-wise breakup (VERIFY-FIRST: enquiry source field maujood hai ya nahi — na ho to source breakup is feature mein nahi banega).
- **Kyun:** Aaj pipeline metrics sirf admissions screen ke andar hain, aur RTE fill haath se likha hai ('38/45'). Principal ko funnel ek nazar mein chahiye — kahan drop ho raha hai, ye pata chalna chahiye.
- **Kahan dikhega:** Dashboard par analytics section ke andar + admissions screen ke upar funnel strip.
- **Data kahan se:** `school_admissions` — maujood. RTE seats `school_settings` (N5) se aayengi.
- **Graph/Excel:** Funnel/bar chart + Excel (AD-R05).

#### N8. Exam oversight widget

- **Kya hai:** Dashboard par ek chhota widget: ongoing exams (kitne chal rahe hain), agla exam kitne din mein, results published kitne, date sheet pending kitni classes ki. Har item par tap → examination screen ka sahi tab.
- **Kyun:** Examination screen mein ye stats maujood hain, par dashboard par inka koi signal nahi hai. Exam season mein principal ko ye sabse pehle chahiye hota hai.
- **Kahan dikhega:** Dashboard par schedule/feed ke paas ek slim widget.
- **Data kahan se:** `school_exam_sessions` + examination screen ke wahi methods — **nayi table nahi**, sirf dashboard surface.
- **Graph/Excel:** Exam results report — bar chart (class-wise pass %) + Excel (AD-R06).

#### N9. Transport safety command

- **Kya hai:** Dashboard par transport ka live card: aaj kitne routes chale, kitne students board hue, **safety mismatches kitne khule hain** (transport screen ka mismatches tab), aur koi incident alert ho to laal highlight. Mismatch par tap → transport screen ka safety tab.
- **Kyun:** Aaj dashboard tile kehta hai '0 Safety Incident Alerts' — haath se likha hai — jabki transport screen mein mismatches ka poora tab hai. Safety par jhootha "0" dikhana galat hai.
- **Kahan dikhega:** KPI grid mein Transport tile ke andar (Modify ke saath) + dashboard par alerts section (N14 ke saath).
- **Data kahan se:** `school_transport` + transport screen ke mismatch methods — maujood. **Nayi table nahi.**
- **Graph/Excel:** Transport report — route-wise boarding + mismatches, bar chart + Excel (AD-R08).

#### N10. Grievance centre (poora workflow, sirf modal nahi)

- **Kya hai:** Grievances ka poora centre: (a) poori list — open + resolved history, category (fee/academic/transport/behaviour/other — VERIFY-FIRST: category field maujood hai ya nahi), aane ki date, **kitne din se khuli hai (age)**; (b) resolve karte waqt **asal resolution notes likhna mandatory** hoga (wahi notes parent ko dikhenge); (c) parent ko jawab/status update ka flow (parent dashboard par status dikhega — parent side ka display Parent deep-dive mein aayega); (d) SLA — jaise 7 din se zyada khuli complaint laal highlight.
- **Kyun:** Aaj grievance "resolve" dabane par wahi ek line save hoti hai aur history gayab ho jaati hai. Enterprise system mein complaint ka poora lifecycle hota hai.
- **Kahan dikhega:** Attention strip / Approvals Centre (N2) se link + drawer mein "Grievances" entry → poora screen (modal se upgrade).
- **Data kahan se:** `school_circulars` (category='ParentComplaint') — maujood hai, **nayi table nahi** (pehle isi ko theek se use karna hai). Resolution notes ka column VERIFY-FIRST — na ho to migration ke saath add karna hai. Category aur SLA rule Maalik se confirm karke CHECKPOINT mein likhna hai.
- **Graph/Excel:** Grievance report — category-wise + ageing, bar chart + Excel (AD-R11).

#### N11. UDISE+ compliance centre (real data, missing-field checklist, Excel)

- **Kya hai:** UDISE+ ka alag centre: (a) har field ka **real source** dikhega — enrolment `school_students` se, gender split DB se (invent nahi hoga), PTR real teacher/student count se, RTE seats `school_settings` (N5) se, NOC/sanitation settings se dates ke saath; (b) **missing-field checklist** — jo field ka data nahi hai, wo laal "Missing" ke saath dikhega, andaze se bhara nahi jayega; (c) **38-field UDISE+ Excel export** ek click par (Summary + Data sheets, Core Modules Excel standard); (d) compliance status tabhi "COMPLIANT" dikhega jab saare required fields real data se bhare hon — nahi to "INCOMPLETE — N fields missing".
- **Kyun:** Aaj UDISE+ sheet andaze par chalti hai aur "COMPLIANT & STATUTORY READY" ka daava karti hai. Ye galat hai aur audit mein pakda jayega. Compliance centre ka kaam hi ye hai ki jo nahi pata, wo "nahi pata" kahe.
- **Kahan dikhega:** UDISE+ modal ko is centre mein upgrade karna hai (modal se poora screen) + Reports Hub ke UDISE+ tab se link.
- **Data kahan se:** `school_students` (gender column VERIFY-FIRST — na ho to gender split "Not recorded" dikhega, invent nahi hoga), `school_teachers`/`users`, `school_settings` (N5), `generateUdisePlusReport` ko dobara likhna hoga (Modify M2).
- **Graph/Excel:** UDISE+ 38-field Excel export (AD-R10) + compliance completeness donut (kitne % fields real hain).

#### N12. Global search (student / staff / parent / admission — ek jagah)

- **Kya hai:** Dashboard ke upar search box — naam se student, staff, parent ya admission application dhoondho. Result par tap → sahi screen (student profile, staff view, admission dossier). Search sirf isi school tak limited rahega.
- **Kyun:** Admin ko kisi student/staff ko dhoondhne ke liye uski screen kholni padti hai. Enterprise command center mein search sabse pehle hota hai.
- **Kahan dikhega:** Dashboard header ke neeche slim search bar.
- **Data kahan se:** `school_students`, `users` (teacher/admin/parent, institute_type=school), `school_admissions` — sab maujood. **Nayi table nahi.**
- **Graph/Excel:** Nahi — search ki report nahi hoti.

#### N13. Broadcast centre (circulars history + class audience + teacher-message approvals)

- **Kya hai:** Circulars ka poora centre: (a) sent history — kisne, kab, kis audience ko, urgent ya nahi; (b) **class-wise audience** — circular kisi ek class ya kuch classes ko bhi bheja ja sake (audience model ka extension: All/Parents/Teachers/Students + class select); (c) **teacher-message approval queue** — Teacher Deep-Dive ke N4 ke hisaab se, agar teacher ke messages par admin approval ka rule hai to wo queue yahin dikhegi (rule Maalik se confirm karna hai — default: teacher seedha bhej sake, approval off; Maalik haan kahe to queue on hogi); (d) circular edit/withdraw (galti se bheja gaya notice wapas lena).
- **Kyun:** Aaj circulars sirf bhej sakte hain — history, class targeting aur approval ka koi flow nahi hai. Broadcast enterprise communication ka core hai.
- **Kahan dikhega:** Dashboard feed section ko is centre se link karna hai + drawer mein "Circulars & Broadcasts" entry (pehle se hai — usi ko upgrade karna hai).
- **Data kahan se:** `school_circulars` — maujood. Class audience ke liye audience column ka extension (VERIFY-FIRST: column ka type kya hai) ya nayi mapping table `school_circular_audience` (circular_id, class_id) + RLS — execution mein pehle column dekho, phir faisla karo.
- **Graph/Excel:** Broadcast report — audience-wise sends, list + Excel (AD-R12).

#### N14. Alerts & notifications (admin ka inbox)

- **Kya hai:** Dashboard par bell icon + inbox: nayi admission aayi, grievance aayi, transport mismatch, teacher leave request, lesson plan scrutiny pending, NOC expiry nazdeek (N5 dates se), fee defaulter spike, exam results published. Har notification par tap → sahi screen. Read/unread state.
- **Kyun:** Admin ko har cheez ke liye alag screen check nahi karni chahiye — alerts ek jagah aane chahiye. Ye enterprise feel ka chhota par bada hissa hai.
- **Kahan dikhega:** AppBar mein bell icon + inbox screen (drawer mein "Notifications" entry).
- **Data kahan se — VERIFY-FIRST:** Pehle dekho ki notifications ka koi system pehle se hai ya nahi (Teacher Deep-Dive ke N14 mein `school_notifications` table propose hui hai — **agar teacher ka kaam pehle ho gaya to wahi table reuse hogi**, dobara nahi banegi; agar nahi bani to is document mein banegi). Events ko notification banane ka kaam har feature ke step mein jodna hai.
- **Graph/Excel:** Nahi — inbox ki report nahi hoti.

---

### C2. MODIFY — isi mein badlav (pehle se hai, par adhoora/galat hai)

#### M1. Real-data purge — fallback numbers hatana (sabse pehla fix, do layer)

- **Aaj:** Dashboard par `?? 450 / 68 / 24 / 94.8 / ₹45L / ₹2.8L / 3` aur service mein `getPrincipalMorningBriefing()` ke catch mein wahi poora fake briefing; library screen mein `_defaultIssued` ki haath se likhi list.
- **Badlav:** (a) Dashboard ke saare `??` fallback **delete** — service se number na aaye to tile par "—" ya "Data nahi mila" dikhega, jhootha number nahi. (b) Service ke andar bhi fallback hatana hai — `totalMarked > 0 ? ... : 94.8` ko `totalMarked > 0 ? ... : 0.0` (aur UI par "aaj attendance mark nahi hui" ka empty state), catch block ko khaali/error result return karna hai, fake briefing nahi. (c) Library ki `_defaultIssued` list **delete** — table khaali ho to empty state dikhega.
- **Verification:** Live DB par test — service fail karke dekho (ya khaali table se): dashboard par **koi bhi** fallback number (450, 68, 94.8, ₹45L, ₹2.8L, 3) **kabhi nahi** dikhna chahiye. Grep se verify karna hai: dashboard file + briefing method mein ye constants nahi hone chahiye (sirf test files mein reh sakte hain).

#### M2. UDISE+ — andaze se real data tak

- **Aaj:** `generateUdisePlusReport()` mein UDISE code, gender split 52/48, RTE 45/38, PTR 18:1, sanitation, NOC — sab haath se likha hai; modal mein bhi wahi fallbacks dobara lage hain.
- **Badlav:** (a) Gender split DB se aayega (`school_students` mein gender column — VERIFY-FIRST: na ho to "Not recorded" dikhega, invent nahi hoga). (b) RTE quota seats aur enrolled `school_settings` (N5) + `school_admissions` se aayenge. (c) PTR real count se banega (students ÷ teachers, dono real). (d) Sanitation/NOC settings se aayenge — **dates ke saath** (N5). (e) Jo field ka data nahi hai, wo "Missing" dikhega — aur compliance status tabhi COMPLIANT hoga jab saare required fields real hon (N11 ka checklist rule). (f) UDISE code settings se aayega, code mein hardcode nahi rahega.
- **Verification:** UDISE+ centre kholo — har field ke saath uska source dikhna chahiye (jaise "Source: school_students"); koi field "Missing" ho to status INCOMPLETE dikhna chahiye, COMPLIANT kabhi nahi.

#### M3. Institute identity — constants se settings tak

- **Aaj:** `_schoolName`, `_affiliationNo`, `_academicSession`, `_currentTerm` — chaaron constants; briefing mein bhi `'Shivalik International School'` aur `'2025-2026'` haath se likhe hain.
- **Badlav:** Ye chaaron `school_settings` / `institutes` (N5) se aayenge. Header, drawer, UDISE modal, briefing — har jagah wahi ek source use hoga. Na mile to sirf date dikhegi, galat naam/session kabhi nahi.
- **Verification:** Settings mein school ka naam badlo — dashboard header, drawer aur UDISE modal teeno mein wahi naam dikhna chahiye.

#### M4. Grievance resolve — fixed line se asal notes tak

- **Aaj:** Har resolve par `'Reviewed & Resolved by Principal'` fix save hota hai.
- **Badlav:** Resolve karte waqt **notes likhna mandatory** hoga — ek text field (kya kiya, kya jawab diya), jo save hoga aur parent ko dikhega. Purani fixed line **delete** karni hai. Resolved complaints ka history bhi dikhega (N10).
- **Verification:** Ek complaint resolve karo apne notes ke saath — history mein wahi notes dikhne chahiye, fixed line kabhi nahi.

#### M5. Attention strip — poori queue + sahi gintee

- **Aaj:** Sirf 3 type ke items; badge mein defaulters ko 1 gina jata hai; umar nahi dikhti.
- **Badlav:** (a) Badge ka hisaab theek karo — har item apni ginti se (40 defaulters = 40, 1 nahi). (b) Strip ko N2 Approvals Centre se jodna hai — top 5 pending + "View all". (c) Har chip par age dikhegi (jaise "5 din se pending"). (d) "0 Pending" wala hara strip tabhi dikhega jab **saare** queues (admissions, certificates, leave, scrutiny, grievances, mismatches) khaali hon — sirf 3 type ke khaali hone par nahi.
- **Verification:** 40 defaulters banao (test data se) — badge mein 40 dikhna chahiye; ek teacher leave pending ho to hara strip **nahi** dikhna chahiye.

#### M6. Command Matrix + Quick Actions — gintee, status aur parity

- **Aaj:** Header kehta hai '13 Operational Modules', list mein 15 hain; sirf 2 modules par count badge hai; Quick Action sheet mein staff leave, allotment, session rollover, reports export, settings ki entry nahi hai.
- **Badlav:** (a) Header ki gintee **dynamic** hogi (list ki length se, haath se nahi). (b) Har module par live status — us module mein kitne pending items hain (jaise certificates pending, transport mismatches, exam sessions upcoming) — jahan count ka source hai wahan badge, jahan nahi wahan VERIFY-FIRST note CHECKPOINT mein. (c) Quick Action sheet mein add karo: Staff Leave Approvals (N3), Session Rollover (promotion screen), Reports Hub export (Part D), Institute Settings (N5). (d) Drawer, matrix aur quick actions — teeno ki list **ek jaisi** honi chahiye (koi entry ek jagah ho aur doosri jagah na ho, aisa nahi hoga).
- **Verification:** Matrix, drawer aur quick actions ki list side-by-side compare karo — koi entry miss nahi honi chahiye; header ki gintee list se match karni chahiye.

#### M7. Route guard — /school/* routes par role check

- **Aaj:** `app_router.dart` mein `/school/admin-dashboard` plain route hai — koi redirect/guard nahi hai. Login switch hi ekmatra gate hai.
- **Badlav:** GoRouter mein guard lagana hai — `/school/*` routes par `institute_type == 'school'` + role check (admin route par sirf admin/sadmin). Guard fail ho to login screen par bhejega (error nahi dikhayega). **Note:** Ye Fix Pack A (F1) ka route-guard hissa hai — agar F1 mein guard pehle se lag gaya ho to **dobara nahi** banana, sirf verify karna hai (VERIFY-FIRST).
- **Verification:** Teacher login se `/school/admin-dashboard` seedha kholne ki koshish karo — guard ko rokna chahiye aur login/dashboard (teacher) par bhejna chahiye.

#### M8. sadmin login — 'sadmin' case + live row check (F1 gate)

- **Aaj:** Login switch mein `'sadmin'` ka case nahi hai (default se admin dashboard milta hai), aur `institute_type` missing ho to default `'college'` hai.
- **Badlav:** (a) Login switch mein explicit `'sadmin'` case jodna hai → `/school/admin-dashboard` (default par bharosa nahi rakhna). (b) ADM0 mein live DB par `sadmin1` ki row verify karni hai — `institute_type = 'school'` hona chahiye, nahi to F1 ke hisaab se fix karna hai (ye Fix Pack A ka kaam hai — is document mein sirf gate hai, F1 dobara nahi karna).
- **Verification:** `sadmin1` se login karo — seedha `/school/admin-dashboard` khulna chahiye, college dashboard kabhi nahi.

#### M9. KPI drill-down — har tile se uski detail

- **Aaj:** Tiles par tap karne se sahi screens khulti hain, par tile ke andar koi detail nahi (jaise aaj kaun absent hai, kaunse defaulters hain).
- **Badlav:** Har tile par tap → uski **filtered list** khulegi (jaise Fee tile → defaulters list; Students tile → aaj absent students; Transport tile → aaj ke mismatches). Tile ke andar chhota "aaj ka highlight" bhi dikhega (jaise "aaj 12 absent" ya "₹X aaj collect hua").
- **Verification:** Har tile par tap karo — khuli hui list tile ke number se match karni chahiye.

#### M10. Loading + error states — bare spinner se 4-state tak

- **Aaj:** Loading mein sirf `CircularProgressIndicator`; error mein `catch (_)` khaali — fail hone par dashboard fallback numbers ke saath load ho jata hai.
- **Badlav:** Step 13 ke 4-state standard ke hisaab se — loading skeleton (har section ka), loaded, **error state with retry button**, empty state with CTA. Service fail ho to error state dikhega, fallback numbers kabhi nahi (M1 ke saath).
- **Verification:** Service fail karke dekho — error state + retry dikhna chahiye, dashboard fallback numbers ke saath load nahi hona chahiye.

#### M11. Fee KPI semantics — "aaj" vs "session" saaf karna

- **Aaj:** Variable `_feeCollectedToday` hai, par value poori lifetime ki paid amount ka yog hai.
- **Badlav:** Tile par do numbers dikhenge — "Aaj ka collection" (aaj ki date ke receipts se) aur "Session total" (poori session ka yog). Variable ka naam aur logic dono theek karne hain. Subtitle mein pending dues session ka hoga, aaj ka nahi.
- **Verification:** Aaj ek fee payment karo — "Aaj ka collection" badhna chahiye, "Session total" bhi; kal ka collection aaj ke number mein nahi aana chahiye.

#### M12. Admissions RTE metric — haath se likha se DB tak

- **Aaj:** Admissions screen mein `'38/45 RTE Seats Filled'` haath se likha hai.
- **Badlav:** RTE seats `school_settings` (N5) se aur filled count `school_admissions` (RTE quota wale enrolled) se aayega. Dashboard ke admissions badge aur N7 funnel mein bhi wahi numbers aayenge.
- **Verification:** Ek RTE admission enroll karo — metric ka filled count badhna chahiye.

#### M13. Staff & User Management link — college screen se sahi tareeke se

- **Aaj:** Matrix aur drawer se `/admin/manage-users` khulta hai (college screen, `initialInstitution` default `'school'`).
- **Badlav:** Link mein institution **explicitly** pass karna hai (`/admin/manage-users/school`) taaki default par bharosa na rahe. Aur N3 ke staff oversight view banne ke baad, matrix ki entry pehle N3 view par jayegi, wahan se "Manage Users" ka link college screen par jayega — sadmin ko seedha college context mein nahi phenkna hai.
- **Verification:** Link par tap karo — khula hua screen school institution par hona chahiye, college par nahi.

#### M14. 4-state standard + touch targets har section par

- **Aaj:** Step 13.1 mein dashboard ka design overhaul hua, par loading sirf spinner hai aur kuch sections mein empty/error state nahi hai.
- **Badlav:** Dashboard ke har section (Pulse, Matrix, Feed, Approvals, Analytics) mein 4-state laagu hoga — loading mein skeleton, khaali mein empty+CTA, error mein retry, loaded mein data. 48dp minimum touch targets aur 8pt grid (Step 13 standard) poore dashboard par.
- **Verification:** Har section ko loading / empty / error / loaded — chaaron haalat mein check karna hai (Gemini khud batayega ki kaise test kiya).

---

## Part D — Reports catalogue (admin ki har report: graph + Excel)

**Rule (sab reports par):** Admin poora school dekh sakta hai — par har report mein filter hoga (class, date range, session, fee head, exam). Har report ka **graph `fl_chart` se** aur **Excel `excel` package se** banega. Excel standard (Core Modules wala hi reuse hoga): pehli sheet **Summary** (title, filters, totals, generated date), doosri sheet **Data** (poori rows), totals row har sheet ke ant mein, file ka naam `Admin_<CODE>_<YYYYMMDD>.xlsx`. Reconciliation rule: report ka har number uski source screen (fee / admissions / attendance / UDISE centre) se match karna chahiye — mismatch mile to report galat hai, data nahi. Reports Hub (`/school/reports`) mein admin tabs yahi catalogue dikhayenge — Morning Briefing tab ko N1 analytics se jodna hai.

| Code | Report | Graph (fl_chart) | Excel mein kya hoga |
|---|---|---|---|
| AD-R01 | Enrolment trend — session mein mahine-wise students | Line chart (mahine-wise enrolment) | Monthly rows + class-wise breakup + totals |
| AD-R02 | Fee collection trend — mahine-wise collected vs pending | Grouped bar chart (collected vs pending) | Monthly rows + head-wise breakup + totals |
| AD-R03 | Defaulters ageing — 0–30 / 31–60 / 61–90 / 90+ din | Bar chart (bucket-wise amount + count) | Student rows + ageing bucket + amount + class |
| AD-R04 | Fee head-wise collection — kaunse head se kitna aaya | Donut chart (head share %) | Head rows + collected + pending + totals |
| AD-R05 | Admission funnel — enquiry se enrolled tak | Bar chart (stage-wise counts + conversion %) | Stage rows + counts + conversion % + RTE split |
| AD-R06 | Exam results — class-wise pass %, subject averages | Bar chart (class-wise pass %) | Class rows + pass % + subject averages + toppers |
| AD-R07 | Staff load & directory — teacher-wise periods + allotment | Bar chart (teacher-wise weekly periods) | Staff rows + subjects + classes + leave balance |
| AD-R08 | Transport — route-wise boarding + safety mismatches | Bar chart (route-wise boarded vs absent) | Route rows + stops + mismatches + incidents |
| AD-R09 | Library — issued/overdue/fines | Bar chart (mahine-wise issues + overdue) | Issue rows + due dates + fine amounts |
| AD-R10 | UDISE+ 38-field statutory export | Donut chart (compliance completeness %) | 38 fields + source column + missing-field flags |
| AD-R11 | Grievances — category-wise + ageing | Bar chart (category counts + ageing buckets) | Complaint rows + category + age + status + notes |
| AD-R12 | Broadcasts — circular sends, audience-wise | Bar chart (audience-wise sends) | Circular rows + audience + date + urgent flag |
| AD-R13 | Approvals ageing — pending days buckets | Bar chart (0–3 / 4–7 / 8+ din) | Approval rows + type + age + approver |
| AD-R14 | Audit activity — action-wise log | — (log list hai) | Log rows + actor + action + entity + timestamp |

**Note:** AD-R14 table-type report hai (isme graph ka matlab nahi hai) — par Excel iska bhi banega, bina exception. AD-R10 ka Excel Reports Hub ke UDISE+ tab wale 38-field export se **wahi** hoga — do alag UDISE export nahi banenge.

---

## Part E — Gemini execution plan (line-by-line)

### E1. Steps aur order

**ADM0 — Verify + F1 gate (koi code change nahi, sirf report).** Pehle ye sab dhoondh kar CHECKPOINT mein likhna hai: (a) live DB par `sadmin1` ki row — `institute_type = 'school'` hai ya nahi (nahi ho to F1 ke hisaab se fix karna hai — ye gate hai, F1 dobara nahi karna); (b) login switch mein `'sadmin'` case ka na hona + router mein guard ka na hona; (c) `institutes` table ke columns (N5 ke liye kya maujood hai); (d) `school_students` mein gender column hai ya nahi (M2/AD-R10 ke liye); (e) teacher leave ka flow kahan hai (college HR ya school — N2/N3 ke liye); (f) fee refund/concession ka flow kahan hai (N2 ke liye); (g) `school_fee_payments` mein month-close ka flag/table hai ya nahi (N6 ke liye); (h) notifications ka system hai ya nahi (Teacher N14 wali `school_notifications` bani ya nahi — N14 ke liye). **ADM0 ke bina ADM1 shuru nahi hoga.**

**ADM1 — Real-data purge (M1, M2, M3, M12 + library fallback).** Dashboard + briefing + UDISE + admissions RTE + library fallback — saare haath se likhe numbers hatane hain. **Done tabhi jab:** dashboard file, `getPrincipalMorningBriefing`, `generateUdisePlusReport`, admissions screen aur library screen mein koi fallback constant (450, 68, 24, 94.8, ₹45L, ₹2.8L, 3, 38/45, 234/216, UK-FS-2026/8911) na bache — grep se verify karna hai. Data na mile to empty/error state dikhega, number nahi.

**ADM2 — Approvals Centre + attention strip (N2 + M5).** Unified queue (jo sources ADM0 mein mile — na mile to CHECKPOINT mein "pending on <source>" likhna hai), sahi gintee, age/SLA, notes ke saath approve/reject. **Done tabhi jab:** har queue item ka count uski source screen se match kare; ek item approve/reject karne par audit log (N4 ka basic) banne lage.

**ADM3 — Analytics + reports, pehla hissa (N1 + N6 + N7 + AD-R01 se AD-R06).** `fl_chart` ka school mein pehla use (teacher dashboard ke saath share hoga — dono ek hi chart standard use karenge). Dashboard par analytics section + Reports Hub ke admin tabs. **Done tabhi jab:** 4 charts real data se ban rahe hon; har chart se uski poori report khul rahi ho.

**ADM4 — Reports, doosra hissa + Excel (AD-R07 se AD-R14 + UDISE Excel).** `excel` package ka school mein pehla use. Har report ka `.xlsx` export (Summary + Data + totals + naming standard). UDISE+ 38-field export Reports Hub wale se **wahi** hoga. **Done tabhi jab:** har AD-R report ka Excel uski screen ke numbers se match kare; CSV/PDF wale purane exports toote nahi hon.

**ADM5 — Naye features (N3, N4, N5, N8, N9, N10, N11, N12, N13, N14).** Order: N5 (settings) pehle — kyunki M2/M3 aur N11 us par depend karte hain; phir N4 (audit trail — har action ke step mein log judna hai), phir N3 (staff oversight — LINK ONLY), N8 (exam widget), N9 (transport safety), N10 (grievance centre), N11 (UDISE centre), N12 (global search), N13 (broadcast centre), N14 (notifications). Har feature ke liye: pehle VERIFY-FIRST check, phir UI, phir RLS (nayi table ho to), phir verification.
**Done tabhi jab:** har feature ka data real ho; RLS wali har table par admin-scope test ho; settings badalne par audit log bane.

**ADM6 — Modifications ka polish (M6, M7, M8, M9, M10, M11, M13, M14).** Matrix parity, route guard, sadmin case, drill-downs, 4-state, fee semantics, manage-users link. **Done tabhi jab:** matrix/drawer/quick-actions ki list ek jaisi ho; teacher login se admin route guard se ruke; har section 4-state mein test ho chuka ho.

**ADM7 — Final QA + HANDOFF.** Poora admin E2E live DB par: `sadmin1` login → dashboard (saare numbers real, koi fallback nahi) → har AD-R report (graph + Excel) → har approval queue ka ek action → UDISE+ centre (koi invented field nahi) → college regression (`flutter analyze` poore repo par, college screens kholkar dekhna — koi college screen nahi tootni chahiye). Phir HANDOFF block (neeche template) + agle dashboard (Parent) ke liye 3-line note.

### E2. Hard rules (Gemini ke liye — todna mana hai)

1. College code/tables/routes — zero touch. Sirf school files + `school_*` tables. `/admin/manage-users` mein koi badlav nahi.
2. Koi mock/fake/demo data nahi — na dashboard mein, na report mein, na UDISE+ mein, na test mein (test data alag se mark hoga aur live DB par nahi jayega). **UDISE+ mein to bilkul nahi.**
3. Har nayi table: SQL file `database/` mein + RLS policies ke saath + CHECKPOINT mein table ka naam aur RLS test ka saboot.
4. Admin-scope har query mein — `institute_id` se filter (multi-institute), kabhi poori table mat uthao aur UI par filter mat karo.
5. Koi secret/key/password file mein nahi. HR module is document mein nahi banega — oversight/link only. Payroll out of scope.
6. Har money/approval action par audit log (N4) mandatory hai — bina log ke action complete nahi mana jayega.
7. Har step: pehle `flutter analyze` us file par, phir poore `lib/features/school/` par — 0 errors, 0 warnings tabhi CHECKPOINT.
8. Har step ke baad `SCHOOL_PROGRESS.md` mein row + CHECKPOINT + commit (`admin-dash: ADM<n> — <title>`). Limit aaye to HANDOFF block likhna hai — adhoora step "ho gaya" nahi kehna.

### E3. HANDOFF template (limit par Gemini ye likhega)

```
HANDOFF — Admin Dashboard Deep-Dive
Poora hua: ADM0–ADM<n> (har step ka commit + CHECKPOINT SCHOOL_PROGRESS.md mein hai)
Chal raha tha: ADM<n+1> — <kya kar raha tha, kahan ruka, kaunsi file khuli thi>
Agla agent yahan se shuru kare: <exact step + pehla action>
Ruka hua / pending: <koi Maalik ka faisla baaki ho to — jaise teacher-message approval rule, grievance category/SLA rule, behaviour notes parent view>
Test saboot: <live DB par kya verify hua, kya nahi>
```

---

## Part F — Admin ke baad (roadmap, order Maalik ka faisla)

1. **Teacher (Dashboard #1)** — deep-dive poora ho chuka hai.
2. **Admin / sadmin (ye document)** — dashboard #2, abhi.
3. **Parent dashboard** — suggestion: teesra number. Kaam: teacher ke naye features ka parent side (messages inbox, behaviour notes — agar Maalik ne parent view ko haan kaha — PTM slots ka parent view pehle se hai, uska polish), grievance status + resolution notes ka parent view (N10 ka doosra hissa), fee schedule + receipts ka parent view.
4. **Student dashboard** — suggestion: chautha number. Kaam: student ka analytics (apna trend, homework, attendance) + Excel (apni report card ka Excel).
5. **Module screens ka second pass** — admissions, fee, transport, library, examination — admin dashboard ke baad jo gaps bachenge (jaise offline attendance, bulk operations), wo alag document mein aayenge.

**Order #3 se #4 tak Maalik ke next call par final hoga — Gemini is document mein sirf Admin (#2) karega, baaki dashboards ko chhooega nahi.**

---

## Appendix — Files, methods, tables (execution ke waqt kaam aayega)

### A. Files

| File | Kaam |
|---|---|
| `lib/features/school/school_admin_dashboard.dart` (1,863 lines) | Admin dashboard — is document ka main file |
| `lib/features/school/reports/school_reports_screen.dart` (2,687 lines) | Reports Hub (Morning Briefing, Fees admin-only, Marks & Merit, Homework, UDISE+) |
| `lib/features/school/admissions/admissions_screen.dart` (1,971 lines) | 5-tab admissions (Pipeline, Intake, Scrutiny, Interaction, Enquiries) |
| `lib/features/school/fee/school_fee_screen.dart` (2,032 lines) | 5-tab fee (Heads, Student Accounts, Defaulters, Schedule Apr–Mar, Receipts) |
| `lib/features/school/certificates/school_certificates_screen.dart` (1,053 lines) | Certificate requests + apply, No-Dues pre-checks |
| `lib/features/school/circulars/circulars_screen.dart` (499 lines) | Circulars list + publish (admin ya teacher) |
| `lib/features/school/promotion/school_promotion_screen.dart` (811 lines) | Promotion register + session archives |
| `lib/features/school/transport/transport_screen.dart` (1,433 lines) | Trip attendance, safety mismatches, routes master |
| `lib/features/school/library/school_library_screen.dart` (1,144 lines) | Books + Issued + Overdue tabs |
| `lib/features/school/examination/school_examination_screen.dart` (1,879 lines) | Sessions, Date Sheet, Admit Cards, Halls & Seating, Marks & Results |
| `lib/features/school/timetable/school_timetable_screen.dart` (1,787 lines) | Week view + substitution desk + syllabus tracker |
| `lib/features/school/academics/school_lesson_plan_screen.dart` (1,909 lines) | NEP 2020 5E Studio (scrutiny desk) |
| `lib/features/auth/login_screen.dart` | Login routing (`institute_type` + role switch; **'sadmin' case nahi hai**) |
| `lib/routes/app_router.dart` | Routes — `/school/admin-dashboard` plain route, **koi guard nahi**; `/admin/manage-users` college screen |
| `lib/services/school_service.dart` (~6,900 lines) | Sab school service methods |
| `lib/services/school_export_service.dart` | PDF/CSV exports (class results, attendance, pending fees) — **koi .xlsx method nahi** |
| `pubspec.yaml` | `fl_chart: ^0.65.0` (school mein unused), `excel: ^4.0.2` (school mein unused), `csv: ^6.0.0`, `pdf`, `printing` |

### B. Service methods (admin se jude, maujood)

`getSchoolStats`, `getPrincipalMorningBriefing`, `generateUdisePlusReport`, `getAdmissions`, `getCirculars`, `createCircular`, `getDefaultersWithAgeing`, `getParentComplaints`, `resolveParentComplaint`, `getTransportRoutes`, `getSchoolClasses` (fallback 6-A…12-A), `getTeacherNames`, `getTeacherDailyLoad`, `getSubstitutionLogs`.

**Maujood nahi hain (grep se verify kiya):** `getStaffList`, `getTeacherLeaves`, `getPendingCertificateRequests`, `getAuditLog`, `getSessionInfo`.

### C. Tables (maujood — nayi tables Part C mein alag se likhi hain)

`school_students`, `school_teachers`, `school_classes`, `school_subjects`, `school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_exam_sessions`, `school_report_card_meta`, `school_student_leaves`, `school_admissions`, `school_fee_accounts`, `school_fee_items`, `school_fee_payments`, `school_fee_receipts`, `school_circulars` (grievances bhi isi mein, category='ParentComplaint'), `school_certificate_requests`, `school_library`, `school_library_issues`, `school_timetable`, `school_transport`, `institutes`, `parent_student_links`.

### D. Nayi tables (sirf tab jab VERIFY-FIRST mein na milen)

`school_audit_log` (N4), `school_settings` (N5 — agar `institutes` mein fields na hon), `school_circular_audience` (N13 — agar audience column extend na ho sake), `school_notifications` (N14 — agar Teacher N14 mein na bani ho). Har ek par RLS mandatory hai.

---

## Aakhri note (Maalik ke liye)

Ye document admin dashboard ko "sundar command center" se "sachha command center" banane ka plan hai. Step 13.1 ne design de diya hai — ab data sachha karna hai. Sabse pehla kaam ADM1 hai — fallback numbers hatana, khaas taur par UDISE+ sheet se andaze hatana. Uske bina aage ka har chart aur har Excel bekaar hai, kyunki principal ko numbers par bharosa hi nahi hoga. Aur ek baat yaad rakhni hai: **UDISE+ sheet mein jo nahi pata, wo "nahi pata" kahegi — andaze se bhari compliance sheet se behtar hai aadhi bhari sachhi sheet.** Isliye order mat badalna: **pehle sachha data, phir approvals, phir charts, phir Excel, phir naye features.**
