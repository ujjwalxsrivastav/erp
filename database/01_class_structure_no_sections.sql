-- ============================================================================
-- SHIVALIK SCHOOL — CLASS STRUCTURE CLEANUP (NO SECTIONS)
-- Run this FIRST, in Supabase Dashboard -> SQL Editor.
-- Idempotent: safe to re-run.
--
-- What it does:
--   1. Makes `section` optional everywhere (droppable later; nothing breaks).
--   2. Merges duplicate class rows of the SAME class name + academic year
--      (e.g. 'Class 10' A + B) into ONE class row and re-points every table
--      that references the old class ids.
--   3. Enforces "only one class of a particular class":
--      UNIQUE (name, academic_year).
--   4. Enforces "only one class teacher of any particular class":
--      a teacher can be class teacher of at most ONE class in the school
--      (UNIQUE (class_teacher_id)); each class row carries exactly one
--      class_teacher_id.
--   5. Cleans display names: 'Class 10-A' -> 'Class 10' for students, and
--      section on class rows is cleared to NULL.
--
-- NOTE: streams like 'Class 11-Science' / 'Class 11-Commerce' also get merged
--       into a single 'Class 11'. Re-introduce streams later as separate
--       columns/groups — for now, per requirement, there are no sections.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Make `section` optional on every school table that has it
-- ---------------------------------------------------------------------------
DO $$
DECLARE t RECORD;
BEGIN
  FOR t IN
    SELECT c.table_name
    FROM information_schema.columns c
    JOIN information_schema.tables ts
      ON ts.table_schema = c.table_schema
     AND ts.table_name  = c.table_name
    WHERE c.table_schema = 'public'
      AND c.column_name = 'section'
      AND ts.table_type = 'BASE TABLE'
      AND c.table_name IN ('school_classes', 'school_students', 'school_homework',
                           'school_attendance', 'school_marks')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN section DROP NOT NULL', t.table_name);
    EXECUTE format('ALTER TABLE public.%I ALTER COLUMN section SET DEFAULT NULL', t.table_name);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2. Merge duplicate classes (same name + academic year) into one row
--    and re-point every class_id reference before deleting the duplicates.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    grp RECORD;
    canonical UUID;   -- matches school_classes.id (uuid) — fixes uuid <> text
    t RECORD;
BEGIN
  FOR grp IN
    SELECT name, COALESCE(academic_year, '') AS ay
    FROM public.school_classes
    GROUP BY name, COALESCE(academic_year, '')
    HAVING count(*) > 1
  LOOP
    -- Oldest row of the group is canonical; its id survives everywhere
    SELECT id INTO canonical
    FROM public.school_classes
    WHERE name = grp.name
      AND COALESCE(academic_year, '') = grp.ay
    ORDER BY created_at ASC NULLS LAST, id
    LIMIT 1;

    -- Re-point ANY school TABLE that has a class_id column.
    -- Views (e.g. class_timetable_view) are excluded: they are not updatable.
    -- Columns have mixed types (uuid vs text), so compare in each column's type.
    FOR t IN
      SELECT c.table_name, c.data_type
      FROM information_schema.columns c
      JOIN information_schema.tables ts
        ON ts.table_schema = c.table_schema
       AND ts.table_name  = c.table_name
      WHERE c.table_schema = 'public'
        AND c.column_name = 'class_id'
        AND ts.table_type = 'BASE TABLE'
        AND c.table_name <> 'school_classes'
    LOOP
      IF t.data_type = 'uuid' THEN
        EXECUTE format(
          'UPDATE public.%I SET class_id = %L::uuid WHERE class_id IN (
              SELECT id FROM public.school_classes
               WHERE name = %L AND COALESCE(academic_year, '''') = %L
                 AND id <> %L::uuid
          )',
          t.table_name, canonical, grp.name, grp.ay, canonical);
      ELSIF t.data_type IN ('text', 'character varying', 'character') THEN
        EXECUTE format(
          'UPDATE public.%I SET class_id = %L WHERE class_id IN (
              SELECT id::text FROM public.school_classes
               WHERE name = %L AND COALESCE(academic_year, '''') = %L
                 AND id <> %L::uuid
          )',
          t.table_name, canonical::text, grp.name, grp.ay, canonical);
      ELSE
        RAISE NOTICE 'Skipping table % (unsupported class_id type: %)',
          t.table_name, t.data_type;
      END IF;
    END LOOP;

    -- Drop the now-orphaned duplicate class rows
    DELETE FROM public.school_classes
    WHERE name = grp.name
      AND COALESCE(academic_year, '') = grp.ay
      AND id <> canonical;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 3. One class per name per academic year (no section dimension)
-- ---------------------------------------------------------------------------
DO $$
DECLARE c RECORD;
BEGIN
  FOR c IN
    SELECT conname, pg_get_constraintdef(oid) AS def
    FROM pg_constraint
    WHERE conrelid = 'public.school_classes'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) LIKE '%name%section%academic_year%'
  LOOP
    EXECUTE format('ALTER TABLE public.school_classes DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE public.school_classes
  DROP CONSTRAINT IF EXISTS school_classes_one_per_year;
ALTER TABLE public.school_classes
  ADD CONSTRAINT school_classes_one_per_year UNIQUE (name, academic_year);

-- ---------------------------------------------------------------------------
-- 4. Exactly one class teacher: each class row carries one class_teacher_id,
--    and the same teacher may not be class teacher of two classes.
-- ---------------------------------------------------------------------------
ALTER TABLE public.school_classes
  DROP CONSTRAINT IF EXISTS school_classes_single_class_teacher;
ALTER TABLE public.school_classes
  ADD CONSTRAINT school_classes_single_class_teacher UNIQUE (class_teacher_id);

-- Clear the section dimension on class rows and normalise student display names
UPDATE public.school_classes SET section = NULL WHERE section IS NOT NULL;

UPDATE public.school_students s
SET    class_name = c.name
FROM   public.school_classes c
WHERE  s.class_id::text = c.id::text
  AND  s.class_name IS DISTINCT FROM c.name;

-- ---------------------------------------------------------------------------
-- 5. Verification (run result should show: no duplicate class names, sections
--    all NULL, and constraint list containing the two new UNIQUE rules)
-- ---------------------------------------------------------------------------
SELECT name, section, academic_year, class_teacher_id
FROM   public.school_classes
ORDER  BY name;

SELECT conname
FROM   pg_constraint
WHERE  conrelid = 'public.school_classes'::regclass AND contype = 'u';

SELECT 'Class structure cleanup completed successfully!' AS result;
