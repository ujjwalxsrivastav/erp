-- ============================================================================
-- SCHOOL HOMEWORK SUBMISSIONS BACKEND
-- Run this in Supabase Dashboard -> SQL Editor.
--
-- Safe to re-run (idempotent). No demo/dummy data is inserted.
--
-- Purpose:
--   * school_homework          = what was assigned (per class)
--   * school_homework_submissions = WHO submitted WHAT and WHEN (per student)
--     One row per (homework, student). Re-submitting a submission updates it.
-- ============================================================================

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

CREATE INDEX IF NOT EXISTS idx_school_hw_submissions_homework
    ON public.school_homework_submissions (homework_id);

CREATE INDEX IF NOT EXISTS idx_school_hw_submissions_student
    ON public.school_homework_submissions (student_username);

-- ---------------------------------------------------------------------------
-- 2. Access (matches the dual-mode ERP policy: RLS disabled for the app)
-- ---------------------------------------------------------------------------
ALTER TABLE public.school_homework_submissions DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.school_homework_submissions
    TO anon, authenticated, service_role;

SELECT 'School homework submissions setup completed successfully!' AS result;
