# Supabase SQL — Run Karwade (in this order)

Supabase Dashboard → SQL Editor me ye files **isi order me** run karo.
Saari files idempotent hain (dobara run karne par error nahi ayega).

| # | File | Kya banta hai |
|---|------|---------------|
| 1 | `01_examination_module.sql` | Examination (COE): exam_sessions, exam_subjects, exam_registrations, hall_tickets, exam_results, revaluation_requests |
| 2 | `02_admin_nodues_certificates.sql` | Admin: nodues_requests, nodues_clearances, certificate_requests, grievance_tickets |
| 3 | `03_hr_recruitment_appraisal_exit.sql` | HR: job_postings, job_applications, appraisal_forms, employee_exits, exit_nodues |
| 4 | `04_finance_budget_p2p_grants.sql` | Finance: purchase_indents, purchase_orders, goods_receipts, vendor_bills, research_grants, grant_expenses |

## Note
- `04` file ke Budget screens purani `sql_migrations/27_enterprise_finance_phase1.sql`
  par depend karte hain (department_budgets, vendors tables wahi se aati hain).
  Agar wo migration kabhi run nahi hui, pehle use run karna.
- Baaki purani migrations (`sql_migrations/` folder) pehle se production me honi chahiye —
  ye nayi files un par hi build karti hain (users, student_details, student_fee_allocations, student_marks).
