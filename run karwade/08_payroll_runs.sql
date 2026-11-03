-- ============================================================
-- PAYROLL DEEPENING: Monthly Payroll Runs + Payslips + Salary Register
-- Tables: payroll_runs, payslips
-- Source data (read-only here): teacher_details + teacher_salary
--   (active structure) + teacher_leaves (LOP computation).
-- A payroll run SNAPSHOTS every active teacher's salary components
-- into payslips, so a month's pay stays frozen forever even if the
-- salary structure is edited later — the old payroll screen computed
-- everything live and persisted nothing.
-- Idempotent: safe to run multiple times.
-- Run AFTER: supabase_teacher_setup.sql,
--            supabase_teacher_salary_setup.sql,
--            supabase_leave_management_setup.sql,
--            update_leave_deductions.sql (adds is_salary_deducted,
--            the flag that marks an approved leave as unpaid / LWP).
-- ============================================================

-- pgcrypto for gen_random_uuid() (usually already enabled on Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------
-- 1. PAYROLL RUNS (one row per month)
-- Lifecycle: draft -> processed -> paid -> locked
-- The app generates runs straight into 'processed' (payslips are
-- inserted in the same action); 'paid' is set when salaries are
-- disbursed, 'locked' freezes a closed month against regeneration.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payroll_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    year INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'processed', 'paid', 'locked')),
    total_gross NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_deductions NUMERIC(15, 2) NOT NULL DEFAULT 0,
    total_net NUMERIC(15, 2) NOT NULL DEFAULT 0,
    employees_count INT NOT NULL DEFAULT 0,
    processed_by TEXT,                       -- users.username of HR who generated
    processed_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (month, year)
);

COMMENT ON TABLE payroll_runs IS 'One persisted payroll cycle per month; totals are the sum of its payslips.';
COMMENT ON COLUMN payroll_runs.status IS 'draft | processed | paid | locked';
COMMENT ON COLUMN payroll_runs.total_deductions IS 'Statutory deductions + LOP deductions across all payslips of the run.';

-- ------------------------------------------------------------
-- 2. PAYSLIPS (one row per employee per run — the salary register)
-- All money columns are SNAPSHOTS copied from teacher_salary at
-- generation time (gross/total_deductions are GENERATED columns on
-- teacher_salary, so they are read, never written, there — and
-- stored as plain values here).
-- LOP: lop_days counts Approved teacher_leaves flagged
-- is_salary_deducted = true overlapping the run month;
-- lop_deduction = gross / working_days * lop_days.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payslips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id UUID NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE,
    employee_id TEXT NOT NULL,               -- teacher_details.employee_id
    teacher_username TEXT,                   -- teacher_details.teacher_id (login username)
    teacher_name TEXT,
    department TEXT,
    working_days INT NOT NULL DEFAULT 30,    -- calendar days in the run month
    present_days NUMERIC(6, 2) NOT NULL DEFAULT 30,
    lop_days NUMERIC(6, 2) NOT NULL DEFAULT 0,
    -- Earnings snapshot
    basic NUMERIC(12, 2) NOT NULL DEFAULT 0,
    hra NUMERIC(12, 2) NOT NULL DEFAULT 0,
    travel NUMERIC(12, 2) NOT NULL DEFAULT 0,
    medical NUMERIC(12, 2) NOT NULL DEFAULT 0,
    special NUMERIC(12, 2) NOT NULL DEFAULT 0,
    other_allowances NUMERIC(12, 2) NOT NULL DEFAULT 0,
    gross NUMERIC(12, 2) NOT NULL DEFAULT 0,
    -- Deductions snapshot
    pf NUMERIC(12, 2) NOT NULL DEFAULT 0,
    professional_tax NUMERIC(12, 2) NOT NULL DEFAULT 0,
    income_tax NUMERIC(12, 2) NOT NULL DEFAULT 0,
    other_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0,
    total_deductions NUMERIC(12, 2) NOT NULL DEFAULT 0,  -- statutory only (excl. LOP)
    lop_deduction NUMERIC(12, 2) NOT NULL DEFAULT 0,
    net_pay NUMERIC(12, 2) NOT NULL DEFAULT 0,            -- gross - total_deductions - lop_deduction
    status TEXT NOT NULL DEFAULT 'generated'
        CHECK (status IN ('generated', 'paid', 'on_hold')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (run_id, employee_id)
);

COMMENT ON TABLE payslips IS 'Frozen per-employee salary snapshot for a payroll run; doubles as the monthly salary register.';
COMMENT ON COLUMN payslips.lop_days IS 'Loss-of-pay days: approved leaves flagged is_salary_deducted overlapping the run month.';
COMMENT ON COLUMN payslips.total_deductions IS 'PF + professional tax + income tax + other deductions (LOP kept separate in lop_deduction).';
COMMENT ON COLUMN payslips.status IS 'generated | paid | on_hold (on_hold slips are skipped when a run is marked paid).';

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_payroll_runs_period
    ON payroll_runs (year, month);
CREATE INDEX IF NOT EXISTS idx_payroll_runs_status
    ON payroll_runs (status);
CREATE INDEX IF NOT EXISTS idx_payslips_run
    ON payslips (run_id);
CREATE INDEX IF NOT EXISTS idx_payslips_employee
    ON payslips (employee_id);
CREATE INDEX IF NOT EXISTS idx_payslips_username
    ON payslips (teacher_username);
CREATE INDEX IF NOT EXISTS idx_payslips_status
    ON payslips (status);

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY (permissive policies, same style as 03/05)
-- ------------------------------------------------------------
ALTER TABLE payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE payslips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON payroll_runs;
CREATE POLICY "Allow all for authenticated" ON payroll_runs
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON payroll_runs;
CREATE POLICY "Allow all for anon" ON payroll_runs
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON payslips;
CREATE POLICY "Allow all for authenticated" ON payslips
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON payslips;
CREATE POLICY "Allow all for anon" ON payslips
    FOR ALL TO anon USING (true) WITH CHECK (true);
