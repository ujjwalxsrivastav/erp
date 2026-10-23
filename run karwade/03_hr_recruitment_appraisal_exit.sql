-- ============================================================
-- HR GAP FEATURES: Recruitment + Appraisal (PBAS/API) + Exit & FnF
-- Tables: job_postings, job_applications, appraisal_forms,
--         employee_exits, exit_nodues
-- Idempotent: safe to run multiple times.
-- ============================================================

-- pgcrypto for gen_random_uuid() (usually already enabled on Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------
-- 1. JOB POSTINGS (Recruitment)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS job_postings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    department TEXT,
    post_type TEXT NOT NULL DEFAULT 'permanent'
        CHECK (post_type IN ('permanent', 'contract', 'adjunct', 'visiting')),
    vacancies INT NOT NULL DEFAULT 1,
    eligibility TEXT,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'closed')),
    published_at TIMESTAMPTZ,
    closing_date DATE,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE job_postings IS 'HR recruitment: advertised posts / vacancies';
COMMENT ON COLUMN job_postings.post_type IS 'permanent | contract | adjunct | visiting';
COMMENT ON COLUMN job_postings.status IS 'draft | published | closed';

-- ------------------------------------------------------------
-- 2. JOB APPLICATIONS (Recruitment)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS job_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_id UUID NOT NULL REFERENCES job_postings(id) ON DELETE CASCADE,
    applicant_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    qualification TEXT,
    experience_years NUMERIC(5, 2) DEFAULT 0,
    resume_url TEXT,
    status TEXT NOT NULL DEFAULT 'applied'
        CHECK (status IN ('applied', 'shortlisted', 'interview_scheduled',
                          'selected', 'rejected', 'offered', 'joined')),
    interview_date TIMESTAMPTZ,
    interview_marks NUMERIC(6, 2),
    remarks TEXT,
    applied_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE job_applications IS 'Applications received against job_postings';
COMMENT ON COLUMN job_applications.status IS 'applied | shortlisted | interview_scheduled | selected | rejected | offered | joined';

-- ------------------------------------------------------------
-- 3. APPRAISAL FORMS (PBAS / API)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appraisal_forms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id TEXT NOT NULL,               -- staff username (users.username)
    appraisal_year TEXT NOT NULL,            -- e.g. '2026-27'
    category TEXT NOT NULL DEFAULT 'teaching'
        CHECK (category IN ('teaching', 'research', 'service')),
    self_score NUMERIC(6, 2),
    student_feedback_score NUMERIC(6, 2),
    hod_score NUMERIC(6, 2),
    final_api_score NUMERIC(6, 2),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'submitted', 'hod_verified',
                          'committee_reviewed', 'approved', 'returned')),
    remarks TEXT,
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE appraisal_forms IS 'Faculty appraisal / PBAS-API forms, one row per employee per year per category';
COMMENT ON COLUMN appraisal_forms.employee_id IS 'Staff username matching users.username / teacher_details';
COMMENT ON COLUMN appraisal_forms.status IS 'draft | submitted | hod_verified | committee_reviewed | approved | returned';

-- ------------------------------------------------------------
-- 4. EMPLOYEE EXITS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS employee_exits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id TEXT NOT NULL,               -- staff username (users.username)
    exit_type TEXT NOT NULL DEFAULT 'resignation'
        CHECK (exit_type IN ('resignation', 'retirement', 'termination',
                             'end_of_contract', 'death')),
    last_working_date DATE,
    notice_period_days INT DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'initiated'
        CHECK (status IN ('initiated', 'no_dues_pending', 'fnf_pending',
                          'completed', 'relieved')),
    fnf_amount NUMERIC(12, 2),
    remarks TEXT,
    initiated_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE employee_exits IS 'Employee separation cases driving no-dues clearance and Full & Final settlement';
COMMENT ON COLUMN employee_exits.status IS 'initiated | no_dues_pending | fnf_pending | completed | relieved';

-- ------------------------------------------------------------
-- 5. EXIT NO-DUES CHECKLIST (one row per department per exit)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS exit_nodues (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exit_id UUID NOT NULL REFERENCES employee_exits(id) ON DELETE CASCADE,
    department TEXT NOT NULL
        CHECK (department IN ('library', 'laboratory', 'it', 'hostel',
                              'finance', 'examination', 'store')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'clear', 'due')),
    due_amount NUMERIC(12, 2) DEFAULT 0,
    remarks TEXT,
    updated_by TEXT,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (exit_id, department)
);

COMMENT ON TABLE exit_nodues IS 'Department-wise no-dues clearance rows for an employee exit';

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_job_postings_status
    ON job_postings (status);
CREATE INDEX IF NOT EXISTS idx_job_postings_department
    ON job_postings (department);
CREATE INDEX IF NOT EXISTS idx_job_applications_posting
    ON job_applications (posting_id);
CREATE INDEX IF NOT EXISTS idx_job_applications_status
    ON job_applications (status);
CREATE INDEX IF NOT EXISTS idx_appraisal_employee
    ON appraisal_forms (employee_id);
CREATE INDEX IF NOT EXISTS idx_appraisal_year_status
    ON appraisal_forms (appraisal_year, status);
CREATE INDEX IF NOT EXISTS idx_employee_exits_employee
    ON employee_exits (employee_id);
CREATE INDEX IF NOT EXISTS idx_employee_exits_status
    ON employee_exits (status);
CREATE INDEX IF NOT EXISTS idx_exit_nodues_exit
    ON exit_nodues (exit_id);

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY (permissive policies, same style as other modules)
-- ------------------------------------------------------------
ALTER TABLE job_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE appraisal_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_exits ENABLE ROW LEVEL SECURITY;
ALTER TABLE exit_nodues ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON job_postings;
CREATE POLICY "Allow all for authenticated" ON job_postings
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON job_postings;
CREATE POLICY "Allow all for anon" ON job_postings
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON job_applications;
CREATE POLICY "Allow all for authenticated" ON job_applications
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON job_applications;
CREATE POLICY "Allow all for anon" ON job_applications
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON appraisal_forms;
CREATE POLICY "Allow all for authenticated" ON appraisal_forms
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON appraisal_forms;
CREATE POLICY "Allow all for anon" ON appraisal_forms
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON employee_exits;
CREATE POLICY "Allow all for authenticated" ON employee_exits
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON employee_exits;
CREATE POLICY "Allow all for anon" ON employee_exits
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON exit_nodues;
CREATE POLICY "Allow all for authenticated" ON exit_nodues
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON exit_nodues;
CREATE POLICY "Allow all for anon" ON exit_nodues
    FOR ALL TO anon USING (true) WITH CHECK (true);
