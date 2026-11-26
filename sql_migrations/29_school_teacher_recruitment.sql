-- ============================================================================
-- SCHOOL TEACHER RECRUITMENT — vacancy forms, applications, documents,
-- document verification and interviews.
--
-- This module is intentionally SCHOOL-ONLY. It does not touch the college
-- `job_postings` / `job_applications` tables, so existing college recruitment
-- keeps working exactly as before.
--
-- Idempotent: safe to run multiple times.
-- Run in Supabase Dashboard > SQL Editor.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. BASE QUESTION TEMPLATES (admin-editable master list)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_vacancy_question_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_key TEXT UNIQUE,
    question_text TEXT NOT NULL,
    question_type TEXT NOT NULL DEFAULT 'short_answer'
        CHECK (question_type IN (
            'short_answer', 'paragraph', 'number', 'date',
            'multiple_choice', 'checkboxes', 'dropdown',
            'yes_no', 'file_upload'
        )),
    options JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_required BOOLEAN NOT NULL DEFAULT true,
    help_text TEXT,
    sort_order INT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE school_vacancy_question_templates IS
    'Master list of base application questions. Admin can edit, reorder, disable or add new ones.';
COMMENT ON COLUMN school_vacancy_question_templates.options IS
    'JSONB array of option strings for choice-type questions.';

-- ----------------------------------------------------------------------------
-- 2. VACANCIES (the published Google-Forms-style vacancy form)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_vacancies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    department TEXT,
    post_type TEXT NOT NULL DEFAULT 'permanent'
        CHECK (post_type IN ('permanent', 'contract', 'adjunct', 'visiting')),
    vacancies INT NOT NULL DEFAULT 1,
    eligibility TEXT,
    description TEXT,
    closing_date DATE,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'published', 'closed')),
    -- Frozen snapshot of the questions used by this form, so later template
    -- edits never change an application that was already submitted.
    form_schema JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- [{"key":"resume","label":"Resume / CV","required":true}, ...]
    required_documents JSONB NOT NULL DEFAULT '[]'::jsonb,
    share_slug TEXT UNIQUE,
    created_by TEXT,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE school_vacancies IS
    'School-only teacher vacancy plus its form definition.';
COMMENT ON COLUMN school_vacancies.form_schema IS
    'JSONB array of {key,label,type,required,options,help_text} questions snapshot.';
COMMENT ON COLUMN school_vacancies.required_documents IS
    'JSONB array of {key,label,required} documents the applicant must upload.';

-- ----------------------------------------------------------------------------
-- 3. APPLICATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_vacancy_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vacancy_id UUID NOT NULL REFERENCES school_vacancies(id) ON DELETE CASCADE,
    applicant_username TEXT,
    applicant_name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    qualification TEXT,
    experience_years NUMERIC(5, 2) DEFAULT 0,
    answers JSONB NOT NULL DEFAULT '{}'::jsonb,
    resume_url TEXT,
    status TEXT NOT NULL DEFAULT 'applied'
        CHECK (status IN (
            'applied', 'documents_pending', 'documents_verified',
            'interview_scheduled', 'interview_completed',
            'selected', 'rejected', 'enrolled'
        )),
    document_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (document_status IN ('pending', 'verified', 'rejected')),
    interview_status TEXT NOT NULL DEFAULT 'not_scheduled'
        CHECK (interview_status IN ('not_scheduled', 'scheduled', 'completed', 'cancelled')),
    rejection_reason TEXT,
    -- Filled in later when the selected candidate is enrolled.
    enrolled_at TIMESTAMPTZ,
    employee_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (vacancy_id, applicant_username)
);

COMMENT ON TABLE school_vacancy_applications IS
    'Teacher applications submitted against a school vacancy form.';
COMMENT ON COLUMN school_vacancy_applications.answers IS
    'JSONB map of question key -> answer value.';
COMMENT ON COLUMN school_vacancy_applications.status IS
    'Pipeline: applied -> documents_pending -> documents_verified -> interview_scheduled -> interview_completed -> selected -> enrolled; or rejected.';

-- A public/anonymous applicant has no username, so the unique constraint above
-- would treat them as NULL (allowed multiple times). Add a stable public token.
ALTER TABLE school_vacancy_applications
    ADD COLUMN IF NOT EXISTS applicant_token TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_school_vacancy_applications_token
    ON school_vacancy_applications (vacancy_id, applicant_token)
    WHERE applicant_token IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 4. APPLICANT DOCUMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_vacancy_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES school_vacancy_applications(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_label TEXT,
    file_name TEXT,
    file_url TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'verified', 'rejected')),
    remarks TEXT,
    verified_by TEXT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE school_vacancy_documents IS
    'Documents uploaded by an applicant, verified one-by-one by an administrator.';

-- ----------------------------------------------------------------------------
-- 5. INTERVIEWS (separate board)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_vacancy_interviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID NOT NULL REFERENCES school_vacancy_applications(id) ON DELETE CASCADE,
    scheduled_at TIMESTAMPTZ NOT NULL,
    mode TEXT NOT NULL DEFAULT 'in_person'
        CHECK (mode IN ('in_person', 'video', 'phone')),
    venue TEXT,
    meeting_link TEXT,
    panel_members JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'completed', 'cancelled', 'rescheduled', 'no_show')),
    marks NUMERIC(6, 2),
    feedback TEXT,
    recommendation TEXT
        CHECK (recommendation IN ('strong_yes', 'yes', 'no', 'strong_no')),
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE school_vacancy_interviews IS
    'Interview rounds for school teacher applicants, shown in a dedicated admin interview board.';

-- ----------------------------------------------------------------------------
-- 6. INDEXES
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_school_vacancies_status
    ON school_vacancies (status);
CREATE INDEX IF NOT EXISTS idx_school_vacancies_created
    ON school_vacancies (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_apps_vacancy
    ON school_vacancy_applications (vacancy_id);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_apps_status
    ON school_vacancy_applications (status);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_apps_username
    ON school_vacancy_applications (applicant_username);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_docs_application
    ON school_vacancy_documents (application_id);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_interviews_application
    ON school_vacancy_interviews (application_id);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_interviews_status
    ON school_vacancy_interviews (status);
CREATE INDEX IF NOT EXISTS idx_school_vacancy_interviews_scheduled
    ON school_vacancy_interviews (scheduled_at);

-- ----------------------------------------------------------------------------
-- 7. ROW LEVEL SECURITY
-- Permissive policies follow the existing ERP convention. The app still
-- enforces admin-only writes in the service layer.
-- ----------------------------------------------------------------------------
ALTER TABLE school_vacancy_question_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_vacancies ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_vacancy_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_vacancy_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_vacancy_interviews ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'school_vacancy_question_templates',
        'school_vacancies',
        'school_vacancy_applications',
        'school_vacancy_documents',
        'school_vacancy_interviews'
    ]
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS "Allow all for authenticated" ON %I', t);
        EXECUTE format(
            'CREATE POLICY "Allow all for authenticated" ON %I FOR ALL TO authenticated USING (true) WITH CHECK (true)',
            t
        );
        EXECUTE format('DROP POLICY IF EXISTS "Allow all for anon" ON %I', t);
        EXECUTE format(
            'CREATE POLICY "Allow all for anon" ON %I FOR ALL TO anon USING (true) WITH CHECK (true)',
            t
        );
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 8. STORAGE BUCKET FOR APPLICANT DOCUMENTS
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'school-vacancy-documents',
    'school-vacancy-documents',
    true,
    10485760, -- 10 MB
    NULL
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = NULL;

DROP POLICY IF EXISTS "school_vacancy_docs_insert" ON storage.objects;
CREATE POLICY "school_vacancy_docs_insert" ON storage.objects
    FOR INSERT TO anon, authenticated
    WITH CHECK (bucket_id = 'school-vacancy-documents');

DROP POLICY IF EXISTS "school_vacancy_docs_select" ON storage.objects;
CREATE POLICY "school_vacancy_docs_select" ON storage.objects
    FOR SELECT TO anon, authenticated
    USING (bucket_id = 'school-vacancy-documents');

DROP POLICY IF EXISTS "school_vacancy_docs_update" ON storage.objects;
CREATE POLICY "school_vacancy_docs_update" ON storage.objects
    FOR UPDATE TO anon, authenticated
    USING (bucket_id = 'school-vacancy-documents');

-- ----------------------------------------------------------------------------
-- 9. SEED BASE QUESTIONS
-- Existing rows are left untouched so admin edits survive re-running this file.
-- ----------------------------------------------------------------------------
INSERT INTO school_vacancy_question_templates
    (template_key, question_text, question_type, options, is_required, help_text, sort_order)
VALUES
    ('full_name', 'Full name', 'short_answer', '[]'::jsonb, true, NULL, 10),
    ('email', 'Email address', 'short_answer', '[]'::jsonb, true, NULL, 20),
    ('phone', 'Phone number', 'short_answer', '[]'::jsonb, true, NULL, 30),
    ('qualification', 'Highest qualification', 'short_answer', '[]'::jsonb, true, 'e.g. M.Sc., B.Ed., Ph.D.', 40),
    ('experience_years', 'Total teaching experience (years)', 'number', '[]'::jsonb, true, NULL, 50),
    ('subjects', 'Subjects you can teach', 'short_answer', '[]'::jsonb, true, 'Separate multiple subjects with commas', 60),
    ('current_employer', 'Current employer / school', 'short_answer', '[]'::jsonb, false, NULL, 70),
    ('why_join', 'Why do you want to join this school?', 'paragraph', '[]'::jsonb, false, NULL, 80),
    ('resume', 'Resume / CV', 'file_upload', '[]'::jsonb, true, 'PDF preferred', 90)
ON CONFLICT (template_key) DO NOTHING;
