-- ============================================================
-- TEACHER LIFECYCLE (Zero-to-Hero): CV -> Interview -> Selection /
-- Rejection Record -> Offer -> Joining / Onboarding -> Department &
-- Subject Mapping -> Payroll Seeding -> HOD Subject Allotment
-- Tables: interview_rounds, recruitment_events, offer_letters,
--         employee_onboarding, teacher_subject_competency,
--         subject_allotments
-- Extends: job_postings / job_applications (see 03 file).
-- Idempotent: safe to run multiple times.
-- Run AFTER: 03_hr_recruitment_appraisal_exit.sql,
--            supabase_teacher_setup.sql, supabase_teacher_salary_setup.sql
-- ============================================================

-- pgcrypto for gen_random_uuid() (usually already enabled on Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------
-- 0. EXTEND job_applications: stage tracking + rejection record
-- Rejected candidates stay in the system forever (never deleted),
-- with the stage at which they were rejected and the reason.
-- ------------------------------------------------------------
ALTER TABLE job_applications
    ADD COLUMN IF NOT EXISTS rejection_stage TEXT;
ALTER TABLE job_applications
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE job_applications
    ADD COLUMN IF NOT EXISTS current_stage TEXT DEFAULT 'applied';

-- Backfill current_stage from the legacy status column (idempotent)
UPDATE job_applications
SET current_stage = status
WHERE (current_stage IS NULL OR current_stage = 'applied')
  AND status IS NOT NULL
  AND status <> 'applied';

COMMENT ON COLUMN job_applications.rejection_stage IS 'Pipeline stage at which the candidate was rejected (applied / shortlisted / interview / selection / offer)';
COMMENT ON COLUMN job_applications.rejection_reason IS 'Reason recorded at rejection; candidate remains in the rejected pool permanently';
COMMENT ON COLUMN job_applications.current_stage IS 'Fine-grained pipeline stage: applied | shortlisted | interview | selected | offered | joined | rejected (status column kept in sync)';

-- ------------------------------------------------------------
-- 1. INTERVIEW ROUNDS (multiple rounds per application)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS interview_rounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES job_applications(id) ON DELETE CASCADE,
    round_no INT NOT NULL DEFAULT 1,
    round_type TEXT NOT NULL DEFAULT 'panel'
        CHECK (round_type IN ('screening', 'demo_lecture', 'panel', 'hr', 'final')),
    scheduled_at TIMESTAMPTZ,
    venue TEXT,
    panel_members JSONB NOT NULL DEFAULT '[]'::jsonb,   -- array of panel member names
    status TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'completed', 'cancelled', 'rescheduled')),
    marks NUMERIC(6, 2),
    feedback TEXT,
    recommendation TEXT
        CHECK (recommendation IN ('strong_yes', 'yes', 'no', 'strong_no')),
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE interview_rounds IS 'Teacher hiring: one row per interview round of a job application';
COMMENT ON COLUMN interview_rounds.panel_members IS 'JSONB array of panel member names';
COMMENT ON COLUMN interview_rounds.recommendation IS 'strong_yes | yes | no | strong_no (NULL until the round is completed)';

-- ------------------------------------------------------------
-- 2. RECRUITMENT EVENTS (management timeline / audit feed)
-- Every step of the hiring pipeline writes an event here so higher
-- management sees a live zero-to-hero timeline per candidate.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recruitment_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID REFERENCES job_applications(id) ON DELETE SET NULL,
    posting_id UUID REFERENCES job_postings(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL DEFAULT 'note'
        CHECK (event_type IN ('cv_received', 'shortlisted', 'interview_scheduled',
                              'interview_done', 'selected', 'rejected',
                              'offer_issued', 'offer_accepted', 'joined', 'note')),
    title TEXT NOT NULL,
    notes TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE recruitment_events IS 'Append-only timeline of recruitment activity for management reporting; never updated or deleted by the app';

-- ------------------------------------------------------------
-- 3. OFFER LETTERS (one offer per application)
-- Salary structure captured here seeds teacher_salary at joining.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS offer_letters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL UNIQUE REFERENCES job_applications(id) ON DELETE CASCADE,
    department TEXT,
    designation TEXT,
    employment_type TEXT,               -- permanent | contract | adjunct | visiting | guest
    basic_salary NUMERIC(12, 2) NOT NULL DEFAULT 0,
    hra NUMERIC(12, 2) NOT NULL DEFAULT 0,
    other_allowances NUMERIC(12, 2) NOT NULL DEFAULT 0,
    joining_date DATE,
    offer_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'issued'
        CHECK (status IN ('issued', 'accepted', 'declined', 'joined')),
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE offer_letters IS 'Offer issued to a selected candidate; basic/HRA/other allowances are monthly amounts that seed payroll on joining';

-- ------------------------------------------------------------
-- 4. EMPLOYEE ONBOARDING (joining case per selected candidate)
-- username + employee_id are generated by the app at onboarding
-- start; Complete Joining creates users / teacher_details /
-- teacher_salary rows from this case + the linked offer.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS employee_onboarding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID UNIQUE REFERENCES job_applications(id) ON DELETE SET NULL,
    username TEXT UNIQUE,               -- future users.username / teacher_details.teacher_id
    employee_id TEXT UNIQUE,            -- e.g. EMP2026001
    full_name TEXT NOT NULL,
    department TEXT,
    designation TEXT,
    joining_date DATE,
    documents JSONB NOT NULL DEFAULT '{}'::jsonb,
    -- documents shape: {"aadhaar": bool, "pan": bool, "degree": bool,
    --                   "experience_letter": bool, "photo": bool,
    --                   "bank_passbook": bool}
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'documents_pending', 'completed')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE employee_onboarding IS 'Joining case for a hired teacher: generated username/employee id, document checklist and completion status';
COMMENT ON COLUMN employee_onboarding.documents IS 'Checklist map: aadhaar / pan / degree / experience_letter / photo / bank_passbook -> bool';

-- ------------------------------------------------------------
-- 5. TEACHER SUBJECT COMPETENCY (what a teacher CAN teach)
-- Captured at onboarding; HOD uses it while allotting subjects.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teacher_subject_competency (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_username TEXT NOT NULL,     -- users.username / teacher_details.teacher_id
    subject_id TEXT NOT NULL,           -- subjects.subject_id
    subject_name TEXT,
    proficiency TEXT NOT NULL DEFAULT 'primary'
        CHECK (proficiency IN ('primary', 'secondary')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (teacher_username, subject_id)
);

COMMENT ON TABLE teacher_subject_competency IS 'Subjects a teacher is competent to teach (primary = core expertise, secondary = can also handle)';

-- ------------------------------------------------------------
-- 6. SUBJECT ALLOTMENTS (what a teacher IS teaching — HOD action)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subject_allotments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    teacher_username TEXT NOT NULL,     -- users.username / teacher_details.teacher_id
    subject_id TEXT NOT NULL,           -- subjects.subject_id
    subject_name TEXT,
    department TEXT,
    semester INT,
    section TEXT,
    academic_year TEXT,                 -- e.g. '2026-27'
    weekly_hours NUMERIC(5, 2) NOT NULL DEFAULT 4,
    allotted_by TEXT,                   -- HOD username
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (teacher_username, subject_id, semester, section, academic_year)
);

COMMENT ON TABLE subject_allotments IS 'HOD subject allotment per teacher / semester / section / academic year; weekly_hours feeds workload reports';

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_interview_rounds_application
    ON interview_rounds (application_id);
CREATE INDEX IF NOT EXISTS idx_interview_rounds_status
    ON interview_rounds (status);
CREATE INDEX IF NOT EXISTS idx_recruitment_events_application
    ON recruitment_events (application_id);
CREATE INDEX IF NOT EXISTS idx_recruitment_events_created
    ON recruitment_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_recruitment_events_posting
    ON recruitment_events (posting_id);
CREATE INDEX IF NOT EXISTS idx_offer_letters_status
    ON offer_letters (status);
CREATE INDEX IF NOT EXISTS idx_onboarding_status
    ON employee_onboarding (status);
CREATE INDEX IF NOT EXISTS idx_competency_teacher
    ON teacher_subject_competency (teacher_username);
CREATE INDEX IF NOT EXISTS idx_allotments_teacher
    ON subject_allotments (teacher_username);
CREATE INDEX IF NOT EXISTS idx_allotments_dept_sem
    ON subject_allotments (department, semester, academic_year);
CREATE INDEX IF NOT EXISTS idx_job_applications_current_stage
    ON job_applications (current_stage);

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY (permissive policies, same style as other modules)
-- ------------------------------------------------------------
ALTER TABLE interview_rounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE recruitment_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_letters ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_onboarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subject_competency ENABLE ROW LEVEL SECURITY;
ALTER TABLE subject_allotments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all for authenticated" ON interview_rounds;
CREATE POLICY "Allow all for authenticated" ON interview_rounds
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON interview_rounds;
CREATE POLICY "Allow all for anon" ON interview_rounds
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON recruitment_events;
CREATE POLICY "Allow all for authenticated" ON recruitment_events
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON recruitment_events;
CREATE POLICY "Allow all for anon" ON recruitment_events
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON offer_letters;
CREATE POLICY "Allow all for authenticated" ON offer_letters
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON offer_letters;
CREATE POLICY "Allow all for anon" ON offer_letters
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON employee_onboarding;
CREATE POLICY "Allow all for authenticated" ON employee_onboarding
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON employee_onboarding;
CREATE POLICY "Allow all for anon" ON employee_onboarding
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON teacher_subject_competency;
CREATE POLICY "Allow all for authenticated" ON teacher_subject_competency
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON teacher_subject_competency;
CREATE POLICY "Allow all for anon" ON teacher_subject_competency
    FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all for authenticated" ON subject_allotments;
CREATE POLICY "Allow all for authenticated" ON subject_allotments
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Allow all for anon" ON subject_allotments;
CREATE POLICY "Allow all for anon" ON subject_allotments
    FOR ALL TO anon USING (true) WITH CHECK (true);

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
