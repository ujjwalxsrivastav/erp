# School ERP — Super Enterprise Deep-Dive ("One Level Above Enterprise")

## Everything That Is Still Missing — One Document, One Execution

**Status:** Analysis + build document — no code changes are made in this file. This file will be given to Gemini, and Gemini will execute it line by line.
**Repo state (verified at the time of analysis):** `origin/main` = `bd75f26` — "student-dash: STU7 — Final QA". The local clone (`~/workspace/erp`, main `1652552`) is stale, so the analysis was done from an archive of `origin/main`, not from the local clone. No changes were made to the repo after the analysis.
**Important note — all four dashboard deep-dives are now executed:** The Teacher (T7), Admin (ADM7), Parent (PAR7) and Student (STU7) deep-dives have all been executed by Gemini — teacher dashboard 4,606 lines, admin 5,747 lines, parent 6,922 lines, student 4,927 lines (on `bd75f26`). This document therefore does not cite line numbers of dashboard files — in SP0, Gemini must verify whatever is in the repo at that time, rather than trusting any line numbers.
**Scope lock:** This document covers ONLY the 12 items listed in Part C. The Teacher / Admin / Parent / Student deep-dives, the Core Modules README and the Chatbot RAG plan will not be built again here — their work lives in their own files, and this document only references them. Anything that already exists in an earlier document will not be written again here.

## 0. How to Read This Document

- **Part A — WHAT EXISTS:** For every super item, what is present in the repo today, with file names. Everything has been verified — absence was confirmed with grep, never claimed by guesswork.
- **Part B — WHY THE GAP EXISTS:** What is missing to go above enterprise level — stated plainly, with evidence.
- **Part C — 12 ITEMS:** Each item has: what exists → **NEW** (additions) → **MODIFY** (changes to what exists). Every feature states: what it is, why it is needed, where it appears, where the data comes from, and what graph/Excel output it has.
- **Part D — Reports catalogue:** Every report of the new modules — with graph + Excel.
- **Part E — Gemini execution plan:** Steps SP0–SP12, verification, checkpoints, hard rules.
- **Part F — What Comes After:** The roadmap after Super.
- **VERIFY-FIRST means:** At execution time, first find the file/table. If the thing already exists, do not build it again — only link to it or extend it.

## 0.1 "One Level Above Enterprise" — What It Means, in Measurable Terms

This document does not claim to beat "enterprise" — it defines what going above it means, and every point will be measured in a CHECKPOINT:

1. **Automation everywhere it makes sense:** Fine auto-posting (library overdue → fee ledger), automatic defaulter lists, automatic substitution suggestions, automatic payroll computation, automatic alerts. No work will be done by hand that can be done by a rule. Measured: every automation has a test case in its CHECKPOINT.
2. **Audit trail on every money and data action:** Fees, payroll, inventory, admission, marks-lock — who changed what, when, and what it was before. Measured: an audit row must exist for every action.
3. **Zero fake data — now system-wide:** The Teacher/Admin/Parent/Student documents removed the fake data from their dashboards. In this Super document, the rule applies to **all new modules** — no fallback numbers, no demo lists, no invented NOCs or ratios.
4. **Reliability — SLA-style checks:** Attendance lock time (no edits after 9:00 AM daily), fee month close/lock, payroll month lock, exam marks freeze. Measured: an attempt to change data after a lock must be blocked and must appear in the audit log.
5. **Observability:** Error logging on every Edge Function and every critical action (Supabase logs) + an error summary visible to the admin. Measured: a failed action must have a findable log — no silent failures.
6. **Every report has a graph + Excel:** Without exception. No report will be a list only (Excel will also be built for the two table-type reports — see Part D).
7. **Performance budgets (measurable):** Dashboard first paint < 2 seconds (live database, 500 students), no list will load more than 100 rows at once (pagination), every query will carry a role filter (fetching a whole table and filtering it in the UI is forbidden).
8. **Multi-school ready — for real:** One school's data will never be visible to another school — this will be tested on both RLS and instituteId, not just as a UI filter.

## 0.2 "Top-Notch UI/UX" — What It Means, in Tokens and States

The Step 13 polish (Slate-50 canvas `#F8FAFC`, ink `#0F172A`, hairline `#E2E8F0`, 8pt grid, 48dp touch targets) is the **base** — Super makes it stricter:

- **Design tokens (one place, used everywhere):** Colours (blue `#2563EB`, emerald `#059669`, violet `#7C3AED`, ink `#0F172A`, slate `#475569`, background `#F8FAFC`, danger `#EF4444`, amber `#D97706`), typography scale (title 18/700, section 15/800, body 13.5/600, caption 11/500), radius (card 14, chip 8, button 10), spacing (8pt grid). No screen will use colours or sizes of its own choice — every screen will be built from shared widgets. Measured: `flutter analyze` + token grep — no hardcoded colours or sizes in new code.
- **Four states on every screen:** Loading skeleton (not a spinner), empty state with a call to action, error state with retry, loaded state. No screen will pass without all four states.
- **Motion (light, and with a purpose):** Page transitions, list-item press feedback, chart animate-in. Motion budget: a 60fps feel — no heavy animation that slows a list.
- **Accessibility:** Contrast ≥ 4.5:1, touch targets ≥ 48dp, layouts must not break at large text scale, screen-reader labels on essential actions.
- **Responsive:** Phone → tablet → desktop — one codebase, with the layout changing at breakpoints (sidebar on desktop, drawer on phone). Measured: every new screen gets a phone + desktop check in its CHECKPOINT.
- **Dark mode is not part of this document** — it was not requested. If it is needed, that will be a separate decision.
- **Consistency check:** Every step's CHECKPOINT will have one line — "UI tokens + 4-state + responsive check passed".

## 0.3 Non-Negotiables (apply at every step)

1. **The College ERP must never break.** Only `lib/features/school/` + `lib/services/school_service.dart` + `school_*` tables + new `school_*` tables + `.github/workflows/deploy.yml` (only in SP1, for the deploy fix) may be touched. College screens/tables/routes — zero touch. **Reuse** of college code is allowed (hostel service, payroll service) — copy it and adapt it for school; do not edit the college file.
2. **No fake/mock/invented data.** If data is not available, show an empty state — never a false number.
3. **RLS on every new table.** No table goes live without RLS. Role scope in every query — a teacher sees only their classes, a parent only their children, a student only their own data, a school only its own institute.
4. **"s"-prefix credential rule (a hard rule from the owner):** ALL credentials/IDs on the school side will start with `s`. HR payroll staff IDs will follow the `shr01` pattern (s + hr + 01). This rule applies to new IDs. **SAFE migration:** In SP0, first verify the formats of the school accounts in the live `users` table — accounts that already have the `s` prefix (such as `steacher1`, `sadmin1`, `sstudent1` — these already exist) must not be touched. No live account will be silently renamed — the rename list must be shown to the owner, and renaming will happen only after their approval.
5. **Free-only AI (chatbot + second AI system):** No paid API key, no local server. Only free-tier serverless (Supabase Edge Functions + provider free tiers). When the quota is exhausted, the bot/system will say "quota exhausted" — it will not spend money.
6. **Verification + commit + CHECKPOINT after every step.** No next step starts without verification. Commit message: `super: SP<n> — <title>`.
7. **Note on the deploy pipeline:** The deploy has already failed 9 times (4 times on 4 Nov, 4 times on 5 Nov, once on 6 Nov at 00:33 IST) — and this document fixes it first, in SP1, because without a working deploy, all further work will never reach the live site. Pushing is the owner's decision.

## 0.4 Dashboard-by-Dashboard Roadmap (the full picture — where Super fits)

| # | Work | Status |
| --- | --- | --- |
| 1 | Teacher deep-dive | **Executed (T7 commit)** — by Gemini |
| 2 | Admin deep-dive | **Executed (ADM7 commit)** — by Gemini |
| 3 | Parent deep-dive | **Executed (PAR7 commit)** — by Gemini |
| 4 | Student deep-dive | **Executed (STU7 commit)** — by Gemini |
| 5 | Core Modules (Admin/HR/Admission/Fees/Reports/Import) | Document ready — execution pending (F1 gate first) |
| 6 | Chatbot RAG (₹0) | Plan ready — **being merged into this Super document (Item 1)** |
| 7 | **SUPER (this document)** | **Now — 12 items, SP0–SP12** |

## 0.5 Item 3 — Terminology (Hostel + Infirmary + Cafeteria)

Item 3 covers three parts of daily school life: **Hostel, Infirmary and Cafeteria**. The owner originally wrote "hostel/client/cafeteria" — "client" was a typo for **infirmary**. In this document, "infirmary" always means the school medical room: student health records, infirmary visits, basic medicine stock, and parent alerts on visits. There is no third-party "client" item and no open question about this term.

## 0.6 Decisions Pending (the owner's decisions — Gemini will not make them)

This list will appear again in the SP0 report. Until an answer is received, the default written here applies:

| # | Decision | Default (if no answer) |
| --- | --- | --- |
| D1 | Should alumni donations be collected or not? | No — only an interest form will be built |
| D2 | Should a discipline appeal flow be built or not? | No |
| D3 | Format of the school code (e.g. `s-shivalik`)? | Propose it in SP0; the owner will confirm |
| D4 | PF/ESI/TDS rates and slabs? | From settings — never fill in by guesswork; confirm in SP0 |
| D5 | Library fine rate + waiver rule? | Confirm in SP0 |
| D6 | Inventory damage fine + depreciation %? | Confirm in SP0 |
| D7 | Should behaviour notes be shown to parents? | No (teacher + admin only) — already pending |
| D8 | Deploy fix method — dart-define or generate .env in CI? | dart-define (recommended) |
| D9 | Live accounts that are not in `s`-prefix form — rename them or not? | No — show the list to the owner; rename only after approval |

---

## Part A — WHAT EXISTS (Existing, repo-verified — origin/main bd75f26)

### A1. Deploy Pipeline and Workflow (the base for Item 11)

- **File:** `.github/workflows/deploy.yml` (855 bytes) — runs on push to `main` + manual dispatch; `permissions: contents: write`; job `build-and-deploy`: checkout → Flutter 3.35.1 stable → `flutter pub get` → `flutter build web --release --base-href /erp/` → JamesIves deploy action, folder `build/web`, branch `gh-pages`.
- **pubspec.yaml line 96:** `- .env` is listed under flutter assets. `.env` is gitignored (it exists in the local repo, not on GitHub) — so the CI checkout never contains `.env`.
- **Deploy failures — 9 times (verified, gh run list + run logs):** 4 times on 4 Nov (~12:22, ~12:50, ~13:58, ~14:20 IST) + 4 times on 5 Nov (11:02 IST `7cce8af`, 12:49 IST `c376d44` teacher-dash T7, 22:05 IST admin-dash ADM7, 23:24 IST `f9248e3` parent-dash PAR7) + once on 6 Nov (00:33 IST `bd75f26` student-dash STU7, run 42090128907, 2m36s). Every run failed in ~2 minutes, with 3 annotations.
- **Cause — verified from the logs, not guessed (the latest run 42090128907 and the earlier run 42079115924 show the same error):**
- `Error detected in pubspec.yaml: No file or variants found for asset: .env.`
- `Target web_release_bundle failed: Exception: Failed to bundle asset files.`
- `Error: Failed to compile application for the Web.`
- Meaning: the build fails at the asset-bundling step of `flutter build web` — the `.env` asset is missing. This is not a code error; it is a configuration error.

### A2. College Payroll (the base for Item 2 — adapt it, do not rebuild it)

- **Files:** `lib/features/hr/services/payroll_service.dart`, `lib/features/hr/screens/payroll_runs_screen.dart`, `payslip_detail_screen.dart`, `my_payslips_screen.dart`, `hr_payroll_management_screen.dart`, `edit_salary_screen.dart`.
- **What exists:** Salary structure (basic, HRA, travel, medical, special, other allowances; `gross_salary` and `total_deductions` GENERATED columns), statutory deductions (provident_fund = PF, professional_tax, income_tax = TDS, other_deductions), **LOP deduction** (from approved flagged leaves — `lopDeduction = gross / workingDays * lopDays`, net pay ≥ 0), payroll runs (generate, mark paid), payslips (per run, per employee, hold/unhold), payroll stats.
- **What does not exist:** No mention of ESI anywhere (confirmed by grep — there is no ESI column or service). There is no school-side payroll code — the Core Modules README also explicitly defers payroll.

### A3. College Hostel (the base for Item 3 — adapt it)

- **Files:** `lib/features/hostel/` — 12 files: `hostel_service.dart` (hostels, rooms, allot/unallot, reassign, auto-allocate, available rooms, student room details), gatepass (create/status), night attendance (rooms/dates/save), incidents (log/get/delete), warden screens (dashboard, rooms, allocation, directory, grievances) + student screens (hostel, grievance).
- **What the school side has:** Nothing — there is no school hostel screen and no school hostel table. Only a college-side table named `hostel_fee_enrollment` exists in the SQL. Parent-side **stubs** were found (`school_service.dart`: `getParentChildInfirmaryRecord` — returning an empty `clinic_visits: []` list, which is the existing stub's field name — and `getParentChildCafeteriaStatus` + `rechargeCafeteriaWallet`) — meaning there is a skeleton for showing data to parents, but there is no admin/staff-side module and no tables.

### A4. Library, Transport, Superadmin (the base for Items 8 and 9)

- **Library:** One screen — `lib/features/school/library/school_library_screen.dart`. Present: catalogue search (title/author), issue dialog, overdue tab (count + list), per-issue `fine` field. **Missing:** reservation, e-books/digital, overdue automation (fine auto-post), catalogue management (add/edit books).
- **Transport:** One screen — `lib/features/school/transport/transport_screen.dart`. "GPS/telematics" exists **only in labels** — the admin dashboard and reports screen say "Safety Telematics Online", "Transport & GPS Fleet", "All Telematics GPS Live", and the parent dashboard has a `gps_status` fallback of `'AIS-140 Compliant'`. The transport screen contains **no code** for GPS/latitude/longitude/live-tracking (confirmed by grep). Live GPS is a claim today, not a feature.
- **Superadmin (college side):** `lib/features/admin/services/superadmin_service.dart` — departments, designations, academic years, settings, institute stats; `institute_setup_screen.dart`. There is no multi-school UI on the school side — the data model is "ready" (instituteId pattern), but there is no school onboarding/switcher/billing flow.

### A5. School Usernames and IDs (the base for Item 2)

- School accounts already use the `s` prefix (verified from SQL): `steacher1`, `sadmin1`, `sstudent1` (`database/dual_mode_school_setup.sql` lines 42–43). The `school_teachers` table's primary key is `username TEXT`.
- **No ID matching the `shr` pattern exists anywhere in the repo** (confirmed by grep — zero matches). The `shr01` pattern is therefore new, and it cannot collide with any existing ID.
- **The state of the live `users` table cannot be verified from the repo** — a live Supabase check is mandatory in SP0 (which school accounts are not in `s`-prefix form; show that list to the owner, do not rename anything).

### A6. AI Code (the base for Items 1 and 12)

- **There is no AI code in the repo** (grep for `openai|gemini|groq|huggingface|llm|chatbot` found only false matches such as `allMarks`). There is no `supabase/functions/` directory, no Edge Function, and no pgvector.
- **Chatbot plan (already prepared):** `School-ERP-Chatbot-RAG-Zero-Cost-Plan.md` (454 lines) — primary Groq `gpt-oss-120b` chat + Gemini embeddings + Supabase pgvector/Edge Functions; fallback Gemini Flash-Lite + Cloudflare Workers AI; ~150–220 chats/day on Groq; 7 items marked "verify at build time". The chatbot will not be designed again in this Super document — only merged, plus integration points (Item 1).

### A7. What Does Not Exist at All (absence confirmed by grep)

- **Alumni:** The word `alumni` does not appear anywhere in the whole repo (0 matches) — no table, no screen, no service.
- **Inventory/assets module:** No module exists (finance has purchase_management for buying, but no stock/inventory; the word `asset` appears only in finance/chart-of-accounts).
- **Activities module:** No module exists (no screen or table for clubs/sports/competitions; `sport` appears only as a co-scholastic domain).
- **Discipline workflow:** No workflow exists — behaviour notes exist in the teacher dashboard (Teacher MD N7, already executed: "Concern / Discipline" type + "No behavioural concerns..." empty state), "Discipline" is a grade in co-scholastic, and the admin dashboard shows "0 Open Incidents" — but there is no incident → inquiry → action → parent notice flow.
- **Permission matrix:** No matrix exists (0 matches) — roles and route guards exist, but there is no "role × feature" table or definition.

---

## Part B — WHY THE GAP EXISTS (what is missing to go above enterprise level)

1. **The deploy is broken — the first gap.** 9 failures, one cause (`.env` asset missing). Until the deploy works, every feature Gemini has built — teacher T7, admin ADM7, parent PAR7 — will never reach the live demo. The first job of Super is the deploy fix; features come after.
2. **Money work is incomplete.** There is no payroll (how will staff be paid?), no fee-gateway settlement, and no admin side for the cafeteria wallet. If the money accounting is half done, the system cannot be called enterprise.
3. **There is no record of boarding and daily life.** Hostel, infirmary and cafeteria — three parts of the school's daily life — are not in the system at all. For a boarding school or a large school, this is a deal-breaker.
4. **The relationship ends when the student leaves.** Once a student leaves, the system forgets them — there is no alumni module. The school's greatest strength (its former students) has no record.
5. **There is no record of the school's belongings.** There is no inventory — lab equipment, books, furniture: where they are, who took them, when they will come back — nothing can be found out.
6. **A child's whole life is not recorded.** Activities (sports, clubs, events) and discipline have no complete record — the report card shows only marks, not what the child does.
7. **Running more than one school is not possible.** The data model is ready, but there is no superadmin UI, school onboarding or per-school billing — the product belongs to one school, not to a company.
8. **The library is still like a register.** Search and overdue exist, but there is no reservation, no e-books and no fine automation — a digital library cannot be claimed.
9. **"Who can do what" is written nowhere.** There is no permission matrix, so every new feature will raise the same question again: "Can this teacher see this or not?" The marks-lock and maker-checker rules are also incomplete.
10. **AI stops at the chatbot.** Report-card remarks have to be written by hand, question papers are made by hand, homework feedback has to be written by hand — the work that eats the most of a teacher's time is still manual.

---

## Part C — 12 ITEMS (NEW + MODIFY)

### Item 1. CHATBOT MERGED IN (RAG chatbot — part of this Super document)

- **Base (already prepared — will not be designed again):** `School-ERP-Chatbot-RAG-Zero-Cost-Plan.md` — primary Groq `gpt-oss-120b` chat (free tier) + Gemini embeddings + Supabase pgvector + Edge Functions; fallback Gemini Flash-Lite + Cloudflare Workers AI; ~150–220 chats/day on Groq; the model never writes raw SQL (9 pre-defined RPC tools); role-scoped RLS; 20-question evaluation gate; steps CB0–CB7.
- **What is added in this Super document (merge, not a redesign):**
- **NEW S1.1 — Questions about the new modules:** The chatbot must also answer questions about the new modules (Items 2–10) — hostel room/bed, payroll FAQs (staff: "When will my payslip come?", "What LOP was deducted?"), alumni information, library (is a book available?), discipline records, cafeteria menu. Meaning: the chatbot's knowledge base will embed the docs/FAQ of **every new module** (when a new module is ingested, its FAQ goes with it — every SP step will have a mandatory "chatbot FAQ" line).
- **NEW S1.2 — New live-data tools:** New safe tools will be added to the RAG's 9 RPC tools — hostel occupancy, my payslip summary, library availability, my activity participation, cafeteria balance. Every tool will be role-scoped (a parent sees only their own child's data, staff only their own payslip).
- **NEW S1.3 — Chatbot widget on every new dashboard:** The same chat widget will appear on every new module's screen — hostel warden, payroll (HR), library, alumni (one shared component, everywhere).
- **MODIFY S1.4 — More evaluation questions:** 10 questions about the new modules will be added to the chatbot plan's 20 test questions (30 total) — the build passes only when 30/30 pass.
- **Graph/Excel:** Chatbot report — usage per role, quota usage, unanswered questions (SP-R13, Part D).

### Item 2. PAYROLL (full — adapt the college payroll)

- **Base (exists — adapt it):** College `PayrollService` — salary structure (basic/HRA/travel/medical/special/other), gross GENERATED column, PF/professional tax/income tax (TDS)/other deductions, LOP (from approved flagged leaves), runs, payslips, hold, mark paid, stats. **ESI does not exist** — it must be added as a new deduction.
- **NEW S2.1 — School salary structure (HR staff):** Every school staff member's salary structure — basic + HRA + travel + medical + special + other allowances; PF + ESI + professional tax + TDS + other deductions; gross/net auto-computed (GENERATED columns, college pattern). **ID rule:** Every school HR staff member will get an ID in the `shr01`, `shr02`... pattern (s + hr + number). **SAFE migration (SP0):** First verify the formats in the live `users`/`school_teachers` tables — accounts that already have the `s` prefix (steacher1, sadmin1) must not be touched. No live account will be renamed without the owner's approval — the rename list must be shown to the owner in the SP0 report.
- **NEW S2.2 — Monthly computation (run):** Create a run for the month → each staff member's gross → LOP (from teacher leave, reusing the college LOP rule) → statutory deductions (PF/ESI/TDS — rates from settings, never hardcoded; **VERIFY-FIRST:** PF/ESI/TDS rates and slabs must be confirmed from the settings table in SP0, never filled in by guesswork) → net pay. Run flow: draft → review → lock. After locking, no change is possible (it will appear in the audit log).
- **NEW S2.3 — Payslips (PDF):** A payslip PDF for every staff member — earnings, deductions, LOP, net pay, YTD totals; staff can view/download their own payslip (My Payslips — adapt the college screen). A payslip needs no QR/verification seal (unlike a report card — a payslip will be simple and clean).
- **NEW S2.4 — Arrears + advances:** Arrears (past dues) can be added to the next run; advances (money taken early) can be deducted in instalments. Both will have a record in the audit trail.
- **NEW S2.5 — Month close/lock + link to the fee ledger:** When the payroll month closes, the total salary expense will be visible to finance (read-only summary — without touching the finance module). After the month closes, that month's run will not reopen (only an admin override + audit entry can reopen it).
- **MODIFY S2.6 — Adapt the college payroll screens, do not rebuild them:** `payroll_runs_screen`, `payslip_detail_screen`, `my_payslips_screen`, `edit_salary_screen` — adapt them for school role/scope (school staff only, school institute). Do not edit the college screens' files — build new screens in school that reuse the `PayrollService` pattern.
- **Graph/Excel:** Payroll reports — monthly cost trend (line), department-wise cost (bar), payslip register Excel (SP-R01, SP-R02, Part D).

### Item 3. HOSTEL / INFIRMARY / CAFETERIA

- **Base (exists):** The college hostel is complete (hostel_service: hostels, rooms, allot/unallot, auto-allocate, gatepass, night attendance, incidents). Parent-side stubs exist (infirmary record + cafeteria wallet, empty lists). There is no school hostel/infirmary/cafeteria module or table.
- **NEW S3.1 — Hostel (adapt the college hostel):** Hostel + rooms/beds (capacity, occupancy), allocation (manual + auto-allocate — adapt the college `autoAllocateRooms`), room change/reassign, **gate pass** (a student going out — parent approval + warden approval, both recorded), **night-out** (date range + reason + approvals), night attendance (the warden marks it daily), warden dashboard (occupancy %, pending gate passes, night-out list, incidents). Parents will see their own child's hostel status (room, gate pass status) — read-only.
- **NEW S3.2 — Infirmary:** A health record per student (allergies, chronic conditions, blood group — filled in by the parent; only the nurse/warden/admin can see it; **this is sensitive data — the strictest RLS will apply here**), infirmary visits (date, symptoms, treatment, whether medicine was given, parent alert), medicine stock (basic — name, quantity, low-stock alert; purchasing/linking to inventory will come from Item 5, not rebuilt here), parent alert on an infirmary visit (in-app notification — there is no SMS/WhatsApp provider, so in-app only).
- **NEW S3.3 — Cafeteria:** Menu (day-wise, veg/non-veg), meal plans (monthly plan per student — taking a plan is optional), wallet (parent recharges it — make the parent-side `rechargeCafeteriaWallet` stub real), canteen orders (student orders — deducted from the wallet), daily sales summary. **Keep the scope clear:** Cafeteria payments will come from the wallet; the link to the fee ledger is only that wallet-recharge records appear in fee reports (the money will not mix with fees — two separate accounts will remain, otherwise reconciliation will break).
- **MODIFY S3.4 — Make the parent stubs real:** `getParentChildInfirmaryRecord` and `getParentChildCafeteriaStatus` currently return empty lists — they must return real data from the new tables (with S3.2/S3.3). An empty list must never be shown when data exists.
- **Graph/Excel:** Hostel occupancy (bar), infirmary visits trend (line), cafeteria sales (bar) + registers in Excel (SP-R03, SP-R04, SP-R05).

### Item 4. ALUMNI

- **Base (exists):** Nothing — the word `alumni` does not appear anywhere in the repo (0 matches).
- **NEW S4.1 — Alumni directory:** Records of former students — name, batch/year, class, current status (college/job — updated by the alumni themselves or filled in by admin), contact (email/phone — **visible only to admin and to the alumni themselves**; other alumni will not see contact details), search/filter (batch, year, class).
- **NEW S4.2 — Engagement:** Alumni events (reunion, guest lecture, mentorship) — create an event, invite alumni (in-app + email — the email provider already exists: Gmail is connected, but the bulk-email flow must be verified in SP0), track RSVPs. Mentorship: alumni mentor current students (opt-in, approved by admin).
- **NEW S4.3 — Communication:** Circulars/notices to alumni (alumni audience — the circulars audience model must be extended: `All/Students/Parents/Teachers` will gain `Alumni` — VERIFY-FIRST).
- **NEW S4.4 — Donations (OPTIONAL — a decision):** Whether donations are collected or not is **the owner's decision** — donation collection will **not** be built in this document. If the owner says yes, the payment flow will be built in a separate step (until then, only an "I want to donate" interest form will be built — no money flow).
- **Graph/Excel:** Alumni per batch (bar), engagement trend (line), events in Excel (SP-R06).

### Item 5. INVENTORY / ASSETS

- **Base (exists):** No module exists. Finance has purchase_management (buying), but no stock accounting.
- **NEW S5.1 — Categories + stock:** Categories (lab equipment, furniture, books, sports, IT, consumables) + items (name, category, quantity, location/room, condition, purchase date, value). Low-stock alert (the admin is alerted as soon as quantity falls below a threshold).
- **NEW S5.2 — Issue/return:** Issue an item to staff/student (who took it, when, when it returns), check the condition on return (note damage + fine — the fine rule must be confirmed with the owner in SP0, never guessed). Library books will not be in this module (they are in Item 9 — two systems will not be built).
- **NEW S5.3 — Maintenance + depreciation (basic):** Maintenance log (when, what was fixed, cost), basic depreciation (straight-line, yearly % from settings — never fill in a rate by guesswork; confirm the settings in SP0), annual audit (physical verification — item found / not found / damaged).
- **NEW S5.4 — Link to purchases:** Items bought through finance purchases will enter inventory directly (no manual entry — the purchase record itself becomes the inventory's opening stock).
- **Graph/Excel:** Stock by category (bar), issue/return trend (line), audit in Excel (SP-R07).

### Item 6. ACTIVITIES

- **Base (exists):** No module exists — there is no screen or table for sports/clubs/competitions (`sport` appears only as a co-scholastic domain).
- **NEW S6.1 — Events:** School events (annual day, sports day, science fair) — create an event, date/venue, participants (class-wise or open), attendance, photos (optional — check the storage cost in SP0; Supabase storage is on the free tier).
- **NEW S6.2 — Clubs:** Clubs (science, drama, music, coding) — create a club, members (a student joins — a teacher approves), meeting schedule, club activity log.
- **NEW S6.3 — Sports + competitions:** Sports teams, competitions (inter-school, intra-school) — participation records, results (position/medal), certificates. **Activity certificates** (participation/winner) — will link to the certificates module (the certificate screen exists — adapt it, do not rebuild it).
- **NEW S6.4 — Student activity record:** An activities tab will be added to every student's profile (Teacher MD N1) — their events, clubs, sports and certificates in one place (linked to the report card's co-scholastic data, not re-entered).
- **Graph/Excel:** Participation per activity (bar), events trend (line), activity register in Excel (SP-R08).

---

### Item 7. DISCIPLINE (full workflow — beyond behaviour notes)

- **Base (exists — a starting point, not a full workflow):** Behaviour notes exist in the teacher dashboard (Teacher MD N7, already executed: "Concern / Discipline" type + empty state "No behavioural concerns..."). "Discipline" is a grade in co-scholastic. The admin dashboard shows "0 Open Incidents" — but there is no incident record.
- **NEW S7.1 — Incident report:** Any teacher can report an incident — student, date/time, place, what happened, category (late, disruption, bullying, damage, uniform, other), severity (low/medium/high), witnesses (optional). As soon as a report is filed, the class teacher + admin get an alert (in-app notification).
- **NEW S7.2 — Inquiry:** Admin/HOD will inquire — talk to the student, talk to the teacher, write notes. The inquiry status (open → inquiring → resolved) will be visible. No action will be taken without an inquiry (fair process — this is a rule, not a shortcut).
- **NEW S7.3 — Action:** Take action — warning, counselling, parent meeting, suspension (only the principal can suspend — a role rule), community service. Every action will be recorded with a date and who took it. After the action, the student's record will be updated (linked to behaviour notes — data will not be re-entered).
- **NEW S7.4 — Parent notice:** A notice will go to the parent (in-app + a discipline tab on the parent dashboard) — what happened, what action was taken, when the parent meeting is. A read receipt will be shown (whether the parent has seen it or not).
- **NEW S7.5 — Appeal (OPTIONAL — a decision):** Whether an appeal flow is built or not is **the owner's decision** — by default, no appeal will be built in this document. If the owner says yes, an appeal step (parent/student appeals → principal reviews) will be added separately.
- **MODIFY S7.6 — Link to behaviour notes:** The teacher's behaviour notes (N7) are the starting point of discipline — when an incident report is created, that student's past notes will be shown (for context). Notes and incidents will remain two separate things (a note = an observation, an incident = a formal record) — they must not be confused.
- **Graph/Excel:** Incidents per month (line), per category (bar), per class (bar), discipline register in Excel (SP-R09).

### Item 8. MULTI-SCHOOL (superadmin — real UI + flows)

- **Base (exists — data model ready, no UI):** College `SuperAdminService` (departments, designations, academic years, settings, institute stats) + `institute_setup_screen`. School data has the instituteId pattern ("multi-school ready" — the model is ready, the UI is not). There is no school onboarding/switcher/billing flow on the school side.
- **NEW S8.1 — School onboarding:** Onboard a new school — school profile (name, address, affiliation, logo), session setup, create an admin account (the school admin gets `sadmin` + school code — **ID rule:** the school code will also follow the `s`-prefix pattern, e.g. `s-shivalik` — confirm in SP0), seed the masters (classes, subjects, fee heads — the Core Modules masters will be reused, not rebuilt).
- **NEW S8.2 — School switcher:** The superadmin can switch from one school to another (dropdown + search) — on switching, all data shown will be that school's (dashboard, reports, settings — all filtered by instituteId at the service layer, not in the UI).
- **NEW S8.3 — Per-school settings:** Each school's own settings — session dates, fee heads, attendance rules, report-card format, circulars audience. One school's setting will not affect another school.
- **NEW S8.4 — Per-school data isolation (must be demonstrated by testing):** instituteId filter in every query + RLS. **Verification (mandatory in SP12):** Log in as School A's admin and search for School B's data — nothing must be found (student, fee, staff — everything). This test will be written in the CHECKPOINT.
- **NEW S8.5 — Billing readiness:** The skeleton for per-school billing — plan, start date, due date, payment status (a read-only record — collecting billing payments is not in this document; the money-collection flow for billing will be built separately, on the owner's decision). Billing here means only a record, not a payment gateway.
- **MODIFY S8.6 — Adapt the college superadmin:** Adapt `SuperAdminService` and `institute_setup_screen` for school multi-school (do not edit the college files — build new screens in school that reuse the service pattern).
- **Graph/Excel:** Schools comparison (students, fees, attendance — bar), per-school summary in Excel (SP-R10).

### Item 9. LIBRARY DEEP-DIVE

- **Base (exists):** One screen — catalogue search (title/author), issue dialog, overdue tab + count, per-issue `fine` field. **Missing:** reservation, e-books, overdue automation, catalogue management.
- **NEW S9.1 — Catalogue management:** Add/edit books (title, author, category, ISBN, copies, shelf) — done by admin/librarian. Bulk add (Excel import — using the Core Modules import pattern: template → dry-run → commit).
- **NEW S9.2 — Reservation:** A student can reserve a book (if it is not available, a waitlist — first to reserve gets it first; a notification is sent when it becomes available). A reservation expires (if it is not issued within 3 days, it leaves the waitlist).
- **NEW S9.3 — Overdue automation + fine into the fee ledger:** Every morning, a job (Edge Function or a scheduled check — **on the free tier**: a scheduled Supabase Edge Function, or a check when the admin dashboard opens) will find overdue books → calculate the fine (rate from settings — confirm in SP0, never guess) → **auto-post the fine to the fee ledger** (Step 11 claims a ₹25 fine was posted on a library return — verify in SP0 whether that auto-posting actually happens or was manual; if it was manual, automate it here).
- **NEW S9.4 — Digital / e-books (FREE SOURCES ONLY — stated clearly):** No paid subscription will be taken for e-books. Only free sources: NCERT e-books (ncert.nic.in — free, public), Project Gutenberg (public domain), and the school's own PDFs (uploaded by teachers — Supabase storage free tier). Every e-book will show a link + category; download counts will be tracked. **No pirated or paid sources.**
- **MODIFY S9.5 — Make the fine rule clear:** When a fine applies (how many days late), how much it is, when it can be waived (a librarian can waive it — with an audit entry) — these rules will be written in settings, never hardcoded in code.
- **Graph/Excel:** Circulation trend (line), popular books (bar), overdue + fine register in Excel (SP-R11).

### Item 10. PERMISSION MATRIX

- **Base (exists):** Roles exist (sadmin, teacher, parent, student, admin) + route guards exist (Admin MD M7). **Missing:** a "role × feature" matrix — who can view/edit/approve what is defined nowhere.
- **NEW S10.1 — Matrix (one place, everything):** Roles (Superadmin, Sadmin, Teacher, Class Teacher, Parent, Student, Librarian, Warden, Nurse, Accountant — **new roles only when a module asks for them**; the meaning of each role must be defined in SP0) × Features (attendance, marks, fees, payroll, hostel, infirmary, library, discipline, inventory, reports...) × Permissions (View / Edit / Approve / None). The matrix will be visible on a settings screen + enforced in code (see S10.2).
- **NEW S10.2 — Enforcement (at both route and service level):** Route guard (a wrong role cannot reach the wrong screen at all) + service-layer check (a role check on the API call too — hiding it in the UI is not enough, because the UI can be bypassed). A matrix check will be applied to every action of every new module.
- **NEW S10.3 — Marks-lock rules:** Marks entry deadline + lock — after locking, a teacher cannot edit (only an admin can unlock — with an audit entry). Lock rules live in settings (per exam, per class).
- **NEW S10.4 — Maker-checker extension (beyond money):** In the Core Modules, maker-checker applies only to money actions. It is extended here: payroll run (the creator ≠ the locker), fee structure change, marks bulk upload approval, discipline suspension. Every sensitive action needs two people — the doer and the approver, who must be different.
- **MODIFY S10.5 — Align the old guards with the matrix:** The route guards that already exist (Admin M7, teacher/parent/student guards) will be aligned with the matrix definition — there will not be two rules in two places (the matrix will be the single source of truth).
- **Graph/Excel:** Permission audit report — which role has what access (table + Excel — SP-R12); audit trail report (who changed what — inside SP-R12).

### Item 11. DEPLOY PIPELINE FIX (first — in SP1)

- **Base (exists — and broken):** `.github/workflows/deploy.yml` (Flutter 3.35.1, build web, gh-pages deploy). **9 failures** (4 Nov: 4, 5 Nov: 4 — 11:02, 12:49, 22:05, 23:24 IST; 6 Nov: 1 — 00:33 IST, student-dash STU7). **Cause verified from the logs (the same error in two runs' logs):** `Error detected in pubspec.yaml: No file or variants found for asset: .env.` + `Target web_release_bundle failed: Exception: Failed to bundle asset files.` — pubspec.yaml line 96 lists `- .env` as an asset, but `.env` is gitignored, so the CI checkout never contains the file. **This is not a code error; it is a configuration error.**
- **NEW S11.1 — Fix (recommended — the decision is the owner's, implemented in SP1):** **Remove** `.env` from the pubspec assets (there is no need for `.env` as an asset — `flutter_dotenv` reads the file at runtime, not from the asset bundle; and secrets should not be put in the bundle anyway). Pass the Supabase URL + anon key to the workflow with `--dart-define` (from GitHub Secrets — `SUPABASE_URL`, `SUPABASE_ANON_KEY`; the anon key is already public in the bundle, but passing it from Secrets is the correct method). **Alternative (if the owner prefers):** generate the `.env` file in a CI step from GitHub Secrets — but this is not recommended (passing via dart-define is better than creating a secrets file).
- **NEW S11.2 — Workflow hardening:** Make `flutter analyze` a step before the build (if analyze fails, the build must not run — fail fast); after the build, check that `build/web` exists; in the deploy step, make the `clean` behaviour explicit (whether old gh-pages content is deleted or not — decide in SP1).
- **NEW S11.3 — Verification (the SP1 CHECKPOINT):** Local `flutter analyze` (0 errors) + local `flutter build web --release --base-href /erp/` (it must pass even without a `.env` file — that is the test) + a review of the workflow file + **after the owner's approval**, a test push (a small commit) whose deploy run must **succeed**. **Pushing happens only on the owner's call.**
- **MODIFY S11.4 — Local builds must use the same method:** Stop relying on a local `.env` file — local builds must also run with `--dart-define` (write this in the README), so that local and CI builds are identical.
- **Graph/Excel:** Deploy health report — runs history (success/fail), duration trend (line) — SP-R14 (Part D). The deploy report will also have a graph + Excel (this document's rule applies to everything).

### Item 12. SECOND AI SYSTEM — besides the chatbot (FREE ONLY, NO LOCAL SETUP)

- **Base (exists):** The chatbot RAG plan (Item 1) — Groq free + Gemini free + Supabase. There is no AI code in the repo. **Stack decision (reuse the chatbot stack — no new research needed):** Groq free tier (chat) + Gemini free tier (embeddings) + Supabase Edge Functions — the same limits verified in the chatbot MD Part 2 (5 Nov 2026). Every new AI feature's cost will come from the same quota — so guardrails are essential (below).
- **Reality check (verified by search, 6 Nov 2026):** Third-party question-paper tools are not "free" — QPForge (3 papers free, then ₹20,000/year), TestMacher (3 papers/month free), Examaker (5 papers free), GyandootAI (3 papers free) — these are trials, not enough for a school's volume. GogyAI says "free forever, no sign-up" (30+ teacher tools) — but it is a website; it cannot be embedded or integrated, it can only be used as a link-out. **The second AI system will therefore be built in-house (on the Groq/Gemini free tiers), not on a third-party subscription.**
- **NEW S12.1 — AI report-card remarks (FEASIBLE — first):** Writing remarks takes the most of a teacher's time. The system: draft a remark from the student's marks + attendance + behaviour notes (Teacher N7) (Groq free) — the teacher approves/edits it; without approval it will not go on the report card. Every remark will carry an "AI draft" tag (whether the teacher approved it or not will appear in the audit log). Volume: ~500 students × 1 remark in one exam — within the Groq free tier (in batches, at night or during exam week).
- **NEW S12.2 — Auto question-paper generation (FEASIBLE — second):** The teacher gives a blueprint (class, subject, chapters, marks, difficulty mix) → the system builds a paper from a question bank (a Supabase table — questions the teacher has made before, or drafted by AI) (Groq free) → the teacher reviews it → PDF/DOCX export (the pdf/printing packages already exist). **A paper will never be used without teacher approval** — AI will never directly make an exam paper.
- **NEW S12.3 — Assignment feedback drafts (FEASIBLE — third):** The teacher asks for a feedback draft on homework submissions (Groq free) — short, constructive, matched to the student's level. The teacher approves/edits it, then the student sees it.
- **NOT FEASIBLE (stated honestly — will not be built):**
- **True ML predictive at-risk:** There is no ML infrastructure on the free tier for training (neither Groq nor the Gemini free tier trains models). What exists: rule-based at-risk (Teacher N8) + **simple trend projection** (derive the trend from past exams with Dart/SQL — this is a calculation, not ML; do not claim it as "AI prediction"). An ML version will come only when there is a paid budget — not in this document.
- **Timetable optimization (with an LLM):** Building a timetable with an LLM is the wrong tool — this is constraint-solving (teacher, room, period clashes). In this document, timetable optimization will be built as a **deterministic algorithm** (in Dart, with no AI cost) — it will not carry the "AI" label. If the owner wants, it can come in a separate step.
- **Guardrails (the same as the chatbot plan — not rewritten here, applied here):** A per-teacher daily limit (AI remarks/papers/feedback combined — within the Groq free tier), batch processing (at night or during exam week, never 500 calls at once), when the quota is exhausted the system will say "quota exhausted, try again tomorrow" (it will not spend money), every AI output will carry an "AI draft — teacher approval pending" tag, only the necessary data snippets will go to the LLM (never a full dump), Cloudflare Workers AI fallback (the one from the chatbot plan).
- **Graph/Excel:** AI usage report — usage per feature, quota usage, approval rate (SP-R15).

---

## Part C-X — Cross-cutting standards (apply to every item — do not rewrite them, take them from here)

### X1. Audit Trail Standard (on every money/data action)

- **Table:** `school_audit_log` — fields: id, institute_id, actor_username, actor_role, action (create/update/approve/lock/delete), entity (fees/payroll/hostel/...), entity_id, old_value (JSON), new_value (JSON), created_at.
- **Where it applies:** Fees payment/refund, payroll run/lock, marks lock/unlock, fee structure change, discipline action, inventory issue/return/audit, hostel allocation change, permission matrix change, admission offer/enroll.
- **Rule:** An action is not complete without its audit row (the audit insert will happen together with the action in the service method — not separately). Audit rows will never be deleted (only archived — there will be no delete button at all).
- **Verification:** After every action, the audit log must be searched for its row (the CHECKPOINT will record one example row's ID).

### X2. Notifications Standard (in-app — there is no SMS/WhatsApp provider)

- **Table:** `school_notifications` (proposed in Teacher MD N14 — if it has already been built, reuse it; do not build the table again; check in SP0).
- **Events (which news, to whom):** Leave request received (to the class teacher), gate pass pending (to the warden), infirmary visit (to the parent), low stock (to the admin), payroll run locked (to staff — "payslip ready"), discipline incident (to the class teacher + admin), reservation available (to the student), quota exhausted (to the admin).
- **Rule:** Every notification will have a link_route (tapping it opens the right screen) + a read/unread state. No notification will be created without a link.

### X3. Excel Standard (detail — the Core Modules standard, repeated here so Gemini does not have to search for it)

- The first sheet is **Summary** (title, filters, generated date/time, totals, generated-by username). The second sheet is **Data** (all rows, header row frozen, totals row at the end). Number formats: money to 2 decimals, dates DD-MMM-YYYY, percentages to 1 decimal.
- File name: `School_<CODE>_<YYYYMMDD>.xlsx` (the prefix can change by role — the teacher/admin reports will use their own standard).
- Export will always use the current filter (whatever filter is applied on the screen will be the one in the Excel file) — an export of "all data" without a filter will not happen (performance + privacy).

### X4. RLS Pattern (on every new table — copy-paste template)

- Every new table will have an `institute_id` column (multi-school isolation) + `created_by` + `created_at`.
- Policies (at least these 3): (a) select — only the user's own institute + role scope (teacher: their classes; parent: their children; student: only themselves); (b) insert/update — only the allowed role (from the matrix); (c) delete — nobody (deactivate with a status change).
- **Verification:** For every table, log in as another role/institute and run a select — it must return empty (the CHECKPOINT will record proof of the test).

### X5. Performance Budgets (measurable — in every step's CHECKPOINT)

- Dashboard first paint < 2 seconds (live database, 500 students). No list will load more than 100 rows at once (pagination mandatory). Every query will have a role filter + institute filter (fetching a whole table and filtering it in the UI is forbidden). Chart data will come aggregated (raw rows will not go into a chart). Edge Function response < 5 seconds (answer before the timeout).

### X6. UI Tokens (Step 13 base + Super strictness)

- Colours: blue `#2563EB`, emerald `#059669`, violet `#7C3AED`, ink `#0F172A`, slate `#475569`, background `#F8FAFC`, danger `#EF4444`, amber `#D97706`, border `#E2E8F0`. Typography: title 18/700, section 15/800, body 13.5/600, caption 11/500. Radius: card 14, chip 8, button 10. Spacing: 8pt grid. Touch: ≥ 48dp. Contrast: ≥ 4.5:1.
- New code will contain no hardcoded colours or sizes (verify with grep). Every new screen: 4-state (skeleton/empty+CTA/error+retry/loaded) + phone/desktop responsive check.

---

## Part D — Reports Catalogue (every report of the new modules: graph + Excel)

**Rule (on all reports — the same standard as the earlier documents):** Every report has filters (class, date range, institute — in multi-school), **a graph from `fl_chart`** and **Excel from the `excel` package**. Excel standard: the first sheet is **Summary** (title, filters, totals, generated date), the second sheet is **Data** (all rows), a totals row at the end of every sheet, file name `School_<CODE>_<YYYYMMDD>.xlsx`. Reconciliation rule: every number in a report must match its source screen. Role scope: teacher — their classes; parent — their children; student — only themselves; superadmin — everything (up to their own institute) — filtered at the service layer.

| Code | Report | Graph (fl_chart) | What the Excel will contain |
| --- | --- | --- | --- |
| SP-R01 | Payroll monthly cost | Line chart (month-wise total cost) | Month rows + gross/deductions/net + staff count |
| SP-R02 | Payslip register | — (it is a register table) | Staff rows + earnings/deductions/LOP/net + YTD |
| SP-R03 | Hostel occupancy | Bar chart (hostel-wise occupancy %) | Hostel/room rows + capacity/occupied/vacant |
| SP-R04 | Infirmary visits | Line chart (month-wise visits) | Visit rows + student/class/reason/medicine |
| SP-R05 | Cafeteria sales | Bar chart (day-wise sales) | Day rows + orders/amount/plan-wise split |
| SP-R06 | Alumni engagement | Bar chart (batch-wise alumni) + line (engagement trend) | Alumni rows + batch/status/event RSVPs |
| SP-R07 | Inventory stock + audit | Bar chart (category-wise stock value) | Item rows + qty/location/condition/audit status |
| SP-R08 | Activities participation | Bar chart (activity-wise participants) | Activity rows + participants/results/certificates |
| SP-R09 | Discipline incidents | Line (month-wise) + bar (category-wise) | Incident rows + student/category/severity/action |
| SP-R10 | Schools comparison (multi-school) | Bar chart (school-wise students/fees/attendance) | School rows + totals + per-school summary |
| SP-R11 | Library circulation | Line (month-wise issues) + bar (popular books) | Issue rows + book/student/dates/fine |
| SP-R12 | Permission audit | — (it is a matrix table) | Role × feature matrix + audit trail (who changed what) |
| SP-R13 | Chatbot usage (Item 1) | Line (day-wise chats) + bar (role-wise) | Usage rows + role/quota/unanswered questions |
| SP-R14 | Deploy health (Item 11) | Line (run duration trend) + success/fail counts | Run rows + commit/status/duration/error |
| SP-R15 | AI usage (Item 12) | Bar (feature-wise usage) + line (quota usage) | Usage rows + feature/teacher/approval rate |

**Note:** SP-R02 and SP-R12 are table-type reports (a graph has no meaning for them) — but their Excel will still be built, without exception.

---

## Part E — Gemini Execution Plan (line by line)

### E1. Steps and Order (SP0–SP12)

**SP0 — Verify (no code change, report only).** First find all of this and write it in the CHECKPOINT: (a) read the deploy log again — is the `.env` error still the same; (b) the formats of school accounts in the live `users` table (which ones are not in `s`-prefix form — show the list to the owner, do not rename anything); (c) the names of the college payroll tables (from the PayrollService `.from()` calls) + whether an ESI column exists; (d) PF/ESI/TDS rates/slabs + fine rates + depreciation % — where they are in settings (never fill them in by guesswork); (e) whether the Step 11 ₹25 library fine is auto-posted or was manual; (f) the circulars audience model (whether Alumni can be added); (g) transport GPS — whether there is real data behind the labels or not; (h) re-verify the Groq/Gemini free-tier limits (chatbot MD Part 2, 5 Nov 2026 — re-check at build time). **SP1 will not start without SP0.**

**SP1 — Deploy pipeline fix (Item 11 — FIRST OF ALL).** Remove `.env` from the pubspec assets + `--dart-define` in the workflow (SUPABASE_URL/ANON_KEY from GitHub Secrets) + a `flutter analyze` step + a build-output check. **Done only when:** a local `flutter build web` passes without a `.env` file + after the owner's approval, a test push's deploy run **succeeds**. Pushing happens only on the owner's call.

**SP2 — Payroll (Item 2).** School salary structure + `shr01` IDs (SAFE migration — show the rename list to the owner, rename only after approval) → monthly run + LOP → payslips PDF → arrears/advances → month close/lock. **Done only when:** one full month run + payslips + lock have been tested on the live database; the ESI deduction is visible.

**SP3 — Hostel / Infirmary / Cafeteria (Item 3).** Adapt the college hostel → infirmary (health records + visits + medicine stock) → cafeteria (menu + plans + wallet) → give the parent stubs real data. **Done only when:** one hostel allocation + one gate pass + one infirmary visit + one cafeteria order have been tested end-to-end live.

**SP4 — Alumni (Item 4).** Directory → engagement/events → communication (Alumni audience) → donations interest form (no money flow). **Done only when:** one alumni event + RSVP + notice have been tested live.

**SP5 — Inventory (Item 5).** Categories + stock → issue/return → maintenance + depreciation → purchase link → audit. **Done only when:** one item's full cycle (purchase → stock → issue → return → audit) has been tested live.

**SP6 — Activities (Item 6).** Events → clubs → sports/competitions → certificates link → student profile activities tab. **Done only when:** one event + one club + one competition + one certificate have been tested live.

**SP7 — Discipline (Item 7).** Incident report → inquiry → action → parent notice → behaviour notes link. (No appeal — on the owner's decision.) **Done only when:** one incident's full cycle has been tested live + the parent has received the notice.

**SP8 — Multi-school (Item 8).** School onboarding → switcher → per-school settings → isolation test → billing record. **Done only when:** two test schools have been created and the isolation test passes (School A's admin cannot see School B's data — proof of the test in the CHECKPOINT).

**SP9 — Library deep-dive (Item 9).** Catalogue management → reservation + waitlist → overdue automation + fine auto-post → e-books (free sources only). **Done only when:** one reservation + one overdue fine auto-post have been tested live.

**SP10 — Permission matrix (Item 10).** Define the matrix → route + service enforcement → marks-lock → maker-checker extension → align the old guards. **Done only when:** the matrix has been tested by logging in as every role (a wrong role cannot reach the wrong screen + the service call is also blocked).

**SP11 — Second AI system (Item 12).** Remarks → question papers → assignment feedback (Groq free, teacher approval mandatory) + trend projection (a calculation, no ML claim) + guardrails + quota fallback. **Done only when:** 5 test cases per feature pass + the quota-exhausted mode has been tested.

**SP12 — Reports + Excel + Final QA + HANDOFF.** SP-R01 to SP-R15 (every report graph + Excel) → full Super end-to-end on the live database (one cycle of every module) → college regression (`flutter analyze` on the whole repo) → deploy run success (after SP1) → HANDOFF block (template below) + a 3-line note for the next work.

### E2. Hard Rules (for Gemini — breaking them is forbidden)

1. College code/tables/routes — zero touch (reuse is allowed — copy and adapt for school; do not edit a college file). Exception: `.github/workflows/deploy.yml` (only in SP1).
2. No mock/fake/demo data — not in the new modules, not in reports, not in tests (test data will be marked separately and will not go to the live database).
3. Every new table: an SQL file in `database/` + RLS policies + the table name and proof of the RLS test in the CHECKPOINT. The strictest RLS will apply to infirmary health records (only nurse/warden/admin + the parent themselves).
4. Teacher-scope / parent-scope / institute-scope in every query — filter at the service layer; never fetch a whole table and filter it in the UI.
5. No secret/key/password in any file. Free-tier keys go in Supabase Secrets — never in the repo.
6. Payroll/HR IDs follow the `shr01` pattern — and no live account will be renamed without the owner's approval.
7. Donations and appeal will not be built without the owner's decision (in this document they are only an interest form / decision point).
8. The "AI draft — teacher approval pending" tag is mandatory on AI outputs. AI will never send a report card, exam paper or parent notice directly.
9. Every step: first `flutter analyze` on that file, then on the whole `lib/features/school/` — 0 errors, 0 warnings, only then a CHECKPOINT.
10. After every step: a row in `SCHOOL_PROGRESS.md` + CHECKPOINT + commit (`super: SP<n> — <title>`). If a limit is reached, write a HANDOFF block — never call an incomplete step "done".

### E3. HANDOFF Template (Gemini writes this when a limit is reached)

```
HANDOFF — Super Enterprise Deep-Dive
Completed: SP0–SP<n> (every step's commit + CHECKPOINT is in SCHOOL_PROGRESS.md)
In progress: SP<n+1> — <what was being done, where it stopped, which file was open>
Next agent starts here: <exact step + first action>
Pending / held: <any owner decision still pending — e.g. donations, appeal, rename list>
Test evidence: <what was verified on the live database, what was not>
```

---

## Part F — After Super (roadmap)

1. **Super (this document)** — 12 items, SP0–SP12.
2. **Student deep-dive** — executed (STU7 commit) — by Gemini. Its work is done; nothing further is needed from this document. (No execution reaches the live site until after the deploy fix in SP1.)
3. **Core Modules execution** — Admin/HR/Admission/Fees/Reports/Import — after the F1 gate (Super's payroll Item 2 connects to the Core Modules HR — the staff data of both must be one and the same; two HRs will not be built).
4. **Transport deep-dive (making GPS real)** — not in Super. The GPS provider + hardware decision is the owner's (it will cost money — it will not be free).
5. **Mobile app / PWA + offline mode** — not in Super. A separate decision after the web is stable.
6. **Security audit + load testing + backup plan** — not in Super. A separate production-hardening document will be made (the audit of the Supabase October warnings will come in it).

**The order from #2 to #6 will be finalised on the owner's next call — Gemini will do only Super (SP0–SP12) from this document and will not touch the other work.**

---

## Appendix — Files, Methods, Tables (useful at execution time)

### A. Files (verified)

| File | Purpose |
| --- | --- |
| `.github/workflows/deploy.yml` (855 bytes) | Deploy workflow — fixed in SP1 |
| `pubspec.yaml` (line 96: `- .env` asset) | The cause of the deploy failure — remove it in SP1 |
| `lib/features/hr/services/payroll_service.dart` | College payroll — adapt it (Item 2) |
| `lib/features/hr/screens/payroll_runs_screen.dart`, `payslip_detail_screen.dart`, `my_payslips_screen.dart`, `hr_payroll_management_screen.dart`, `edit_salary_screen.dart` | College payroll screens — adapt them |
| `lib/features/hostel/` (12 files — service + warden/student screens) | College hostel — adapt it (Item 3) |
| `lib/features/school/library/school_library_screen.dart` | Library — the base for the deep-dive (Item 9) |
| `lib/features/school/transport/transport_screen.dart` | Transport — no GPS code (labels only) |
| `lib/features/admin/services/superadmin_service.dart` | College superadmin — adapt it (Item 8) |
| `lib/services/school_service.dart` (~7,000+ lines) | All school methods (parent infirmary/cafeteria stubs were found here) |
| `lib/services/school_export_service.dart` | PDF/CSV exports — the Excel pattern will be extended from here |
| `pubspec.yaml` | `fl_chart`, `excel`, `csv`, `pdf`, `printing` — already present |

### B. Methods Worth Reusing (exist — do not write them again)

`PayrollService`: `getRuns`, `getRunById`, `getPayslips`, `getPayslipForEmployee`, `generateRun` (the LOP rule is inside it), `markRunPaid`, `setPayslipHold`, `getPayrollStats`. `HostelService`: `getHostels`, `getRoomsByHostel`, `allotRoom`, `unallotRoom`, `reassignRoom`, `autoAllocateRooms`, `getGatepasses`, `createGatepass`, `updateGatepassStatus`, `getRoomsForAttendance`, `saveAttendance`, `getIncidents`, `logIncident`. `SuperAdminService`: `getDepartments`, `createDepartment`, `getDesignations`, `getAcademicYears`, `setCurrentAcademicYear`, `getSettings`, `saveSettings`, `getInstituteStats`.

### C. Tables (exist — from the school SQL)

`school_attendance`, `school_marks`, `school_co_scholastic`, `school_homework`, `school_homework_submissions`, `school_students`, `school_teachers` (PK `username`), `school_timetable`, `school_classes`, `school_subjects`, `school_exam_sessions`, `school_report_card_meta`, `school_student_leaves`, `school_circulars`, `school_library`, `school_library_issues`, `school_notifications`, `school_teacher_messages`, `school_parent_teacher_messages`, `institutes`, `parent_student_links`, `hostel_fee_enrollment` (college).

### D. New Tables (built in the SP steps — RLS mandatory on every one)

`school_payroll_runs`, `school_payslips`, `school_salary_structures` (Item 2); `school_hostels`, `school_hostel_rooms`, `school_hostel_allocations`, `school_gate_passes`, `school_hostel_attendance` (Item 3 hostel); `school_infirmary_records`, `school_infirmary_visits`, `school_medicine_stock` (Item 3 infirmary); `school_cafeteria_menus`, `school_meal_plans`, `school_cafeteria_wallets`, `school_canteen_orders` (Item 3 cafeteria); `school_alumni`, `school_alumni_events`, `school_alumni_rsvps` (Item 4); `school_inventory_items`, `school_inventory_issues`, `school_inventory_maintenance`, `school_inventory_audits` (Item 5); `school_events`, `school_clubs`, `school_club_members`, `school_sports`, `school_competitions` (Item 6); `school_discipline_incidents`, `school_discipline_inquiries`, `school_discipline_actions` (Item 7); `school_schools` (onboarding — or extend `institutes`, decide in SP0), `school_billing_records` (Item 8); `school_library_books` (catalogue — or extend `school_library`, decide in SP0), `school_library_reservations`, `school_ebooks` (Item 9); `school_permission_matrix`, `school_audit_log` (Items 10 + audit trail); `school_ai_usage` (Items 1, 12).

### E. Per-Item Deliverables (screens + service + SQL — what Gemini has to build)

| Item | New screens (lib/features/school/...) | Service methods (in school_service.dart — or a new school_super_service.dart, decide in SP0) | SQL file (database/...) |
| --- | --- | --- | --- |
| 1 Chatbot | Chat widget (shared — on every new module) | New RPC tools (hostel/payslip/library/activity/cafeteria) | `school_ai_usage` (usage log) |
| 2 Payroll | salary structure, payroll runs, payslip detail, my payslips, payroll reports | `generateSchoolPayrollRun`, `getSchoolPayslips`, `markSchoolRunPaid`, `getSchoolPayrollStats` | `school_payroll_setup.sql` |
| 3 Hostel/Infirmary/Cafeteria | hostel dashboard + rooms + gate pass + night attendance, infirmary visits + stock, cafeteria menu + wallet + orders | Adapt the HostelService pattern; `getInfirmaryVisits`, `logInfirmaryVisit`, `getCafeteriaMenu`, `rechargeWallet` (make the stub real) | `school_hostel_setup.sql`, `school_infirmary_setup.sql`, `school_cafeteria_setup.sql` |
| 4 Alumni | alumni directory, alumni events, alumni notices | `getAlumni`, `createAlumniEvent`, `rsvpAlumniEvent` | `school_alumni_setup.sql` |
| 5 Inventory | inventory list, issue/return, maintenance, audit | `getInventoryItems`, `issueInventoryItem`, `returnInventoryItem`, `auditInventory` | `school_inventory_setup.sql` |
| 6 Activities | events, clubs, sports/competitions, student activities tab | `getSchoolEvents`, `joinClub`, `logActivityResult` | `school_activities_setup.sql` |
| 7 Discipline | incident report, inquiry, action, parent notice | `reportIncident`, `inquireIncident`, `resolveIncident` | `school_discipline_setup.sql` |
| 8 Multi-school | school onboarding, school switcher, per-school settings, billing record | Adapt the SuperAdminService pattern; `getSchools`, `switchSchool`, `getSchoolSettings` | `school_multi_setup.sql` (or extend `institutes` — decide in SP0) |
| 9 Library | catalogue manage, reservation + waitlist, e-books | `reserveBook`, `getReservations`, `postLibraryFine`, `getEbooks` | `school_library_deep_setup.sql` |
| 10 Permissions | permission matrix settings, audit trail view | `getPermissionMatrix`, `updatePermission`, `getAuditLog` | `school_permissions_setup.sql` |
| 11 Deploy | (no screen — workflow + pubspec) | — | — |
| 12 Second AI | remarks review, question paper builder, feedback review | Edge Functions (remarks/paper/feedback) + `logAiUsage` | `school_ai_usage` (with Item 1) |

---

## Final Note (for the owner)

This document is the plan to turn the school ERP from a "good product" into a "complete product" — but its first line is the deploy fix. The deploy is broken, so the other 11 items mean nothing until then, because nothing will reach the live site. Do not change the order: **first SP1 (deploy), then SP2 (payroll — the money accounting), then the rest.** One decision is still pending, and Gemini will not make it: **whether donations and the appeal flow should be built or not.** Its answer should come in the SP0 report; after that, the work will not stop.
