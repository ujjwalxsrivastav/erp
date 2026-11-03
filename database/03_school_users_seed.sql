-- ============================================================================
-- SHIVALIK SCHOOL — LOGIN ACCOUNTS RESET + SEED (users / parents / admin)
--
-- Run AFTER database/02_school_seed_test_data.sql
--
-- Makes the school's login accounts exactly match the seeded Class 10 data so
-- Admin → Manage Users shows every student, teacher and the school admin with
-- live, correct role counts.
--
-- What it does (single transaction — all or nothing):
--   0. Runs users_institution_setup.sql logic (users.institution column,
--      secure_add_user_v2). The role constraint is only added when no account
--      still uses a college-only role (hr / hod / staff).
--   1. DROPS every existing SCHOOL login account — students, teachers,
--      parents, deans, counsellors, temp students, wardens, conductors,
--      accountants, librarians. College accounts and admin accounts are kept.
--   2. Drops the school profile rows those accounts owned (school_students,
--      school_teachers, teacher_details, staff) and account-owned rows in
--      school_timetable / school_fee_payments / school_attendance /
--      parent_student_links, so no orphans survive the reset.
--   3. Re-creates from 02_school_seed_test_data.sql:
--        50 students  s10s01 .. s10s50     (school_students rows, Class 10)
--        22 teachers  steach01 .. steach22 (school_teachers + teacher_details)
--        1 admin      shiv_admin          (school principal)
--        parents      one per student, named parent_<parent name>
--                     (e.g. parent_rajesh_sharma), linked to the child
--   4. Links everything: users.institution = 'school',
--      users.institute_type = 'school', Class 10 class teacher = steach01.
--      Login routing reads users.institution, so the admin lands on the
--      school dashboard. Manage Users (School tab) then lists every account
--      above with its name and live per-role counts.
--
-- Every account's password is its own username (demo logins).
-- Re-runnable: each run resets the school accounts to this exact state.
--
-- NOTE: ids printed in the output below are the ones you can paste into
-- Supabase's "Delete rows" confirmation when deleting the school users
-- through the dashboard.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Institution column + role constraint (mirrors users_institution_setup.sql)
-- ---------------------------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS institution TEXT NOT NULL DEFAULT 'college';

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_institution_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_institution_check
  CHECK (institution IN ('school', 'college'));

CREATE INDEX IF NOT EXISTS users_institution_role_idx
  ON public.users (institution, role);

DO $$
BEGIN
  IF to_regprocedure('public.hash_password(text)') IS NULL THEN
    RAISE EXCEPTION 'public.hash_password(text) is missing — run '
      'database_export/security/01_security_foundation.sql first.';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.users
    WHERE role NOT IN (
      'student', 'teacher', 'admin', 'parent', 'dean', 'admissiondean',
      'counsellor', 'temp_student', 'warden', 'conductor',
      'transport_officer', 'accountant', 'librarian'
    )
  ) THEN
    RAISE NOTICE 'users_role_check left unchanged: some accounts still use '
      'college-only roles (hr / hod / staff). Run users_institution_setup.sql '
      'once those are removed to fully tighten it.';
  ELSE
    ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
    ALTER TABLE public.users
      ADD CONSTRAINT users_role_check
      CHECK (role IN (
        'student', 'teacher', 'admin', 'parent', 'dean', 'admissiondean',
        'counsellor', 'temp_student', 'warden', 'conductor',
        'transport_officer', 'accountant', 'librarian'
      ));
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.secure_add_user_v2(
  p_username TEXT,
  p_password TEXT,
  p_role TEXT,
  p_created_by TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_hashed_password TEXT;
  v_clean_username TEXT;
  v_valid_roles TEXT[] := ARRAY['student', 'teacher', 'admin'];
BEGIN
  IF p_username IS NULL OR TRIM(p_username) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Username is required');
  END IF;
  IF p_password IS NULL OR TRIM(p_password) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Password is required');
  END IF;
  IF LENGTH(p_password) < 6 THEN
    RETURN json_build_object('success', false, 'message', 'Password must be at least 6 characters');
  END IF;
  IF p_role IS NULL OR NOT (p_role = ANY(v_valid_roles)) THEN
    RETURN json_build_object('success', false, 'message', 'Unsupported role: ' || COALESCE(p_role, ''));
  END IF;

  v_clean_username := LOWER(TRIM(p_username));
  IF v_clean_username !~ '^[a-z0-9_]+$' THEN
    RETURN json_build_object('success', false, 'message', 'Username can only contain letters, numbers, and underscores');
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE username = v_clean_username) THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  END IF;

  v_hashed_password := public.hash_password(p_password);

  INSERT INTO public.users (username, password, role, institution)
  VALUES (
    v_clean_username,
    v_hashed_password,
    p_role,
    CASE WHEN p_role = 'admin' THEN 'college' ELSE 'school' END
  );

  RETURN json_build_object(
    'success', true,
    'message', 'User created successfully',
    'username', v_clean_username,
    'role', p_role
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error creating user: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_add_user_v2 TO anon, authenticated;

-- Directory table read by homework / teacher UIs for display names.
CREATE TABLE IF NOT EXISTS public.school_teachers (
  username   TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  subject    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
GRANT SELECT ON public.school_teachers TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. PRINT the school accounts about to be dropped.
--    public.users has no primary key or id column (accounts are keyed by
--    username), so ctid is printed only as a row reference — nothing below
--    depends on it.
-- ---------------------------------------------------------------------------
SELECT ctid::text AS row_id, u.username, u.role, u.institution
FROM public.users u
WHERE u.institution = 'school'
   OR u.institute_type = 'school'
   OR u.role IN ('student', 'teacher', 'parent', 'dean')
   OR LOWER(u.role) IN (
        'parent', 'dean', 'admissiondean', 'counsellor', 'temp_student',
        'warden', 'conductor', 'transport_officer', 'accountant', 'librarian'
      )
ORDER BY u.role, u.username;

CREATE TEMP TABLE _school_accounts ON COMMIT DROP AS
SELECT u.username
FROM public.users u
WHERE u.institution = 'school'
   OR u.institute_type = 'school'
   OR u.role IN ('student', 'teacher', 'parent', 'dean')
   OR LOWER(u.role) IN (
        'parent', 'dean', 'admissiondean', 'counsellor', 'temp_student',
        'warden', 'conductor', 'transport_officer', 'accountant', 'librarian'
      );

-- ---------------------------------------------------------------------------
-- 2. DROP school accounts + their owned profile / activity rows
-- ---------------------------------------------------------------------------
DELETE FROM public.parent_student_links
WHERE parent_username IN (SELECT username FROM _school_accounts)
   OR student_username IN (SELECT username FROM _school_accounts);

DELETE FROM public.school_timetable
WHERE teacher_username IN (SELECT username FROM _school_accounts);

DELETE FROM public.school_fee_payments
WHERE student_id IN (SELECT username FROM _school_accounts);

DELETE FROM public.school_attendance
WHERE student_id IN (SELECT username FROM _school_accounts);

DELETE FROM public.school_teachers
WHERE username IN (SELECT username FROM _school_accounts);

DELETE FROM public.teacher_details
WHERE teacher_id IN (SELECT username FROM _school_accounts);

DELETE FROM public.staff
WHERE staff_code IN (SELECT username FROM _school_accounts);

-- Profile rows kept their username in school_students (accounts were just
-- removed, so every username match is orphaned).
DELETE FROM public.school_students
WHERE username IN (SELECT username FROM _school_accounts);

DELETE FROM public.users
WHERE username IN (SELECT username FROM _school_accounts);

-- ---------------------------------------------------------------------------
-- 3. USERS — 50 students of Class 10
-- ---------------------------------------------------------------------------
INSERT INTO public.users (username, password, role, institution, institute_type)
SELECT username, public.hash_password(username), 'student', 'school', 'school'
FROM (
  SELECT 's10s' || lpad(g::text, 2, '0') AS username FROM generate_series(1, 50) g
) u
ON CONFLICT (username) DO UPDATE
  SET password       = EXCLUDED.password,
      role           = 'student',
      institution    = 'school',
      institute_type = 'school';

-- ---------------------------------------------------------------------------
-- 4. STUDENT MASTER RECORDS (school_students)
-- ---------------------------------------------------------------------------
DO $$
DECLARE cid TEXT;
BEGIN
  SELECT id::text INTO cid
  FROM public.school_classes
  WHERE name = 'Class 10'
  ORDER BY created_at ASC NULLS LAST
  LIMIT 1;

  IF cid IS NULL THEN
    INSERT INTO public.school_classes (name, section, academic_year)
    VALUES ('Class 10', NULL, '2026-2027')
    RETURNING id::text INTO cid;
  END IF;
END $$;

-- Name arrays are written once here and reused for the student rows (this
-- block) and the parent accounts (step 7), so a student's parent login always
-- carries the same parent_name / contact as the child row.
CREATE TEMP TABLE names_tmp ON COMMIT DROP AS
SELECT
  ARRAY[
    'Aarav','Vivaan','Aditya','Vihaan','Arjun','Reyansh','Ishaan','Karthik',
    'Ananya','Diya','Advika','Ira','Myra','Sara','Anika','Riya','Navya','Kiara',
    'Rohan','Kabir','Dhruv','Advait','Shaurya','Atharv','Pranav',
    'Meera','Tara','Zoya','Radhika','Sneha','Priya','Nisha','Kavya',
    'Aryan','Viyan','Nivaan','Yash','Rudra','Om','Dev','Parth',
    'Shanaya','Aadhya','Prisha','Anvi','Charvi','Trisha','Vaani','Hiral','Nitya'
  ] AS fn,
  ARRAY[
    'Sharma','Verma','Gupta','Singh','Mehta','Malhotra','Chopra','Kapoor',
    'Joshi','Nair','Pillai','Desai','Bose','Chatterjee','Rathore','Thakur',
    'Iyer','Banerjee','Reddy','Menon','Khanna','Saxena','Pandey','Bhat'
  ] AS ln,
  ARRAY[
    'Rajesh','Suresh','Mahesh','Naveen','Vikram','Sanjay','Anil','Prakash',
    'Harish','Mukesh','Dinesh','Ramesh','Ajay','Nikhil','Ashok','Vinod'
  ] AS pfn
;

WITH cfg AS (
  SELECT (SELECT id::text FROM public.school_classes
          WHERE name = 'Class 10'
          ORDER BY created_at ASC NULLS LAST LIMIT 1) AS cid
),
g AS (SELECT generate_series(1, 50) AS i)
INSERT INTO public.school_students
  (id, username, name, class_id, class_name, roll_number, admission_no,
   parent_name, contact)
SELECT
  'SCH10-' || lpad(i::text, 2, '0'),
  's10s' || lpad(i::text, 2, '0'),
  n.fn[1 + (r % array_length(n.fn,1))] || ' ' ||
    n.ln[1 + ((r / array_length(n.fn,1)) % array_length(n.ln,1))],
  (SELECT cid FROM cfg),
  'Class 10',
  lpad(i::text, 2, '0'),
  'ADM26-10-' || lpad(i::text, 2, '0'),
  CASE
    WHEN (r % 4) = 3
      THEN 'Mrs. ' || n.fn[1 + ((r / 7) % array_length(n.fn,1))] || ' ' ||
           n.ln[1 + ((r / array_length(n.fn,1)) % array_length(n.ln,1))]
    ELSE 'Mr. ' ||
           n.pfn[1 + ((r / 3) % array_length(n.pfn,1))] || ' ' ||
           n.ln[1 + ((r / array_length(n.fn,1)) % array_length(n.ln,1))]
  END,
  '98' || lpad(((r % 90000000) + 10000000)::text, 8, '0')
FROM g, names_tmp n,
     LATERAL (SELECT ('x' || substr(md5('cls10-student-' || i::text), 1, 6))::bit(24)::int AS r) h
ON CONFLICT (id) DO UPDATE
  SET username     = EXCLUDED.username,
      name         = EXCLUDED.name,
      class_id     = EXCLUDED.class_id,
      class_name   = EXCLUDED.class_name,
      roll_number  = EXCLUDED.roll_number,
      admission_no = EXCLUDED.admission_no,
      parent_name  = EXCLUDED.parent_name,
      contact      = EXCLUDED.contact;

-- ---------------------------------------------------------------------------
-- 5. USERS — 22 subject teachers (steach01 is also the Class 10 class teacher)
--    Profile rows go into both school_teachers (display names used across the
--    school UI) and teacher_details (what Manage Users reads).
-- ---------------------------------------------------------------------------
WITH teachers (i, tname, subject, qualification) AS (
  VALUES
    ( 1, 'Rakesh Sharma',      'Mathematics',       'M.Sc (Mathematics), B.Ed'),
    ( 2, 'Sunita Gupta',       'Mathematics',       'M.Sc (Mathematics), B.Ed'),
    ( 3, 'Deepak Mehta',       'Mathematics',       'M.Sc (Mathematics), M.Ed'),
    ( 4, 'Anjali Nair',        'Science',           'M.Sc (Physics), B.Ed'),
    ( 5, 'Vivek Rathore',      'Science',           'M.Sc (Chemistry), B.Ed'),
    ( 6, 'Pooja Desai',        'Physics',           'M.Sc (Physics), B.Ed'),
    ( 7, 'Amit Chatterjee',    'Physics',           'M.Sc (Physics), B.Ed'),
    ( 8, 'Rekha Iyer',         'Chemistry',         'M.Sc (Chemistry), B.Ed'),
    ( 9, 'Suresh Pillai',      'Chemistry',         'M.Sc (Chemistry), B.Ed'),
    (10, 'Nandini Bose',       'Biology',           'M.Sc (Botany), B.Ed'),
    (11, 'Farah Khan',         'English',           'M.A (English), B.Ed'),
    (12, 'Rajiv Malhotra',     'English',           'M.A (English), B.Ed'),
    (13, 'Shalini Kapoor',     'English',           'M.A (English), M.Ed'),
    (14, 'Geeta Pandey',       'Hindi',             'M.A (Hindi), B.Ed'),
    (15, 'Ravi Saxena',        'Hindi',             'M.A (Hindi), B.Ed'),
    (16, 'Manish Thakur',      'Social Studies',    'M.A (History), B.Ed'),
    (17, 'Swati Joshi',        'Social Studies',    'M.A (Geography), B.Ed'),
    (18, 'Neha Kulkarni',      'Computer Science',  'MCA, B.Ed'),
    (19, 'Imran Sheikh',       'Computer Science',  'MCA, B.Ed'),
    (20, 'Vidya Shankar',      'Sanskrit',          'M.A (Sanskrit), B.Ed'),
    (21, 'Sunil Bhatia',       'Physical Education','B.P.Ed'),
    (22, 'Priyanka Sen',       'Art & Craft',       'B.F.A')
),
dir AS (
  INSERT INTO public.school_teachers (username, name, subject)
  SELECT 'steach' || lpad(t.i::text, 2, '0'), t.tname, t.subject
  FROM teachers t
  ON CONFLICT (username) DO UPDATE
    SET name = EXCLUDED.name,
        subject = EXCLUDED.subject
  RETURNING username
)
INSERT INTO public.users (username, password, role, institution, institute_type)
SELECT
  'steach' || lpad(t.i::text, 2, '0'),
  public.hash_password('steach' || lpad(t.i::text, 2, '0')),
  'teacher', 'school', 'school'
FROM teachers t
ON CONFLICT (username) DO UPDATE
  SET password       = EXCLUDED.password,
      role           = 'teacher',
      institution    = 'school',
      institute_type = 'school';

INSERT INTO public.teacher_details
  (teacher_id, employee_id, name, designation, department, subject,
   highest_qualification, date_of_joining, employment_type, status,
   created_at, updated_at)
SELECT
  'steach' || lpad(t.i::text, 2, '0'),
  'EMP-10-' || lpad(t.i::text, 2, '0'),
  t.tname,
  CASE WHEN t.i = 1 THEN 'Class Teacher' ELSE 'Subject Teacher' END,
  'Class 10',
  t.subject,
  t.qualification,
  DATE '2020-06-01' + (t.i * 40),
  'Permanent',
  'Active',
  now(), now()
FROM (
  VALUES
    ( 1, 'Rakesh Sharma',      'Mathematics',       'M.Sc (Mathematics), B.Ed'),
    ( 2, 'Sunita Gupta',       'Mathematics',       'M.Sc (Mathematics), B.Ed'),
    ( 3, 'Deepak Mehta',       'Mathematics',       'M.Sc (Mathematics), M.Ed'),
    ( 4, 'Anjali Nair',        'Science',           'M.Sc (Physics), B.Ed'),
    ( 5, 'Vivek Rathore',      'Science',           'M.Sc (Chemistry), B.Ed'),
    ( 6, 'Pooja Desai',        'Physics',           'M.Sc (Physics), B.Ed'),
    ( 7, 'Amit Chatterjee',    'Physics',           'M.Sc (Physics), B.Ed'),
    ( 8, 'Rekha Iyer',         'Chemistry',         'M.Sc (Chemistry), B.Ed'),
    ( 9, 'Suresh Pillai',      'Chemistry',         'M.Sc (Chemistry), B.Ed'),
    (10, 'Nandini Bose',       'Biology',           'M.Sc (Botany), B.Ed'),
    (11, 'Farah Khan',         'English',           'M.A (English), B.Ed'),
    (12, 'Rajiv Malhotra',     'English',           'M.A (English), B.Ed'),
    (13, 'Shalini Kapoor',     'English',           'M.A (English), M.Ed'),
    (14, 'Geeta Pandey',       'Hindi',             'M.A (Hindi), B.Ed'),
    (15, 'Ravi Saxena',        'Hindi',             'M.A (Hindi), B.Ed'),
    (16, 'Manish Thakur',      'Social Studies',    'M.A (History), B.Ed'),
    (17, 'Swati Joshi',        'Social Studies',    'M.A (Geography), B.Ed'),
    (18, 'Neha Kulkarni',      'Computer Science',  'MCA, B.Ed'),
    (19, 'Imran Sheikh',       'Computer Science',  'MCA, B.Ed'),
    (20, 'Vidya Shankar',      'Sanskrit',          'M.A (Sanskrit), B.Ed'),
    (21, 'Sunil Bhatia',       'Physical Education','B.P.Ed'),
    (22, 'Priyanka Sen',       'Art & Craft',       'B.F.A')
) AS t(i, tname, subject, qualification)
ON CONFLICT (teacher_id) DO UPDATE
  SET employee_id           = EXCLUDED.employee_id,
      name                  = EXCLUDED.name,
      designation           = EXCLUDED.designation,
      department            = EXCLUDED.department,
      subject               = EXCLUDED.subject,
      highest_qualification = EXCLUDED.highest_qualification,
      status                = EXCLUDED.status,
      updated_at            = now();

-- ---------------------------------------------------------------------------
-- 6. ADMIN — one school principal account (school dashboard + manage users)
-- ---------------------------------------------------------------------------
INSERT INTO public.users (username, password, role, institution, institute_type)
VALUES (
  'shiv_admin',
  public.hash_password('shiv_admin'),
  'admin', 'school', 'school'
)
ON CONFLICT (username) DO UPDATE
  SET password       = EXCLUDED.password,
      role           = 'admin',
      institution    = 'school',
      institute_type = 'school';

-- ---------------------------------------------------------------------------
-- 7. PARENTS — every student's parent in school_students gets a login
--    parent_<roll> (parent_01 .. parent_50). The parent named in "Mr. Rajesh
--    Sharma" becomes parent_rajesh_sharma; duplicate names get a roll suffix.
-- ---------------------------------------------------------------------------
DELETE FROM public.parent_student_links
WHERE parent_username IN (SELECT username FROM _school_accounts)
   OR parent_username LIKE 'parent%';

WITH p AS (
  SELECT
    s.username                                         AS student_username,
    s.roll_number,
    s.parent_name,
    s.contact,
    'parent_' || btrim(
      regexp_replace(
        regexp_replace(s.parent_name, '^(Mr|Mrs|Ms)\.?\s+', '', 'i'),
        '[^a-z0-9]+', '_', 'g'
      ),
      '_'
    ) AS base_username
  FROM public.school_students s
  WHERE s.class_name = 'Class 10'
    AND s.parent_name IS NOT NULL
    AND btrim(s.parent_name) <> ''
),
u AS (
  -- Same username rule as the parent_student_links insert below.
  SELECT DISTINCT ON (base_username)
    base_username || CASE
      WHEN count(*) OVER (PARTITION BY base_username) = 1 THEN ''
      ELSE '_' || roll_number
    END AS username
  FROM p
  ORDER BY base_username, roll_number
)
INSERT INTO public.users (username, password, role, institution, institute_type)
SELECT u.username, public.hash_password(u.username), 'parent', 'school', 'school'
FROM u
ON CONFLICT (username) DO UPDATE
  SET password       = EXCLUDED.password,
      role           = 'parent',
      institution    = 'school',
      institute_type = 'school';

-- ---------------------------------------------------------------------------
-- 8. LINK — Class 10 class teacher + parent ↔ children
-- ---------------------------------------------------------------------------
UPDATE public.school_classes
SET    class_teacher_id = 'steach01'
WHERE  name = 'Class 10';

INSERT INTO public.parent_student_links (parent_username, student_username, relation)
SELECT
  p.username,
  p.student_username,
  CASE WHEN p.parent_name ILIKE 'Mrs%' OR p.parent_name ILIKE 'Ms%'
       THEN 'Mother' ELSE 'Father' END
FROM (
  SELECT
    s.username AS student_username,
    s.roll_number,
    s.parent_name,
    'parent_' || btrim(
      regexp_replace(
        regexp_replace(s.parent_name, '^(Mr|Mrs|Ms)\.?\s+', '', 'i'),
        '[^a-z0-9]+', '_', 'g'
      ),
      '_'
    ) AS base_username
  FROM public.school_students s
  WHERE s.class_name = 'Class 10'
    AND s.parent_name IS NOT NULL
    AND btrim(s.parent_name) <> ''
) x
JOIN (
  SELECT DISTINCT ON (base_username)
    base_username || CASE
      WHEN count(*) OVER (PARTITION BY base_username) = 1 THEN ''
      ELSE '_' || roll_number
    END AS username,
    parent_name
  FROM (
    SELECT
      s.roll_number,
      s.parent_name,
      'parent_' || btrim(
        regexp_replace(
          regexp_replace(s.parent_name, '^(Mr|Mrs|Ms)\.?\s+', '', 'i'),
          '[^a-z0-9]+', '_', 'g'
        ),
        '_'
      ) AS base_username
    FROM public.school_students s
    WHERE s.class_name = 'Class 10'
      AND s.parent_name IS NOT NULL
      AND btrim(s.parent_name) <> ''
  ) y
  ORDER BY base_username, roll_number
) p ON p.base_username = x.base_username
ON CONFLICT (parent_username, student_username) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- 9. VERIFICATION — should match Admin → Manage Users (School tab)
-- ---------------------------------------------------------------------------
SELECT what, accounts FROM (
  SELECT 'students'    AS what, count(*)::int AS accounts
    FROM public.users WHERE institution = 'school' AND role = 'student'
  UNION ALL
  SELECT 'teachers',    count(*)::int FROM public.users WHERE institution = 'school' AND role = 'teacher'
  UNION ALL
  SELECT 'admins',      count(*)::int FROM public.users WHERE institution = 'school' AND role = 'admin'
  UNION ALL
  SELECT 'parents',     count(*)::int FROM public.users WHERE institution = 'school' AND role = 'parent'
  UNION ALL
  SELECT 'other school roles', count(*)::int FROM public.users
    WHERE institution = 'school' AND role NOT IN ('student', 'teacher', 'admin', 'parent')
) v;

-- Students whose login cannot be resolved to a name in Manage Users.
SELECT 'students without name lookup' AS check, count(*) AS rows
FROM public.users u
WHERE u.institution = 'school' AND u.role = 'student'
  AND NOT EXISTS (
    SELECT 1 FROM public.school_students s WHERE s.username = u.username);

SELECT 'Teachers without name lookup' AS check, count(*) AS rows
FROM public.users u
WHERE u.institution = 'school' AND u.role = 'teacher'
  AND NOT EXISTS (
    SELECT 1 FROM public.teacher_details t WHERE t.teacher_id = u.username);

-- Cleanup leftovers of earlier seeds (removes duplicate / sectioned classes,
-- and profile rows whose login no longer exists).
DELETE FROM public.school_students s
WHERE s.username IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.users u WHERE u.username = s.username);

SELECT 'School accounts seeded — log in with shiv_admin / shiv_admin, '
       's10s01 / s10s01, steach01 / steach01, or any parent_* account '
       '(password = username)' AS result;
