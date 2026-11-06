-- ============================================================================
-- SCHOOL EXAMINATION & MARKS MANAGEMENT
-- ============================================================================
-- Run this once in the Supabase SQL editor.  These tables back the admin
-- Examination Controller: exam cycles, class date sheets and room allocation.
-- Marks themselves remain in public.school_marks; per-paper locks are kept in
-- public.school_marks_locks (created by school_permissions_setup.sql).

BEGIN;

-- school_permission_service writes this field whenever an administrator locks
-- or unlocks an assessment.  Keep older installations compatible.
ALTER TABLE IF EXISTS public.school_marks_locks
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- Theory and internal-assessment components are stored separately while
-- marks_obtained remains the combined score used by existing report cards.
ALTER TABLE IF EXISTS public.school_marks
  ADD COLUMN IF NOT EXISTS theory_marks NUMERIC(6,2),
  ADD COLUMN IF NOT EXISTS internal_marks NUMERIC(6,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS public.school_exam_management_sessions (
  id                  TEXT PRIMARY KEY,
  institute_id        TEXT NOT NULL DEFAULT 'SHIV-SCH',
  title               TEXT NOT NULL,
  term                TEXT,
  academic_year       TEXT NOT NULL,
  status              TEXT NOT NULL DEFAULT 'Draft'
                        CHECK (status IN ('Draft', 'Scheduled', 'Ongoing', 'Evaluation', 'Published')),
  start_date          DATE NOT NULL,
  end_date            DATE NOT NULL,
  passing_percentage  NUMERIC(5,2) NOT NULL DEFAULT 33 CHECK (passing_percentage BETWEEN 0 AND 100),
  instructions        TEXT,
  is_published        BOOLEAN NOT NULL DEFAULT FALSE,
  created_by          TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS public.school_exam_schedule_papers (
  id                  TEXT PRIMARY KEY,
  session_id          TEXT NOT NULL REFERENCES public.school_exam_management_sessions(id) ON DELETE CASCADE,
  institute_id        TEXT NOT NULL DEFAULT 'SHIV-SCH',
  class_id            TEXT NOT NULL,
  class_name          TEXT,
  subject             TEXT NOT NULL,
  exam_date           DATE NOT NULL,
  day_name            TEXT,
  start_time          TEXT NOT NULL,
  end_time            TEXT NOT NULL,
  duration            TEXT,
  max_theory          NUMERIC(6,2) NOT NULL DEFAULT 80,
  max_practical       NUMERIC(6,2) NOT NULL DEFAULT 20,
  pass_marks          NUMERIC(6,2) NOT NULL DEFAULT 33,
  hall_name           TEXT,
  room_no             TEXT,
  invigilator         TEXT,
  status              TEXT NOT NULL DEFAULT 'Scheduled',
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.school_exam_rooms (
  id                    TEXT PRIMARY KEY,
  institute_id          TEXT NOT NULL DEFAULT 'SHIV-SCH',
  room_name             TEXT NOT NULL,
  block                 TEXT,
  capacity              INTEGER NOT NULL DEFAULT 0 CHECK (capacity >= 0),
  allocated_count       INTEGER NOT NULL DEFAULT 0 CHECK (allocated_count >= 0),
  allocated_classes     TEXT,
  chief_invigilator     TEXT,
  support_invigilator   TEXT,
  bench_type            TEXT,
  status                TEXT NOT NULL DEFAULT 'Ready',
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS school_exam_mgmt_sessions_school_idx
  ON public.school_exam_management_sessions (institute_id, start_date DESC);
CREATE INDEX IF NOT EXISTS school_exam_schedule_papers_session_class_idx
  ON public.school_exam_schedule_papers (session_id, class_id, exam_date);
CREATE INDEX IF NOT EXISTS school_exam_rooms_school_idx
  ON public.school_exam_rooms (institute_id, room_name);

CREATE OR REPLACE FUNCTION public.school_exam_management_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS school_exam_mgmt_sessions_touch ON public.school_exam_management_sessions;
CREATE TRIGGER school_exam_mgmt_sessions_touch
  BEFORE UPDATE ON public.school_exam_management_sessions
  FOR EACH ROW EXECUTE FUNCTION public.school_exam_management_touch_updated_at();
DROP TRIGGER IF EXISTS school_exam_schedule_papers_touch ON public.school_exam_schedule_papers;
CREATE TRIGGER school_exam_schedule_papers_touch
  BEFORE UPDATE ON public.school_exam_schedule_papers
  FOR EACH ROW EXECUTE FUNCTION public.school_exam_management_touch_updated_at();
DROP TRIGGER IF EXISTS school_exam_rooms_touch ON public.school_exam_rooms;
CREATE TRIGGER school_exam_rooms_touch
  BEFORE UPDATE ON public.school_exam_rooms
  FOR EACH ROW EXECUTE FUNCTION public.school_exam_management_touch_updated_at();

ALTER TABLE public.school_exam_management_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_exam_schedule_papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_exam_rooms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "School examination sessions access" ON public.school_exam_management_sessions;
CREATE POLICY "School examination sessions access" ON public.school_exam_management_sessions
  FOR ALL USING (institute_id = COALESCE(current_setting('app.current_institute_id', true), institute_id))
  WITH CHECK (institute_id = COALESCE(current_setting('app.current_institute_id', true), institute_id));
DROP POLICY IF EXISTS "School examination papers access" ON public.school_exam_schedule_papers;
CREATE POLICY "School examination papers access" ON public.school_exam_schedule_papers
  FOR ALL USING (institute_id = COALESCE(current_setting('app.current_institute_id', true), institute_id))
  WITH CHECK (institute_id = COALESCE(current_setting('app.current_institute_id', true), institute_id));
DROP POLICY IF EXISTS "School examination rooms access" ON public.school_exam_rooms;
CREATE POLICY "School examination rooms access" ON public.school_exam_rooms
  FOR ALL USING (institute_id = COALESCE(current_setting('app.current_institute_id', true), institute_id))
  WITH CHECK (institute_id = COALESCE(current_setting('app.current_institute_id', true), institute_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_exam_management_sessions TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_exam_schedule_papers TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_exam_rooms TO anon, authenticated;

COMMIT;
