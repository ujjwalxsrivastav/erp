# School ERP — Student Dashboard Deep-Dive (Enterprise Upgrade)

## Dashboard #3 — Student (Teacher #1 ho gaya, ab student ki baari)

**Status:** Analysis document — isme koi code change nahi hai. Ye file Gemini ko di jayegi, Gemini isko line-by-line execute karega.
**Repo state (verified, analysis ke waqt):** `origin/main` = `7cce8af` — "Enterprise NEP 2020 Lesson Plan Studio" (5 Nov 2026). Local clone (`~/workspace/erp`, main `1652552`) stale hai, isliye analysis `origin/main` ke archive se ki gayi hai, local clone se nahi. Analysis ke baad repo mein koi change nahi kiya gaya hai.
**Scope lock:** Is document ka kaam SIRF student dashboard aur student se jude screens tak hai. Teacher dashboard (Teacher Deep-Dive MD, Dashboard #1) aur Admin/Parent dashboards is document mein nahi banenge — unka number Part F mein roadmap ke roop mein hai.
**Step 13.2 par build karna hai, dobara nahi banana:** Student dashboard ka light-theme overhaul (Step 13.2, 4 Nov 2026 09:47 IST) ho chuka hai — Slate-50 canvas, passport hero card, 4 KPI tiles, schedule timeline, 8 quick actions, homework + exam cards, circulars, drawer + desktop sidebar. Is document mein us overhaul ko **chhedna nahi hai** — sirf uske upar real data, analytics, reports aur naye features jodne hain. Ek baat saaf kar dun: Step 13.2 CHECKPOINT mein "real 4 master KPI tiles" aur "today's live class schedule timeline" likha hai — par code padhne par schedule **poora hardcoded** nikla aur Upcoming Tests ka count bhi hardcoded nikla (Part A3, A5). Isliye STU1 mein ye dobara verify karna hai, UI ko haath lagaye bina.
**Ye document Core Modules README ko replace nahi karta.** Admin / HR / Admission / Fees / Reports / Excel Import wala kaam (Core Modules README, Steps 1–8) alag track hai. Jahan dono overlap karte hain (Excel standard, Reports), wahan isi document mein Core Modules wala standard reuse hoga — doosra standard invent nahi hoga.

---

## 0. Kaise padhna hai (How to Read)

- **Part A — YE YE HAI:** Aaj student dashboard mein kya-kya maujood hai, file aur route ke saath. Har cheez repo se verify ki gayi hai — koi feature "hai" nahi kaha gaya jab tak file mein nahi dikha.
- **Part B — KAMI KYUN HAI:** Enterprise feel kyun nahi aa raha — seedhi baat, saboot ke saath.
- **Part C — YE YE KARNE JA RAHA HUN:** Do hisse — **C1 NEW (extra)** aur **C2 MODIFY (isi mein badlav)**. Har feature mein likha hai: kya hai, kyun chahiye, kahan dikhega, data kahan se aayega, aur uska graph/Excel kya hoga.
- **Part D — Reports catalogue:** Student ki har report — graph + Excel, dono ke saath. Koi report sirf list nahi hogi. Student ki reports hamesha **"meri"** reports hain — sirf uska apna data.
- **Part E — Gemini execution plan:** Steps, verification, checkpoint, hard rules.
- **Part F — Dashboard-by-dashboard roadmap:** Student ke baad ka order.
- **VERIFY-FIRST ka matlab:** Execution ke waqt pehle file/table dhoondhni hai. Agar cheez pehle se maujood nikli to dobara nahi banani — sirf dashboard se link/queue banana hai. Agar nahi mili to hi nayi banani hai.

## 0.1 Non-negotiables (har step par laagu)

1. **College ERP kabhi nahi tootega.** Sirf `lib/features/school/` + `lib/services/school_service.dart` + `school_*` tables + nayi `school_*` tables chhoo sakte hain. College screens, college tables, college routes — zero touch.
2. **Koi fake/mock/invented data nahi.** Koi number, list ya schedule haath se nahi likha jayega. Data na mile to empty state dikhega ("koi data nahi"), kabhi jhootha number nahi.
3. **Har nayi table par RLS — aur student sirf apna data dekhega.** Bina RLS ke koi table live nahi jayegi. Student ko sirf **uski apni** attendance, marks, homework, fees, leave, library, transport dikhega — kisi aur student ka ek bhi record kabhi nahi. Ye rule service layer par lagega, sirf UI par nahi.
4. **Har step ke baad verification + commit + CHECKPOINT.** Bina verification ke agla step nahi. Har step ka commit message: `student-dash: STU<n> — <title>`.
5. **Deploy pipeline ka note:** 4 Nov 2026 ko GitHub Pages deploy 4 baar fail hua tha (workflow 'Deploy Flutter Web to GitHub Pages'). Isliye Gemini har step ke baad `flutter analyze` + `flutter build web` locally chalayega aur result CHECKPOINT mein likhega. Push karna Maalik ka faisla hai — Gemini khud push karke pipeline par nahi chhodega jab tak Maalik na kahe.
6. **Payroll is document ka hissa nahi hai** (Maalik ke faisle par pending hai — Core Modules mein bhi deferred hai).
7. **Fee ka rule:** Student ko sirf **apni** fees, apna due, apni receipts dikhengi. Kisi aur student ki fee, defaulter list ya collection report student ko kabhi nahi dikhegi. Fee **collection** (admin ka kaam) student dashboard ka hissa nahi hai.
8. **Parent/teacher ka data student ko nahi dikhega.** Teacher ke remarks student ko report card mein dikhte hain (wo theek hai), par teacher ke internal notes, doosre students ke marks/rank-list, aur parent ke grievance/PTM details student dashboard par kabhi nahi aayenge. Rank dikhana hai to sirf student ki apni rank — poori merit list nahi (Maalik chahe to is rule ko CHECKPOINT mein badal sakta hai).

## 0.2 Dashboard-by-dashboard roadmap (poori picture)

| # | Dashboard | Aaj ki haalat (verified) | Is deep-dive mein |
|---|---|---|---|
| 1 | **Teacher** (`/school/teacher-dashboard`) | Deep-dive MD poora ho gaya (Dashboard #1) — 14 NEW + 14 MODIFY + T-R01–T-R14 | Ho gaya — is document ka hissa nahi |
| 2 | Admin / sadmin (`/school/admin-dashboard`) | Step 13.1 mein command center overhaul ho chuka hai (Morning Pulse, approvals queue, UDISE+ sheet) | Baad mein — order Maalik ke next call par |
| 3 | **Student** (`/school/student-dashboard`) | Step 13.2 overhaul ho chuka hai, par schedule + tests hardcoded hain, koi chart/Excel nahi, LMS-lite student tak nahi pahuncha | **YE DOCUMENT — poora deep-dive** |
| 4 | Parent (`/school/parent-dashboard`) | Multi-child switcher, live metrics, PTM booking, grievance tickets, LMS-lite modal maujood hain (Step 10) | Baad mein — order Maalik ke next call par |

Suggestion (impose nahi): Student ke baad Parent ka deep-dive lena behtar hai, kyunki parent dashboard mein LMS-lite aur PTM pehle se hain — wahan se student wale features ka parent side seedha judta hai.

## 0.3 Benchmark — tagde level ke school ERP mein student portal kaisa hota hai

Leading school ERPs (ScoolsPRO, ScholarERP, EduSaaS-class platforms) ke student portals mein ye cheezein **standard** hain — inhi se compare karke is document ki kami list bani hai:

- **My attendance + trend** — apni attendance %, mahine ka trend chart, CBSE 75% rule ka warning.
- **My grades + progress charts** — exam-wise trend, subject-wise average, strongest/weakest subjects, report card PDF download.
- **Homework submit + feedback** — file attach karke submit karna, teacher ka grade/remark wapas dekhna, due-date alerts.
- **Study materials + quizzes** — class ke notes/PDF, online MCQ quizzes with score.
- **Timetable + exam countdown** — aaj ka schedule, agla exam kitne din mein, date sheet aur hall ticket.
- **Fee statement + receipts** — apna due, month-wise statement, payment history, receipt PDF download.
- **Leave apply + track** — khud leave apply karna aur uska status dekhna.
- **Library + certificates** — apni issued books, due dates, fine; certificate request + status.
- **Reports har format mein** — PDF, Excel aur CSV export apni reports ka.
- **Notifications** — homework due, fee due, exam, leave decision — ek inbox mein.

Inme se humare system mein attendance view, report card, homework submit (confirm wala), fee statement, leave apply, library, certificates **maujood** hain — par schedule hardcoded hai, analytics/charts nahi hain, Excel nahi hai, study materials student tak nahi pahunche hain, quizzes poori tarah hardcoded hain, aur dashboard par apni progress ka koi chart nahi hai. Wahi gap is document mein bhara ja raha hai.

---

## Part A — YE YE HAI (Existing student features, repo-verified)

### A1. Student dashboard shell

- **File:** `lib/features/school/school_student_dashboard.dart` (1,488 lines)
- **Route:** `/school/student-dashboard`
- **Header:** Pinned SliverAppBar — school logo + naam, CBSE affiliation + session, Refresh button, Circulars button, avatar chip (class dikhti hai, tap → `/school/report-card`). **Gap (pehle se note):** school ka naam `'Shivalik International School'`, affiliation `'CBSE #3530124'` aur session `'Active Session 2025-26'` — teeno `static const` haath se likhe hain. Multi-institute system mein ye DB/session se aane chahiye (Modify M6).
- **Hero card (passport card):** "Hello, {naam} 👋", class • Admission No, STUDENT badge, aaj ki date, aur "{n} Assignments Due" chip. Naam/class/admission no real profile (`getSchoolStudentProfile`) se aate hain — **par fallback** hain: naam na mile to username, class na mile to `'Class 10-A'`, admission no na mile to `'SHIV-2024-89'`.
- **Layout:** Wide screen (≥1080px) par desktop sidebar (260px) + content; chhoti screen par drawer. Pull-to-refresh maujood hai (`_loadStudentData` dobara chalta hai). Fade-in animation (600ms) hai.
- **Loading state:** Sirf beech mein `CircularProgressIndicator` — skeleton nahi hai. **Error state nahi hai:** outer `catch (_)` khaali hai — service fail ho to dashboard chupchaap fallback data dikhata rahega, student ko pata bhi nahi chalega ki data load nahi hua (Modify M7).

### A2. KPI grid (4 cards) — 2 real, 1 aadha-real, 1 fake

| Card | Aaj ka source | Haalat |
|---|---|---|
| Attendance — `94%`, badge "On Track (>=75%)" / "Needs Attention" | Real — `getStudentAttendancePercent(username)`; **par fallback 94.2 hai** (error par `catchError((_) => 94.2)` aur `attPct > 0 ? attPct : 94.2`) | Aadha-real — attendance 0 ho ya service fail ho, tab bhi 94.2% dikhega |
| Pending Homework — "3 Due" | Real — `getHomework` + `getHomeworkSubmissions` se not-submitted ka count | Sahi |
| School Fees Due — `₹0` / amount, badge "Fully Settled" / "Pay Online" | Real — `getStudentFees(username)` se due nikala jaata hai (amount − paid) | Sahi |
| Upcoming Tests — "2 Scheduled", badge "CBSE Term II" | **Haath se likha constant** (`int _upcomingTests = 2;` — kahin update nahi hota) | FAKE — exam sessions se kabhi nahi aata |

KPI cards par tap karne se sahi screens khulti hain (attendance / homework / fees / report-card) — par card ke andar **koi drill-down nahi** (jaise attendance ka trend, kaunsi homework due hai, agla test kab hai).

### A3. Today's Class Schedule — poora hardcoded (sabse bada jhooth)

- **File mein:** `_todaySchedule` sirf 2 jagah hai — define (line 65) aur render (line 858/861). **`_loadStudentData` isko kabhi update nahi karta.** Matlab dashboard par dikhne wala schedule hamesha wahi 4 periods hain jo file mein likhe hain: Mathematics (Mr. R. Sharma, Room 102), English Literature (Ms. A. Sen), Physics Lab (Dr. K. Verma, Sci Lab 1), Social Science (Mrs. P. Joshi) — 08:30 se 11:45.
- **Iska matlab:** Kisi bhi student ko, kisi bhi class ka, kisi bhi din — yahi 4 periods dikhenge. Teacher ke naam, room, time — sab file mein likhe hue hain, timetable table se kuch nahi aata.
- **Aur gap:** Koi empty state nahi hai — chhutti wale din bhi yahi schedule dikhega. Room na mile to default `'Room 102'` hai.
- **Theek cheez:** Schedule item par period badge (P1–P4), time, room, teacher dikhte hain; "Full Timetable →" button `/school/timetable` par le jaata hai — aur timetable screen mein student ka apna class resolve hota hai (neeche A11). Bas dashboard wala hissa fake hai (Modify M1).

### A4. Quick Services grid (8 tiles)

| Tile | Route | Aaj kya hai |
|---|---|---|
| Timetable | `/school/timetable` | Apni class ka week view (neeche A11) |
| Homework | `/school/homework` | List + submit (neeche A8) |
| Attendance | `/school/attendance` | Apna monthly view + heatmap (neeche A9) |
| Report Card | `/school/report-card` | HPC report card + PDF download (neeche A10) |
| Fees & Dues | `/school/fees` | Apni fee statement + payment + receipt (neeche A12) |
| Apply Leave | `/school/leave` | Khud leave apply + status (neeche A13) |
| Circulars | `/school/circulars` | School notices, category + audience ke saath (neeche A15) |
| Library | `/school/library` | Search + apni issued books (neeche A14) |

### A5. Lower sections — Pending Homework + Recent Exam Scores

- **Pending Homework card:** Top 3 **not-submitted** homework (real — `getHomework` minus `getHomeworkSubmissions`); due label real tareeke se banta hai ("2d overdue" / "Due today" / "Tomorrow" / "In N days"); khaali ho to empty state hai ("🎉 All caught up! No pending homework."). Tap → generic `/school/homework` list khulti hai (kisi ek homework par seedha nahi jaata — Modify M8).
- **Recent Exam Scores card:** `getStudentMarks(username)` ke pehle 4 records dikhte hain (marks + grade). **Gap 1:** Service mein **koi order nahi hai** (`getStudentMarks` mein `.order()` nahi lagta) — isliye "Recent" ka matlab hai "DB se jo pehle 4 aaye", latest exam ki guarantee nahi hai (Modify M5). **Gap 2:** Grade dashboard par **inline compute hoti hai** (≥90 A1, ≥80 A2, ≥70 B1, **else B2**) — 9-point CBSE scale nahi hai; 40% wala student bhi B2 dikhega, jo galat hai (Modify M4). Service se `m['grade']` aaye to wahi use hota hai, nahi aaye to ye galat scale lagta hai. **Gap 3:** Kaunsa exam hai (Unit Test / Half Yearly / Annual) — card par exam ka naam hi nahi dikhta (Modify M5).

### A6. Announcements — Latest School Circulars

- Real circulars (`getCirculars`, pehle 3) title + category + date ke saath; tap → `/school/circulars`. **Gap:** Circulars khaali hon to **poora section gayab ho jaata hai** (`if (_announcements.isNotEmpty)`) — koi empty state nahi hai ("koi naya circular nahi" dikhna chahiye — Modify M10).

### A7. Sidebar / drawer (desktop + mobile)

- **Categories:** ACADEMIC SERVICES — Timetable, Homework, Attendance, Report Card, **Date Sheet & Hall Ticket** (`/school/examination`), Leave Requests. CAMPUS & FINANCES — Fee Dues & Receipts, Circulars & Notices, **Bus & Transport** (`/school/transport`), Library Books, **Certificates** (`/school/certificates`). Neeche Sign Out.
- **Gap (parity):** Drawer mein Transport, Certificates aur Date Sheet & Hall Ticket hain — par Quick Services grid (A4) mein **nahi** hain. Ulta, grid aur drawer ki list ek jaisi nahi hai (Modify M11). **Aur gap:** Drawer mein **My Reports**, **Study Materials** aur **My Profile** ka entry nahi hai — student in tak dashboard se pahunch hi nahi sakta.

### A8. Homework — list + submit (student side)

- **File:** `lib/features/school/homework/homework_list_screen.dart` (959 lines). Student ko apni class ki homework list dikhti hai (active + past tabs); apna submission record backend se aata hai (`getHomeworkSubmissions(studentUsername:)`); har homework par uska submission status dikhta hai.
- **Submit flow (verified):** Student "Mark as Submitted" button dabata hai → dialog khulta hai jisme **text note** likha jaata hai (`TextField`) → confirm karne par submission `school_homework_submissions` mein save hoti hai ("Homework submitted! Your submission is recorded."). **Gap:** File/photo attach karne ka koi flow student side par nahi hai — button par upload icon hai, par asal mein sirf confirm + note hota hai. Teacher ko submission list dikhti hai (teacher MD mein verified). **Gap 2:** Submit karne ke baad teacher ka grade/remark student ko kahin nahi dikhta — grading ka feedback loop adhoora hai (New N5).

### A9. Attendance — student view (is screen mein kaafi kuch theek hai)

- **File:** `lib/features/school/attendance/school_attendance_screen.dart` (2,131 lines). Student apna scaffold dekhta hai (`_buildStudentScaffold`): mahine ke records, Present/Absent/Late/Leave stat chips, **Monthly Visual Heatmap Calendar** (`_buildStudentMonthCalendar`) aur day-by-day activity log.
- **Service:** `getStudentAttendancePercent(username)` + `getStudentAttendanceRecords` — apna data hi aata hai.
- **Gap:** Ye sab attendance screen ke andar hai — **dashboard par iska kuch nahi dikhta** (na trend, na heatmap ka chhota version, na "75% se kitne din door ho" wali chetavni). Dashboard ka KPI sirf ek % hai (New N1 + New N13).

### A10. Report Card — student view

- **File:** `lib/features/school/marks/report_card_screen.dart` (1,331 lines). Student apna CBSE Holistic Progress Card dekhta hai: overall banner, promotion verdict card, summary metrics, **analytics section** (strongest/weakest subject + breakdown — **text-based hai, koi chart nahi**; sirf `LinearProgressIndicator` bars hain, `fl_chart` ka use nahi), remarks card, subject-wise marks rows, co-scholastic section, grading scale card. **Download Report Card (PDF)** button hai (`report_card_pdf.dart` se).
- **Gap:** Analytics text-only hai (chart nahi); exam-wise trend nahi hai (ek exam ka card dikhta hai, pichhle exams se compare nahi hota); Excel export nahi hai (PDF hai — Part D: STU-R05).

### A11. Timetable — student view (role-based, theek direction mein hai)

- **File:** `lib/features/school/timetable/school_timetable_screen.dart` (1,787 lines). Student role par **sirf 1 tab** (routine grid) dikhta hai; uski **apni class backend se resolve hoti hai** (`getSchoolStudentProfile`) — class picker nahi dikhta. Substitution desk aur syllabus tracker teacher/admin ke tabs hain, student ko nahi dikhte.
- **Gap:** Dashboard ka schedule (A3) is screen se juda nahi hai — dashboard fake schedule dikhata hai, jabki asli timetable yahan maujood hai (Modify M1 isi ko jodega).

### A12. Fees — student view (kaafi deep hai)

- **File:** `lib/features/school/fee/school_fee_screen.dart` (2,032 lines). Student ko apna view dikhta hai: **12-month April–March schedule**, har mahine due date 5th, **₹100 late fee fine** per overdue month, itemized fee heads (Tuition, Computer/IT, Science Lab, Sports, Library, Exam, aadi), real-time overdue alerts, one-click online/counter payment modal, **instant official PDF receipt**. Service: `getStudentFeeSummary`, `getStudentFees`, `getStudentReceipts`.
- **Gap:** Dashboard ka Fees KPI sirf total due dikhata hai — agla due kab hai, kitne mahine overdue hain, ye nahi dikhta (Modify M14). Excel statement nahi hai (Part D: STU-R08).

### A13. Leave — student khud apply karta hai (verified)

- **File:** `lib/features/school/leave/student_leave_screen.dart` (1,084 lines). Student "Apply for Leave" sheet kholta hai → `applyStudentLeave(studentUsername: _username, appliedBy: _username, appliedByRole: 'student')` — **matlab student khud apply karta hai, parent nahi** (parent side ka leave flow parent dashboard deep-dive mein verify hoga — yahan sirf student side likha hai). Apni leaves ki list + class teacher ka decision (approve/reject + reason) track kar sakta hai. Approve hone par attendance **excused** mark hoti hai.
- **Gap:** Dashboard par leave ka koi card nahi hai — pending leave ka status dekhne ke liye leave screen kholni padti hai (New N7).

### A14. Library + Certificates (+ transport) — screens hain, dashboard par nahi

- **Library** (`school_library_screen.dart`, 1,144 lines): search + apni issued books `school_library_issues` se. **Gap (fallback):** Real issued list khaali ho to file mein likhi hui **demo list** dikhti hai (`_defaultIssued` — ISSUE-01/02/03) — ye demo data live student ko kabhi nahi dikhna chahiye (Modify M12).
- **Certificates** (`school_certificates_screen.dart`): request list `school_certificate_requests` se aati hai. **Gap (fallback):** Khaali/error ho to file mein likhi **demo requests** dikhti hain (`_defaultCertificateRequests` — 28 Oct / 1 Nov / 2 Nov ki dates ke saath) (Modify M12).
- **Transport** (`transport_screen.dart` + `getStudentTransport`): student ka bus/route data service mein hai — par dashboard par bus ka koi card nahi hai (New N8).

### A15. Circulars — audience model maujood hai, student-side filter nahi

- **File:** `lib/features/school/circulars/circulars_screen.dart` (499 lines). Publish karte waqt **Target Audience** chuna jaata hai (`'All'` default) aur list mein "Audience: X" dikhta hai. **Gap:** `getCirculars` mein audience se filter nahi hota — student ko saare circulars dikhte hain, sirf apni class wale nahi. Execution mein verify karna hai ki student-side audience filter chahiye ya nahi (Modify — VERIFY-FIRST, Part E STU0 mein).

### A16. LMS-lite — study materials + quizzes (student tak pahuncha hi nahi)

- **Service maujood hai:** `lib/services/school_service.dart` mein "LMS-LITE (STUDY MATERIALS & ONLINE QUIZZES)" section — `getStudyMaterials({classId, subject})` aur `getOnlineQuizzes({classId})`.
- **Par student dashboard par iska koi entry nahi hai.** LMS-lite modal **sirf parent dashboard** mein hai (`school_parent_dashboard.dart` — "LMS-Lite" label, `_showLmsMaterialsModal`). Student apne notes/materials apne dashboard se nahi dekh sakta.
- **Aur bada gap (fallback demo data):** `getStudyMaterials` mein `school_circulars` se `StudyMaterial` category padhi jaati hai (content mein `STUDY_MATERIAL|ClassId:...|Subject:...|Title:...|Url:...` format) — par **list khaali ho to 3 hardcoded demo materials** return hote hain (Mrs. Sunita Sharma / Mrs. Gupta / Ms. Nair ke naam, `shivalikschool.edu.in/lms/*.pdf` URLs). `getOnlineQuizzes` to **poora hardcoded list return karta hai** (quiz-sci-01 Chemical Reactions, quiz-math-01 Quadratic Equations — questions + correct answers file mein likhe hain). Ye dono live system mein kabhi nahi hone chahiye (Modify M13, New N3, New N4).

### A17. Student ke liye maujood service methods (`lib/services/school_service.dart`, 6,882 lines)

`getSchoolStudentProfile`, `getHomework` (class filter ke saath), `getHomeworkSubmissions` (studentUsername filter), `getStudentAttendancePercent`, `getStudentAttendanceRecords`, `getAttendanceReport`, `getAttendanceSummary`, `getStudentMarks` (examType filter), `getReportCardMeta`, `getStudentFees`, `getStudentFeeSummary`, `getStudentReceipts`, `getFeePayments`, `getFeeReport`, `getCirculars` (category filter), `getStudentTransport`, `getStudentLeaves`, `getStudyMaterials`, `getOnlineQuizzes`, `applyStudentLeave`.

**VERIFY-FIRST (STU0 mein check karna hai):** `getStudentAttendancePercent` aur `getStudentFees` ke parameter ka naam `studentId` hai, par dashboard `username` pass karta hai — method ke andar username se student kaise resolve hota hai, ye padhkar confirm karna hai. Agar resolve nahi hota to ye bug hai, feature nahi.

### A18. Student se jude maujood tables (database/*.sql se)

`school_students`, `school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_student_leaves`, `school_timetable`, `school_classes`, `school_subjects`, `school_exam_sessions`, `school_report_card_meta`, `school_fee_accounts`, `school_fee_items`, `school_fee_payments`, `school_fee_receipts`, `school_circulars`, `school_library`, `school_library_issues`, `school_certificate_requests`, `school_transport`, `institutes`, `parent_student_links`.

---

## Part B — KAMI KYUN HAI (enterprise feel kyun nahi aa raha)

Seedhi baat — screens ban gayi hain, par dashboard **dikhawa** zyada aur **kaam** kam karta hai:

1. **Sabse bada kaaran — aaj ka schedule hi fake hai.** Student dashboard ka "Today's Class Schedule" backend se kabhi load hi nahi hota — hamesha wahi 4 periods (Mr. R. Sharma, Ms. A. Sen, Dr. K. Verma, Mrs. P. Joshi) dikhte hain. Jis dashboard ka schedule hi file mein likha ho, use koi student seriously nahi lega — aur chhutti wale din bhi wahi schedule dikhega.
2. **Upcoming Tests bhi fake hai.** "2 Scheduled, CBSE Term II" — ye number kabhi badalta hi nahi, exam sessions table se juda nahi hai. Exam ka countdown student ke liye sabse zaroori cheez hai, aur wahi haath se likha hai.
3. **Attendance % ka fallback jhootha hai.** Service fail ho ya attendance 0 ho, tab bhi 94.2% dikhega. 94.2% dikhakar student ko "On Track" ka badge dena — jabki asli data aaya hi nahi — galat hai.
4. **Grade ka scale galat hai.** Dashboard par 40% wala student bhi B2 dikhega, kyunki scale mein C/D/E/fail hai hi nahi. Report card mein 9-point CBSE scale hai, dashboard par 4-point jugaad hai — dono ka grade ek dusre se match nahi karega.
5. **"Recent" scores recent nahi hain.** Marks ki service mein order hi nahi hai — dashboard pehle 4 records utha kar "Recent Exam Scores" keh deta hai. Kaunsa exam hai, ye bhi nahi likha.
6. **Koi chart nahi.** `fl_chart` dependency maujood hai, par school vertical mein ek bhi chart render nahi hota. Apni attendance ka trend, marks ka trend, homework completion — sab sirf list ya count hai. Student apni progress ko **dekh** hi nahi sakta, sirf padh sakta hai.
7. **Koi Excel nahi.** `excel` package pubspec mein hai, par **poori app mein kahin use nahi hota** — ek bhi `.xlsx` export nahi banta. Student apni attendance register, marks ya fee statement Excel mein nahi nikaal sakta.
8. **Study materials student tak pahunche hi nahi.** LMS-lite parent dashboard mein hai, student dashboard mein nahi. Aur uske peeche jo data hai wo bhi demo hai — khaali list par 3 hardcoded notes aur poora hardcoded quiz list return hota hai.
9. **Homework submit adhoora hai.** Student sirf "Mark as Submitted" + text note kar sakta hai — file attach nahi kar sakta. Aur submit karne ke baad teacher ne grade/remark diya ya nahi, ye student ko kahin nahi dikhta — feedback loop toota hua hai.
10. **Dashboard par student ki "apni" cheezein nahi dikhti.** Leave ka status, bus ka card, certificates ka status, library ki due dates — ye sab screens mein hain, par dashboard par ek bhi card nahi hai. Student ko har cheez ke liye alag screen kholni padti hai.
11. **Error chhup jaata hai.** Service fail ho to dashboard chupchaap fallback data dikhata rahega — student ko pata bhi nahi chalega ki uska asli data load nahi hua. Aur library/certificates mein khaali list par demo data dikhta hai — live student ko kabhi demo issues/requests nahi dikhne chahiye.
12. **Step 13.2 ka daava aur code ka sach alag hai.** CHECKPOINT mein "real 4 master KPI tiles" aur "today's live class schedule timeline" likha hai — par code mein 1 KPI fake hai, 1 aadha-fake hai, aur schedule poora hardcoded hai. UI overhaul theek hua tha, par data wala hissa usmein poora nahi hua. Isliye is document ka pehla kaam UI badalna nahi, **data sachha karna** hai.

---

## Part C — YE YE KARNE JA RAHA HUN

### C1. NEW (extra) features — pehle nahi the, ab banenge

Har feature mein: **kya hai / kyun / kahan dikhega / data kahan se / graph-Excel**.

#### N1. My Progress Analytics (dashboard par charts)

- **Kya hai:** Dashboard par ek naya "My Progress" section — 4 charts, sirf student ka apna data: (a) meri attendance trend, pichhle 30 din (line chart); (b) mere marks ka trend, exam-wise overall % (line chart); (c) subject-wise average, latest exam (bar chart); (d) homework completion % — submitted / late / missing (donut chart). Har chart par tap → uski poori report (Part D).
- **Kyun:** Yehi wo cheez hai jo dashboard ko "enterprise" banati hai — student ko ek nazar mein pata chale ki wo kidhar ja raha hai, kis subject mein peeche hai.
- **Kahan dikhega:** Dashboard par KPI grid ke neeche, schedule section se pehle.
- **Data kahan se:** `school_attendance`, `school_marks`, `school_homework_submissions` — sab maujood. Aggregation `school_service.dart` mein naye methods se hogi (ek method per chart, testable). **Koi nayi table nahi.**
- **Graph/Excel:** Charts `fl_chart` se (school mein pehla asli use). Har chart ke saath **Excel export** button (Part D: STU-R01, STU-R03, STU-R04, STU-R06).

#### N2. My Reports hub (student-scoped)

- **Kya hai:** Student ke liye alag reports hub — sirf uska apna data. Poora catalogue Part D mein hai (STU-R01 se STU-R12). Har report mein: filter (subject, exam, date range), **graph + Excel dono**, aur drill-down (report se seedha attendance / marks / homework / fee screen).
- **Kyun:** Aaj reports hub admin-flavoured hai (Morning Briefing, Fees admin-only, Marks & Merit, Homework, UDISE+) aur student dashboard se uska **koi link nahi hai**. Student apni report ek jagah se nahi nikaal sakta.
- **Kahan dikhega:** Dashboard par "My Reports" section + drawer entry → `/school/reports` ka student-scoped view (wahi screen, student role par sirf student tabs; Fees tab nahi, Morning Briefing nahi, UDISE+ nahi — sirf uski apni reports).
- **Data kahan se:** Maujood tables + N1 wali aggregation methods.
- **Graph/Excel:** Har report — Part D dekho. Koi report sirf-list nahi hogi.

#### N3. Study Materials (LMS-lite) — student dashboard par

- **Kya hai:** Student apni class ke study materials dekhe: subject-wise notes/PDF list, title, uploaded-by (teacher ka naam), date. File par tap → PDF khule/download ho. Subject filter hoga.
- **Kyun:** LMS-lite aaj sirf parent dashboard mein hai — student, jiske liye notes hain, wahi unhe apne dashboard se nahi dekh sakta. Ye sabse seedha gap hai.
- **Kahan dikhega:** Dashboard par "Study Materials" tile + drawer entry (Quick Services grid mein 9th tile banegi).
- **Data kahan se:** `getStudyMaterials` (school_circulars, category 'StudyMaterial') — **wahi method reuse karna hai**, naya nahi banana. **Par pehle M13 karna hai** — khaali list par hardcoded demo materials hatane hain, warna student ko demo notes dikhenge.
- **Graph/Excel:** Materials ki report — subject-wise count (list + Excel — STU-R12 family).

#### N4. Online quizzes (real) — hardcoded list hatakar asli quiz

- **Kya hai:** Student apni class ke online quizzes dekhe, quiz attempt kare (MCQ, timer), submit karne par score turant dekhe, aur apne purane attempts + scores ki history dekhe.
- **Kyun:** Aaj `getOnlineQuizzes` poora hardcoded list return karta hai (quiz-sci-01, quiz-math-01 — questions + correct answers file mein likhe hain). Ye demo hai, asli quiz system nahi hai. Enterprise student portal mein practice quizzes standard hain.
- **Kahan dikhega:** Dashboard par "Practice Quizzes" tile + Study Materials section ke andar (N3 ke saath).
- **Data kahan se — VERIFY-FIRST:** Pehle dhoondhna hai ki quiz ki koi real table hai ya nahi (`school_quiz*` jaisi table database mein nahi dikhi — tables list A18 mein nahi hai). Agar nahi hai to **nayi tables**: `school_quizzes` (id, class_id, subject, title, duration_minutes, total_questions, questions JSON, created_by, created_at) + `school_quiz_attempts` (id, quiz_id, student_id, score, total, answers JSON, attempted_at) — dono par RLS (student sirf apni class ke quizzes dekh sake, sirf apne attempts dekh sake; teacher/admin hi quiz banaye — quiz banana is document mein nahi hai, sirf attempt + history hai).
- **Graph/Excel:** Quiz scores — per-subject average (bar chart) + Excel (STU-R12 family).

#### N5. Homework file submission + teacher feedback view

- **Kya hai:** Student homework submit karte waqt **file/photo attach** kar sake (file_picker dependency pubspec mein pehle se hai) + text note likh sake. Submit karne ke baad usi homework par teacher ka grade/remark dikhe (jab teacher grade de).
- **Kyun:** Aaj submit sirf "Mark as Submitted" + note hai — teacher ko kaam dikhta hi nahi, aur student ko feedback milta hi nahi. Submit ka matlab file pahunchna hota hai, sirf tick lagana nahi.
- **Kahan dikhega:** Homework list screen ke andar (student side) — submit dialog mein attach button + submitted homework par "Teacher Feedback" section.
- **Data kahan se — VERIFY-FIRST:** Pehle `school_homework_submissions` ke columns dekho (file_url jaisa column hai ya nahi; teacher grade/remark ke columns hain ya nahi). Na hon to migration ke saath columns add karne hain — nayi table nahi. File storage ke liye Supabase Storage ka bucket use hoga — **VERIFY-FIRST: bucket maujood hai ya banana hai; bucket ka naam + policy STU0 mein likhni hai.** File ka naam, size limit aur allowed types (PDF/image) CHECKPOINT mein likhne hain.
- **Graph/Excel:** Submission log + feedback status — Excel (STU-R07).

#### N6. My Goals / targets — apna target, apni progress

- **Kya hai:** Student har subject mein apna target % set kare (jaise Maths mein 85%). Dashboard par har subject ke saamne target vs actual dikhe (progress bar). Target poora ho to chhota celebration state, peeche ho to "dhyan do" hint — koi rank, koi compare nahi, sirf khud se comparison.
- **Kyun:** Enterprise student portal mein goal-setting standard hai — bina target ke progress ka matlab nahi banta. Ye student ko apni padhai ka malik banata hai.
- **Kahan dikhega:** My Progress section (N1) ke andar per-subject target rows + ek "Set Target" sheet.
- **Data kahan se:** **Nayi table** `school_student_goals` (id, student_id, subject, target_percent, created_at, updated_at) + RLS (sirf apne goals dekh/badlo).
- **Graph/Excel:** Target vs actual — bar chart + Excel (STU-R04 family).

#### N7. My Leave — status card on dashboard

- **Kya hai:** Dashboard par ek chhota card: meri pending leave (dates + reason ki ek line + "Pending with class teacher"), aur meri aakhri decided leave (approved/rejected + reason). Tap → `/school/leave` (poori list + apply).
- **Kyun:** Leave apply karne ka flow maujood hai, par dashboard par uska koi nishaan nahi hai — student ko status dekhne ke liye screen kholni padti hai, aur reject hua to use pata bhi nahi chalta.
- **Kahan dikhega:** Dashboard par hero card ke neeche ya KPI grid ke paas ek slim card (sirf tab jab koi pending ya haal ki leave ho — nahi to nahi dikhega).
- **Data kahan se:** `school_student_leaves` + `getStudentLeaves` — maujood. **Koi nayi table nahi.**
- **Graph/Excel:** Leave history — Excel (STU-R10).

#### N8. My Transport card — bus ka status

- **Kya hai:** Dashboard par ek chhota card: meri bus route, mera stop, aaj boarding hui ya nahi, aur bus se judi koi alert (route change, delay). Tap → `/school/transport`.
- **Kyun:** `getStudentTransport` service maujood hai aur drawer mein Transport ka link hai — par dashboard par bus ka koi card nahi hai. Roz bus se aane wale student ke liye ye roz ki zaroori jaankari hai.
- **Kahan dikhega:** Dashboard par schedule section ke neeche ek slim card (sirf tab jab student ka transport enrolled ho — nahi to card nahi dikhega).
- **Data kahan se:** `getStudentTransport` + `school_transport` — maujood. **Koi nayi table nahi.**
- **Graph/Excel:** Nahi — transport card ki report nahi hoti. Sirf card + detail screen.

#### N9. My Certificates — request + status on dashboard

- **Kya hai:** Dashboard par certificates ka card: meri requests aur unka status (pending / ready / collected), aur naya certificate request karne ka button (Bonafide, TC, Character — jo types maujood hain, wahi). Ready hone par download ka link.
- **Kyun:** Certificates screen maujood hai aur drawer mein link hai — par dashboard par uska koi card nahi hai. Student ko pata hi nahi chalta ki uska certificate ready hua ya nahi.
- **Kahan dikhega:** Dashboard par Quick Services ke paas ek card (sirf tab jab koi request ho ya request karni ho).
- **Data kahan se:** `school_certificate_requests` — maujood. **Par pehle M12 karna hai** — demo fallback requests hatane hain.
- **Graph/Excel:** Requests log — Excel (STU-R13 note, Part D ke baad).

#### N10. Notifications / inbox (chhota, par zaroori)

- **Kya hai:** Dashboard par ek bell icon + inbox: naye circulars, homework due (kal due hai), fee due (5th nazdeek hai), leave ka faisla (approved/rejected), exam ki date sheet, quiz naya aaya. Har notification par tap → sahi screen. Read/unread state.
- **Kyun:** Student ko har cheez ke liye alag screen check nahi karni chahiye — alerts ek jagah aane chahiye. Ye enterprise feel ka chhota par bada hissa hai. (Teacher MD mein bhi yahi feature hai — **wahi `school_notifications` table dono use karenge**, do tables nahi banengi.)
- **Kahan dikhega:** AppBar mein bell icon + inbox screen (drawer mein "Notifications" entry).
- **Data kahan se — VERIFY-FIRST:** Pehle dekho ki notifications ka koi system pehle se hai ya nahi (circulars, fee due, leave decision — inke events maujood hain). Agar koi central table nahi hai to **nayi table** `school_notifications` (user_id, role, type, title, body, link_route, is_read, created_at) + RLS (sirf apni notifications). Events ko notification banane ka kaam har feature ke step mein jodna hai — alag se bada system nahi banana.
- **Graph/Excel:** Nahi — inbox ki report nahi hoti. Sirf list + read/unread.

#### N11. Exam countdown + date sheet + hall ticket widget

- **Kya hai:** Dashboard par ek widget: agla exam (naam + kitne din mein), uski date sheet ka link, aur hall ticket download ka button (jab admit card ready ho). (Lesson plan screen mein exam countdown pehle se hai — wahi data student dashboard par laana hai.)
- **Kyun:** Student ka saara kaam exam ke around ghoomta hai — aur aaj dashboard par exam ka naam tak nahi hai (sirf fake "2 Scheduled" likha hai). Date Sheet & Hall Ticket drawer mein hai, par dashboard se uska koi raasta nahi hai.
- **Kahan dikhega:** Dashboard par schedule section ke upar ek slim banner (M2 ke saath — Upcoming Tests KPI ko ye widget replace karega).
- **Data kahan se:** `school_exam_sessions` + admit card candidates (`getExamAdmitCardCandidates` — **VERIFY-FIRST: student apna admit card dekh sakta hai ya nahi; examination screen admin/teacher-oriented lagti hai**). **Nayi table nahi.**
- **Graph/Excel:** Exam-wise performance — STU-R03 (trend) ke saath judta hai.

#### N12. My Profile / ID card

- **Kya hai:** Student apni profile dekhe: naam, class-section, admission no, roll no, guardian ka naam + phone, aur ek printable ID card view (photo initial + details + QR — QR ka data sirf admission no hoga, koi sensitive data nahi).
- **Kyun:** Student ko apni details dekhne ki jagah hi nahi hai — hero card mein sirf naam-class-admission no hai. Guardian ka number bhi student ko pata hona chahiye (emergency mein kaam aata hai).
- **Kahan dikhega:** Avatar chip par tap → profile sheet; drawer mein "My Profile" entry.
- **Data kahan se — VERIFY-FIRST:** Pehle dhoondhna hai ki profile dikhane wali screen pehle se hai ya nahi (dashboard ke bahar). Agar hai to **sirf link** banana hai. Agar nahi hai to `school_students` + `parent_student_links` se profile sheet banani hai — **nayi table nahi**. Edit ka haq student ko nahi hoga (details admin badlega) — sirf view.
- **Graph/Excel:** Nahi — profile ki report nahi hoti.

#### N13. Attendance alerts — "75% rule" ki chetavni

- **Kya hai:** Dashboard par attendance card ke andar ek warning line — (a) attendance <75% ho to laal warning + kitni % kami hai; (b) 75% se upar ho to "aur kitne din absent reh sakte ho 75% se neeche gire bina" (rule-based hisaab, school ke working days se — koi AI claim nahi); (c) CBSE defaulters rule ka ek line mein matlab ("75% se neeche hone par board exam mein baithne par rok lag sakti hai" — sirf tab jab school ka rule ye kehta ho, VERIFY-FIRST).
- **Kyun:** Student ko % dekhkar samajh nahi aata ki uska kya matlab hai. Enterprise portal % ko **matlab** mein badal deta hai — "tum safe ho" ya "tum khatre mein ho".
- **Kahan dikhega:** Attendance KPI card ke andar + My Progress section (N1) ke attendance chart ke neeche.
- **Data kahan se:** `getStudentAttendancePercent` + `getStudentAttendanceRecords` — maujood. **Koi nayi table nahi.**
- **Graph/Excel:** Attendance trend + Excel (STU-R01, STU-R02).

#### N14. Ask Teacher — subject teacher ko sawaal

- **Kya hai:** Student apne subject teacher ko chhota sawaal bhej sake (doubt): subject, message, aur teacher ka jawab wahi thread mein dikhe. Sirf apne subjects ke teachers ko.
- **Kyun:** Enterprise student portal mein teacher se baat karne ka raasta hota hai — aaj student ke paas teacher tak pahunchne ka koi in-app raasta nahi hai. (Teacher side ka inbox teacher dashboard ke agle pass mein aayega — is document mein sirf student ka bhejna + jawab dekhna hai.)
- **Kahan dikhega:** Dashboard par "Ask Teacher" tile + subject-wise list (homework card ke paas ya Quick Services mein).
- **Data kahan se:** **Nayi table** `school_student_queries` (id, student_id, teacher_id, subject, message, reply, status, created_at, replied_at) + RLS (student sirf apne sawaal dekh sake; teacher sirf apne subject ke sawaal dekh sake).
- **Graph/Excel:** Nahi — queries ki report nahi hoti. Sirf thread list.

---

### C2. MODIFY — isi mein badlav (pehle se hai, par adhoora/galat hai)

#### M1. Today's schedule — hardcoded se real timetable tak (sabse pehla fix)

- **Aaj:** `_todaySchedule` file mein likha hai (4 periods, naam wale teachers, Room 102) aur `_loadStudentData` isko kabhi update nahi karta.
- **Badlav:** Student ki **apni class ka aaj ka schedule** timetable se aayega — wahi logic jo timetable screen mein student ki class resolve karta hai (`getSchoolStudentProfile` se class, phir us class ka aaj ka routine). Period, time, subject, room, teacher — sab real. Koi lecture na ho (chhutti) to empty state dikhega ("Aaj koi lecture nahi — enjoy your holiday!"), kabhi fake schedule nahi. Room na mile to room chip hi nahi dikhega.
- **Verification:** Alag-alag classes ke 2 students se login karwao — dono ko **apni-apni** class ka schedule dikhna chahiye, aur chhutti wale din empty state.

#### M2. Upcoming Tests — fake count se real exam countdown tak

- **Aaj:** `int _upcomingTests = 2;` kabhi update nahi hota; badge "CBSE Term II" haath se likha hai.
- **Badlav:** `school_exam_sessions` se agle exams niklenge — count real hoga, badge mein agle exam ka naam + din dikhenge (N11 widget ke saath). Koi exam scheduled na ho to card par "No exams scheduled" dikhega, "2 Scheduled" kabhi nahi.
- **Verification:** Exam session add/remove karo — dashboard ka count aur widget turant badalna chahiye.

#### M3. Attendance % ka jhootha fallback hatana

- **Aaj:** Error par `catchError((_) => 94.2)` aur `attPct > 0 ? attPct : 94.2` — matlab data na aaye to bhi 94.2% + "On Track" badge.
- **Badlav:** Attendance na mile to card par **"Not available yet"** dikhega (grey state, koi % nahi, koi badge nahi) aur tap karne par attendance screen khulegi. Attendance 0% ho to **0%** dikhega (sachha number, laal "Needs Attention" badge ke saath). Koi bhi number sirf tab dikhega jab wo `getStudentAttendancePercent` se aaya ho.
- **Verification:** Attendance data delete/empty karke test karo (test student par) — 94.2 kabhi nahi dikhna chahiye.

#### M4. Grade scale — jugaad se CBSE 9-point scale tak

- **Aaj:** Dashboard par inline scale hai (≥90 A1, ≥80 A2, ≥70 B1, else B2) — 40% wala bhi B2 dikhega.
- **Badlav:** Grade **hamesha** report card wale 9-point CBSE scale se aayega (`school_report_card_meta` / report card screen ka scale — VERIFY-FIRST: scale kahan defined hai, wahi source dono jagah use hoga). Dashboard par inline grade compute karne wala code **delete** hoga. Agar service se grade aaya hai to wahi dikhega; nahi aaya to grade ki jagah sirf % dikhega, galat grade kabhi nahi.
- **Verification:** 40%, 55%, 72% wale marks ke liye dashboard aur report card ka grade **ek jaisa** hona chahiye.

#### M5. Recent Scores — arbitrary 4 se latest exam tak

- **Aaj:** `getStudentMarks` ke pehle 4 records (koi order nahi) "Recent Exam Scores" kehkar dikhte hain; exam ka naam nahi dikhta.
- **Badlav:** (a) Service mein latest exam pehle aaye — `getStudentMarks` mein order lagana hai (exam/date ke hisaab se — VERIFY-FIRST: `school_marks` mein date/exam ka column kaunsa hai). (b) Card par exam ka naam dikhega (jaise "Half Yearly 2025-26"). (c) Sirf latest exam ke subjects dikhenge, alag-alag exams ke mixed subjects nahi.
- **Verification:** Do exams ke marks daalo — card mein hamesha **latest** exam dikhna chahiye, purana nahi.

#### M6. Institute naam + session — hardcoded se DB tak

- **Aaj:** `'Shivalik International School'`, `'CBSE #3530124'`, `'Active Session 2025-26'` — teeno `static const` hain.
- **Badlav:** Institute ka naam + affiliation `institutes` table se aayenge (VERIFY-FIRST: admin dashboard mein institute ka naam kahan se aata hai — wahi source). Session (2025-26) session table/settings se aayega — VERIFY-FIRST: session kahan stored hai. Na mile to sirf naam dikhega, galat session kabhi nahi.
- **Verification:** Institute ka naam badal kar dekho (test) — dashboard ka header badalna chahiye.

#### M7. Loading + error — spinner se 4-state tak

- **Aaj:** Loading mein sirf beech wala spinner; error par khaali `catch (_)` — dashboard chupchaap fallback data dikhata rahega.
- **Badlav:** Step 13 ke 4-state standard ke hisaab se — loading skeleton (hero + KPI + schedule ke grey blocks), loaded, **error state with retry button**, empty state with CTA. Har section (KPI, schedule, homework, results, announcements) apna error/empty state dikhayega — poora dashboard ek saath fail nahi hoga, jis section ka data nahi aaya sirf wahi error dikhayega.
- **Verification:** Network/service fail karke dekho — error state + retry dikhna chahiye, fallback data (94.2%, SHIV-2024-89, fake schedule) nahi.

#### M8. Homework card — generic list se specific homework tak

- **Aaj:** Card ke har item par tap generic `/school/homework` list kholta hai.
- **Badlav:** Har homework item par tap **usi homework** par le jayega (homework id ke saath — VERIFY-FIRST: homework list screen deep-link support karti hai ya nahi; nahi karti to route/query param jodna hai). Item par due-date urgency dikhegi (overdue laal, due-today amber, baaki normal) aur submitted homework card se hat jayega (aaj sirf not-submitted dikhte hain — ye theek hai, bas graded feedback ka chip jud jayega N5 ke saath).
- **Verification:** Ek homework par tap karo — wahi homework khulni chahiye, list ka top nahi.

#### M9. Results card — marks list se progress jhalak tak

- **Aaj:** Sirf subject + marks + grade ki list hai.
- **Badlav:** Har subject row par pichhle exam se compare ka chhota indicator (↑/↓/→ — sirf tab jab pichhla exam ka data ho), aur card ke upar exam ka naam + overall % (M5 ke saath). Tap → us exam ka report card (aaj generic report card khulta hai — VERIFY-FIRST: report card screen exam select support karti hai ya nahi).
- **Verification:** Do exams ke data par card mein trend indicators sahi dikhne chahiye.

#### M10. Announcements — gayab section se empty state tak

- **Aaj:** Circulars khaali hon to poora section gayab ho jaata hai.
- **Badlav:** Koi circular na ho to section dikhega — "No new circulars" empty state + "View All" button ke saath. Section kabhi gayab nahi hoga.
- **Verification:** Circulars khaali karke dekho (test) — section empty state ke saath dikhna chahiye.

#### M11. Drawer aur quick-actions ki parity

- **Aaj:** Drawer mein Transport, Certificates, Date Sheet & Hall Ticket hain — grid mein nahi hain. Grid mein 8 tiles hain, drawer mein 12 entries hain — dono alag lists hain.
- **Badlav:** Ek hi source of truth — grid tiles aur drawer entries **ek jaisi list** se banengi. Final list: Dashboard, Timetable, Homework, Attendance, Report Card, Date Sheet & Hall Ticket, Leave Requests, Fee Dues & Receipts, Circulars & Notices, Bus & Transport, Library Books, Certificates, Study Materials (N3), Practice Quizzes (N4), My Reports (N2), Notifications (N10), My Profile (N12), Sign Out.
- **Verification:** Grid aur drawer ki list side-by-side compare karo — koi entry ek jagah ho aur doosri jagah na ho, aisa nahi hona chahiye.

#### M12. Library + Certificates ke demo fallback hatana

- **Aaj:** Issued list khaali ho to `_defaultIssued` (ISSUE-01/02/03) dikhti hai; requests khaali hon to `_defaultCertificateRequests` (Oct/Nov ki dates) dikhti hain.
- **Badlav:** Dono fallback lists **poori delete** — khaali ho to empty state dikhega ("No books issued", "No requests yet" + request karne ka CTA). Koi bhi demo issue/request live student ko kabhi nahi dikhega.
- **Verification:** Aise student se login karo jiski koi book issued nahi hai — demo issues **kabhi nahi** dikhne chahiye. Grep se verify karna hai: `_defaultIssued` aur `_defaultCertificateRequests` codebase mein kahin nahi hone chahiye.

#### M13. LMS fallback purge (service level)

- **Aaj:** `getStudyMaterials` khaali list par 3 hardcoded demo notes return karta hai; `getOnlineQuizzes` poora hardcoded list return karta hai.
- **Badlav:** Dono methods se hardcoded return **delete** — khaali ho to khaali list return hogi, aur UI empty state dikhayega. Ye N3/N4 ka precondition hai — bina iske student ko demo notes dikhenge.
- **Verification:** Koi StudyMaterial na ho to `getStudyMaterials` khaali list de — `mat-01/02/03` aur `quiz-sci-01` codebase mein kahin nahi hone chahiye (grep se verify).

#### M14. Fees KPI — total due se poori jaankari tak

- **Aaj:** Card sirf total due dikhata hai ("₹0" ya amount).
- **Badlav:** Card par 3 cheezein dikhengi: total due + **agla due kab hai** (date) + **kitne mahine overdue** hain (agar hon to). Tap → fee screen (aaj bhi wahi jaata hai — theek hai). Receipts ka count bhi chhota chip banega (jaise "12 receipts").
- **Verification:** Ek mahina overdue wale student se login karo — card par overdue count + due date sahi dikhni chahiye.

---

## Part D — Reports catalogue (student ki har report: graph + Excel)

**Rule (sab reports par):** Student sirf **apna** data dekhega — filter service layer par lagega (`student_id` / username se). Kisi aur student ka data report mein kabhi nahi aayega — na graph mein, na Excel mein. Har report mein filter hoga (subject, exam, date range). Har report ka **graph `fl_chart` se** aur **Excel `excel` package se** banega. Excel standard (Core Modules wala hi reuse hoga): pehli sheet **Summary** (title, student naam + class, filters, totals, generated date), doosri sheet **Data** (poori rows), totals row har sheet ke ant mein, file ka naam `Student_<username>_<CODE>_<YYYYMMDD>.xlsx`. Reconciliation rule: report ka har number uski source screen (attendance / marks / homework / fee) se match karna chahiye — mismatch mile to report galat hai, data nahi.

| Code | Report | Graph (fl_chart) | Excel mein kya hoga |
|---|---|---|---|
| STU-R01 | My attendance trend — pichhle 30 din / mahina | Line chart (din-wise %) | Daily rows + monthly summary + 75% rule line |
| STU-R02 | My monthly attendance register — date-wise P/A/L/Leave | — (register table hai; trend STU-R01 mein hai) | Poora register + summary counts |
| STU-R03 | My marks trend — exam-wise overall % | Line chart (exam-wise %) | Exam-wise rows + subject breakdown |
| STU-R04 | My subject-wise performance — latest exam | Bar chart (subject averages) + target vs actual (N6) | Subject rows + marks + grade + target |
| STU-R05 | My report card data export — subject × exam matrix | — (report card ka data hai; trend STU-R03 mein hai) | Subject × exam matrix + grades + remarks |
| STU-R06 | My homework completion — submitted / late / missing | Donut chart (%) | Per-homework rows + status + submitted date |
| STU-R07 | My homework submissions log + teacher feedback | — (log list hai) | Submission rows + file name + grade/remark |
| STU-R08 | My fee statement — heads, months, paid/due/fine | Bar chart (mahine-wise due vs paid) | Month-wise rows + heads + fine + totals |
| STU-R09 | My receipts list | — (receipt list hai) | Receipt rows + receipt no + mode + amount |
| STU-R10 | My leave history | Bar chart (mahine-wise leaves) | Leave rows + dates + reason + status |
| STU-R11 | My library history — issued / returned / fine | Bar chart (mahine-wise issues) | Book rows + issue/return dates + fine |
| STU-R12 | My study progress — materials read + quizzes attempted/scored | Bar chart (subject-wise quiz avg score) | Materials rows + quiz attempts + scores |
| STU-R13 | My certificates log (N9) | — (log list hai) | Request rows + type + status + dates |

**Note:** STU-R02, STU-R05, STU-R07, STU-R09 aur STU-R13 table-type reports hain (inme graph ka matlab nahi hai) — par Excel inka bhi banega, bina exception. STU-R13 tabhi banega jab N9 banega; STU-R12 ka quiz hissa tabhi jab N4 banega.

---

## Part E — Gemini execution plan (line-by-line)

### E1. Steps aur order

**STU0 — Verify (koi code change nahi, sirf report).** Pehle ye sab dhoondh kar CHECKPOINT mein likhna hai: (a) student login se `/school/student-dashboard` tak ka route + role guard mein student case; (b) `getStudentAttendancePercent` / `getStudentFees` ke andar username se student kaise resolve hota hai (parameter ka naam `studentId` hai — agar resolve nahi hota to ye bug hai, CHECKPOINT mein likhna hai); (c) `school_marks` mein date/exam ka column kaunsa hai (M5 ke order ke liye); (d) 9-point CBSE grading scale kahan defined hai (M4 ke liye — report card wala source); (e) session (2025-26) kahan stored hai aur admin dashboard mein institute ka naam kahan se aata hai (M6 ke liye); (f) student apna admit card dekh sakta hai ya nahi — examination screen ka student view kya hai (N11 ke liye); (g) profile dikhane wali screen pehle se hai ya nahi (N12 ke liye); (h) quiz ki koi real table hai ya nahi (N4 ke liye); (i) Supabase Storage bucket maujood hai ya banana hai — file submission (N5) ke liye bucket naam + policy; (j) circulars mein student-side audience filter chahiye ya nahi (A15 ke liye); (k) notifications ka koi system hai ya nahi (N10 ke liye). **STU0 ke bina STU1 shuru nahi hoga.**

**STU1 — Real-data purge (M1, M2, M3, M4, M5, M6, M12, M13).** Hardcoded schedule (4 periods + naam wale teachers), fake "2 Scheduled" tests, 94.2% fallback, galat grade scale, institute naam/session constants, library + certificates ke demo fallbacks, LMS ke hardcoded notes + quizzes — sab hatana hai. **Done tabhi jab:** student dashboard file mein koi haath se likha schedule/number/naam na bache (grep se verify karna hai: `Mr. R. Sharma`, `Room 102`, `94.2`, `SHIV-2024-89`, `Class 10-A` fallback, `mat-01`, `quiz-sci-01`, `_defaultIssued`, `_defaultCertificateRequests` — ye sab nahi hone chahiye; sirf empty-state texts reh sakte hain). **Step 13.2 ka UI overhaul is step mein chhedna nahi hai** — sirf data wala hissa badlega.

**STU2 — My Progress Analytics + My Reports hub, pehla hissa (N1 + N2 + STU-R01 se STU-R06).** `fl_chart` ka school mein pehla use (teacher dashboard ke saath — jo pehle bane, wahi pattern doosra use karega; dono ko alag-alag chart style nahi banana). Dashboard par analytics section + reports hub ka student scope. **Done tabhi jab:** 4 charts real data se ban rahe hon (sirf student ka apna data); har chart se uski poori report khul rahi ho; student-scope filter service layer par laga ho (doosre student ka data kabhi na aaye — 2 alag students se test karna hai).

**STU3 — Reports, doosra hissa + Excel (STU-R07 se STU-R13 + M14 ka Excel hissa).** `excel` package ka school mein pehla use. Har report ka `.xlsx` export (Summary + Data + totals + naming standard). **Done tabhi jab:** har STU-R report ka Excel uski screen ke numbers se match kare; PDF wale purane exports (report card PDF, fee receipt PDF) toote nahi hon.

**STU4 — Naye features, pehla hissa (N3, N4, N5).** Study Materials (LMS-lite student tak), Online quizzes (real), Homework file submission + teacher feedback. **Done tabhi jab:** materials/quizzes mein koi hardcoded entry na bache; file submission test student par end-to-end chale (attach → submit → teacher ko dikhe → grade/remark student ko dikhe); RLS wali har nayi table par student-scope test ho.

**STU5 — Naye features, doosra hissa (N6, N7, N8, N9, N10, N11, N12, N13, N14).** Goals, leave status card, transport card, certificates card, notifications, exam widget, profile, attendance alerts, Ask Teacher. **Done tabhi jab:** har feature ka data real ho; notifications sirf apni hon; goals sirf apne hon; queries sirf apne subjects ke teachers ko jayein.

**STU6 — Modifications ka polish (M7, M8, M9, M10, M11).** 4-state loading/error, homework deep-link, results trend, announcements empty state, drawer/grid parity. **Done tabhi jab:** dashboard aur drawer/grid ki list ek jaisi ho; har section 4-state mein test ho chuka ho (loading / empty / error / loaded).

**STU7 — Final QA + HANDOFF.** Poora student E2E live DB par: student login → dashboard (saare numbers real, koi fallback nahi) → har STU-R report (graph + Excel) → har naya feature → **privacy test** (doosre student ka data kahin nahi dikhna chahiye — attendance, marks, fee, homework, leave, library — har jagah check) → college regression (`flutter analyze` poore repo par, college screens kholkar dekhna — koi college screen nahi tootni chahiye). Phir HANDOFF block (neeche template) + agle dashboard (Parent) ke liye 3-line note.

### E2. Hard rules (Gemini ke liye — todna mana hai)

1. College code/tables/routes — zero touch. Sirf school files + `school_*` tables.
2. Koi mock/fake/demo data nahi — na dashboard mein, na report mein, na service fallback mein, na test mein (test data alag se mark hoga aur live DB par nahi jayega).
3. Har nayi table: SQL file `database/` mein + RLS policies ke saath + CHECKPOINT mein table ka naam aur RLS test ka saboot. **Student-scope har query mein** — `student_id` / username se filter, kabhi poori table mat uthao aur UI par filter mat karo.
4. Koi secret/key/password file mein nahi. Koi doosre student ka data student dashboard/report/Excel mein kabhi nahi.
5. Har step: pehle `flutter analyze` us file par, phir poore `lib/features/school/` par — 0 errors, 0 warnings tabhi CHECKPOINT.
6. Har step ke baad `SCHOOL_PROGRESS.md` mein row + CHECKPOINT + commit (`student-dash: STU<n> — <title>`). Limit aaye to HANDOFF block likhna hai — adhoora step "ho gaya" nahi kehna.
7. **Step 13.2 ka UI overhaul dobara nahi banana.** Colours, passport card, KPI tiles, schedule timeline ka design, drawer/sidebar — wahi rahenge. Sirf data, analytics, reports aur naye features judenge.

### E3. HANDOFF template (limit par Gemini ye likhega)

```
HANDOFF — Student Dashboard Deep-Dive
Poora hua: STU0–STU<n> (har step ka commit + CHECKPOINT SCHOOL_PROGRESS.md mein hai)
Chal raha tha: STU<n+1> — <kya kar raha tha, kahan ruka, kaunsi file khuli thi>
Agla agent yahan se shuru kare: <exact step + pehla action>
Ruka hua / pending: <koi Maalik ka faisla baaki ho to — jaise quiz banana teacher ka kaam hai ya admin ka, behaviour/remarks parent ko dikhane wala rule>
Test saboot: <live DB par kya verify hua, kya nahi — privacy test ka result zaroor likhna hai>
```

---

## Part F — Student ke baad (roadmap, order Maalik ka faisla)

1. **Teacher (Dashboard #1)** — deep-dive MD poora ho gaya. Execution Maalik ke call par.
2. **Admin / sadmin command center (Dashboard #2)** — suggestion: abhi bhi pending. Kaam: analytics + Excel parity (admin ki har report bhi graph + Excel), approvals queue ka deep-dive, UDISE+ sheet ka Excel parity.
3. **Student (Dashboard #3, ye document)** — abhi.
4. **Parent dashboard (Dashboard #4)** — suggestion: agla number. Kaam: teacher ke naye features ka parent side (messages inbox, behaviour notes — agar Maalik ne parent view ko haan kaha — PTM slots ka parent view pehle se hai, uska polish), LMS-lite ka parent view pehle se hai (is document ke N3 se juda hai — parent ko wahi materials dikhte hain jo student ko dikhenge).
5. **Module screens ka second pass** — attendance, marks, homework, timetable, lesson plans — student dashboard ke baad jo gaps bachenge (jaise offline homework submit, bulk operations), wo alag document mein aayenge.

**Order #2 aur #4 Maalik ke next call par final hoga — Gemini is document mein sirf Student (#3) karega, baaki dashboards ko chhooega nahi.**

---

## Appendix — Files, methods, tables (execution ke waqt kaam aayega)

### A. Files

| File | Kaam |
|---|---|
| `lib/features/school/school_student_dashboard.dart` (1,488 lines) | Student dashboard — is document ka main file |
| `lib/features/school/homework/homework_list_screen.dart` (959 lines) | Homework list + student submit (confirm + note) |
| `lib/features/school/attendance/school_attendance_screen.dart` (2,131 lines) | Student scaffold: monthly records + heatmap + activity log |
| `lib/features/school/marks/report_card_screen.dart` (1,331 lines) | CBSE HPC report card + PDF download + text analytics |
| `lib/features/school/timetable/school_timetable_screen.dart` (1,787 lines) | Student ko sirf routine grid (1 tab), apni class auto-resolve |
| `lib/features/school/fee/school_fee_screen.dart` (2,032 lines) | Student fee view: April–March schedule, ₹100 late fee, payment modal, PDF receipt |
| `lib/features/school/leave/student_leave_screen.dart` (1,084 lines) | Student khud leave apply karta hai (`appliedByRole: 'student'`) + status track |
| `lib/features/school/library/school_library_screen.dart` (1,144 lines) | Search + issued books (demo fallback `_defaultIssued` hai — hatana hai) |
| `lib/features/school/certificates/school_certificates_screen.dart` | Requests list (demo fallback `_defaultCertificateRequests` hai — hatana hai) |
| `lib/features/school/circulars/circulars_screen.dart` (499 lines) | Circulars + Target Audience model |
| `lib/features/school/examination/school_examination_screen.dart` | Sessions + date sheets + admit cards + halls (student view VERIFY-FIRST) |
| `lib/features/school/transport/transport_screen.dart` | Transport (student view drawer se) |
| `lib/features/school/reports/school_reports_screen.dart` (2,687 lines) | Reports hub (admin-flavoured — student scope jodna hai) |
| `lib/features/school/parent/school_parent_dashboard.dart` | LMS-lite modal yahin hai (student tak pahunchana hai — N3) |
| `lib/services/school_service.dart` (6,882 lines) | Sab school service methods (LMS-lite section line ~5942) |
| `lib/services/school_export_service.dart` | PDF/CSV exports (class results, attendance, pending fees) |
| `lib/services/report_card_pdf.dart` | Report card PDF generation |
| `pubspec.yaml` | `fl_chart: ^0.65.0` (school mein unused), `excel: ^4.0.2` (poori app mein unused), `csv: ^6.0.0`, `file_picker: ^8.0.0`, `pdf`, `printing` |

### B. Service methods (student se jude, maujood)

`getSchoolStudentProfile`, `getHomework`, `getHomeworkSubmissions`, `getStudentAttendancePercent`, `getStudentAttendanceRecords`, `getAttendanceReport`, `getAttendanceSummary`, `getStudentMarks`, `getReportCardMeta`, `getStudentFees`, `getStudentFeeSummary`, `getStudentReceipts`, `getFeePayments`, `getFeeReport`, `getCirculars`, `getStudentTransport`, `getStudentLeaves`, `applyStudentLeave`, `getStudyMaterials`, `getOnlineQuizzes`, `getStudentsInClass`, `getStudentsByClass`, `getParentChildren`.

### C. Tables (maujood — nayi tables Part C mein alag se likhi hain)

`school_students`, `school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_student_leaves`, `school_timetable`, `school_classes`, `school_subjects`, `school_exam_sessions`, `school_report_card_meta`, `school_fee_accounts`, `school_fee_items`, `school_fee_payments`, `school_fee_receipts`, `school_circulars`, `school_library`, `school_library_issues`, `school_certificate_requests`, `school_transport`, `institutes`, `parent_student_links`.

### D. Nayi tables (sirf tab jab VERIFY-FIRST mein na milen)

`school_quizzes` + `school_quiz_attempts` (N4 — quiz ki real table nahi dikhi), `school_student_goals` (N6), `school_notifications` (N10 — teacher MD wali hi table, doosri nahi banegi), `school_student_queries` (N14). `school_teacher_messages` / `school_behaviour_notes` / `school_teacher_leaves` is document ki nahi hain (teacher MD ki hain). Har ek par RLS mandatory hai — student sirf apna data.

---

## Aakhri note (Maalik ke liye)

Ye document student dashboard ko "screens ka set" se "meri progress ka workspace" banane ka plan hai. Sabse pehla kaam STU1 hai — fake schedule, fake tests aur jhootha 94.2% hatana. Uske bina aage ka har chart aur har Excel bekaar hai, kyunki dashboard par bharosa hi nahi hoga. Step 13.2 mein UI theek ho gaya tha — ab usi UI ke andar **sachha data** daalna hai. Isliye order mat badalna: **pehle sachha data, phir charts, phir Excel, phir naye features.** Aur ek baat — student ki reports hamesha sirf uski apni hongi; privacy test STU7 mein sabse important hai, usko halke mein mat lena.
