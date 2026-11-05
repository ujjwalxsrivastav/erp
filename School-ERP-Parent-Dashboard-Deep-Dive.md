# School ERP — Parent Dashboard Deep-Dive (Enterprise Upgrade)

## Dashboard — Parent (teeno dashboards ek-ek karke; Teacher #1 ho chuka hai)

**Status:** Analysis document — isme koi code change nahi hai. Ye file Gemini ko di jayegi, Gemini isko line-by-line execute karega.
**Repo state (verified, analysis ke waqt):** `origin/main` = `7cce8af` — "Enterprise NEP 2020 Lesson Plan Studio". Local clone (`~/workspace/erp`, main `1652552`) stale hai, isliye analysis `origin/main` ke archive se ki gayi hai, local clone se nahi. Analysis ke baad repo mein koi change nahi kiya gaya hai.
**Scope lock:** Is document ka kaam SIRF parent dashboard aur parent se jude screens/flows tak hai. Teacher dashboard (deep-dive ho chuka hai) aur Admin/Student dashboards is document mein nahi banenge — unka number Part F mein roadmap ke roop mein hai.
**Ye document Core Modules README ko replace nahi karta.** Admin / HR / Admission / Fees / Reports / Excel Import wala kaam (Core Modules README, Steps 1–8) alag track hai. Jahan dono overlap karte hain (Excel standard, Reports, fee ledger), wahan isi document mein Core Modules wala standard reuse hoga — doosra standard invent nahi hoga.
**Parent is school ERP ka sabse bada user hai.** Parent app, daily attendance alerts, homework diary aur communication add-on nahi hain — ye parent dashboard ka core hain. Isi liye is document mein "parent ko kya dikhe" se zyada "parent ko roz kya chahiye" par focus hai.

---

## 0. Kaise padhna hai (How to Read)

- **Part A — YE YE HAI:** Aaj parent dashboard mein kya-kya maujood hai, file aur route ke saath. Har cheez repo se verify ki gayi hai — koi feature "hai" nahi kaha gaya jab tak file mein nahi dikha.
- **Part B — KAMI KYUN HAI:** Enterprise feel kyun nahi aa raha — seedhi baat, saboot ke saath.
- **Part C — YE YE KARNE JA RAHA HUN:** Do hisse — **C1 NEW (extra)** aur **C2 MODIFY (isi mein badlav)**. Har feature mein likha hai: kya hai, kyun chahiye, kahan dikhega, data kahan se aayega, aur uska graph/Excel kya hoga.
- **Part D — Reports catalogue:** Parent ki har report — **per child**, graph + Excel, dono ke saath. Koi report sirf list nahi hogi.
- **Part E — Gemini execution plan:** Steps PAR0–PAR7, verification, checkpoint, hard rules.
- **Part F — Dashboard-by-dashboard roadmap:** Teacher ke baad ka order.
- **VERIFY-FIRST ka matlab:** Execution ke waqt pehle file/table dhoondhni hai. Agar cheez pehle se maujood nikli to dobara nahi banani — sirf dashboard se link/queue banana hai. Agar nahi mili to hi nayi banani hai.

## 0.1 Non-negotiables (har step par laagu)

1. **College ERP kabhi nahi tootega.** Sirf `lib/features/school/` + `lib/services/school_service.dart` + `school_*` tables + nayi `school_*` tables chhoo sakte hain. College screens, college tables, college routes — zero touch.
2. **Koi fake/mock/invented data nahi.** Koi number, naam, schedule, bus, teacher ya result haath se nahi likha jayega. Data na mile to empty state dikhega ("koi data nahi"), kabhi jhootha number nahi.
3. **Parent sirf apne linked bachche ka data dekhega — hamesha, har screen par.** Ye sirf UI filter nahi hai — service layer par `parent_student_links` se filter lagega, aur RLS se band hoga. Kisi aur parent ke bachche ka data parent ko **kabhi** nahi dikhna chahiye (Part B, kami #1 dekho — aaj ye rule tootta hai).
4. **Har nayi table par RLS.** Bina RLS ke koi table live nahi jayegi.
5. **Har step ke baad verification + commit + CHECKPOINT.** Bina verification ke agla step nahi. Har step ka commit message: `parent-dash: PAR<n> — <title>`.
6. **Deploy pipeline ka note:** 4 Nov 2026 ko GitHub Pages deploy 4 baar fail hua tha (workflow 'Deploy Flutter Web to GitHub Pages'). Isliye Gemini har step ke baad `flutter analyze` + `flutter build web` locally chalayega aur result CHECKPOINT mein likhega. Push karna Maalik ka faisla hai — Gemini khud push karke pipeline par nahi chhodega jab tak Maalik na kahe.
7. **Payroll is document ka hissa nahi hai** (Maalik ke faisle par pending hai — Core Modules mein bhi deferred hai).
8. **Fee ka ledger Core Modules wala hi chalega.** Parent dashboard fee dikhayega aur pay karwayega, par fee ke rules (structures, demand, late fee, receipts) dobara nahi likhe jayenge — Core Modules README wala fee system hi source of truth hai.

## 0.2 Dashboard-by-dashboard roadmap (poori picture)

| # | Dashboard | Aaj ki haalat (verified) | Is deep-dive mein |
|---|---|---|---|
| 1 | **Teacher** (`/school/teacher-dashboard`) | Deep-dive ho chuka hai (Teacher Dashboard Deep-Dive MD) — 14 NEW + 14 MODIFY + T-R01–T-R14 reports | Ho gaya — is document ka kaam nahi |
| 2 | Admin / sadmin (`/school/admin-dashboard`) | Step 13.1 mein command center overhaul ho chuka hai (Morning Pulse, approvals queue, UDISE+ sheet, grievance resolution tool) | Alag document mein ban raha hai (Maalik ne teeno ek-ek karke banane ko kaha hai) |
| 3 | **Parent** (`/school/parent-dashboard`) | Multi-child switcher, live metrics, PTM booking, grievance tickets, LMS-lite maujood hain (Step 10) — par metrics mein fake fallbacks, alerts haath se likhe, aur design purana hai | **YE DOCUMENT — poora deep-dive** |
| 4 | Student (`/school/student-dashboard`) | Step 13.2 mein light-theme overhaul ho chuka hai (passport card, KPI tiles, schedule timeline) | Alag document mein ban raha hai (Maalik ne teeno ek-ek karke banane ko kaha hai) |

**Boundary notes (doosre dashboards se takraav na ho):** (a) Teacher MD ka N4 (teacher → parents ko class announcements/messaging **bhejna**) — bhejne ka side teacher document mein hi rahega; **dekhne/inbox ka side is document mein hai** (New PN1). (b) Behaviour notes parent ko dikhane hain ya nahi — **ye Maalik ka pending faisla hai**; is document mein ye decision point hai (New PN10), default **OFF** (sirf teacher + admin) — Maalik haan kahe tabhi parent view banega.

## 0.3 Benchmark — tagde level ke school ERP mein parent app kaisa hota hai

Leading school ERPs (ScoolsPRO, ScholarERP, EduSaaS-class platforms) ke parent apps mein ye cheezein **standard** hain — inhi se compare karke is document ki kami list bani hai:

- **Instant absence alert** — bacha absent mark hote hi parent ko SMS/push/in-app alert; late ki bhi khabar.
- **Homework diary** — roz ki homework (subject, due date, status) ek jagah; teacher ki remark ke saath.
- **Fee pay + digital receipts** — online pay, itemized fee heads, receipt download, payment history.
- **Report cards + trends** — result dekhna, exam-wise trend, subject-wise performance.
- **PTM booking asli availability se** — asli teacher list, asli slots, apni bookings dekhna/cancel/reschedule.
- **Live bus tracking** — route, stop, ETA, boarding/alighting ki khabar.
- **Two-way messaging** — teacher se seedha baat (na ki sirf school ki taraf se notices).
- **Per-child reports har format mein** — PDF, Excel aur CSV export, har bachche ki alag report.

Inme se humare system mein PTM booking, grievance ticket, LMS-lite, leave apply aur metrics **maujood** hain — par alerts haath se likhe hain, homework diary nahi hai, PTM mein asli teacher/slot nahi hain, bus live nahi hai, teacher se two-way baat nahi hai, aur per-child Excel reports **nahi** hain. Wahi gap is document mein bhara ja raha hai.

---

## Part A — YE YE HAI (Existing parent features, repo-verified)

### A1. Parent dashboard shell

- **File:** `lib/features/school/parent/school_parent_dashboard.dart` (1,628 lines)
- **Route:** `/school/parent-dashboard` (login mein `case 'parent'` se yahin route hota hai — `lib/features/auth/login_screen.dart` line 86–87)
- **Header:** Pink gradient SliverAppBar (expanded 200) — "Welcome, \<parent\>" + "Shivalik International School — Parent Portal" + "CBSE K-12" badge. **Gap (pehle se note):** institute ka naam haath se likha hai; AppBar ka style Admin (13.1) / Student (13.2) / Teacher ke minimalist light theme se match nahi karta — parent dashboard abhi bhi **blurry orbs + glass panels** wali purani candy design par hai (background mein 3 blur orbs, pink/violet/amber gradients, `BackdropFilter` blur 26 wala drawer). Step 13 ne baaki dashboards se orbs hataye, parent ka nahi hataya.
- **Loading / error states:** Loading par sirf spinner + "Connecting to Shivalik Student Ledger..." text (skeleton nahi); error par message + "Retry Connection" button maujood hai. Pull-to-refresh maujood hai.
- **Drawer (10 entries):** Dashboard, Attendance, Homework, Fees & Receipts, Circulars, Transport & Bus, Report Cards, Timetable, Library, Certificates, Logout. **Gap:** Drawer mein **Reports, Messages/Inbox, Notifications, My Children, Profile** — kuch nahi hai. PTM, Grievance, Leave, LMS-Lite sirf quick-action dialogs se khulte hain, drawer se nahi (Modify PM12).

### A2. Multi-child switcher + child info card

- **Switcher:** Ek se zyada bachche hon to upar pill switcher dikhta hai — naam + class ke saath, select karne par us bachche ka data load hota hai (`_onChildChanged` → `_loadSelectedChildData`).
- **Data source:** `getParentChildren(parentUsername)` — `parent_student_links` table se link nikaal kar har link ke liye `school_students` se bachche ka record laata hai, `relation` link se jodta hai.
- **Child info card:** Bachche ka naam, class-section, roll/admission no, relation ("Linked as: ..."), "Active Session 2025-26", aur report card dekhne ka arrow button (`/school/report-card`).
- **Gap (pehle se note):** Session `'2025-26'` haath se likha hai; naam/roll ke fallbacks `'Aarav Sharma'` / `'SCH2026-10A'` haath se likhe hain; aur sabse badi baat — **koi bachcha link na ho to bhi card "Aarav Sharma, Class 10, SCH2026-10A" dikhata hai** (kyunki `_currentChild` null hone par bhi fallback values use hoti hain). Parent jiska koi bachcha link nahi hai, wo bhi ek fake bachcha dekhega (Modify PM10 + Part B kami #1).

### A3. Live metrics grid (4 cards)

- **Cards:** Attendance % (tap → `/school/attendance`), Fees Due (tap → `/school/fees`), Homework Due (tap → `/school/homework`), Latest Result (tap → `/school/report-card`).
- **Data source:** `getChildDashboardMetrics(studentId, classId)` — attendance %, pending fees (amount + display), pending homework count, latest result (grade + %) — service mein real compute hota hai (attendance table, fee summary, marks se).
- **Gap (pehle se note — sabse bada jhooth):** Metric na mile to **teen alag fake values** dikhte hain: dashboard default attendance `92.5%` aur result `'A1 (94%)'`; service ke error fallback mein attendance `92.5%` aur result `'A2 (86%)'`. Matlab ek hi bachche ka result do jagah do alag dikh sakta hai (A1 94% vs A2 86%) — dono haath se likhe hain. Fees ka fallback `'₹0'` hai — fees baaki hone par bhi "₹0 due" dikh sakta hai. **ClassId ka fallback bhi guess hai:** `class_name` mein '9' ho to `'cls-9a'`, warna `'cls-10a'` — class naam se id guess karna galat hai (Modify PM1).

### A4. Quick actions (4 dialogs)

| Action | Kya hai (verified) |
|---|---|
| Apply Leave | Dialog: leave type (Medical / Casual / Family Function), From/To date pickers (aaj se 60 din tak), reason mandatory. `applyStudentLeave` se `school_student_leaves` mein insert + class teacher ko circular notification. Submit par "Leave request submitted to Class Teacher" snackbar + data reload. **Gap:** `studentId` fallback `'sstudent1'`, `classId` fallback `'cls-10a'` haath se likhe; document ke naam par `'Self-Certified by Parent <username>'` string bhejta hai — koi real document upload nahi hai (Modify PM7). |
| Book PTM | Dialog: teacher dropdown, slot dropdown, agenda text, Confirm. `bookPtmSlot` se booking hoti hai. **Gap:** Teacher list **haath se likhi hai** — 'Mrs. Sunita Sharma (Class Teacher)', 'Mrs. Gupta (Chemistry)', 'Ms. Nair (English)'; slots bhi **haath se likhe hain** — sirf 3 fixed slots (09:30 / 10:00 / 11:15); **date choose hi nahi kar sakte** — date hamesha aaj + 3 din fixed hai. Apni bookings dekhne/cancel/reschedule karne ki koi jagah nahi hai (New PN7, Modify PM4). |
| Grievance | Dialog: department (Academic / Transport / Finance / Infrastructure), subject, description. `fileParentComplaint` se ticket banta hai — ticket number `'TKT-'` + timestamp ka hissa. Submit par dialog mein ticket number dikhta hai. **Gap:** Apne tickets ki list/status/history parent ko kahin nahi dikhti — sirf file kar sakte hain, track nahi kar sakte (New PN8). |
| LMS-Lite | Bottom sheet modal: `getStudyMaterials(classId)` se class ke study materials (title, subject, uploaded by) + download button. **Gap:** Download button par sirf snackbar dikhta hai — `'Downloading <title>...'` — **koi real download nahi hota**. Material ka file URL fallback `'https://shivalikschool.edu.in/resources/notes.pdf'` haath se likha hai (New PN14, Modify PM5). |

### A5. Instant Alerts card — "Live Student & Safety Alerts" (naamak, live nahi)

- Card mein **do haath se likhe hue alert items** hain, koi service call nahi:
  1. "School Transport Live — Bus UK-07-PA-1024 on Rajpur Road route (ETA 12 mins)" → `/school/transport`
  2. "Class Homework Assigned — Science & Mathematics worksheets pending submission before Friday" → `/school/homework`
- Bus number, route, ETA, subjects, "Friday" — sab haath se likha hai. Transport module mein live telematics maujood hai (Step 8), par dashboard usse nahi jodta. **Ye card "live" nahi hai — ye demo text hai** (Modify PM3, New PN2).

### A6. Student Leave Applications section

- Selected bachche ki recent leaves (top 3, `getStudentLeaves`) — type, dates, reason, aur status chip (Approved / Rejected / Pending, rang ke saath). Khaali ho to "No leave applications filed for this child." + "+ New Leave" button jo Apply Leave dialog kholta hai.
- Leave ka aage ka flow: parent apply karta hai → class teacher approve/reject karta hai (leave screen) → approve par attendance **excused** mark ho jaati hai (Step 10 checkpoint mein is flow ki E2E ID darj hai — par code mein fallbacks dekh kar PAR0 mein live re-verification mandatory hai).

### A7. Circulars section (top 3)

- `getCirculars()` se aakhri 3 circulars — title, date, category chip. "View All" → `/school/circulars`.
- **Audience model (verified):** Circulars mein `target_audience` field hai, par options sirf `['All', 'Students', 'Parents', 'Teachers']` hain — **class-wise audience nahi hai**. Iska matlab teacher apni class ke parents ko alag se circular nahi bhej sakta — teacher MD ke N4 ke liye ye VERIFY-FIRST ab answered hai: class-wise messaging ke liye **nayi table** chahiye, circulars extend nahi honge (New PN1 mein detail hai).

### A8. Fee view (parent ko fee dikhna + pay karna)

- **Fee screen:** `lib/features/school/fee/school_fee_screen.dart` — parent/student role allowed hai (teacher ko ledger access nahi). Parent ko itemized fee heads, 12-month April–March schedule, due date (har mahine ki 5 taarikh), ₹100 late fee fine (5 ke baad unpaid par), online/counter pay modal, aur instant official PDF receipt milta hai (`payMonthlyFee` + receipt dialog, `fee_receipt_pdf.dart`).
- **Gap (pehle se note — VERIFY-FIRST, zaroori):** Fee screen apna data **logged-in username** se load karti hai (`targetUser = username`) — parent ke liye **child select karne ka flow file mein nahi dikha**, aur dashboard ka Fees Due card bhi bina child context ke `/school/fees` par le jaata hai. Parent login se fee screen kholkar PAR0 mein check karna hai ki kis bachche ka ledger dikhta hai — agar parent ke username se student profile dhoondhi ja rahi hai to parent ko galat/khaali ledger dikhega (Modify PM6). Username na mile to fallback `'sstudent1'` bhi hai — parent ko kisi aur bachche ka data dikh sakta hai.

### A9. Homework, report card, aur baaki screens (parent view)

- **Homework** (`homework_list_screen.dart`): parent ko student wala view milta hai (`_isStudent = role == 'student' || role == 'parent'`) — homework list, apne bachche ka submission record, teacher ki submission counts. Par dashboard par sirf "Homework Due" count dikhta hai — aaj ki homework diary nahi hai (New PN3).
- **Report card** (`report_card_screen.dart`): parent sirf apne bachche ka card dekhta hai — picker kabhi nahi milta (`_isStaff = role != student && role != parent`; "Students (and parents) only ever see their own card"). CBSE HPC standard, QR seal, principal signature. Par dashboard se trend nahi dikhta (New PN5 / PAR-R04).
- **Attendance screen:** parent ko bachche ki attendance dikhti hai (Daily/Monthly/Defaulters tabs) — par dashboard par sirf % hai, aaj ki status (present/absent/late) nahi (New PN4).
- **Transport / Timetable / Library / Certificates:** Drawer se khulte hain, par **bina child context ke** — parent ko khud samajhna padta hai ki kaunsa bachcha, kaunsi class. Transport screen mein live telematics hai (Step 8), par parent dashboard se uska koi live link nahi hai (New PN11).

### A10. Parent ke liye maujood service methods (`lib/services/school_service.dart`, 6,882 lines)

`getParentChildren`, `getChildDashboardMetrics`, `getStudentLeaves`, `applyStudentLeave`, `bookPtmSlot`, `fileParentComplaint`, `getStudyMaterials`, `getCirculars`. (Teacher wale methods alag hain — teacher MD mein list hain.)

### A11. Parent se jude maujood tables (database/*.sql se)

`parent_student_links`, `school_students`, `school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_student_leaves`, `school_circulars`, `school_fee_payments`, `school_fee_receipts`, `school_fee_items`, `school_fee_accounts`, `school_classes`, `school_subjects`, `school_timetable`, `school_exam_sessions`, `school_report_card_meta`, `school_transport`, `school_library`, `school_library_issues`, `institutes`.

### A12. Ek ajeeb sach — PTM, grievance aur study material ki koi alag table nahi hai

- **PTM bookings, parent grievances aur study materials — teeno `school_circulars` table mein store hote hain**, content ko string mein encode karke (jaise `'PTM_SLOT_BOOKING | Parent: ... | Student: ...'`, `'PARENT_COMPLAINT | Ticket: ...'`, `'STUDY_MATERIAL | ClassId: ... | Subject: ... | Title: ... | Url: ...'`). Inki koi dedicated table `database/*.sql` mein nahi hai.
- Iska matlab: PTM booking ek "circular" hai, grievance ek "circular" hai, aur study material bhi ek "circular" hai — in par na sahi status tracking hai, na sahi query, na RLS alag se. Grievance ka status badalna bhi circular ke content string ko `replaceAll` karke hota hai. Ye enterprise design nahi hai — ye jugaad hai (New PN7, PN8, PN14 mein dedicated tables ka plan hai).

---

## Part B — KAMI KYUN HAI (enterprise feel kyun nahi aa raha)

Seedhi baat — parent dashboard school ERP ka sabse zyada use hone wala screen hai, par aaj ye **sach se zyada dikhawa** karta hai:

1. **Sabse bada kaaran — privacy ka rule tootta hai.** `getParentChildren` mein agar parent ka koi bachcha link nahi hai to service `school_students` se **pehle 2 bachche utha kar de de hai** (`limit(2)`). Matlab jis parent ka koi bachcha link nahi hai, wo kisi aur ke 2 bachchon ka naam, class, attendance, fees, homework — sab dekh sakta hai. Ye bug nahi, **data leak** hai. Enterprise system mein aisa ek din bhi nahi chal sakta.
2. **Jhootha bachcha, jhootha result.** Koi bachcha link na ho to dashboard "Aarav Sharma, Class 10, SCH2026-10A" dikhata hai; metrics na milen to attendance `92.5%` aur result kabhi `'A1 (94%)'`, kabhi `'A2 (86%)'` — do jagah do alag fake values. Fees ka fallback `'₹0'` hai — fees baaki hone par bhi "₹0 due" dikh sakta hai. Parent ko apne bachche ke baare mein **galat khabar** dena, khabar na dene se zyada kharab hai.
3. **"Live Alerts" live nahi hain.** Bus UK-07-PA-1024, ETA 12 mins, Science-Maths worksheets "before Friday" — ye sab haath se likha text hai. Bacha absent hua, bus late hui, fees ki due date aayi — inme se kisi ki parent ko asli khabar nahi milti. Parent app ka sabse important kaam (alert) hi fake hai.
4. **PTM booking nakli availability par chalti hai.** Teacher list haath se likhi hai (3 naam), slots haath se likhe hain (3 fixed), date choose hi nahi kar sakte. Parent ko lagta hai usne PTM book kar li — par asli teacher ki availability se iska koi lena-dena nahi hai. Aur booking ke baad use dekhne/cancel karne ki jagah bhi nahi hai.
5. **PTM, grievance, study material — sab "circular" hain.** In teeno ki koi table nahi hai; sab `school_circulars` mein string encode karke pade hain. Grievance ka status badalna content string ko edit karke hota hai. Is design par ticket tracking, status timeline ya reporting kabhi nahi ban sakti.
6. **Homework diary nahi hai.** Parent ko sirf ek count dikhta hai ("Homework Due: 3") — aaj ki homework kaunsi hai, kis subject ki hai, kab due hai, submit hui ya nahi — ye dekhne ke liye use homework screen mein ghusna padta hai, aur wahan bhi parent ko student wala view milta hai, parent wala diary nahi.
7. **Fee parent ke hisaab se nahi chalta.** Fee screen username se load hoti hai, bachcha select karne ka flow nahi dikha. Ek se zyada bachche hon to parent kis bachche ki fees dekh raha hai — ye clear hi nahi hai.
8. **Teacher se baat karne ka koi raasta nahi hai.** Parent class teacher ko message nahi bhej sakta, aur teacher ke bheje hue messages dekhne ka inbox bhi nahi hai. Communication sirf ek taraf hai (school → parent, circular padh lo).
9. **Koi chart, koi Excel nahi.** `fl_chart` school mein kahin use nahi hota, `excel` package school mein kahin use nahi hota. Parent apne bachche ki attendance trend ya marks trend graph mein nahi dekh sakta, aur koi report Excel mein nahi nikaal sakta.
10. **Design baaki dashboards se peeche hai.** Admin (13.1), Student (13.2) aur Teacher minimalist light theme par aa gaye — parent abhi bhi pink gradient + blurry orbs + glass panels par hai. Sabse bade user ka dashboard sabse purana dikhta hai.
11. **Dashboard par "aaj" nahi hai.** Aaj bacha present hai ya absent, aaj ki homework kaunsi hai, aaj ka timetable kya hai, agla exam kab hai — ye sab dekhne ke liye parent ko 4 alag screens kholni padti hain. Dashboard "aaj ka din" nahi batata.
12. **Step 10 ka E2E daava dobara verify karna hai.** SCHOOL_PROGRESS.md mein Step 10 par "Verified E2E on live Supabase" likha hai (leave ID, PTM ID, ticket TKT-892104 ke saath) — par code padhne par upar wale saare fake fallbacks aur hardcoded values dikhe. Isliye is document mein Step 10 ko "ho gaya" maan kar aage nahi badha jayega — PAR0 mein live re-verification mandatory hai. (Ye kisi par ilzaam nahi hai — bas itna hai ki code aur checkpoint ki baat milti nahi hai, to zameen par dobara check karna hai.)

---

## Part C — YE YE KARNE JA RAHA HUN

### C1. NEW (extra) features — pehle nahi the, ab banenge

Har feature mein: **kya hai / kyun / kahan dikhega / data kahan se / graph-Excel**.

#### PN1. Messages Inbox — teacher aur school ke messages parent ko (DISPLAY side)

- **Kya hai:** Parent ke liye ek inbox — teacher ke class announcements, homework updates, school notices, aur PTM/grievance ke replies — sab ek jagah, per child filter ke saath, read/unread state ke saath. Har message par tap → poora message + related screen (homework ho to homework diary, circular ho to circulars). **Boundary saaf hai:** bhejne ka side teacher document mein hai (teacher MD N4) — is document mein sirf **dekhne** ka side hai.
- **Kyun:** Aaj parent ko teacher ka message dekhne ki jagah hi nahi hai. Circulars alag, homework alag, PTM ka confirmation alag — parent ko har cheez alag jagah dhoondhni padti hai. Enterprise parent app mein inbox hi ghar hota hai.
- **Kahan dikhega:** Dashboard par "Messages" section (top 3 unread + count badge) + drawer entry + AppBar mein bell icon ke saath inbox screen.
- **Data kahan se:** Circulars ki audience sirf `['All', 'Students', 'Parents', 'Teachers']` hai — **class-wise audience nahi hai**, isliye circulars extend nahi honge. **Nayi table** `school_teacher_messages` (id, teacher_id, class_id, subject, body, created_at) + RLS (teacher sirf apni classes ko bhej sake; parent sirf apne bachche ki class ke messages dekh sake). Ye wahi table hai jo teacher MD ke N4 mein propose hui hai — dono documents mein ek hi table, ek hi naam, ek hi RLS rule.
- **Graph/Excel:** Inbox ki report nahi hoti — list + read/unread hi kaafi hai. (Messages ka count report PAR-R14 ke summary mein aayega.)

#### PN2. Real Live Alerts — asli events se asli khabar

- **Kya hai:** "Live Student & Safety Alerts" card ko asli event feed se bharna: (a) bacha absent mark hote hi alert ("Aarav aaj absent mark hua hai"); (b) late aane par alert; (c) homework assign hone par alert; (d) fees ki due date paas aane par alert; (e) leave approve/reject hone par alert; (f) PTM confirm hone par alert; (g) exam datesheet aane par alert. Har alert par tap → sahi screen. Read/unread state ke saath.
- **Kyun:** Ye parent app ka sabse important feature hai — aaj ye card haath se likha hua hai. Asli alerts ke bina parent ko school ki khabar ke liye roz dashboard kholna padta hai, aur tab bhi khabar fake milti hai.
- **Kahan dikhega:** Dashboard par alerts card (PN1 ke inbox se alag — alerts events hain, messages teacher ke bheje hue hain; dono ka feed ek inbox screen mein tabs se bhi dikh sakta hai, par card alag rahega).
- **Data kahan se:** **Nayi table** `school_notifications` (id, user_id, user_role, child_id, type, title, body, link_route, is_read, created_at) + RLS (parent sirf apni notifications dekhe). Events ko notification banane ka kaam usi step mein jodna hai jis step mein event banta hai (attendance mark, leave decision, PTM booking, homework assign) — alag se bada system nahi banana.
- **Graph/Excel:** Nahi — alerts ki report nahi hoti.

#### PN3. Homework Diary — roz ki homework, ek jagah

- **Kya hai:** Per child homework diary: aaj ki homework (subject, title, due date, status — pending / submitted / late / missing), is hafte ki list, teacher ki remark, aur material ka link (PN14 se). Late/missing homework red highlight ke saath. Parent ko har homework par "submitted" ka saboot (submission date/time) dikhega.
- **Kyun:** Parent roz yehi dekhne aata hai — "aaj homework mein kya mila, bache ne kiya ya nahi". Count se kaam nahi hota, diary se hota hai.
- **Kahan dikhega:** Dashboard par "Aaj ki Homework" section (top 3 + "View all" → poori diary) + drawer entry.
- **Data kahan se:** `school_homework` + `school_homework_submissions` — sab maujood. **Koi nayi table nahi.**
- **Graph/Excel:** Homework completion donut (PN5 ke reports mein) + diary ka Excel export (PAR-R07).

#### PN4. Attendance detail — aaj ki status + trend + warning

- **Kya hai:** Per child attendance detail: (a) **aaj ki status** — present / absent / late / leave / not marked yet (school ne abhi mark nahi ki to ye saaf likha hoga); (b) is mahine ka calendar/heatmap (attendance screen wala heatmap, per child); (c) trend chart — pichhle 30 din ki % (line chart); (d) **<75% warning** — CBSE rule: attendance 75% se neeche jaate hi parent ko warning card dikhega, kyunki board exam ke liye 75% zaroori hai.
- **Kyun:** Dashboard par sirf "%" dekh kar parent ko ye nahi pata chalta ki aaj bacha school gaya ya nahi. "Aaj" ki khabar parent app ka roz ka kaam hai.
- **Kahan dikhega:** Dashboard par stats card ke neeche "Aaj: Present/Absent" ki line + detail screen (attendance card par tap → yahi detail khulegi, generic attendance screen nahi).
- **Data kahan se:** `school_attendance` — maujood. **Koi nayi table nahi.**
- **Graph/Excel:** Trend line chart + heatmap + Excel (PAR-R01, PAR-R02, PAR-R03).

#### PN5. My Reports hub — per child reports (graph + Excel)

- **Kya hai:** Parent ke liye reports hub — har report **per child** (child switcher se bachcha badlo, report badal jayegi). Poora catalogue Part D mein hai (PAR-R01 se PAR-R14). Har report mein: filter (exam, subject, date range), **graph + Excel dono**, aur drill-down (report se seedha attendance/homework/fee screen).
- **Kyun:** Aaj parent ke paas reports ka koi raasta hi nahi hai — reports hub admin/teacher ka hai aur parent dashboard se kata hua hai. Parent ko apne bachche ki report ke liye admin ke hub mein nahi jaana chahiye.
- **Kahan dikhega:** Dashboard par "My Reports" section + drawer entry → `/school/reports` ka parent-scoped view (wahi screen, parent role par sirf parent tabs; Fees ka summary tab parent-scope mein chalega, baaki admin tabs nahi).
- **Data kahan se:** Maujood tables + PN3/PN4/PN6 wali aggregation.
- **Graph/Excel:** Har report — Part D dekho. Koi report sirf-list nahi hogi.

#### PN6. Fee statement deep — per child, poora hisaab

- **Kya hai:** Per child fee statement: (a) month-wise schedule (April–March, due date har mahine ki 5 taarikh); (b) fee heads ka itemized breakdown (Tuition, Computer/IT, Lab, Sports, Library, Exam); (c) paid vs due vs overdue, late fee ₹100 ka clear hisaab; (d) online pay (pay modal — Core Modules wala flow) + counter pay ki jaankari; (e) receipts ki list + PDF download; (f) payment history.
- **Kyun:** Parent ke liye fees sabse sensitive cheez hai — "kitna dena hai, kab tak, kis cheez ka, aur pehle kya diya" — ye chaaro sawaal ek screen par hone chahiye. Aaj parent ko ye dekhne ke liye fee screen mein ghusna padta hai jahan bachcha select karne ka flow hi nahi dikha.
- **Kahan dikhega:** Dashboard par Fees Due card par tap → selected bachche ki fee statement (child context ke saath) + drawer mein "Fees & Receipts" (pehle se hai — usi ko child-scoped karna hai).
- **Data kahan se:** Core Modules wala fee system (`school_fee_items`, `school_fee_payments`, `school_fee_receipts`, `school_fee_accounts`) — **fee ke rules dobara nahi likhne, sirf parent view banana hai**. Parent→child resolution PM6 mein fix hoga.
- **Graph/Excel:** Paid vs due bar chart (mahine-wise) + fee statement Excel (PAR-R08) + receipts Excel (PAR-R09).

#### PN7. PTM Manager — meri bookings, asli availability se

- **Kya hai:** (a) **Meri PTM bookings ki list** — upcoming + past, status ke saath (booked / done / no-show), cancel aur reschedule ka button (reschedule par wahi booking flow dobara, purani booking cancel hoke nayi banegi — double booking nahi hogi). (b) **Asli availability se booking** — teacher list allotment se aayegi (class teacher + subject teachers, haath se likhe 3 naam nahi), slots PTM config se aayenge (fixed 3 slots nahi), **date picker hoga** (aaj + 3 din fixed nahi). (c) Booking confirm hone par PN2 mein alert aayega.
- **Kyun:** Aaj PTM booking nakli availability par chalti hai aur booking ke baad parent use dekh bhi nahi sakta. PTM parent-teacher rishtedari ka sabse bada din hota hai — iska flow sabse saaf hona chahiye.
- **Kahan dikhega:** Dashboard par "PTM" section (agli booking + Book button) + drawer entry "My PTM Bookings".
- **Data kahan se — VERIFY-FIRST:** Pehle dhoondho ki PTM slots ki config kahan hai (koi table/config hai ya nahi) aur teacher allotment ka source kya hai (`getTeacherClasses` / allotment). Aaj PTM bookings `school_circulars` mein string encode karke padi hain — **nayi table** `school_ptm_bookings` (id, parent_username, student_id, teacher_id, date, time_slot, agenda, status, created_at) + RLS (parent sirf apni bookings dekhe; teacher sirf apne slots dekhe). Purani circular-encoded bookings padhne ka raasta bhi rakhna hai (history na khoye) — migration ka faisla admin se PAR0 mein confirm karna hai, andha migration nahi hoga.
- **Graph/Excel:** PTM history Excel (PAR-R11).

#### PN8. Grievance Tracker — ticket file karo, track bhi karo

- **Kya hai:** (a) **Mere tickets ki list** — ticket number, subject, department, date, aur status timeline (Filed → In Review → Resolved / Reopen). (b) Ticket par tap → poori detail + school ka reply (agar admin ne reply diya ho). (c) Resolved ticket ko reopen karne ka button. (d) Naya ticket file karne ka flow wahi rahega (dialog — category, subject, description), par ticket number ka format aur status tracking naye system se aayega.
- **Kyun:** Aaj parent sirf ticket file kar sakta hai — uske baad ticket kahan gaya, kisne dekha, kya hua — kuch pata nahi chalta. Bina tracking ke grievance system sirf "shikayat peti" hai, system nahi.
- **Kahan dikhega:** Dashboard par "My Grievances" section (open tickets ka count + top 2) + drawer entry.
- **Data kahan se:** Aaj grievances `school_circulars` mein string encode karke padi hain — **nayi table** `school_parent_grievances` (id, ticket_no, parent_username, student_id, category, subject, description, status, admin_reply, created_at, updated_at) + RLS (parent sirf apne tickets dekhe). Admin side par grievance resolution tool pehle se hai (Step 13.1) — nayi table se jodna Admin deep-dive ka kaam hoga, is document mein sirf parent side + table design hai. Purani circular-encoded tickets padhne ka raasta rakhna hai (history na khoye).
- **Graph/Excel:** Grievance history Excel (PAR-R12).

#### PN9. Class Teacher se seedha message (1:1)

- **Kya hai:** Parent apne bachche ke class teacher ko seedha message bhej sake (homework, attendance, ya koi concern) aur teacher ka reply dekh sake — ek thread mein, per child. Message bhejta waqt parent ko dikhega ki message kis teacher ko ja raha hai (class teacher ka naam allotment se aayega, haath se likha nahi).
- **Kyun:** Enterprise parent app mein two-way communication hoti hai — sirf school ki taraf se notices padhna kaafi nahi hai. Aaj parent ke paas teacher tak pahunchne ka koi raasta nahi hai.
- **Kahan dikhega:** Child profile/section se "Message Class Teacher" button + inbox (PN1) mein alag tab "Teacher Messages".
- **Data kahan se:** **Nayi table** `school_parent_teacher_messages` (id, parent_username, student_id, teacher_id, body, sender_role, created_at) + RLS (parent sirf apne threads dekhe; teacher sirf apni classes ke threads dekhe). **Cross-dashboard note:** Teacher side par reply karne ka inbox teacher dashboard mein nahi hai — wo teacher document ka follow-up hai (is document mein parent side + table design hai; teacher ko reply ka UI chahiye, ye baat HANDOFF mein likhni hai aur Maalik se confirm karni hai).
- **Graph/Excel:** Nahi — messages ki report nahi hoti.

#### PN10. Behaviour notes ka parent view — DECISION POINT (Maalik ka faisla pending)

- **Kya hai:** Teacher ke behaviour notes (positive ya concern) parent ko dikhane hain ya nahi — **ye is document ka ek matra aisa feature hai jo Maalik ke faisle ke bina nahi banega.** Default **OFF** hai: parent ko notes nahi dikhenge, sirf teacher + admin dekhenge (teacher MD N7 ka default).
- **Agar Maalik haan kahe to:** Child profile mein "Teacher Notes" section — note ka type (positive/concern), date, teacher ka naam, aur note text. Parent notes par reply nahi kar sakta (reply ke liye PN9 hai). Concern wale notes par parent ko PN2 mein alert aayega.
- **Agar Maalik na kahe to:** Ye feature poora drop ho jayega — iski koi table, koi UI, koi report nahi banegi. Execution mein iska step **BLOCKED** rahega jab tak Maalik jawab na de.
- **Kahan dikhega (haan hone par):** Child profile sheet ke andar "Teacher Notes" tab.
- **Data kahan se (haan hone par):** Teacher MD N7 wali `school_behaviour_notes` table — **wahi table, dobara nahi banegi**; parent view sirf usi table par RLS ke saath read karega (parent sirf apne bachche ke notes dekhe).
- **Graph/Excel (haan hone par):** Notes summary Excel (PAR-R14 ke andar ek sheet).

#### PN11. Transport live — mere bachche ki bus, live

- **Kya hai:** Per child transport card: bus/route, stop, **live ETA**, aur boarding/alighting status (bachcha bus mein chadha ya utra — Step 8 wala per-stop attendance). Bus late ho ya route badle to PN2 mein alert.
- **Kyun:** Dashboard ka "Transport Live" alert aaj haath se likha hai, jabki transport module mein live telematics maujood hai. Parent ko apne bachche ki bus ki asli khabar milni chahiye — ye parent app ke sabse zyada khole jaane wale features mein se ek hai.
- **Kahan dikhega:** Dashboard par alerts card ke neeche transport card (agar bachcha bus use karta hai to hi dikhega — bus use na karne wale parent ko ye card nahi dikhega) + drawer mein "Transport & Bus" (pehle se hai).
- **Data kahan se — VERIFY-FIRST:** Transport module ka live data kya hai (per-stop boarding/alighting, journey telematics — Step 8 ke hisaab se maujood hai) — PAR0 mein check karna hai ki parent ke liye kaunsa live field available hai aur kis table se aata hai (`school_transport` + journey data).
- **Graph/Excel:** Transport attendance Excel (PAR-R13).

#### PN12. Exam datesheet + countdown widget

- **Kya hai:** Per child widget: agla exam kab hai (countdown — "Half Yearly mein 12 din"), us exam ki date sheet ka link, aur result aane par PN2 mein alert + report card ka link.
- **Kyun:** Parent ka saara sawaal exam ke around ghoomta hai — "exam kab hai, datesheet kya hai, result kab aayega". Ye widget dashboard ko "aaj kya zaroori hai" wali feeling deta hai.
- **Kahan dikhega:** Dashboard par schedule/datesheet ki slim banner (exam paas ho to highlighted).
- **Data kahan se:** `school_exam_sessions` — maujood. **Nayi table nahi.**
- **Graph/Excel:** Exam-wise trend PAR-R04 mein aayega.

#### PN13. My Children — linked bachche + link request

- **Kya hai:** (a) Linked bachchon ki list (naam, class, relation, linked date). (b) **Naya bachcha link karne ka request** — admission number + date of birth daal kar request bhejo; admin approve kare to bachcha link ho jayega (admin side ka approval Admin deep-dive mein aayega — is document mein sirf parent side + request table hai). (c) Galat link ki report (agar koi aur ka bachcha dikh raha ho to "Report wrong link" — admin ko alert jayega).
- **Kyun:** Aaj parent apne linked bachche dekh bhi nahi sakta ki kaun link hai, aur naya bachcha link karne ka koi flow nahi hai — sab admin ko bol kar karwana padta hai. Aur Part B kami #1 (galat bachche dikhna) ka ek hissa ye bhi hai ki parent ke paas "ye mera bachcha nahi hai" bolne ki jagah nahi hai.
- **Kahan dikhega:** Drawer mein "My Children" + dashboard par child switcher ke paas "+ Link Child" ka chhota button.
- **Data kahan se:** `parent_student_links` (maujood) + **nayi table** `school_link_requests` (id, parent_username, admission_no, dob, status, created_at, decided_by) + RLS (parent sirf apni requests dekhe).
- **Graph/Excel:** Nahi — linking ki report nahi hoti.

#### PN14. Study materials — asli download, asli files

- **Kya hai:** LMS-Lite modal ko asli banao: (a) download button **sach mein file download** kare (file URL se — `file_url` field maujood hai, use karna hai); (b) subject filter + search; (c) material ki list mein upload date aur uploaded-by dikhe; (d) file attach hi na ho to "file not attached" state dikhe — fake URL fallback kabhi nahi.
- **Kyun:** Aaj download button sirf snackbar dikhata hai aur file URL ka fallback ek haath se likha `notes.pdf` link hai. Parent ko lagta hai notes download ho gaye, par kuch download nahi hota.
- **Kahan dikhega:** Wahi LMS-Lite modal (dashboard quick action + homework diary se bhi link).
- **Data kahan se — VERIFY-FIRST:** Materials aaj `school_circulars` mein 'StudyMaterial' category se aate hain (content mein `STUDY_MATERIAL | ClassId: | Subject: | Title: | Url: | UploadedBy:` encode hota hai). Upload ka flow kahan hai (teacher/admin kahan se upload karta hai) — PAR0 mein dhoondhna hai. Agar upload flow maujood hai to **wahi reuse** karo; agar nahi hai to upload flow teacher/admin side ka kaam hai (is document mein sirf parent ka download + list hai). **Nayi table is feature mein nahi** — pehle circulars-based flow ko theek se kaam karwao; dedicated materials table ka faisla tab hoga jab upload flow samajh aaye (PAR0 mein likhna hai).
- **Graph/Excel:** Nahi — materials ki report nahi hoti.

---

### C2. MODIFY — isi mein badlav (pehle se hai, par adhoora/galat hai)

#### PM1. Fake metrics purge — jhoothe numbers hatana (sabse pehla fix)

- **Aaj:** Dashboard default attendance `92.5%` aur result `'A1 (94%)'`; service ke error fallback mein attendance `92.5%` aur result `'A2 (86%)'`; naam `'Aarav Sharma'`, roll `'SCH2026-10A'`, classId guess `'cls-9a'/'cls-10a'`, session `'2025-26'`, institute naam haath se likha.
- **Badlav:** (a) Dashboard ke saare fallbacks delete — metric na mile to card par "Not available" / empty state dikhega, kabhi jhootha % ya grade nahi. (b) Service (`getChildDashboardMetrics`) bhi fallback dena band kare — compute na ho to `null`/`0` + "not available" flag de, `92.5`/`A2 (86%)` kabhi nahi. (c) ClassId guess delete — `class_id` sirf `school_students`/`school_classes` se aayega; na mile to metrics load hi nahi hoga aur empty state dikhega. (d) Session institute ke session config se aayega (VERIFY-FIRST: session kahan store hota hai — admin dashboard mein kya use hota hai); na mile to session line hi nahi dikhegi.
- **Verification:** Aise parent se login karo jiske bachche ka koi data nahi hai — dashboard par **koi number, naam ya grade nahi** dikhna chahiye, sirf empty states. Live DB par ek bachche ki attendance mark karo — dashboard ka % turant badalna chahiye.

#### PM2. getParentChildren privacy fix — galat bachche dikhna band (security fix, PAR1 mein sabse pehle)

- **Aaj:** Koi link na ho to service `school_students` se pehle 2 bachche de deti hai (`limit(2)`).
- **Badlav:** Koi link na ho to **khaali list** milegi + dashboard par "No child linked yet" empty state dikhega — usme "+ Link Child" ka button hoga (PN13) aur admin se contact karne ki line hogi. Kisi bhi haal mein bina link ke bachche ka data parent ko nahi milega. Ye fix **PAR1 mein sabse pehle** hoga — iske bina aage ka kaam shuru nahi hoga.
- **Verification:** Aise parent se login karo jiska koi bachcha link nahi hai — **koi bachcha, koi naam, koi metrics nahi** dikhna chahiye. Doosre parent ke bachche ka username se seedha access karke bhi check karna hai — access **deny** hona chahiye (RLS test PAR7 mein).

#### PM3. Alerts card asli karna — haath se likhe alerts hatana

- **Aaj:** Bus UK-07-PA-1024 (ETA 12 mins) aur Science-Maths worksheets ("before Friday") haath se likhe hain.
- **Badlav:** Dono hardcoded items **delete** — alerts card sirf PN2 ke event feed se bharega. Koi alert na ho to "No new alerts" empty state dikhega. Transport wala alert PN11 ke live data se aayega, homework wala alert PN3 ke real homework se aayega — alag se haath se likha text kabhi nahi.
- **Verification:** Dashboard kholo — bus number, ETA, "Friday" jaisa koi haath se likha text **kahin nahi** dikhna chahiye (grep se verify karna hai).

#### PM4. PTM dialog asli karna — teacher, slot, date teeno real

- **Aaj:** Teacher list haath se likhi (3 naam), slots haath se likhe (3 fixed), date fixed (aaj + 3 din).
- **Badlav:** (a) Teacher dropdown allotment se aayega (class teacher + us bachche ke subject teachers — `getTeacherClasses` / allotment data se). (b) Slots PTM config se aayenge (VERIFY-FIRST: config kahan hai — agar config nahi hai to admin se slot config banwana PAR0 mein note karna hai, haath se likhe slots nahi). (c) **Date picker hoga** — parent date choose kar sake (aaj se 30 din tak, school ke PTM days ke hisaab se). (d) Booking ke baad PN7 wali bookings list mein booking dikhni chahiye.
- **Verification:** Kisi teacher ko allotment se hatao — PTM dropdown se wo naam **gayab** hona chahiye. Koi booking karo — PN7 ki list mein turant dikhni chahiye.

#### PM5. LMS download asli karna — snackbar se real download tak

- **Aaj:** Download button sirf `'Downloading <title>...'` snackbar dikhata hai; file URL fallback haath se likha `notes.pdf` link hai.
- **Badlav:** (a) Download button `file_url` se asli file download kare (web par file download ka wahi pattern jo report card PDF / receipts mein use hota hai — dobara invent nahi karna). (b) URL fallback delete — file URL na ho to button ki jagah "file not attached" dikhega. (c) Download fail ho to error snackbar + retry.
- **Verification:** Ek material download karo — file sach mein download honi chahiye. Bina URL wale material par download button **nahi** dikhna chahiye.

#### PM6. Fee screen parent scoping — parent ko sahi bachche ka ledger

- **Aaj:** Fee screen logged-in username se load hoti hai; parent ke liye child select ka flow nahi dikha; fallback `'sstudent1'` bhi hai.
- **Badlav:** (a) Parent role par fee screen **selected bachche** ka ledger dikhayegi — child switcher fee screen ke upar hoga (dashboard se aate waqt selected bachcha route ke through pass hoga). (b) Username fallback `'sstudent1'` delete — username na mile to error state dikhega, kisi aur bachche ka ledger nahi. (c) Fees Due card (dashboard) selected bachche ka amount dikhayega (aaj metrics se aata hai — wahi rahega, par child context ke saath).
- **Verification:** 2 bachchon wale parent se login karo — pehle bachche ki fees dekho, phir doosre ki — **dono ke amounts alag** dikhne chahiye aur har ek apne bachche se match karna chahiye. Ek parent doosre parent ke bachche ka ledger **kabhi nahi** khol paye.

#### PM7. Leave dialog hardening — fallback ids aur fake document hatana

- **Aaj:** `studentId` fallback `'sstudent1'`, `classId` fallback `'cls-10a'`; document ke naam par `'Self-Certified by Parent <username>'` string bhejta hai.
- **Badlav:** (a) Fallback ids delete — student/class na mile to dialog hi nahi khulega, error dikhega ("child data not loaded, retry karo"). (b) Document upload **asli** hoga — medical leave par optional document picker (file_picker — pubspec mein maujood hai); document na ho to field khaali jayega, fake "Self-Certified" string kabhi nahi. (c) Leave type list config se aayegi (Medical/Casual/Family Function aaj haath se likhe hain — ye teeno theek hain, par list ek jagah se aani chahiye taaki admin badal sake; VERIFY-FIRST: leave types kahan define hain).
- **Verification:** Leave apply karo — `school_student_leaves` mein sahi student_id aur class_id hone chahiye, `'sstudent1'`/`'cls-10a'` kabhi nahi.

#### PM8. Design parity — minimalist light theme (orbs aur glass hatana)

- **Aaj:** Pink gradient AppBar, 3 blurry orbs, glass panels, gradient drawer — Admin (13.1), Student (13.2) aur Teacher ke minimalist light theme se match nahi karta.
- **Badlav:** Slate-50 canvas (`#F8FAFC`), white cards, hairline `#E2E8F0` borders, deep ink `#0F172A` typography — wahi standard jo baaki dashboards par hai. Parent ki pehchaan (pink accent `#DB2777`) **muted tareeke se** rahegi (small badges, active states, icons) — poori screen pink nahi hogi. Drawer bhi light-theme hoga (white background, ink text — aaj ka pink gradient + blur drawer hat jayega). Orbs aur `BackdropFilter` blur **poora delete** hoga.
- **Verification:** Parent dashboard aur student dashboard side-by-side kholo — canvas, cards, drawer aur AppBar ka style **ek jaisa** hona chahiye, sirf accent colour alag.

#### PM9. Stats grid drill-down — card se detail tak

- **Aaj:** Cards sahi screens par le jaate hain, par bina child context ke aur bina detail ke.
- **Badlav:** (a) Attendance card → PN4 attendance detail (aaj ki status + trend). (b) Fees Due card → PN6 fee statement (selected bachche ki). (c) Homework Due card → PN3 diary (aaj ki homework). (d) Latest Result card → report card + PAR-R04 trend. Har card par tap karte waqt **selected bachcha** saath jayega (route param ya shared state — jo pattern app mein pehle se use hota hai, wahi).
- **Verification:** 2 bachchon wale parent se ek bachcha select karke Attendance card par tap karo — khuli screen mein **wahi bachcha** dikhna chahiye.

#### PM10. Child info card real — fake bachcha kabhi nahi

- **Aaj:** Naam `'Aarav Sharma'`, roll `'SCH2026-10A'`, session `'2025-26'` fallbacks; koi bachcha na ho to bhi fake card dikhta hai.
- **Badlav:** (a) Saare fallbacks delete — naam/roll/class DB se aayenge; na aayen to card ki jagah empty state dikhega. (b) Session session config se aayega (PM1 ke saath). (c) Relation `parent_student_links` se aayega (pehle se aata hai — wahi rahega). (d) Card par report card button rahega (pehle se hai).
- **Verification:** PM1 wali verification ke saath — koi bachcha link na ho to card ki jagah "No child linked yet" dikhna chahiye.

#### PM11. Circulars dashboard integration — inbox se jodna

- **Aaj:** Dashboard par top 3 circulars hain, "View All" se circulars screen khulti hai.
- **Badlav:** Circulars PN1 ke inbox mein mil jayenge — inbox mein filter hoga (All / School Notices / Class Messages / Teacher Messages). Dashboard par top 3 ki jagah **top 3 unread** dikhenge (circulars + teacher messages, date ke hisaab se). Read karne par badge count ghatega.
- **Verification:** Ek naya circular publish karo — parent dashboard par unread count **badhna** chahiye; padhne par **ghatna** chahiye.

#### PM12. Drawer + dashboard parity + Profile entry

- **Aaj:** Drawer mein 10 entries hain; PTM/Grievance/Leave/LMS sirf quick actions se khulte hain; Profile/Settings kahin nahi hai.
- **Badlav:** Ek hi source of truth — dashboard sections, quick actions aur drawer entries **ek jaisi list** se banengi. Final drawer list: Dashboard, Messages (PN1), Notifications (PN2), My Children (PN13), Attendance, Homework Diary (PN3), Fees & Receipts, My Reports (PN5), PTM Bookings (PN7), Grievances (PN8), Circulars, Transport & Bus, Report Cards, Timetable, Library, Certificates, Study Materials (PN14), Profile & Settings, Logout. **Profile & Settings** mein hoga: contact details dekhna/update request, notification preferences (alerts on/off per type — VERIFY-FIRST: preferences ka koi system hai ya nahi; na ho to `school_parent_preferences` table + RLS isi feature mein banegi), aur "Report wrong link" (PN13).
- **Verification:** Dashboard aur drawer ki list side-by-side compare karo — koi entry miss nahi honi chahiye.

#### PM13. 4-state standard har jagah

- **Aaj:** Dashboard load par error + retry hai, par loading sirf spinner hai (skeleton nahi); dialogs aur lists mein 4-state adhoora hai.
- **Badlav:** Dashboard ke har section (switcher, metrics, alerts, leaves, circulars) mein 4-state laagu hoga — loading mein skeleton, khaali mein empty+CTA, error mein retry, loaded mein data. 48dp minimum touch targets aur 8pt grid (Step 13 standard) poore dashboard par.
- **Verification:** Har section ko loading / empty / error / loaded — chaaron haalat mein check karna hai (Gemini khud batayega ki kaise test kiya).

#### PM14. Child switcher robustness — bachcha badlo to sab badle

- **Aaj:** Switcher se metrics aur leaves reload hote hain, par fee card, alerts aur circulars child scope se nahi badalte (circulars to school-wide hain hi; fee card bina context ke fee screen kholta hai).
- **Badlav:** (a) Bachcha badalne par **sab kuch** reload hoga — metrics, leaves, homework diary, fee due, attendance status, messages, reports. (b) Aakhri selected bachcha session mein yaad rahega (wapas aane par wahi bachcha dikhe). (c) Switcher mein bachche ki class + initials/photo dikhegi (sirf naam nahi).
- **Verification:** Bachcha A select karke fees dekho, phir bachcha B select karo — dashboard ka har number **B ka** hona chahiye, A ka kuch nahi rehna chahiye.

---

## Part D — Reports catalogue (parent ki har report: per child, graph + Excel)

**Rule (sab reports par):** Har report **per child** hai — child switcher se bachcha badlo, report ka data badal jayega. Parent sirf apne linked bachchon ki reports dekh sakta hai — filter service layer par `parent_student_links` se lagega. Har report mein filter hoga (exam, subject, date range). Har report ka **graph `fl_chart` se** aur **Excel `excel` package se** banega. Excel standard (Core Modules wala hi reuse hoga): pehli sheet **Summary** (child name, class, filters, totals, generated date), doosri sheet **Data** (poori rows), totals row har sheet ke ant mein, file ka naam `Parent_<parentUsername>_<CODE>_<YYYYMMDD>.xlsx` (bachche ka naam Summary sheet ke andar likha hoga, file naam mein nahi — taaki file naam chhota aur safe rahe). Reconciliation rule: report ka har number uski source screen (attendance / marks / homework / fee) se match karna chahiye — mismatch mile to report galat hai, data nahi.

| Code | Report | Graph (fl_chart) | Excel mein kya hoga |
|---|---|---|---|
| PAR-R01 | Attendance trend — per child, pichhle 30 din / mahina | Line chart (din-wise %) | Daily rows + monthly summary |
| PAR-R02 | Attendance register — per child, date-wise P/A/L/Leave | — (register table hai; trend PAR-R01 mein hai) | Poora register + summary counts |
| PAR-R03 | Attendance warning — <75% status + monthly summary | Bar chart (mahine-wise %) | Monthly rows + 75% threshold flag |
| PAR-R04 | Marks trend — per child, exam-wise | Line chart (exam-wise % / grade) | Exam-wise rows per subject |
| PAR-R05 | Subject-wise performance — per child, latest exam | Bar chart (subject averages) | Subject rows + marks + grade |
| PAR-R06 | Report card summary — per child, saare exams | — (card summary table hai) | Exam-wise summary + grades + remarks |
| PAR-R07 | Homework completion — per child | Donut chart (submitted/late/missing %) | Per-homework rows + status + due dates |
| PAR-R08 | Fee statement — per child, month-wise | Bar chart (paid vs due, mahine-wise) | Month rows + heads + late fee + totals |
| PAR-R09 | Fee receipts & payment history — per child | — (receipts table hai) | Receipt rows + receipt no + amount + mode + date |
| PAR-R10 | Leave history — per child | — (list hai) | Leave rows + type + dates + status + approver |
| PAR-R11 | PTM history — per child | — (list hai) | PTM rows + teacher + date + slot + status |
| PAR-R12 | Grievance history — per child | — (list hai) | Ticket rows + category + status + dates |
| PAR-R13 | Transport attendance — per child, boarding/alighting | — (table hai; VERIFY-FIRST: data availability) | Date rows + boarding/alighting status + route |
| PAR-R14 | Monthly progress pack — per child, ek mahine ka sab kuch | Line chart (attendance %) + bar chart (marks) | 4 sheets: Attendance + Marks + Homework + Fees (har sheet par summary) |

**Note:** PAR-R02, PAR-R06, PAR-R09, PAR-R10, PAR-R11, PAR-R12, PAR-R13 table-type reports hain (inme graph ka matlab nahi hai) — par Excel inka bhi banega, bina exception. PAR-R13 tabhi banega jab transport ka per-child boarding data PAR0 mein confirm ho jaye — na mile to ye report drop hogi, fake data se nahi banegi.

---

## Part E — Gemini execution plan (line-by-line)

### E1. Steps aur order

**PAR0 — Verify (koi code change nahi, sirf report).** Pehle ye sab dhoondh kar CHECKPOINT mein likhna hai: (a) `getParentChildren` ka no-link behaviour aur RLS — live DB par test karke likhna hai ki bina link wale parent ko kya dikhta hai; (b) parent login se fee screen — kis bachche ka ledger dikhta hai, child select ka flow hai ya nahi; (c) circulars ki audience values (`All/Students/Parents/Teachers` — class-wise nahi, ye confirm hai) aur PTM/grievance/materials ka circulars-encoded storage (ye bhi confirm hai — kaunsi category/content format use hota hai, note karna hai); (d) PTM slots ki config kahan hai aur teacher allotment ka source kya hai; (e) transport ka live per-child data kya hai (`school_transport` + journey data — PAR-R13 ke liye); (f) study materials ka upload flow kahan hai (teacher/admin kahan se upload karta hai); (g) notifications/preferences ka koi system hai ya nahi; (h) Step 10 ke E2E daave (leave ID, PTM ID, ticket TKT-892104) — live DB par dobara verify karna hai ki wo records aaj bhi maujood hain ya nahi; (i) **behaviour notes parent view ka faisla Maalik se poochna hai** — PN10 iske bina BLOCKED rahega. **PAR0 ke bina PAR1 shuru nahi hoga.**

**PAR1 — Real-data purge + privacy fix (PM1, PM2, PM10, PM5 ka URL fallback, PM7 ke fallback ids).** Saare haath se likhe fallbacks hatana hain (92.5, A1 94%, A2 86%, Aarav Sharma, SCH2026-10A, cls-9a/cls-10a guess, sstudent1, session 2025-26, notes.pdf URL, Self-Certified string). **Sabse pehle PM2** (privacy fix) — uske bina aage ka kaam shuru nahi hoga. **Done tabhi jab:** bina link wale parent ko koi bachcha nahi dikhta (PAR0 wale live test se verify); bina data wale bachche ke dashboard par koi number/naam/grade nahi dikhta, sirf empty states; grep se verify karna hai ki parent dashboard file mein `92.5`, `A1 (94%)`, `Aarav Sharma`, `SCH2026-10A`, `cls-9a`, `cls-10a`, `sstudent1` kahin nahi bache (sirf test/seed files mein reh sakte hain, app code mein nahi).

**PAR2 — Design parity + drawer/profile (PM8, PM12, PM13).** Orbs + glass + pink gradient hatakar minimalist light theme laana hai; drawer ki list PM12 wali banana hai (Messages, Notifications, My Children, My Reports, Profile & Settings ke saath); har section mein 4-state laana hai. **Done tabhi jab:** parent dashboard aur student dashboard side-by-side ek jaise dikhein (sirf accent alag); drawer ki list PM12 se match kare.

**PAR3 — Bachche ka roz ka kaam (PN4 attendance detail, PN3 homework diary, PN12 exam widget, PM9 drill-downs, PM14 switcher).** **Done tabhi jab:** dashboard par "aaj" dikhe (aaj ki attendance status, aaj ki homework, agla exam); bachcha badalne par har number badle; <75% warning sahi waqt par dikhe.

**PAR4 — Communication (PN1 inbox, PN2 live alerts, PN9 1:1 teacher message, PM3, PM11).** **Done tabhi jab:** teacher ka bheja hua message (teacher MD N4 wali table se) parent ke inbox mein dikhe; absent mark hote hi alert aaye; alerts card mein koi haath se likha text na bache. **Note:** PN10 (behaviour notes view) is step mein **nahi** aayega — wo Maalik ke faisle par BLOCKED hai; faisla aate hi use alag mini-step mein karna hai.

**PAR5 — Paisa aur admin flows (PN6 fee deep, PM6 fee scoping, PN7 PTM manager, PN8 grievance tracker, PM4 PTM dialog, PM7 leave hardening).** **Done tabhi jab:** parent sahi bachche ki fees dekhe aur pay kar sake (receipt ke saath); PTM booking asli teacher/slot/date se ho aur bookings list mein dikhe; grievance ka status timeline dikhe. **Fee ke rules dobara nahi likhne** — Core Modules wala fee system hi source hai.

**PAR6 — Reports + Excel (PN5, PAR-R01 se PAR-R14, PM11 inbox integration).** `fl_chart` ka parent mein pehla use (charts), `excel` package ka parent mein pehla use (.xlsx). Har report per child hogi. **Done tabhi jab:** har PAR-R report ka Excel uski screen ke numbers se match kare; parent doosre parent ke bachche ki report **kabhi nahi** khol paye.

**PAR7 — Final QA + HANDOFF.** Poora parent E2E live DB par: (a) 2 bachchon wala parent — switch karke har section check; (b) bina link wala parent — koi data nahi dikhna chahiye; (c) har PAR-R report (graph + Excel) per child; (d) leave apply → teacher approve → attendance excused (poora flow ek baar live karke dikhana hai); (e) PTM book → list mein dikhe; (f) grievance file → status dikhe; (g) college regression (`flutter analyze` poore repo par, college screens kholkar dekhna — koi college screen nahi tootni chahiye). Phir HANDOFF block (neeche template) + agle dashboard ke liye 3-line note.

### E2. Hard rules (Gemini ke liye — todna mana hai)

1. College code/tables/routes — zero touch. Sirf school files + `school_*` tables (+ `parent_student_links` jo pehle se school ki hai).
2. Koi mock/fake/demo data nahi — na dashboard mein, na report mein, na test mein (test data alag se mark hoga aur live DB par nahi jayega). Khaas taur par: koi bus number, ETA, teacher naam, slot, grade ya % haath se nahi likhna.
3. Har nayi table: SQL file `database/` mein + RLS policies ke saath + CHECKPOINT mein table ka naam aur RLS test ka saboot. Parent-scope har query mein — `parent_student_links` se filter, kabhi poori table mat uthao aur UI par filter mat karo.
4. PTM/grievance/materials ki nayi tables banate waqt purani circular-encoded history **delete mat karna** — purani entries padhne ka raasta rakhna hai; migration ka faisla admin se PAR0 mein confirm karke hi hoga.
5. Koi secret/key/password file mein nahi. Fee ke rules dobara nahi likhne.
6. Har step: pehle `flutter analyze` us file par, phir poore `lib/features/school/` par — 0 errors, 0 warnings tabhi CHECKPOINT.
7. Har step ke baad `SCHOOL_PROGRESS.md` mein row + CHECKPOINT + commit (`parent-dash: PAR<n> — <title>`). Limit aaye to HANDOFF block likhna hai — adhoora step "ho gaya" nahi kehna.
8. **PN10 (behaviour notes parent view) Maalik ke faisle ke bina shuru nahi hoga.** Faisla "naa" ho to iska step cancel kar dena hai, "haan" ho to hi banana hai.

### E3. HANDOFF template (limit par Gemini ye likhega)

```
HANDOFF — Parent Dashboard Deep-Dive
Poora hua: PAR0–PAR<n> (har step ka commit + CHECKPOINT SCHOOL_PROGRESS.md mein hai)
Chal raha tha: PAR<n+1> — <kya kar raha tha, kahan ruka, kaunsi file khuli thi>
Agla agent yahan se shuru kare: <exact step + pehla action>
Ruka hua / pending: <koi Maalik ka faisla baaki ho to — jaise behaviour notes parent view (PN10), PTM slot config, materials upload flow>
Test saboot: <live DB par kya verify hua, kya nahi — khaas taur par privacy test (bina link wala parent) aur 2-bachche wala switch test>
```

---

## Part F — Parent ke baad (roadmap, order Maalik ka faisla)

1. **Teacher (deep-dive ho chuka hai)** — dashboard #1, poora.
2. **Parent (ye document)** — teacher ke baad; parent school ERP ka sabse bada user hai, isliye iska deep-dive pehle aaya.
3. **Admin / sadmin command center** — alag document mein ban raha hai (Maalik ne teeno ek-ek karke banane ko kaha hai). Kaam: analytics + Excel parity, approvals queue ka deep-dive, UDISE+ sheet ka Excel parity, grievance resolution ka admin side (PN8 wali nayi table se jodna), PTM slot config ka admin side (PN7), link requests ka approval (PN13).
4. **Student dashboard** — alag document mein ban raha hai (Maalik ne teeno ek-ek karke banane ko kaha hai). Kaam: student ka analytics (apna trend, homework, attendance) + Excel (apni report card ka Excel).
5. **Module screens ka second pass** — attendance, marks, homework, timetable, fee, transport — parent dashboard ke baad jo gaps bachenge (jaise fee screen ka parent scoping agar PAR mein poora na ho, ya transport ka live data), wo alag document mein aayenge.

**Admin aur Student ke deep-dives is document mein nahi hain — Gemini is document mein sirf Parent karega, baaki dashboards ko chhooega nahi. Teacher document ka follow-up bhi baaki hai:** teacher side par parent messages ka reply inbox (PN9 ka doosra hissa) — wo teacher document mein jodna hoga, is document mein nahi.

---

## Appendix — Files, methods, tables (execution ke waqt kaam aayega)

### A. Files

| File | Kaam |
|---|---|
| `lib/features/school/parent/school_parent_dashboard.dart` (1,628 lines) | Parent dashboard — is document ka main file |
| `lib/features/school/leave/student_leave_screen.dart` | Student leave — parent apply karta hai, class teacher approve/reject karta hai |
| `lib/features/school/fee/school_fee_screen.dart` | Fee view + pay modal + receipts (parent/student role allowed; teacher ko ledger access nahi) |
| `lib/features/school/homework/homework_list_screen.dart` (959 lines) | Homework list — parent ko student wala view milta hai |
| `lib/features/school/marks/report_card_screen.dart` | CBSE HPC report cards — parent sirf apne bachche ka card dekhta hai, picker kabhi nahi |
| `lib/features/school/attendance/school_attendance_screen.dart` (2,131 lines) | Daily/Monthly/Defaulters + monthly heatmap |
| `lib/features/school/circulars/circulars_screen.dart` | Circulars — audience sirf All/Students/Parents/Teachers (class-wise nahi) |
| `lib/features/school/transport/transport_screen.dart` | Transport — live telematics (Step 8), per-stop attendance |
| `lib/features/school/timetable/school_timetable_screen.dart` (1,787 lines) | Timetable (drawer se, bina child context ke) |
| `lib/features/school/library/school_library_screen.dart` | Library (drawer se) |
| `lib/features/school/certificates/school_certificates_screen.dart` | Certificates (drawer se) |
| `lib/features/school/reports/school_reports_screen.dart` (2,687 lines) | Reports hub (admin-flavoured — parent-scoped view PN5 mein banega) |
| `lib/services/school_service.dart` (6,882 lines) | Sab school service methods |
| `lib/services/school_export_service.dart` | PDF/CSV exports (class results, attendance, pending fees) |
| `lib/features/auth/login_screen.dart` | Login — `case 'parent'` → `/school/parent-dashboard` |
| `lib/routes/app_router.dart` | Routes — `/school/parent-dashboard` |
| `pubspec.yaml` | `fl_chart: ^0.65.0` (school mein unused), `excel: ^4.0.2` (school mein unused), `csv: ^6.0.0`, `pdf`, `printing`, `file_picker` |

### B. Service methods (parent se jude, maujood)

`getParentChildren`, `getChildDashboardMetrics`, `getStudentLeaves`, `applyStudentLeave`, `bookPtmSlot`, `fileParentComplaint`, `getStudyMaterials`, `getCirculars`.

### C. Tables (maujood — nayi tables Part C mein alag se likhi hain)

`parent_student_links`, `school_students`, `school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_student_leaves`, `school_circulars`, `school_fee_items`, `school_fee_accounts`, `school_fee_payments`, `school_fee_receipts`, `school_classes`, `school_subjects`, `school_timetable`, `school_exam_sessions`, `school_report_card_meta`, `school_transport`, `school_library`, `school_library_issues`, `institutes`.

### D. Nayi tables (sirf tab jab VERIFY-FIRST mein na milen — har ek par RLS mandatory hai)

| Table | Feature | RLS rule (ek line mein) |
|---|---|---|
| `school_teacher_messages` | PN1 (inbox) — teacher MD N4 wali wahi table | Teacher sirf apni classes ko bhej sake; parent sirf apne bachche ki class ke messages dekhe |
| `school_notifications` | PN2 (live alerts) | Parent sirf apni (apne bachchon ki) notifications dekhe |
| `school_ptm_bookings` | PN7 (PTM manager) | Parent sirf apni bookings dekhe; teacher sirf apne slots dekhe |
| `school_parent_grievances` | PN8 (grievance tracker) | Parent sirf apne tickets dekhe |
| `school_parent_teacher_messages` | PN9 (1:1 teacher message) | Parent sirf apne threads dekhe; teacher sirf apni classes ke threads dekhe |
| `school_link_requests` | PN13 (child link request) | Parent sirf apni requests dekhe |
| `school_parent_preferences` | PM12 (notification preferences) — VERIFY-FIRST: agar preferences ka system pehle se hai to ye table nahi banegi | Parent sirf apni preferences dekhe/bad le |

---

## Aakhri note (Maalik ke liye)

Parent dashboard ko "notices padhne ki screen" se "roz ka saathi" banane ka plan hai. Sabse pehla kaam PAR1 hai — **privacy fix + jhoothe numbers hatana**. Bina link wale parent ko doosre ke bachche dikhna band hona chahiye, aur bina data ke dashboard par koi number nahi dikhna chahiye. Uske baad hi alerts, homework diary aur reports ka matlab banta hai — kyunki parent ko apne bachche ke baare mein **galat khabar** dena, khabar na dene se zyada kharab hai. Isliye order mat badalna: **pehle sachha aur safe data, phir alerts aur diary, phir reports aur Excel, phir naye features.** Aur ek faisla aapka pending hai — **behaviour notes parent ko dikhane hain ya nahi (PN10)** — uska jawab milte hi wo step khul jayega.
