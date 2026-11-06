-- ============================================================================
-- SCHOOL HOMEWORK SUBMISSIONS BACKEND
-- Run this in Supabase Dashboard -> SQL Editor.
--
-- Safe to re-run (idempotent). No demo/dummy data is inserted.
--
-- Purpose:
--   * school_homework            = what was assigned (per class)
--   * school_homework_submissions = WHO submitted WHAT and WHEN (per student)
--     One row per (homework, student). Re-submitting updates that row.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Submissions table — one row per student per homework item
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_homework_submissions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    homework_id     UUID NOT NULL REFERENCES public.school_homework(id) ON DELETE CASCADE,
    student_id      TEXT,                        -- school_students.id (best effort)
    student_username TEXT NOT NULL,              -- users.username (identity)
    student_name    TEXT,
    note            TEXT,
    attachment_url  TEXT,
    status          TEXT NOT NULL DEFAULT 'submitted'
                    CHECK (status IN ('submitted', 'returned', 'graded')),
    teacher_feedback TEXT,
    reviewed_at     TIMESTAMPTZ,
    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (homework_id, student_username)
);

-- ---------------------------------------------------------------------------
-- 2. HARDEN AN EXISTING TABLE
--    Older/partial runs may have created the table without every column or
--    without the unique pair. The app's upsert needs that unique pair; add the
--    missing pieces here so submissions cannot silently fail.
-- ---------------------------------------------------------------------------
ALTER TABLE public.school_homework_submissions
    ADD COLUMN IF NOT EXISTS student_id       TEXT,
    ADD COLUMN IF NOT EXISTS student_name     TEXT,
    ADD COLUMN IF NOT EXISTS note             TEXT,
    ADD COLUMN IF NOT EXISTS attachment_url   TEXT,
    ADD COLUMN IF NOT EXISTS status           TEXT DEFAULT 'submitted',
    ADD COLUMN IF NOT EXISTS teacher_feedback TEXT,
    ADD COLUMN IF NOT EXISTS reviewed_at      TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS submitted_at     TIMESTAMPTZ DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at       TIMESTAMPTZ DEFAULT now();

-- Collapse duplicates (keep the newest) before enforcing uniqueness.
DELETE FROM public.school_homework_submissions a
USING public.school_homework_submissions b
WHERE a.homework_id = b.homework_id
  AND a.student_username = b.student_username
  AND (a.submitted_at, a.id) < (b.submitted_at, b.id);

-- A unique INDEX satisfies PostgREST's ON CONFLICT (homework_id, student_username).
CREATE UNIQUE INDEX IF NOT EXISTS school_hw_submissions_homework_student_uidx
    ON public.school_homework_submissions (homework_id, student_username);

CREATE INDEX IF NOT EXISTS idx_school_hw_submissions_homework
    ON public.school_homework_submissions (homework_id);

CREATE INDEX IF NOT EXISTS idx_school_hw_submissions_student
    ON public.school_homework_submissions (student_username);

-- ---------------------------------------------------------------------------
-- 3. Access (matches the dual-mode ERP policy: RLS disabled for the app)
-- ---------------------------------------------------------------------------
ALTER TABLE public.school_homework_submissions DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.school_homework_submissions
    TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4. VERIFY — these two rows must be returned with constraint/index present
-- ---------------------------------------------------------------------------
SELECT indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'school_homework_submissions';

SELECT 'School homework submissions setup completed successfully!' AS result;

COMMIT;
