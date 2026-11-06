-- ============================================================================
-- MARKS COLUMN PATCH — fixes "column ... does not exist" when a teacher saves
-- exam / class-test marks.
--
-- Why: the app writes theory_marks + internal_marks + class_id to
-- public.school_marks, and updated_at / deadline / unlock_reason to
-- public.school_marks_locks. Those columns are added by
-- dual_mode_school_setup.sql, school_examination_management_setup.sql and
-- school_permissions_setup.sql, so a database that skipped any of them rejects
-- the save with PGRST204 ("Could not find the 'theory_marks' column ...").
--
-- Idempotent: safe to run any number of times.
-- Run in Supabase Dashboard -> SQL Editor, then reload the app.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.school_marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    student_name TEXT,
    class_name TEXT NOT NULL,
    section TEXT,
    subject TEXT NOT NULL,
    exam_type TEXT NOT NULL,
    marks_obtained NUMERIC NOT NULL DEFAULT 0,
    total_marks NUMERIC NOT NULL DEFAULT 100,
    grade TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_marks
    ADD COLUMN IF NOT EXISTS class_id       TEXT,
    ADD COLUMN IF NOT EXISTS theory_marks   NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS internal_marks NUMERIC(6,2) DEFAULT 0,
    ADD COLUMN IF NOT EXISTS remarks        TEXT,
    ADD COLUMN IF NOT EXISTS created_at     TIMESTAMPTZ DEFAULT now();

-- Older tables created `section NOT NULL`; inserts without a section used to
-- fail on that constraint. The app treats sections as optional.
ALTER TABLE public.school_marks ALTER COLUMN section DROP NOT NULL;

CREATE TABLE IF NOT EXISTS public.school_marks_locks (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    exam_id TEXT NOT NULL,
    class_id TEXT NOT NULL,
    subject TEXT NOT NULL DEFAULT 'All',
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    locked_by TEXT,
    unlocked_at TIMESTAMPTZ,
    unlocked_by TEXT,
    unlock_reason TEXT,
    deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.school_marks_locks
    ADD COLUMN IF NOT EXISTS updated_at    TIMESTAMPTZ DEFAULT now(),
    ADD COLUMN IF NOT EXISTS deadline      TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS unlock_reason TEXT,
    ADD COLUMN IF NOT EXISTS unlocked_at   TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS unlocked_by   TEXT;

-- The upsert on (student_id, subject, exam_type) needs this unique index;
-- without it every save falls back to slower per-row writes.
UPDATE public.school_marks m
SET student_name = s.name
FROM public.school_students s
WHERE m.student_id = s.username
  AND (m.student_name IS NULL OR m.student_name <> s.name);

DELETE FROM public.school_marks a
USING public.school_marks b
WHERE a.student_id = b.student_id
  AND a.subject = b.subject
  AND a.exam_type = b.exam_type
  AND (a.created_at, a.id) < (b.created_at, b.id);

CREATE UNIQUE INDEX IF NOT EXISTS school_marks_student_subject_exam_uidx
    ON public.school_marks (student_id, subject, exam_type);

ALTER TABLE public.school_marks DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_marks_locks DISABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_marks TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_marks_locks TO anon, authenticated;

COMMIT;

-- Verification: should list class_id, theory_marks, internal_marks.
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'school_marks'
-- ORDER BY ordinal_position;

-- PostgREST caches the schema; after running this, press Refresh on the API
-- settings page (or wait ~1 minute) so Supabase picks up the new columns.
