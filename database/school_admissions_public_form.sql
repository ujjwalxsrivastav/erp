-- ============================================================================
-- School Admissions — public application form support
-- ============================================================================
-- The public admission form (route `/admissions/school-apply`) collects basic
-- student/parent details plus a "referral" (who/where the applicant was
-- referred by). These columns extend the original 8-column table so the full
-- submission is persisted and visible in the admin Admissions Pipeline.
--
-- Safe to run more than once.
-- ============================================================================

ALTER TABLE school_admissions
  ADD COLUMN IF NOT EXISTS application_no TEXT,
  ADD COLUMN IF NOT EXISTS dob TEXT,
  ADD COLUMN IF NOT EXISTS gender TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS previous_school TEXT,
  ADD COLUMN IF NOT EXISTS referral TEXT,
  ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'public_form',
  ADD COLUMN IF NOT EXISTS counsellor_id UUID,
  ADD COLUMN IF NOT EXISTS counsellor_name TEXT,
  ADD COLUMN IF NOT EXISTS counsellor_assigned_at TIMESTAMPTZ,
  -- Workflow visibility for the counsellor desk: every admin action writes the
  -- display status here (the constrained `status` column stays pending/
  -- approved/rejected for compatibility).
  ADD COLUMN IF NOT EXISTS status_detail TEXT,
  ADD COLUMN IF NOT EXISTS doc_status TEXT DEFAULT 'Pending',
  ADD COLUMN IF NOT EXISTS documents JSONB,
  ADD COLUMN IF NOT EXISTS test_score INT,
  ADD COLUMN IF NOT EXISTS interview_notes TEXT,
  ADD COLUMN IF NOT EXISTS fee_demanded NUMERIC,
  ADD COLUMN IF NOT EXISTS offer_valid_till TEXT,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_school_admissions_created_at
  ON school_admissions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_school_admissions_status
  ON school_admissions (status);

CREATE INDEX IF NOT EXISTS idx_school_admissions_counsellor
  ON school_admissions (counsellor_id);

-- Public (anonymous) submissions must be able to insert rows. The original
-- setup script already disables RLS and grants anon access; this keeps the
-- migration safe for databases created before that.
ALTER TABLE school_admissions DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE school_admissions TO anon, authenticated, service_role;
