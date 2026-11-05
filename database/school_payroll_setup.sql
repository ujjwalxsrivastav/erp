-- School ERP Super Enterprise: Payroll Tables & Audit Log Setup
-- Conforming to Part C Item 2 (S2.1 - S2.5) & Part C-X1 (Audit Trail)

-- 1. Unified Audit Log Table (Cross-Cutting Standard X1)
CREATE TABLE IF NOT EXISTS public.school_audit_log (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    actor_username TEXT NOT NULL,
    actor_role TEXT NOT NULL DEFAULT 'admin',
    action TEXT NOT NULL, -- create, update, approve, lock, delete, hold, adjust
    entity TEXT NOT NULL, -- payroll, fees, hostel, infirmary, inventory, discipline, permissions
    entity_id TEXT NOT NULL,
    old_value JSONB DEFAULT '{}'::jsonb,
    new_value JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_school_audit_entity ON public.school_audit_log (entity, entity_id);
CREATE INDEX IF NOT EXISTS idx_school_audit_actor ON public.school_audit_log (actor_username);
CREATE INDEX IF NOT EXISTS idx_school_audit_inst ON public.school_audit_log (institute_id);

ALTER TABLE public.school_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "school_audit_read" ON public.school_audit_log;
CREATE POLICY "school_audit_read" ON public.school_audit_log
    FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "school_audit_insert" ON public.school_audit_log;
CREATE POLICY "school_audit_insert" ON public.school_audit_log
    FOR INSERT TO authenticated, anon WITH CHECK (true);

-- 2. School Staff Salary Structures
CREATE TABLE IF NOT EXISTS public.school_salary_structures (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    employee_id TEXT NOT NULL, -- e.g. steacher1, shr01, sadmin1
    employee_name TEXT NOT NULL,
    department TEXT NOT NULL DEFAULT 'Academics',
    designation TEXT NOT NULL DEFAULT 'Teacher',
    basic_pay NUMERIC(12, 2) NOT NULL DEFAULT 25000.00,
    hra NUMERIC(12, 2) NOT NULL DEFAULT 7500.00,
    travel_allowance NUMERIC(12, 2) NOT NULL DEFAULT 2000.00,
    medical_allowance NUMERIC(12, 2) NOT NULL DEFAULT 1500.00,
    special_allowance NUMERIC(12, 2) NOT NULL DEFAULT 2000.00,
    other_allowances NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gross_salary NUMERIC(12, 2) GENERATED ALWAYS AS (
        basic_pay + hra + travel_allowance + medical_allowance + special_allowance + other_allowances
    ) STORED,
    provident_fund NUMERIC(12, 2) NOT NULL DEFAULT 3000.00, -- 12% of basic
    esi_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0.00,     -- 0.75% if gross <= 21000
    professional_tax NUMERIC(12, 2) NOT NULL DEFAULT 200.00,
    income_tax NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    other_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    bank_name TEXT DEFAULT 'State Bank of India',
    bank_account_no TEXT DEFAULT '98765432101',
    ifsc_code TEXT DEFAULT 'SBIN0001234',
    pan_number TEXT DEFAULT 'ABCDE1234F',
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_school_salary_emp ON public.school_salary_structures (employee_id);
CREATE INDEX IF NOT EXISTS idx_school_salary_inst ON public.school_salary_structures (institute_id);

ALTER TABLE public.school_salary_structures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "school_salary_structures_all" ON public.school_salary_structures;
CREATE POLICY "school_salary_structures_all" ON public.school_salary_structures
    FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- 3. School Payroll Runs
CREATE TABLE IF NOT EXISTS public.school_payroll_runs (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    month_year TEXT NOT NULL, -- e.g. '2026-10', '2026-11'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft', -- draft, reviewed, locked, paid
    total_staff INTEGER NOT NULL DEFAULT 0,
    total_gross NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_deductions NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_lop NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    total_net_pay NUMERIC(14, 2) NOT NULL DEFAULT 0.00,
    locked_at TIMESTAMPTZ,
    locked_by TEXT,
    paid_at TIMESTAMPTZ,
    paid_by TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_school_payroll_runs_month ON public.school_payroll_runs (month_year);
CREATE INDEX IF NOT EXISTS idx_school_payroll_runs_inst ON public.school_payroll_runs (institute_id);

ALTER TABLE public.school_payroll_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "school_payroll_runs_all" ON public.school_payroll_runs;
CREATE POLICY "school_payroll_runs_all" ON public.school_payroll_runs
    FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- 4. School Payslips
CREATE TABLE IF NOT EXISTS public.school_payslips (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    run_id TEXT NOT NULL REFERENCES public.school_payroll_runs(id) ON DELETE CASCADE,
    employee_id TEXT NOT NULL, -- steacher1, shr01, etc.
    employee_name TEXT NOT NULL,
    department TEXT NOT NULL DEFAULT 'Academics',
    designation TEXT NOT NULL DEFAULT 'Teacher',
    working_days INTEGER NOT NULL DEFAULT 30,
    present_days NUMERIC(4, 1) NOT NULL DEFAULT 30.0,
    lop_days NUMERIC(4, 1) NOT NULL DEFAULT 0.0,
    basic_pay NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    hra NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    travel_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    medical_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    special_allowance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    other_allowances NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gross_salary NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    provident_fund NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    esi_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    professional_tax NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    income_tax NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    lop_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    arrears NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    advances_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    other_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_pay NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    status TEXT NOT NULL DEFAULT 'normal', -- normal, on_hold, paid
    payment_mode TEXT DEFAULT 'Bank Transfer',
    payment_reference TEXT,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_school_payslips_run ON public.school_payslips (run_id);
CREATE INDEX IF NOT EXISTS idx_school_payslips_emp ON public.school_payslips (employee_id);
CREATE INDEX IF NOT EXISTS idx_school_payslips_inst ON public.school_payslips (institute_id);

ALTER TABLE public.school_payslips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "school_payslips_all" ON public.school_payslips;
CREATE POLICY "school_payslips_all" ON public.school_payslips
    FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);
