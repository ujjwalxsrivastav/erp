# School ERP — Teacher Dashboard Deep-Dive (Enterprise Upgrade)

## Dashboard #1 — Teacher (pehle teacher, phir baaki dashboards)

**Status:** Analysis document — isme koi code change nahi hai. Ye file Gemini ko di jayegi, Gemini isko line-by-line execute karega.
**Repo state (verified, analysis ke waqt):** `origin/main` = `7cce8af` — "Enterprise NEP 2020 Lesson Plan Studio". Local clone (`~/workspace/erp`, main `1652552`) stale hai, isliye analysis `origin/main` ke archive se ki gayi hai, local clone se nahi. Analysis ke baad repo mein koi change nahi kiya gaya hai.
**Scope lock:** Is document ka kaam SIRF teacher dashboard aur teacher se jude screens tak hai. Baaki dashboards (Admin, Student, Parent) is document mein nahi banenge — unka number Part F mein roadmap ke roop mein hai.
**Ye document Core Modules README ko replace nahi karta.** Admin / HR / Admission / Fees / Reports / Excel Import wala kaam (Core Modules README, Steps 1–8) alag track hai. Jahan dono overlap karte hain (Excel standard, Reports), wahan isi document mein Core Modules wala standard reuse hoga — doosra standard invent nahi hoga.

---

## 0. Kaise padhna hai (How to Read)

- **Part A — YE YE HAI:** Aaj teacher dashboard mein kya-kya maujood hai, file aur route ke saath. Har cheez repo se verify ki gayi hai — koi feature "hai" nahi kaha gaya jab tak file mein nahi dikha.
- **Part B — KAMI KYUN HAI:** Enterprise feel kyun nahi aa raha — seedhi baat, saboot ke saath.
- **Part C — YE YE KARNE JA RAHA HUN:** Do hisse — **C1 NEW (extra)** aur **C2 MODIFY (isi mein badlav)**. Har feature mein likha hai: kya hai, kyun chahiye, kahan dikhega, data kahan se aayega, aur uska graph/Excel kya hoga.
- **Part D — Reports catalogue:** Teacher ki har report — graph + Excel, dono ke saath. Koi report sirf list nahi hogi.
- **Part E — Gemini execution plan:** Steps, verification, checkpoint, hard rules.
- **Part F — Dashboard-by-dashboard roadmap:** Teacher ke baad ka order.
- **VERIFY-FIRST ka matlab:** Execution ke waqt pehle file/table dhoondhni hai. Agar cheez pehle se maujood nikli to dobara nahi banani — sirf dashboard se link/queue banana hai. Agar nahi mili to hi nayi banani hai.

## 0.1 Non-negotiables (har step par laagu)

1. **College ERP kabhi nahi tootega.** Sirf `lib/features/school/` + `lib/services/school_service.dart` + `school_*` tables + nayi `school_*` tables chhoo sakte hain. College screens, college tables, college routes — zero touch.
2. **Koi fake/mock/invented data nahi.** Koi number, list ya schedule haath se nahi likha jayega. Data na mile to empty state dikhega ("koi data nahi"), kabhi jhootha number nahi.
3. **Har nayi table par RLS.** Bina RLS ke koi table live nahi jayegi. Teacher sirf apni classes aur apne subjects ka data dekhega — kisi aur teacher ki class ka data kabhi nahi.
4. **Har step ke baad verification + commit + CHECKPOINT.** Bina verification ke agla step nahi. Har step ka commit message: `teacher-dash: T<n> — <title>`.
5. **Deploy pipeline ka note:** 4 Nov 2026 ko GitHub Pages deploy 4 baar fail hua tha (workflow 'Deploy Flutter Web to GitHub Pages'). Isliye Gemini har step ke baad `flutter analyze` + `flutter build web` locally chalayega aur result CHECKPOINT mein likhega. Push karna Maalik ka faisla hai — Gemini khud push karke pipeline par nahi chhodega jab tak Maalik na kahe.
6. **Payroll is document ka hissa nahi hai** (Maalik ke faisle par pending hai — Core Modules mein bhi deferred hai).
7. **Fee collection teacher ka kaam nahi hai.** Reports mein Fees tab admin-only hi rahega — teacher ko fee ka data nahi dikhega.

## 0.2 Dashboard-by-dashboard roadmap (poori picture)

| # | Dashboard | Aaj ki haalat (verified) | Is deep-dive mein |
|---|---|---|---|
| 1 | **Teacher** (`/school/teacher-dashboard`) | Screens maujood hain, par KPI fake hai, koi chart nahi, koi Excel nahi, koi analytics nahi | **YE DOCUMENT — poora deep-dive** |
| 2 | Admin / sadmin (`/school/admin-dashboard`) | Step 13.1 mein command center overhaul ho chuka hai (Morning Pulse, approvals queue, UDISE+ sheet) | Baad mein — analytics + Excel parity ka deep-dive, order Maalik ke next call par |
| 3 | Student (`/school/student-dashboard`) | Step 13.2 mein light-theme overhaul ho chuka hai (passport card, KPI tiles, schedule timeline) | Baad mein — order Maalik ke next call par |
| 4 | Parent (`/school/parent-dashboard`) | Multi-child switcher, live metrics, PTM booking, grievance tickets maujood hain (Step 10) | Baad mein — order Maalik ke next call par |

Suggestion (impose nahi): Teacher ke baad Admin ka deep-dive lena behtar hai, kyunki Admin command center se hi teacher ke naye features (approvals, messaging audience, substitution) control honge.

## 0.3 Benchmark — tagde level ke school ERP mein teacher portal kaisa hota hai

Leading school ERPs (ScoolsPRO, ScholarERP, EduSaaS-class platforms) ke teacher portals mein ye cheezein **standard** hain — inhi se compare karke is document ki kami list bani hai:

- **One-tap attendance** — class-wise register, Present/Absent/Late, parents ko instant absence alert.
- **Gradebook + analytics** — marks ek baar daalo, grade/GPA/rank auto, performance ke charts (trend, distribution, subject-wise average).
- **Timetable + substitute alerts** — apna schedule, substitution ki khabar, period-wise status.
- **Parent communication** — class announcements aur homework updates seedha parents tak.
- **Reports har format mein** — PDF, Excel aur CSV export; 100+ report templates wale systems mein har list ka export hota hai.
- **At-risk flagging** — attendance <75%, marks girna, homework miss — ek jagah flagged students.
- **Homework/assignment tracking** — submission counts, late/missing status, grading queue.

Inme se humare system mein attendance, marks, homework, timetable, lesson plans **maujood** hain — par analytics, Excel, parent messaging, at-risk flagging aur dashboard-level reporting **nahi** hain. Wahi gap is document mein bhara ja raha hai.

---

## Part A — YE YE HAI (Existing teacher features, repo-verified)

### A1. Teacher dashboard shell

- **File:** `lib/features/school/school_teacher_dashboard.dart` (879 lines)
- **Route:** `/school/teacher-dashboard`
- **Header:** AppBar mein "Teacher & Faculty Workspace" + date + Refresh + Logout. **Gap (pehle se note):** subtitle mein institute ka naam haath se likha hai — `'Shivalik International School • $dateStr'`. Multi-institute system mein ye DB se aana chahiye (Modify M3).
- **Hero card:** Teacher ka naam (`getTeacherDisplayName`), class-teacher wali class (`getClassTeacherClasses` — pehli class dikhti hai, baaki nahi), FACULTY badge, aur "Register" button jo seedha `/school/attendance` par le jaata hai.
- **Pull-to-refresh + Refresh button:** maujood hai (`_loadData` dobara chalta hai).
- **Drawer (12 entries):** Dashboard, Lesson Plans & 5E Studio, Enter & Upload Marks, Bulk CSV Marks Upload, Report Cards & HPC, Exam Sessions & Date Sheet, Daily Attendance, Homework & Tasks, Leave Approvals, Class Timetable, Official Circulars, School Library, Logout. **Gap:** Drawer mein **Reports ka entry nahi hai** — teacher reports tak dashboard se pahunch hi nahi sakta (Modify M5).

### A2. KPI grid (4 cards) — yahan sabse bada jhooth hai

| Card | Aaj ka source | Haalat |
|---|---|---|
| Attendance Today — `38 / 42`, `90% Rate` | **Haath se likhe constants** (`_totalStudents = 42`, `_presentToday = 38`) | FAKE — DB se nahi aata |
| Homework to Grade — pending count | Real — `getPendingHomeworkToGrade(username)` | Sahi, par sirf count; queue nahi |
| Classes Today — lectures count | Real — `getTeacherTimetable(username)` ki length | Sahi |
| Leave Approvals — pending count | Real — `getLeaveRequestsForClassTeacher(username)` ki length | Sahi, par sirf count; top pending nahi dikhte |

KPI cards par tap karne se sahi screens khulti hain (attendance / homework / timetable / leave) — par card ke andar **koi drill-down nahi** (jaise aaj kaun absent hai, kaunsi homework pending hai).

### A3. Examination & Marks Master (dashboard section)

- **Enter / Edit Marks** → `/school/marks-entry` (1,389 lines): class + subject + exam select karke marks entry; per-student remarks; **Scholastic tab + Co-Scholastic tab** (co-scholastic areas par grade, teacher remark); stats summary ribbon; batch action toolbar; bottom save dock; marks validation (0 se max marks ke beech); save ke baad report card remarks + co-scholastic grades save hote hain (`saveCoScholastic`).
- **Bulk CSV Upload** → `/school/marks/csv`: spreadsheet se class marks import (CSV; Excel file ka seedha import nahi — Modify M6 mein .xlsx import bhi aayega).
- **Report Cards & HPC** → `/school/report-card`: CBSE Holistic Progress Card standard, 9-point grading, 360-degree co-scholastic domains (Work Education, Arts, Sports, Discipline), QR verification seal, Principal digital signature, promotion engine se linkage (Step 9). Dashboard se "All Cards" bhi isi par jaata hai.
- **Exam Sessions & Date Sheet** → `/school/examination`: exam sessions aur date sheet (examination controller module). Dashboard ke main sections mein iska tile nahi hai — sirf drawer mein hai (Modify M11: parity).

### A4. Daily Operations (7 tiles)

| Tile | Route | Aaj kya hai |
|---|---|---|
| Daily Attendance | `/school/attendance` (2,131 lines) | Daily Register + Monthly Register + **CBSE Defaulters (<75%)** tabs; P/A/L/Leave KPI strip; search + batch "All Present"; student-wise P/A/L segmented selector; lock/unlock ke saath edit; note save; loading skeleton + error view + retry. **Monthly heatmap** bhi hai (attendance overhaul commit). Par **koi trend chart nahi, koi Excel export nahi** (reports hub se attendance PDF/CSV hota hai, dashboard se nahi). |
| Lesson Plan & 5E Studio | `/school/lesson-plans` (1,909 lines) | NEP 2020 Studio: 5 tabs — Pacing & Syllabus, 5E Lesson Studio, Authoring Wizard, Principal Scrutiny (HOD scrutiny desk), Reflective Diary & Remedial. Bloom's Taxonomy colours, exam countdown, Avg Concept Mastery %, Approved/ Taught plans count, Remedial sessions count, syllabus velocity matrix. Ye screen kaafi deep hai — par dashboard par iska **koi status card nahi** (kitne plans scrutiny mein atke hain, syllabus kitna peeche hai — Modify M9). |
| Homework & Tasks | `/school/homework` (959 lines) + `/school/homework/add` | Homework list (active + past); teacher ko per-homework **real submission count** aur **submission list** dikhti hai (`getHomeworkSubmissionCounts`, `getHomeworkSubmissions`); student ka apna submission record bhi hai. **Gap:** grading ka dedicated queue nahi — count se list tak jaana padta hai, aur grade/remark per submission ka flow dashboard se verify karna hai (New N12, VERIFY-FIRST). |
| Leave Requests | `/school/leave` | Class teacher apni classes ki student leave approve/reject karta hai; pending + reviewed lists; reject par reason mandatory; approve par attendance **excused** mark ho jaati hai; sirf class teacher ko approve/reject ka haq hai (doosre teacher ko warning dikhti hai). Dashboard par sirf count hai — kaunsi leave pending hai, ye nahi dikhta (Modify M10). |
| Class Timetable | `/school/timetable` (1,787 lines) | Week view, period timeline cards, **substitution coverage desk** (uncovered slots, load-balanced recommendations), **syllabus tracker** (taught vs planned). Dashboard par "Today's Teaching Schedule" dikhta hai (neeche A5). |
| Official Circulars | `/school/circulars` | School events aur exam notifications; category chips; publish CTA ke saath empty state. Dashboard se sirf **padhna** — teacher ki taraf se apni class ko notice bhejna dashboard se nahi hota (New N4, VERIFY-FIRST: circulars ki audience model dekhni hai). |
| Library Books | `/school/library` | Resource search aur issued titles. Teacher ke liye read-only use — theek hai, isme koi badlav nahi (sirf drawer/dashboard parity mein rahega). |

### A5. Today's Teaching Schedule (dashboard section)

- Real data: `getTeacherTimetable(username)` se aaj ka schedule; har period par subject, class, room, time, period badge, aur **"Take Attendance"** button.
- **Gap 1:** Agar service khaali list de to pehle se likha hua fallback schedule dikhta hai — Mathematics, Class 10-A/10-B/9-A, Room 201/301/101. Ye demo data hai, live system mein kabhi nahi dikhna chahiye (Modify M2).
- **Gap 2:** Room ka default `'Room 201'` hai jab room na mile — jhootha room dikhane se behtar hai room na dikhana.
- **Gap 3:** Attendance button har period ko generic `/school/attendance` par le jaata hai — class/period pre-select nahi hota, aur ye nahi pata chalta ki us period ki attendance mark ho chuki hai ya nahi (New N13).
- **Gap 4:** "Weekly View" button timetable par le jaata hai — theek hai.

### A6. Reports hub (maujood hai, par teacher se kata hua)

- **File:** `lib/features/school/reports/school_reports_screen.dart` (2,687 lines), **Route:** `/school/reports`
- **Tabs:** Morning Briefing (operational briefing + full attendance), Fees (**admin-only**), Marks & Merit (Half Yearly/Annual filter + rank-wise list), Homework, UDISE+ (38-field statutory export).
- **Exports (maujood):** `lib/services/school_export_service.dart` — Class Results PDF/CSV, Attendance PDF/CSV, Pending Fees PDF/CSV, UDISE export. **Par:** (a) koi `.xlsx` export nahi hai — `excel: ^4.0.2` pubspec mein hai par **school vertical mein kahin use nahi hota**; (b) **school vertical mein `fl_chart` ka ek bhi use nahi hai** — `fl_chart: ^0.65.0` pubspec mein pada hai, par koi chart kahin render nahi hota; (c) teacher dashboard se `/school/reports` ka **koi link nahi hai**.
- Reports hub aaj admin-flavoured hai (Morning Briefing principal ka hai). Teacher ke liye teacher-scoped tabs chahiye — Part D mein alag catalogue hai.

### A7. Teacher ke liye maujood service methods (`lib/services/school_service.dart`, 6,882 lines)

`getTeacherDetails`, `getTeacherTimetable` (day filter ke saath), `getTeacherClasses`, `getTeacherAssignments`, `getTeacherNames`, `getTeacherDisplayName`, `getTeacherDailyLoad` (day-wise load), `getSubstitutionLogs` (date filter ke saath — **service maujood hai, dashboard par dikhta nahi**), `getPendingHomeworkToGrade`, `getPendingHomeworkCount`, `getClassTeacherClasses`, `getClassTeacherForClass`, `getLeaveRequestsForClassTeacher`, `getCoScholastic`, `saveCoScholastic`, `getHomeworkSubmissions`, `getHomeworkSubmissionCounts`.

### A8. Teacher se jude maujood tables (database/*.sql se)

`school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_students`, `school_teachers`, `school_timetable`, `school_classes`, `school_subjects`, `school_exam_sessions`, `school_report_card_meta`, `school_student_leaves`, `school_circulars`, `school_library`, `school_library_issues`, `institutes`, `parent_student_links`.

---

## Part B — KAMI KYUN HAI (enterprise feel kyun nahi aa raha)

Seedhi baat — screens ban gayi hain, par dashboard **dikhawa** zyada aur **kaam** kam karta hai:

1. **Sabse bada kaaran — jhootha KPI.** Attendance Today `38/42` haath se likha hai. Jis dashboard ka pehla number hi fake ho, us par koi principal ya teacher bharosa nahi karega. Enterprise system mein dashboard ka har number ka source hota hai aur tap karne par uski detail khulti hai.
2. **Koi chart nahi.** `fl_chart` dependency maujood hai, par school vertical mein ek bhi chart render nahi hota. Attendance ka trend, marks ka distribution, homework completion — sab sirf list ya count hai. Bina visual ke "analysis" nahi hoti, sirf "record" hota hai.
3. **Koi Excel nahi.** `excel` package maujood hai, par school mein ek bhi `.xlsx` export nahi banta. Reports hub mein PDF/CSV hai — par school ko board, audit aur apne record ke liye Excel chahiye hota hai, aur teacher ko apni class ka gradebook Excel mein chahiye hota hai.
4. **Teacher apni class ko nahi dekh sakta.** "My Students" hi nahi hai — class roster, student profile (attendance % + marks + homework + leave ek jagah), search — kuch nahi. Teacher ko student ka poora picture dekhne ke liye 4 screens ghoomni padti hain.
5. **Reports teacher se kate hue hain.** Reports hub hai, par dashboard se uska link hi nahi hai, aur hub admin-flavoured hai. Teacher apni class ki report ek jagah se nahi nikaal sakta.
6. **Communication nahi hai.** Teacher apni class ke parents ko notice/homework update seedha nahi bhej sakta. Parent ko khabar sirf absence alert ya PTM booking se milti hai.
7. **Substitution, apni leave, PTM, behaviour — dashboard par nahi.** `getSubstitutionLogs` service maujood hai par dashboard par "aaj meri substitution" kahin nahi dikhta. Teacher ki apni leave ka flow, PTM slots, behaviour notes — dashboard se gayab hain.
8. **Error chhup jaata hai.** `_loadData` mein `catch (_)` khaali hai — service fail ho to dashboard chupchaap purana/fallback data dikhata rahega, teacher ko pata bhi nahi chalega ki data load nahi hua.
9. **Period-level kaam adhoora hai.** Period ka attendance button generic screen kholta hai; ye nahi pata ki kaunsa period mark ho gaya, kaunsa baaki hai.
10. **At-risk bachon ka koi signal nahi.** Attendance <75% ka defaulters tab attendance screen ke andar hai, par dashboard par "in bachon par dhyan do" ki koi list nahi — na marks girne ka, na homework miss hone ka.
11. **Institute ka naam, fallback schedule, default room — haath se likhe hue.** Ye teeno chhoti cheezein milkar system ko "demo" jaisa feel deti hain, "enterprise" jaisa nahi.

---

## Part C — YE YE KARNE JA RAHA HUN

### C1. NEW (extra) features — pehle nahi the, ab banenge

Har feature mein: **kya hai / kyun / kahan dikhega / data kahan se / graph-Excel**.

#### N1. My Students — class roster + student profile sheet (sabse pehle, sabse zaroori)

- **Kya hai:** Teacher ki har class (class-teacher wali + subject wali) ka roster. Har student ki ek profile sheet: photo/initials, roll no, attendance % (is mahine + poore session), latest exam ka result (subject-wise marks + grade), homework status (submitted / late / missing count), active leave, behaviour notes count. Student par tap → poori sheet khulegi (attendance trend mini-chart + marks trend + homework list).
- **Kyun:** Bina iske teacher student ko "record" ki tarah dekhta hai, "bacha" ki tarah nahi. Enterprise teacher portal ki pehchaan hi student 360° view hai.
- **Kahan dikhega:** Dashboard par naya section "My Students" (class filter chips ke saath) + drawer entry. Search box: naam se student dhoondhna (Modify M12 ke saath).
- **Data kahan se:** Sab maujood hai — `school_students`, `school_attendance`, `school_marks`, `school_homework_submissions`, `school_student_leaves`. **Koi nayi table nahi.**
- **Graph/Excel:** Profile sheet mein attendance trend (line chart) + marks trend (line chart); poori class ka roster **Excel export** (T-R02 family — Part D).

#### N2. Teacher Analytics section (dashboard par charts)

- **Kya hai:** Dashboard par ek naya "My Class Analytics" section — 4 charts: (a) meri classes ki attendance trend, pichhle 30 din (line chart); (b) class performance distribution — kitne bachon ne A/B/C/D grade liya, latest exam (bar chart); (c) subject-wise average — mere subjects ka average ek saath (bar chart); (d) homework completion % — submitted/late/missing (donut chart). Har chart par tap → uski poori report (Part D).
- **Kyun:** Yehi wo cheez hai jo dashboard ko "enterprise" banati hai — teacher ko ek nazar mein pata chale ki class kidhar ja rahi hai.
- **Kahan dikhega:** Dashboard par KPI grid ke neeche, marks section se pehle.
- **Data kahan se:** `school_attendance`, `school_marks`, `school_homework_submissions` — sab maujood. Aggregation `school_service.dart` mein naye methods se hogi (ek method per chart, testable).
- **Graph/Excel:** Charts `fl_chart` se (school mein pehla asli use). Har chart ke saath **Excel export** button (Part D: T-R01, T-R04, T-R05, T-R07).

#### N3. My Reports hub (teacher-scoped)

- **Kya hai:** Teacher ke liye alag reports hub — sirf uski classes aur subjects. Poora catalogue Part D mein hai (T-R01 se T-R12). Har report mein: filter (class, subject, exam, date range), **graph + Excel dono**, aur drill-down (report se seedha student/marks/attendance screen).
- **Kyun:** Aaj reports hub admin ka hai aur dashboard se kata hua hai. Teacher ko apni report ke liye admin ke hub mein nahi jaana chahiye.
- **Kahan dikhega:** Dashboard par "My Reports" section + drawer entry → `/school/reports` ka teacher-scoped view (wahi screen, teacher role par sirf teacher tabs; Fees tab admin-only hi rahega).
- **Data kahan se:** Maujood tables + N2 wali aggregation methods.
- **Graph/Excel:** Har report — Part D dekho. Koi report sirf-list nahi hogi.

#### N4. Class announcements + parent messaging (teacher → apni class ke parents)

- **Kya hai:** Teacher apni class ke parents ko notice bhej sake: class announcement (test ki date, PTM, trip) aur homework update. Har message ka delivery log (kab, kis class ko, kisne bheja). Parents ko ye unke dashboard/notices mein dikhega (parent side ka display parent dashboard deep-dive mein hoga — is document mein sirf teacher ka bhejna hai).
- **Kyun:** Enterprise ERPs mein parent communication teacher portal ka core part hai. Aaj teacher ke paas parents tak pahunchne ka koi raasta hi nahi hai.
- **Kahan dikhega:** Dashboard par "Message Parents" tile + drawer entry; message list (sent history) ke saath.
- **Data kahan se — VERIFY-FIRST:** Pehle `school_circulars` ki audience model dekho. Agar circulars mein class-wise audience pehle se hai to **wahi extend karo** (teacher ko class-audience wala circular banane ka haq do, admin approval ke saath ya bina — ye rule Maalik se confirm karke CHECKPOINT mein likhna hai). Agar audience model nahi hai to **nayi table** `school_teacher_messages` (id, teacher_id, class_id, subject, body, created_at) + RLS (teacher sirf apni classes ko bhej sake; parent sirf apni class ke messages dekh sake).
- **Graph/Excel:** Is feature ki report: messages sent per class (list + Excel — T-R13, Part D ke baad note mein).

#### N5. My Substitution — "aaj meri substitution"

- **Kya hai:** Dashboard par ek card: aaj mujhe kis teacher ki jagah, kis class, kis period mein jaana hai; hafte ki substitution list bhi. Substitution accept/acknowledge ka button (acknowledge karne par status badle — substitution desk ko dikhe).
- **Kyun:** Service maujood hai (`getSubstitutionLogs`), par teacher ko pata hi nahi chalta ki use kisi aur ki class leni hai — ye to substitution desk ka sabse basic kaam hai.
- **Kahan dikhega:** Dashboard par Today's Schedule ke upar ek compact card (agar aaj substitution hai to highlighted, nahi hai to chhota "aaj koi substitution nahi" line).
- **Data kahan se:** `getSubstitutionLogs` + timetable substitution desk ka data — **nayi table nahi** (sirf UI + acknowledge status, jo substitution desk ke existing flow se lena hai — VERIFY-FIRST).
- **Graph/Excel:** Weekly substitution load — bar chart + Excel (T-R11).

#### N6. Teacher ki apni leave (apply + status + history)

- **Kya hai:** Teacher apni leave apply kare (dates, reason, type), apni leave ka status dekhe (pending/approved/rejected), aur history dekhe. Leave approve hone par substitution desk ko automatic signal jaye (morning coverage se linkage — timetable module mein substitution desk pehle se hai).
- **Kyun:** Aaj dashboard par sirf **student** leave approvals hain — teacher ki apni leave ka koi flow dashboard se nahi hai. Enterprise HR mein staff leave basic hai.
- **Kahan dikhega:** Dashboard par "My Leave" tile + drawer entry (student "Leave Approvals" se alag — dono ka naam alag rahega taaki confusion na ho).
- **Data kahan se — VERIFY-FIRST:** Pehle dhoondho ki school teacher-leave ka flow pehle se kahan hai (Step 10 note kehta hai "teacher leaves linked to morning coverage" — ho sakta hai college HR se linked ho). Agar college HR ka leave flow school teacher par chalta hai to **wahi reuse karo**, naya flow mat banao. Agar nahi chalta to **nayi table** `school_teacher_leaves` (teacher_id, dates, reason, type, status, approver, created_at) + RLS + substitution desk ko signal.
- **Graph/Excel:** Leave summary — list + Excel (T-R10 family).

#### N7. Behaviour / discipline notes (per student)

- **Kya hai:** Teacher kisi student par note likh sake — positive (participation, improvement) ya concern (discipline, homework miss, behaviour). Har note: student, date, type, note text, teacher. Class teacher + admin dekh sakein. Parent ko dikhana hai ya nahi — **ye rule Maalik se confirm karna hai** (default: parent ko nahi, sirf teacher + admin; Maalik haan kahe to parent view parent dashboard deep-dive mein aayega).
- **Kyun:** Enterprise ERPs mein pastoral care ka record hota hai — bina iske teacher ke paas student ke behaviour ka koi history nahi rehta, aur PTM mein bolne ko kuch nahi hota.
- **Kahan dikhega:** Student profile sheet (N1) ke andar "Notes" tab + dashboard par "Recent Notes" ki chhoti list.
- **Data kahan se:** **Nayi table** `school_behaviour_notes` (id, student_id, teacher_id, class_id, type, note, created_at) + RLS (teacher sirf apni classes ke students par note likh/dekh sake).
- **Graph/Excel:** Notes summary per class — list + Excel (T-R14 note, Part D ke baad).

#### N8. Attention Needed — at-risk students ki ek list

- **Kya hai:** Dashboard par ek "Attention Needed" list — wo students jinke baare mein rule-based signal hai: (a) attendance <75% (CBSE rule — defaulters tab mein ye rule pehle se hai); (b) latest exam mein average se 20% neeche ya fail grade; (c) pichhli 3 homework mein se 2+ missing. Har entry mein **reason likha hoga** (kaunsa rule trigger hua) — koi black-box score nahi, koi AI claim nahi.
- **Kyun:** Yehi wo feature hai jo teacher ko "kahan dhyan dena hai" batata hai — bina iske teacher ko har student ko ek-ek karke check karna padta hai.
- **Kahan dikhega:** Dashboard par analytics section ke neeche, red/amber highlight ke saath; entry par tap → student profile sheet (N1).
- **Data kahan se:** `school_attendance` + `school_marks` + `school_homework_submissions` — sab maujood. Rules `school_service.dart` mein ek method mein likhe jayenge taaki rule badalna aasan ho.
- **Graph/Excel:** At-risk list ka Excel export (T-R03 family).

#### N9. Exam countdown + datesheet widget

- **Kya hai:** Dashboard par ek chhota widget: agla exam kitne din mein hai, uska naam, aur us exam ki date sheet ka link. (Lesson plan screen mein exam countdown pehle se hai — wahi data dashboard par laana hai.)
- **Kyun:** Teacher ka saara kaam exam ke around ghoomta hai — ye widget dashboard ko "aaj kya zaroori hai" wali feeling deta hai.
- **Kahan dikhega:** Dashboard par schedule section ke upar ek slim banner.
- **Data kahan se:** `school_exam_sessions` — maujood. **Nayi table nahi.**

#### N10. My PTM slots

- **Kya hai:** Teacher apne PTM slots dekhe (kaunsa parent, kis student ke liye, kab), aur slot ka status (booked / done / no-show) update kare.
- **Kyun:** Parent side par PTM booking maujood hai (Step 10) — par teacher side par apne slots dekhne ka koi flow dashboard se nahi hai. Dono taraf ka flow poora hona chahiye.
- **Kahan dikhega:** Dashboard par "PTM" tile + drawer entry (chhota section — PTM ka poora system dobara nahi banana).
- **Data kahan se — VERIFY-FIRST:** Parent PTM booking wali table dhoondhni hai (Step 10 mein PTM slot booking ID maujood hai — wahi table reuse karni hai). **Nayi table sirf tab jab PTM table hi na mile.**

#### N11. Weekly teaching load view

- **Kya hai:** Mere hafte ka load — din-wise lectures (bar chart), total periods, free periods, substitution load alag se. Load zyada ho (jaise ek din mein 7 periods) to highlight.
- **Kyun:** `getTeacherDailyLoad` service maujood hai par kahin dikhta nahi. Enterprise ERPs mein teacher workload balance dekhna admin + teacher dono ke liye standard hai.
- **Kahan dikhega:** Dashboard par schedule section ke andar "Week View" toggle, ya reports hub mein (T-R12).
- **Data kahan se:** `getTeacherDailyLoad` + `getTeacherTimetable` — maujood.
- **Graph/Excel:** Bar chart + Excel (T-R12).

#### N12. Homework grading queue

- **Kya hai:** Dashboard par "Grade Karna Hai" ki queue — har entry: homework title, class, due date, submitted count, late count, missing count, aur "Grade Karo" button jo seedha us homework ki submission list par le jaye. Queue mein sabse pehle wo homework jinki due date nikal gayi hai.
- **Kyun:** Aaj dashboard sirf count batata hai ("5 Pending") — teacher ko ye nahi pata ki kaunsi homework, kis class ki, kitni late hai. Count se kaam nahi hota, queue se hota hai.
- **Kahan dikhega:** Dashboard par KPI card ke neeche expandable queue (top 5 + "View all" → homework list).
- **Data kahan se — VERIFY-FIRST:** Pehle homework list screen mein grading action dhoondhna hai (marks/remark per submission). Agar grading action maujood hai to **sirf queue + deep-link** banana hai, grading dobara nahi. Agar nahi hai to grading action (per-submission marks/remark save) bhi isi feature mein banana hai — data `school_homework_submissions` mein hi jayega (grade/remark columns VERIFY-FIRST — na hon to migration ke saath add karna hai).
- **Graph/Excel:** Homework completion + grading pending — donut + Excel (T-R07, T-R08).

#### N13. Period-wise attendance state

- **Kya hai:** Today's schedule mein har period par status badge: "Marked" (hara) ya "Pending" (amber). "Take Attendance" button us period ki class + period pre-select karke attendance screen khole. Din ke ant mein "aaj ke saare periods marked" ka confirmation state.
- **Kyun:** Aaj button generic screen kholta hai aur teacher ko yaad rakhna padta hai ki kaunsa period ho gaya. Period-level tracking enterprise attendance ka basic hai.
- **Kahan dikhega:** Today's Teaching Schedule section ke andar (Modify M2 ke saath).
- **Data kahan se:** `school_attendance` (period ka column VERIFY-FIRST — agar period-wise attendance store nahi hoti to period column + migration isi feature mein aayegi, bina purana data tode).
- **Graph/Excel:** Period-wise attendance register — Excel (T-R02 family).

#### N14. Notifications / inbox (chhota, par zaroori)

- **Kya hai:** Dashboard par ek bell icon + inbox: naye circulars, substitution alerts, leave request aayi, PTM booked, lesson plan scrutiny ka faisla (approved/returned). Har notification par tap → sahi screen. Read/unread state.
- **Kyun:** Teacher ko har cheez ke liye alag screen check nahi karni chahiye — alerts ek jagah aane chahiye. Ye enterprise feel ka chhota par bada hissa hai.
- **Kahan dikhega:** AppBar mein bell icon + inbox screen (drawer mein "Notifications" entry).
- **Data kahan se — VERIFY-FIRST:** Pehle dekho ki notifications ka koi system pehle se hai ya nahi (circulars, substitution alerts, PTM — inke events maujood hain). Agar koi central table nahi hai to **nayi table** `school_notifications` (user_id, type, title, body, link_route, is_read, created_at) + RLS (sirf apni notifications). Events ko notification banane ka kaam har feature ke step mein jodna hai — alag se bada system nahi banana.
- **Graph/Excel:** Nahi — inbox ki report nahi hoti. Sirf list + read/unread.

---

### C2. MODIFY — isi mein badlav (pehle se hai, par adhoora/galat hai)

#### M1. KPI "Attendance Today" — fake number se real number tak (sabse pehla fix)

- **Aaj:** `38 / 42` haath se likha hai.
- **Badlav:** Class-teacher wali class(es) ki **aaj ki real attendance** `school_attendance` se aayegi (present / total, % badge real). Agar aaj ki attendance abhi mark nahi hui hai to card par "Not marked yet" dikhega aur tap karne par attendance screen khulegi — **kabhi jhootha number nahi**. Card par tap → aaj ke absentees ki list (drill-down).
- **Verification:** Live DB par test — aaj ki attendance mark karo, dashboard ka number badalna chahiye; attendance na mark ho to "Not marked yet" dikhna chahiye.

#### M2. Today's schedule — fallback schedule aur default room hatana + period pre-select

- **Aaj:** Service khaali de to Mathematics 10-A/10-B/9-A ka likha hua schedule dikhta hai; room na mile to 'Room 201'.
- **Badlav:** (a) Fallback schedule **poora delete** — koi lecture na ho to "No lectures scheduled for today. Free day!" wala empty state hi dikhega (ye empty state pehle se hai, use hi rakhna hai). (b) Room na mile to room chip hi nahi dikhega. (c) "Take Attendance" button period-scoped hoga (N13 ke saath) — class + period pre-select.
- **Verification:** Aisi teacher se login karo jiska aaj koi lecture nahi hai — fallback schedule **kabhi nahi** dikhna chahiye.

#### M3. Institute ka naam — hardcoded se DB tak

- **Aaj:** AppBar subtitle mein `'Shivalik International School'` haath se likha hai.
- **Badlav:** `institutes` table (ya institute settings — VERIFY-FIRST: kahan se institute ka naam aata hai, admin dashboard mein kya use hota hai) se institute ka naam aayega. Na mile to sirf date dikhegi, galat naam kabhi nahi.

#### M4. Silent error — chhupi hui failure se dikhne wali failure tak

- **Aaj:** `_loadData` mein `catch (_)` khaali hai — service fail ho to dashboard chupchaap purana data dikhata rahega.
- **Badlav:** Step 13 ke 4-state standard ke hisaab se — loading skeleton, loaded, **error state with retry button**, empty state with CTA. Error par user ko pata chalna chahiye ki data load nahi hua aur retry kar sakta hai.
- **Verification:** Network/service fail karke dekho — error state + retry dikhna chahiye, fallback data nahi.

#### M5. Reports tak pahunch — dashboard + drawer mein "My Reports" jodna

- **Aaj:** Teacher dashboard aur drawer mein `/school/reports` ka koi link nahi hai.
- **Badlav:** Dashboard par "My Reports" section + drawer entry. Reports screen par teacher role ke liye **sirf teacher-scoped tabs** dikhenge (Morning Briefing principal ka hai — teacher ko nahi; Fees tab admin-only hi rahega; Marks & Merit aur Homework tabs teacher-scope mein chalenge). Teacher-scoped report ka data sirf uski classes/subjects tak limited rahega (service layer par filter, sirf UI par nahi).
- **Verification:** Teacher login se reports kholo — kisi aur teacher ki class ka data **kabhi nahi** dikhna chahiye; Fees tab nahi dikhna chahiye.

#### M6. Marks gradebook — analytics strip + Excel export + .xlsx import

- **Aaj:** Marks entry mein stats ribbon hai, par class-level analytics (average, distribution, toppers, weak students) nahi hai; CSV import hai, Excel export/import nahi hai.
- **Badlav:** (a) Marks entry screen ke upar class analytics strip — class average, highest/lowest, grade distribution (mini bar chart), top 3 + attention wale students (N8 ke rules se). (b) **Class gradebook ka .xlsx export** — `excel` package se (pubspec mein maujood, school mein unused): Summary sheet + student × subject matrix + totals. (c) CSV import ke saath **.xlsx import** bhi (wahi dry-run validation wala pattern jo Core Modules ke Excel Import mein hai: template → dry-run → error file → commit).
- **Verification:** Ek class ka gradebook export karo — har student, har subject, total, grade sab match karna chahiye marks entry screen se.

#### M7. Attendance screen — trend chart + Excel export

- **Aaj:** Daily/Monthly/Defaulters tabs + KPI strip + heatmap maujood hain; chart nahi, Excel nahi (PDF/CSV reports hub se hota hai).
- **Badlav:** (a) Weekly attendance trend chart (class-wise %, line chart) Monthly tab ke upar. (b) Attendance register ka **.xlsx export** (date-wise rows + summary) — dashboard ke KPI se bhi yahi export khulna chahiye.
- **Verification:** Export ki har row attendance screen ki list se match karni chahiye.

#### M8. Homework screen — submission list se grading queue tak

- **Aaj:** Per-homework submission count + submission list maujood hai.
- **Badlav:** N12 wali queue ka doosra hissa — submission list mein per-submission grade/remark action (agar nahi hai to banana hai, VERIFY-FIRST), late/missing ka clear status chip, aur per-homework submission status ka **.xlsx export**.
- **Verification:** Ek homework grade karo — count, list aur export teeno mein wahi grade dikhna chahiye.

#### M9. Lesson plans — dashboard par status cards

- **Aaj:** Lesson plan screen kaafi deep hai (5E, Bloom's, scrutiny, reflective diary), par dashboard par uska koi nishaan nahi hai.
- **Badlav:** Dashboard par 3 chhote cards — (a) Scrutiny mein atke plans (count + list link), (b) Syllabus velocity — mere subjects mein planned vs taught % (mini progress bar), (c) Lagging alerts (jo topics peeche chal rahe hain). Data lesson plan screen ke wahi methods se aayega — dobara logic nahi likhna.
- **Verification:** Ek plan scrutiny mein bhejo — dashboard card ka count badhna chahiye.

#### M10. Leave approvals — count se queue tak

- **Aaj:** Dashboard par sirf pending count hai.
- **Badlav:** Dashboard par "Leave Approvals" card ke neeche top 3 pending leaves (student, class, dates, reason ki ek line) + "View all" jo leave screen par le jaye. Approve/reject ka action leave screen mein hi rahega (wahan remarks + mandatory rejection reason pehle se hai).
- **Verification:** Ek leave approve karo — dashboard count aur queue dono turant update hone chahiye.

#### M11. Drawer aur dashboard tiles ki parity

- **Aaj:** Drawer mein Examination hai, dashboard sections mein nahi; dashboard mein Reports nahi hai, drawer mein bhi nahi; dashboard par Library tile hai, drawer mein bhi hai — par dono jagah list alag-alag hai.
- **Badlav:** Ek hi source of truth — dashboard sections, grid tiles aur drawer entries **ek jaisi list** se banengi (koi tile ek jagah ho aur doosri jagah na ho, aisa nahi hoga). Final list: Dashboard, My Students (N1), My Reports (N3), Lesson Plans, Marks Entry, CSV Upload, Report Cards, Examination, Attendance, Homework, Leave Approvals, My Leave (N6), Timetable, Circulars, Library, Notifications (N14), Logout.
- **Verification:** Dashboard aur drawer ki list side-by-side compare karo — koi entry miss nahi honi chahiye.

#### M12. Search — naam se student dhoondhna

- **Aaj:** Dashboard par koi search nahi hai.
- **Badlav:** Dashboard ke upar search box — apni classes ke students ko naam se dhoondho, result par tap → student profile sheet (N1). Search sirf apni classes tak limited rahega.
- **Verification:** Doosri teacher ki class ka student search mein **kabhi nahi** aana chahiye.

#### M13. 4-state standard har jagah

- **Aaj:** Step 13 mein screens par 4-state (skeleton, empty+CTA, error+retry, loaded) ka daava hai, par teacher dashboard par error state nahi hai (M4) aur kuch sections mein empty state nahi hai.
- **Badlav:** Dashboard ke har section (KPI, schedule, queue, analytics, students) mein 4-state laagu hoga — loading mein skeleton, khaali mein empty+CTA, error mein retry, loaded mein data. 48dp minimum touch targets aur 8pt grid (Step 13 standard) poore dashboard par.
- **Verification:** Har section ko loading / empty / error / loaded — chaaron haalat mein screenshot-level check karna hai (Gemini khud batayega ki kaise test kiya).

#### M14. Timetable — taught vs planned status dashboard par

- **Aaj:** Timetable screen mein syllabus tracker hai (taught vs planned), par dashboard ke schedule items par ye nahi dikhta ki period padhaya gaya ya nahi.
- **Badlav:** Schedule item par chhota status — "Taught" (hara tick) ya "Pending" (amber). Teacher period ke baad "Taught" mark kar sake (syllabus tracker ka wahi flow — dobara nahi banana).
- **Verification:** Ek period ko taught mark karo — dashboard aur timetable dono mein wahi status dikhna chahiye.

---

## Part D — Reports catalogue (teacher ki har report: graph + Excel)

**Rule (sab reports par):** Teacher sirf apni classes aur apne subjects ka data dekhega — filter service layer par lagega. Har report mein filter hoga (class, subject, exam, date range). Har report ka **graph `fl_chart` se** aur **Excel `excel` package se** banega. Excel standard (Core Modules wala hi reuse hoga): pehli sheet **Summary** (title, filters, totals, generated date), doosri sheet **Data** (poori rows), totals row har sheet ke ant mein, file ka naam `Teacher_<username>_<CODE>_<YYYYMMDD>.xlsx`. Reconciliation rule: report ka har number uski source screen (attendance / marks / homework) se match karna chahiye — mismatch mile to report galat hai, data nahi.

| Code | Report | Graph (fl_chart) | Excel mein kya hoga |
|---|---|---|---|
| T-R01 | Attendance trend — meri classes, pichhle 30 din / mahina | Line chart (din-wise %) | Daily rows + monthly summary |
| T-R02 | Attendance register — class × date, P/A/L/Leave | — (register table hai; trend T-R01 mein hai) | Poora register + summary counts |
| T-R03 | Defaulters — attendance <75% (CBSE rule) + at-risk list (N8) | Bar chart (sabse kam attendance wale top 10) | Student list + reason column + attendance % |
| T-R04 | Class performance / gradebook — latest exam | Bar chart (grade distribution A–E) | Student × subject matrix + total + grade + rank |
| T-R05 | Subject-wise average — mere subjects ka comparison | Bar chart (subject averages) | Subject rows + average + highest/lowest |
| T-R06 | Student progress — ek student ka trend (exam-wise) | Line chart (exam-wise % / grade) | Exam-wise rows per student |
| T-R07 | Homework completion — submitted / late / missing | Donut chart (%) | Per-homework rows + status counts |
| T-R08 | Homework grading pending — grade karni hai | — (queue list hai) | Pending queue + due dates + submitted counts |
| T-R09 | Lesson plan velocity — planned vs taught, syllabus % | Bar chart (subject-wise taught %) | Subject rows + planned/taught/lagging topics |
| T-R10 | Leave summary — meri classes ki leaves | Bar chart (mahine-wise leaves) | Leave rows + status + approval dates |
| T-R11 | Substitution load — mera hafta | Bar chart (din-wise substitution periods) | Substitution rows + total periods |
| T-R12 | Weekly teaching load — lectures, free periods | Bar chart (din-wise load) | Day-wise rows + totals |
| T-R13 | Messages sent — class announcements (N4) | — (log list hai) | Message log + class + date |
| T-R14 | Behaviour notes summary (N7) | Bar chart (positive vs concern, class-wise) | Notes rows + type + date |

**Note:** T-R13 aur T-R14 tabhi banenge jab N4 aur N7 banenge — pehle un features ka data hona chahiye. T-R02 aur T-R08 table-type reports hain (inme graph ka matlab nahi hai) — par Excel inka bhi banega, bina exception.

---

## Part E — Gemini execution plan (line-by-line)

### E1. Steps aur order

**T0 — Verify (koi code change nahi, sirf report).** Pehle ye sab dhoondh kar CHECKPOINT mein likhna hai: (a) teacher login se `/school/teacher-dashboard` tak ka route + role guard mein teacher case; (b) institute ka naam kahan se aata hai (admin dashboard mein kya use hota hai); (c) `school_circulars` ki audience model (class-wise hai ya nahi); (d) homework list mein grading action hai ya nahi + `school_homework_submissions` mein grade/remark columns hain ya nahi; (e) school teacher-leave ka flow kahan hai (college HR se linked hai ya nahi); (f) PTM booking wali table ka naam; (g) `school_attendance` mein period ka column hai ya nahi; (h) notifications ka koi system hai ya nahi. **T0 ke bina T1 shuru nahi hoga.**

**T1 — Real data purge (M1, M2, M3, M4).** Hardcoded KPI (42/38), fallback schedule, default room 'Room 201', hardcoded institute naam — sab hatana hai. Error state + retry laana hai. **Done tabhi jab:** teacher dashboard par koi haath se likha number/schedule/room/naam na bache (grep se verify karna hai: `42`, `38`, `Room 201`, `Shivalik International School` dashboard file mein nahi hone chahiye — sirf empty-state texts reh sakte hain).

**T2 — My Students + search (N1 + M12).** Roster + profile sheet + search. **Done tabhi jab:** class-teacher aur subject-teacher dono ki classes dikhein; doosri teacher ki class ka student kabhi na dikhe; profile sheet mein attendance %, latest marks, homework status, leave, notes — sab real data se.

**T3 — Analytics + My Reports, pehla hissa (N2 + N3 + T-R01 se T-R06).** `fl_chart` ka school mein pehla use. Dashboard par analytics section + reports hub ka teacher scope. **Done tabhi jab:** 4 charts real data se ban rahe hon; har chart se uski poori report khul rahi ho; teacher-scope filter service layer par laga ho.

**T4 — Reports, doosra hissa + Excel (T-R07 se T-R14 + M6 + M7 + M8 ka Excel).** `excel` package ka school mein pehla use. Har report ka `.xlsx` export (Summary + Data + totals + naming standard). **Done tabhi jab:** har T-R report ka Excel uski screen ke numbers se match kare; CSV/PDF wale purane exports toote nahi hon.

**T5 — Naye features (N4, N5, N6, N7, N8, N9, N10, N11, N12, N13, N14).** Order: N13 (period state) + N5 (substitution) pehle (schedule se jude hain), phir N8 (at-risk) + N12 (grading queue), phir N4 (messaging) + N7 (behaviour) + N6 (own leave) + N10 (PTM) + N9 (exam widget) + N11 (weekly load) + N14 (notifications). Har feature ke liye: pehle VERIFY-FIRST check, phir UI, phir RLS (nayi table ho to), phir verification.
**Done tabhi jab:** har feature ka data real ho; RLS wali har table par teacher-scope test ho (doosri teacher ka data nahi dikhna chahiye).

**T6 — Modifications ka polish (M5, M9, M10, M11, M13, M14).** Reports link, lesson cards, leave queue, drawer parity, 4-state, taught status. **Done tabhi jab:** dashboard aur drawer ki list ek jaisi ho; har section 4-state mein test ho chuka ho.

**T7 — Final QA + HANDOFF.** Poora teacher E2E live DB par: teacher login → dashboard (saare numbers real) → har T-R report (graph + Excel) → har naya feature → college regression (`flutter analyze` poore repo par, college screens kholkar dekhna — koi college screen nahi tootni chahiye). Phir HANDOFF block (neeche template) + agle dashboard (Admin) ke liye 3-line note.

### E2. Hard rules (Gemini ke liye — todna mana hai)

1. College code/tables/routes — zero touch. Sirf school files + `school_*` tables.
2. Koi mock/fake/demo data nahi — na dashboard mein, na report mein, na test mein (test data alag se mark hoga aur live DB par nahi jayega).
3. Har nayi table: SQL file `database/` mein + RLS policies ke saath + CHECKPOINT mein table ka naam aur RLS test ka saboot.
4. Teacher-scope har query mein — `username` / teacher id se filter, kabhi poori table mat uthao aur UI par filter mat karo.
5. Koi secret/key/password file mein nahi. Koi fee/payment ka code teacher dashboard mein nahi.
6. Har step: pehle `flutter analyze` us file par, phir poore `lib/features/school/` par — 0 errors, 0 warnings tabhi CHECKPOINT.
7. Har step ke baad `SCHOOL_PROGRESS.md` mein row + CHECKPOINT + commit (`teacher-dash: T<n> — <title>`). Limit aaye to HANDOFF block likhna hai — adhoora step "ho gaya" nahi kehna.

### E3. HANDOFF template (limit par Gemini ye likhega)

```
HANDOFF — Teacher Dashboard Deep-Dive
Poora hua: T0–T<n> (har step ka commit + CHECKPOINT SCHOOL_PROGRESS.md mein hai)
Chal raha tha: T<n+1> — <kya kar raha tha, kahan ruka, kaunsi file khuli thi>
Agla agent yahan se shuru kare: <exact step + pehla action>
Ruka hua / pending: <koi Maalik ka faisla baaki ho to — jaise behaviour notes parent ko dikhane wala rule, messaging approval rule>
Test saboot: <live DB par kya verify hua, kya nahi>
```

---

## Part F — Teacher ke baad (roadmap, order Maalik ka faisla)

1. **Teacher (ye document)** — dashboard #1, abhi.
2. **Admin / sadmin command center** — suggestion: doosra number. Kaam: analytics + Excel parity (admin ki har report bhi graph + Excel), approvals queue ka deep-dive, UDISE+ sheet ka Excel parity.
3. **Parent dashboard** — suggestion: teesra number. Kaam: teacher ke naye features ka parent side (messages inbox, behaviour notes — agar Maalik ne parent view ko haan kaha — PTM slots ka parent view pehle se hai, uska polish).
4. **Student dashboard** — suggestion: chautha number. Kaam: student ka analytics (apna trend, homework, attendance) + Excel (apni report card ka Excel).
5. **Module screens ka second pass** — attendance, marks, homework, timetable, lesson plans — teacher dashboard ke baad jo gaps bachenge (jaise offline attendance, bulk operations), wo alag document mein aayenge.

**Order #2 se #4 tak Maalik ke next call par final hoga — Gemini is document mein sirf Teacher (#1) karega, baaki dashboards ko chhooega nahi.**

---

## Appendix — Files, methods, tables (execution ke waqt kaam aayega)

### A. Files

| File | Kaam |
|---|---|
| `lib/features/school/school_teacher_dashboard.dart` (879 lines) | Teacher dashboard — is document ka main file |
| `lib/features/school/attendance/school_attendance_screen.dart` (2,131 lines) | Daily/Monthly/Defaulters attendance |
| `lib/features/school/marks/marks_entry_screen.dart` (1,389 lines) | Scholastic + co-scholastic marks entry |
| `lib/features/school/marks/marks_csv_upload_screen.dart` | Bulk marks import (CSV) |
| `lib/features/school/marks/report_card_screen.dart` | CBSE HPC report cards |
| `lib/features/school/homework/homework_list_screen.dart` (959 lines) | Homework list + submissions |
| `lib/features/school/homework/add_homework_screen.dart` | Homework create |
| `lib/features/school/timetable/school_timetable_screen.dart` (1,787 lines) | Week view + substitution desk + syllabus tracker |
| `lib/features/school/academics/school_lesson_plan_screen.dart` (1,909 lines) | NEP 2020 5E Studio |
| `lib/features/school/leave/student_leave_screen.dart` | Student leave approvals |
| `lib/features/school/reports/school_reports_screen.dart` (2,687 lines) | Reports hub (admin-flavoured) |
| `lib/features/school/examination/school_examination_screen.dart` | Exam sessions + date sheet |
| `lib/features/school/circulars/circulars_screen.dart` | Circulars (read) |
| `lib/features/school/library/school_library_screen.dart` | Library search + issues |
| `lib/services/school_service.dart` (6,882 lines) | Sab school service methods |
| `lib/services/school_export_service.dart` | PDF/CSV exports (class results, attendance, pending fees) |
| `pubspec.yaml` | `fl_chart: ^0.65.0` (school mein unused), `excel: ^4.0.2` (school mein unused), `csv: ^6.0.0`, `pdf`, `printing` |

### B. Service methods (teacher se jude, maujood)

`getTeacherDetails`, `getTeacherTimetable`, `getTeacherClasses`, `getTeacherAssignments`, `getTeacherNames`, `getTeacherDisplayName`, `getTeacherDailyLoad`, `getSubstitutionLogs`, `getPendingHomeworkToGrade`, `getPendingHomeworkCount`, `getClassTeacherClasses`, `getClassTeacherForClass`, `getLeaveRequestsForClassTeacher`, `getCoScholastic`, `saveCoScholastic`, `getHomeworkSubmissions`, `getHomeworkSubmissionCounts`.

### C. Tables (maujood — nayi tables Part C mein alag se likhi hain)

`school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_students`, `school_teachers`, `school_timetable`, `school_classes`, `school_subjects`, `school_exam_sessions`, `school_report_card_meta`, `school_student_leaves`, `school_circulars`, `school_library`, `school_library_issues`, `institutes`, `parent_student_links`.

### D. Nayi tables (sirf tab jab VERIFY-FIRST mein na milen)

`school_teacher_messages` (N4 — agar circulars audience na ho), `school_teacher_leaves` (N6 — agar college HR flow na chale), `school_behaviour_notes` (N7), `school_notifications` (N14). Har ek par RLS mandatory hai.

---

## Aakhri note (Maalik ke liye)

Ye document teacher dashboard ko "screens ka set" se "enterprise workspace" banane ka plan hai. Sabse pehla kaam T1 hai — jhootha KPI hatana. Uske bina aage ka har chart aur har Excel bekaar hai, kyunki dashboard par bharosa hi nahi hoga. T1 ke baad hi analytics aur reports ka matlab banta hai. Isliye order mat badalna: **pehle sachha data, phir charts, phir Excel, phir naye features.**
