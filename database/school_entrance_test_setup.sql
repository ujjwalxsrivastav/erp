-- ============================================================================
-- School Admissions — Entrance Test Builder + Candidate Portal
-- ============================================================================
-- Extends the entrance examination stage with:
--
--   * admin-authored class tests (one page per subject, Google-Form style)
--   * candidate credentials (enrollment number + ddmmyy password)
--   * a public candidate portal that opens the test for the candidate's class
--
-- Flow:
--   Admin creates a test for a class → issues an enrollment number/password to
--   an applicant → the candidate signs in at /entrance-test → answers each
--   subject page → the result is scored and written back to school_admissions.
--
-- Safe to run more than once.
-- ============================================================================

-- 1. Test headers ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_entrance_tests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_name TEXT NOT NULL,
  title TEXT NOT NULL,
  duration_minutes INT NOT NULL DEFAULT 90,
  status TEXT NOT NULL DEFAULT 'published',   -- draft | published | archived
  instructions TEXT,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_entrance_tests_class
  ON school_entrance_tests (class_name);

-- 2. Questions (each subject is rendered on its own page) --------------------
CREATE TABLE IF NOT EXISTS school_entrance_test_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  test_id UUID NOT NULL REFERENCES school_entrance_tests (id) ON DELETE CASCADE,
  subject TEXT NOT NULL,
  question_text TEXT NOT NULL,
  options JSONB NOT NULL DEFAULT '[]'::jsonb,
  correct_answer TEXT,
  marks INT NOT NULL DEFAULT 10,
  order_index INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_entrance_questions_test
  ON school_entrance_test_questions (test_id);
CREATE INDEX IF NOT EXISTS idx_entrance_questions_subject
  ON school_entrance_test_questions (test_id, subject);

-- 3. Candidate credentials + attempt state -----------------------------------
CREATE TABLE IF NOT EXISTS school_entrance_candidates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admission_id UUID,
  enrollment_no TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,                     -- ddmmyy, shared by the admin desk
  class_name TEXT NOT NULL,
  test_id UUID,
  candidate_name TEXT,
  parent_name TEXT,
  status TEXT NOT NULL DEFAULT 'issued',      -- issued | in_progress | submitted
  total_score NUMERIC,
  max_score NUMERIC,
  percentage NUMERIC,
  grade TEXT,
  subject_scores JSONB NOT NULL DEFAULT '[]'::jsonb,
  answers JSONB NOT NULL DEFAULT '{}'::jsonb,
  issued_by TEXT,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_entrance_candidates_admission
  ON school_entrance_candidates (admission_id);
CREATE INDEX IF NOT EXISTS idx_entrance_candidates_enrollment
  ON school_entrance_candidates (enrollment_no);

-- 4. Denormalised enrollment number on the admission row ---------------------
ALTER TABLE school_admissions
  ADD COLUMN IF NOT EXISTS entrance_enrollment_no TEXT;

-- 5. Permissive access consistent with the rest of the school modules --------
ALTER TABLE school_entrance_tests DISABLE ROW LEVEL SECURITY;
ALTER TABLE school_entrance_test_questions DISABLE ROW LEVEL SECURITY;
ALTER TABLE school_entrance_candidates DISABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE school_entrance_tests TO anon, authenticated, service_role;
GRANT ALL ON TABLE school_entrance_test_questions TO anon, authenticated, service_role;
GRANT ALL ON TABLE school_entrance_candidates TO anon, authenticated, service_role;

-- 6. Verification helpers ----------------------------------------------------
-- SELECT t.class_name, t.title, count(q.id) AS questions
-- FROM school_entrance_tests t
-- LEFT JOIN school_entrance_test_questions q ON q.test_id = t.id
-- GROUP BY t.id ORDER BY t.class_name, t.title;
--
-- SELECT enrollment_no, password, candidate_name, class_name, status
-- FROM school_entrance_candidates ORDER BY issued_at DESC;
