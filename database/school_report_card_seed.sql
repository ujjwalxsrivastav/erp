-- ============================================================================
-- SHIVALIK SCHOOL — REPORT CARD SEED DATA
-- Run AFTER database/01_class_structure_no_sections.sql and
--          database/02_school_seed_test_data.sql (uses the Class 10 roster).
--
-- Idempotent: safe to re-run.
--
--   * school_exam_sessions      : the exam sessions a report card can be
--                                 produced for (Half Yearly, Final).
--   * school_report_card_meta   : per-student / per-exam teacher remark and
--                                 promotion verdict (admin editable).
--   * school_co_scholastic      : 3-point (A/B/C) co-scholastic grades.
--   * unique (student_id, subject, exam_type) on school_marks so the app's
--     upsert never duplicates rows.
--   * school_marks              : Half Yearly + Final marks for EVERY student
--                                 in school_students (deterministic, stable).
--   * school_attendance         : period attendance so the analytics section
--                                 has real data for the current session.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. EXAM SESSIONS — card order defines display order in the app
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_exam_sessions (
  id           BIGSERIAL PRIMARY KEY,
  code         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  academic_year TEXT NOT NULL DEFAULT '2026-2027',
  display_order INT NOT NULL DEFAULT 0,
  is_published BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.school_exam_sessions (code, name, academic_year, display_order)
VALUES
  ('half_yearly', 'Half Yearly', '2026-2027', 1),
  ('final',       'Final',       '2026-2027', 2)
ON CONFLICT (code) DO UPDATE
  SET name = EXCLUDED.name,
      academic_year = EXCLUDED.academic_year,
      display_order = EXCLUDED.display_order;

-- ---------------------------------------------------------------------------
-- 2. REPORT CARD META — remark + verdict written by the admin per session
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_report_card_meta (
  student_id    TEXT NOT NULL,
  exam_type     TEXT NOT NULL,
  academic_year TEXT NOT NULL DEFAULT '2026-2027',
  teacher_remark TEXT,
  promotion_verdict TEXT,
  updated_by    TEXT,
  updated_at    TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (student_id, exam_type, academic_year)
);

-- ---------------------------------------------------------------------------
-- 3. CO-SCHOLASTIC GRADES — 3-point scale per report card session
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_co_scholastic (
  student_id    TEXT NOT NULL,
  exam_type     TEXT NOT NULL,
  area          TEXT NOT NULL,
  grade         TEXT NOT NULL CHECK (grade IN ('A', 'B', 'C')),
  descriptor    TEXT,
  created_at    TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (student_id, exam_type, area)
);

-- ---------------------------------------------------------------------------
-- 4. OPEN UP THE NEW TABLES FOR THE APP/ANON KEY (RLS off, like other
--    school_* tables; write access is enforced in the app by role)
-- ---------------------------------------------------------------------------
ALTER TABLE IF EXISTS public.school_exam_sessions    DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.school_report_card_meta DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.school_co_scholastic    DISABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_exam_sessions    TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_report_card_meta TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.school_co_scholastic    TO anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.school_exam_sessions_id_seq TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. UNIQUE (student_id, subject, exam_type) — makes the app's upsert safe
-- ---------------------------------------------------------------------------
UPDATE public.school_marks m
SET student_name = s.name
FROM public.school_students s
WHERE m.student_id = s.username
  AND (m.student_name IS NULL OR m.student_name <> s.name);

-- Collapse pre-existing duplicates (keep the newest row) before adding the index.
DELETE FROM public.school_marks a
USING public.school_marks b
WHERE a.student_id = b.student_id
  AND a.subject = b.subject
  AND a.exam_type = b.exam_type
  AND (a.created_at, a.id) < (b.created_at, b.id);

CREATE UNIQUE INDEX IF NOT EXISTS school_marks_student_subject_exam_uidx
  ON public.school_marks (student_id, subject, exam_type);

-- ---------------------------------------------------------------------------
-- 6. SUBJECTS — if 02_school_seed_test_data.sql was not run, make sure the
--    Class 10 subject list exists so the marks below have something to join.
-- ---------------------------------------------------------------------------
INSERT INTO public.school_subjects (id, class_id, name, code)
SELECT 'sub-10-' || lower(replace(v.name, ' ', '')),
       c.id::text, v.name, v.code
FROM public.school_classes c
CROSS JOIN (VALUES
  ('Mathematics',        'MATH10'),
  ('Science',            'SCI10'),
  ('English',            'ENG10'),
  ('Hindi',              'HIN10'),
  ('Social Studies',     'SST10'),
  ('Computer Science',   'CS10')
) AS v(name, code)
WHERE c.name = 'Class 10'
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. MARKS — Half Yearly + Final for every student.
--    Deterministic offsets keyed on md5(name || subject || exam) so the data
--    looks varied but never changes between re-runs; Final ~4 points better
--    than Half Yearly to make the analytics trend meaningful.
--
--    Students are split into three bands keyed on their username so every
--    re-seed always contains learners the support radar can flag:
--      bucket 0 (~10%)  : 14–31 per subject  -> overall below 33% (critical)
--      bucket 1 (~10%)  : 34–48 per subject  -> overall 33–49%  (watchlist)
--      bucket 2 (rest)  : 30–97 per subject  -> normal spread
-- ---------------------------------------------------------------------------
WITH subjects AS (
  SELECT name FROM public.school_subjects WHERE class_id IN (
    SELECT id::text FROM public.school_classes WHERE name = 'Class 10'
  )
),
roster AS (
  SELECT username, name, class_id, class_name,
         (('x' || substr(md5('band-' || username), 1, 6))::bit(24)::int % 10) AS band
  FROM public.school_students
  WHERE class_name = 'Class 10'
),
base AS (
  SELECT r.username, r.name, r.class_id, r.class_name, sub.name AS subject,
         r.band,
         ('x' || substr(md5('hpc-' || r.username || '-' || sub.name), 1, 6))::bit(24)::int AS h
  FROM roster r
  CROSS JOIN subjects sub
)
INSERT INTO public.school_marks
  (student_id, student_name, class_id, class_name, section, subject, exam_type,
   marks_obtained, total_marks, grade, remarks)
SELECT
  username, name, class_id, class_name, NULL, subject, x.exam_type,
  x.obtained, 100,
  CASE
    WHEN x.obtained >= 91 THEN 'A1'
    WHEN x.obtained >= 81 THEN 'A2'
    WHEN x.obtained >= 71 THEN 'B1'
    WHEN x.obtained >= 61 THEN 'B2'
    WHEN x.obtained >= 51 THEN 'C1'
    WHEN x.obtained >= 41 THEN 'C2'
    WHEN x.obtained >= 33 THEN 'D'
    WHEN x.obtained >= 21 THEN 'E1'
    ELSE 'E2'
  END,
  x.exam_type || ' — seeded report card data'
FROM base b
CROSS JOIN LATERAL (
  (SELECT 'Half Yearly'::text AS exam_type,
     (CASE b.band
        WHEN 0 THEN 14 + (b.h % 18)   -- 14–31  critical
        WHEN 1 THEN 34 + (b.h % 15)   -- 34–48  watchlist
        ELSE 30 + (b.h % 68)          -- 30–97  normal
      END)::int AS obtained)
  UNION ALL
  (SELECT 'Final'::text,
     (CASE b.band
        WHEN 0 THEN 16 + (b.h % 17)
        WHEN 1 THEN 35 + (b.h % 14)
        ELSE LEAST(99, 36 + (b.h % 64))
      END)::int)
) x
-- Re-running refreshes the seeded rows so the weak-student bands take effect,
-- but never overwrites marks a teacher typed in the app.
ON CONFLICT (student_id, subject, exam_type) DO UPDATE
  SET marks_obtained = EXCLUDED.marks_obtained,
      total_marks    = EXCLUDED.total_marks,
      grade          = EXCLUDED.grade
  WHERE school_marks.remarks LIKE '%seeded report card data%';

-- ---------------------------------------------------------------------------
-- 8. CO-SCHOLASTIC — 4 areas, grade derived from the student's final %
-- ---------------------------------------------------------------------------
WITH areas(slot, area, hi_desc, lo_desc) AS (
  VALUES
    (1, 'Work Education (ICT / Pre-Vocational)',
        'Exceptional problem-solving in digital simulations',
        'Needs guided practice with digital tools'),
    (2, 'Art Education (Visual & Performing)',
        'High creative expression and aesthetic appreciation',
        'Developing creative confidence'),
    (3, 'Health & Physical Education (Sports)',
        'Exemplary teamwork, stamina, and track participation',
        'Regular participation, needs more stamina building'),
    (4, 'Discipline & Value Inculcation',
        'Exemplary code of conduct, punctuality, and peer support',
        'Improving punctuality and classroom conduct')
),
pct AS (
  SELECT student_id, exam_type, sum(marks_obtained) * 100.0 / NULLIF(sum(total_marks), 0) AS p
  FROM public.school_marks
  WHERE exam_type IN ('Half Yearly', 'Final')
  GROUP BY student_id, exam_type
)
INSERT INTO public.school_co_scholastic (student_id, exam_type, area, grade, descriptor)
SELECT p.student_id, p.exam_type, a.area,
       CASE WHEN p.p >= 80 THEN 'A' WHEN p.p >= 55 THEN 'B' ELSE 'C' END,
       CASE WHEN p.p >= 80 THEN a.hi_desc ELSE a.lo_desc END
FROM pct p
CROSS JOIN areas a
ON CONFLICT (student_id, exam_type, area) DO UPDATE
  SET grade = EXCLUDED.grade,
      descriptor = EXCLUDED.descriptor;

-- ---------------------------------------------------------------------------
-- 9. META — default remark + verdict per session (admin can override in app)
-- ---------------------------------------------------------------------------
WITH pct AS (
  SELECT student_id, exam_type, sum(marks_obtained) * 100.0 / NULLIF(sum(total_marks), 0) AS p
  FROM public.school_marks
  WHERE exam_type IN ('Half Yearly', 'Final')
  GROUP BY student_id, exam_type
)
INSERT INTO public.school_report_card_meta
  (student_id, exam_type, academic_year, teacher_remark, promotion_verdict, updated_by)
SELECT p.student_id, p.exam_type, '2026-2027',
       CASE
         WHEN p.p >= 90 THEN 'Outstanding academic consistency and high intellectual curiosity. Exemplary student.'
         WHEN p.p >= 80 THEN 'Very good performance. Deep understanding of core subjects and high diligence.'
         WHEN p.p >= 70 THEN 'Good progress shown. Capable of scoring higher with structured practice.'
         WHEN p.p >= 50 THEN 'Satisfactory. Regular revision and problem-solving practice recommended.'
         ELSE 'Needs substantial improvement and dedicated parent-teacher counselling support.'
       END,
       CASE
         WHEN p.p >= 33 AND p.exam_type = 'Final' THEN 'PROMOTED TO CLASS 11 (Session 2027-2028)'
         WHEN p.p >= 33 THEN 'ELIGIBLE FOR CLASS 11 (Subject to Final Examination)'
         ELSE 'ACADEMIC RETENTION / REMEDIAL REQUIRED (Score below qualifying threshold)'
       END,
       'seed'
FROM pct p
ON CONFLICT (student_id, exam_type, academic_year) DO UPDATE
  SET teacher_remark    = EXCLUDED.teacher_remark,
      promotion_verdict = EXCLUDED.promotion_verdict
  WHERE school_report_card_meta.updated_by = 'seed';

-- ---------------------------------------------------------------------------
-- 10. ATTENDANCE — last 45 days so the analytics card has real data
-- ---------------------------------------------------------------------------
INSERT INTO public.school_attendance
  (student_id, student_name, class_name, section, class_id, date, status, marked_by)
SELECT s.username, s.name, s.class_name, NULL, s.class_id, d::date,
       CASE
         WHEN ('x' || substr(md5('att-' || s.username || d::date::text), 1, 4))::bit(16)::int % 12 = 0
           THEN 'absent'
         ELSE 'present'
       END,
       'steach01'
FROM public.school_students s
CROSS JOIN generate_series(CURRENT_DATE - INTERVAL '45 day', CURRENT_DATE - INTERVAL '1 day', INTERVAL '1 day') d
WHERE extract(isodow FROM d) < 6
  AND s.class_name = 'Class 10'
ON CONFLICT (student_id, date) DO NOTHING;

COMMIT;
