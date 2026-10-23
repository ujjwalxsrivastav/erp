-- ============================================================
-- 07: Student Admission Flow — Admission Applications
-- Module: Leads / Admissions (lead -> admission form -> review
--         -> enrolled student)
-- Run in Supabase SQL Editor. Idempotent — safe to re-run.
-- Depends on: leads table (supabase_lead_management_setup.sql).
-- The matching in-app flow lives in
--   lib/features/leads/services/admission_flow_service.dart
--   lib/features/leads/screens/admission_form_screen.dart
--   lib/features/leads/screens/admission_review_screen.dart
-- ============================================================

-- ------------------------------------------------------------
-- ADMISSION APPLICATIONS
-- One row per filled admission form. Optionally linked to a
-- lead (lead_id). On approval + enrolment the row is marked
-- 'enrolled' and enrolled_student_id stores the created
-- users.username / student_details.student_id.
--
-- Field coverage mirrors the user's HTML prototypes:
--   leaddemo.html            (enquiry / lead fields)
--   demo/admissionformdemo.html (full admission form fields)
-- Fields that have no dedicated column (Aadhaar number, parent
-- occupations, guardian email, separate 10th record, stream,
-- batch, hostel / transport requirement, registration-fee
-- payment) are preserved in extra_details (jsonb) so no data
-- captured by the form is lost.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admission_applications (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Link back to the originating lead (nullable: walk-ins can
    -- apply without a prior enquiry)
    lead_id             UUID REFERENCES leads(id) ON DELETE SET NULL,

    -- App-generated application number, e.g. ADM-2026-0001
    application_no      TEXT UNIQUE,

    -- Personal details
    student_name        TEXT NOT NULL,
    email               TEXT,
    phone               TEXT NOT NULL,
    alternate_phone     TEXT,
    date_of_birth       DATE,
    gender              TEXT,                       -- male | female | other
    address             TEXT,
    city                TEXT,
    state               TEXT,
    pincode             TEXT,

    -- Family details
    father_name         TEXT,
    father_phone        TEXT,
    mother_name         TEXT,
    guardian_name       TEXT,

    -- Category: General | OBC | SC | ST | EWS
    category            TEXT DEFAULT 'General',

    -- Academic details (highest qualification, e.g. 12th)
    qualification       TEXT,                       -- 10th | 12th | Graduate | Diploma
    board               TEXT,                       -- CBSE | ICSE | HPBOSE | State Board
    percentage          NUMERIC(5, 2),
    passing_year        INT,
    previous_school     TEXT,

    -- Course applied for
    course              TEXT,                       -- e.g. B.Tech, BCA, MBA
    department          TEXT,                       -- e.g. CSE, ECE, ME
    branch              TEXT,
    session             TEXT,                       -- e.g. '2026-27'
    semester            INT NOT NULL DEFAULT 1,
    section             TEXT,

    -- How this application came in: admission_form | walk-in |
    -- counsellor | referral ...
    source              TEXT,

    -- Documents received checklist, e.g.
    -- {"photo": true, "marksheet": true, "tc": false,
    --  "aadhaar": true, "caste_certificate": false}
    -- Values may be boolean (received) or a storage URL string.
    documents           JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Remaining prototype fields (aadhaar, occupations,
    -- guardian email, 10th record, stream, batch, facilities,
    -- registration-fee payment) — see header note.
    extra_details       JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Review workflow
    status              TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft', 'submitted', 'under_review',
                                          'documents_pending', 'approved',
                                          'rejected', 'enrolled')),
    reviewed_by         TEXT,                       -- users.username of reviewer
    review_remarks      TEXT,

    -- Set when the applicant is converted into a student
    enrolled_student_id TEXT,                       -- users.username after conversion

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE admission_applications IS 'Student admission applications: lead-linked admission forms with review workflow (submitted -> under_review -> documents_pending/approved/rejected -> enrolled).';
COMMENT ON COLUMN admission_applications.application_no IS 'App-generated application number in ADM-YYYY-#### format.';
COMMENT ON COLUMN admission_applications.documents IS 'Documents checklist jsonb: photo / marksheet / tc / aadhaar / caste_certificate -> bool (received) or storage URL.';
COMMENT ON COLUMN admission_applications.extra_details IS 'Prototype fields without dedicated columns: aadhaar, parent occupations, guardian email, 10th record, stream, batch, hostel/transport requirement, registration-fee payment.';
COMMENT ON COLUMN admission_applications.enrolled_student_id IS 'users.username / student_details.student_id created on conversion.';

-- ------------------------------------------------------------
-- INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_admission_applications_status
    ON admission_applications(status);
CREATE INDEX IF NOT EXISTS idx_admission_applications_lead
    ON admission_applications(lead_id);
CREATE INDEX IF NOT EXISTS idx_admission_applications_phone
    ON admission_applications(phone);
CREATE INDEX IF NOT EXISTS idx_admission_applications_created
    ON admission_applications(created_at DESC);

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY (repo-style permissive policies)
-- ------------------------------------------------------------
ALTER TABLE admission_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admission_applications_all" ON admission_applications;
CREATE POLICY "admission_applications_all" ON admission_applications
    FOR ALL USING (true) WITH CHECK (true);
