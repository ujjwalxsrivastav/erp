-- ============================================================================
-- School Counsellors — role, directory, and round-robin admission allotment
-- ============================================================================
-- Adds the `counsellor` user role for the school portal, a counsellor
-- directory table used for round-robin assignment, and the admission columns
-- that record which counsellor was allotted.
--
-- Safe to run more than once.
-- ============================================================================

-- 1. Allow the counsellor role on the users table ----------------------------
-- Some databases predate the dual-mode migration; make sure the school column
-- exists before seeding counsellor accounts.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS institute_type TEXT DEFAULT 'college';

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_role_check
  CHECK (
    LOWER(role) IN (
      'student', 'teacher', 'admin', 'staff', 'hr', 'hod',
      'parent', 'accountant', 'librarian', 'transport', 'receptionist',
      'principal', 'superadmin', 'class_teacher', 'warden', 'nurse',
      'conductor', 'driver', 'attendant', 'transport_officer',
      'counsellor', 'counselor', 'admissiondean',
      'sstudent', 'steacher', 'sparent', 'sadmin'
    )
    OR role IN ('HR', 'HOD')
  ) NOT VALID;

-- 1b. Account-creation RPC ------------------------------------------------
-- The app creates teacher/counsellor logins through `secure_add_user_v2`.
-- Older definitions only accepted student/teacher/admin, so counsellor
-- accounts failed with "Invalid role". This version accepts the school roles
-- used by Manage Users and fills the institution columns when they exist.
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
  v_valid_roles TEXT[] := ARRAY['student', 'teacher', 'admin', 'counsellor', 'counselor'];
  v_institution TEXT;
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
  IF p_role IS NULL OR NOT (LOWER(p_role) = ANY(v_valid_roles)) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid role. Valid roles: student, teacher, admin, counsellor'
    );
  END IF;

  v_clean_username := LOWER(TRIM(p_username));
  IF v_clean_username !~ '^[a-z0-9_]+$' THEN
    RETURN json_build_object('success', false,
      'message', 'Username can only contain letters, numbers, and underscores');
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE username = v_clean_username) THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  END IF;

  v_hashed_password := public.hash_password(p_password);
  v_institution := CASE WHEN LOWER(p_role) = 'admin' THEN 'college' ELSE 'school' END;

  INSERT INTO public.users (username, password, role)
  VALUES (v_clean_username, v_hashed_password, LOWER(p_role));

  -- Keep whichever institution columns this database has in sync.
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'institute_type'
  ) THEN
    EXECUTE 'UPDATE public.users SET institute_type = $1 WHERE username = $2'
      USING v_institution, v_clean_username;
  END IF;
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'institution'
  ) THEN
    EXECUTE 'UPDATE public.users SET institution = $1 WHERE username = $2'
      USING v_institution, v_clean_username;
  END IF;

  RETURN json_build_object(
    'success', true,
    'message', 'User created successfully',
    'username', v_clean_username,
    'role', LOWER(p_role)
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  WHEN OTHERS THEN
    RETURN json_build_object('success', false,
      'message', 'Error creating user: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_add_user_v2
  TO anon, authenticated, service_role;

-- 1c. Teacher display-name directory ---------------------------------------
-- School screens resolve teacher names from this table; admins may create
-- teachers before the seed script that originally defined it has run.
CREATE TABLE IF NOT EXISTS public.school_teachers (
  username   TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  subject    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.school_teachers DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE public.school_teachers TO anon, authenticated, service_role;

-- Older databases also carry an `institution` column used by the admin user
-- management screens. Counsellor rows are synced after seeding below.

-- 2. Counsellor directory -----------------------------------------------------
CREATE TABLE IF NOT EXISTS school_counsellors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    username TEXT UNIQUE NOT NULL,          -- links to public.users.username
    name TEXT NOT NULL,
    email TEXT,
    phone TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    -- Round-robin state: the allocator picks the counsellor with the fewest
    -- assignments, breaking ties by who was assigned longest ago.
    assignments_count INT NOT NULL DEFAULT 0,
    last_assigned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_school_counsellors_active
  ON school_counsellors (is_active);
CREATE INDEX IF NOT EXISTS idx_school_counsellors_round_robin
  ON school_counsellors (assignments_count, last_assigned_at);

ALTER TABLE school_counsellors DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE school_counsellors TO anon, authenticated, service_role;

-- 3. Seed 10 counsellor accounts (username = password for demo logins) --------
INSERT INTO public.users (username, password, role, institute_type)
VALUES
    ('scounsellor1',  'scounsellor1',  'counsellor', 'school'),
    ('scounsellor2',  'scounsellor2',  'counsellor', 'school'),
    ('scounsellor3',  'scounsellor3',  'counsellor', 'school'),
    ('scounsellor4',  'scounsellor4',  'counsellor', 'school'),
    ('scounsellor5',  'scounsellor5',  'counsellor', 'school'),
    ('scounsellor6',  'scounsellor6',  'counsellor', 'school'),
    ('scounsellor7',  'scounsellor7',  'counsellor', 'school'),
    ('scounsellor8',  'scounsellor8',  'counsellor', 'school'),
    ('scounsellor9',  'scounsellor9',  'counsellor', 'school'),
    ('scounsellor10', 'scounsellor10', 'counsellor', 'school')
ON CONFLICT (username) DO UPDATE
SET password = EXCLUDED.password,
    role = EXCLUDED.role,
    institute_type = EXCLUDED.institute_type;

-- Keep the legacy `institution` column in sync when that column exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users'
      AND column_name = 'institution'
  ) THEN
    EXECUTE 'UPDATE public.users SET institution = ''school'' WHERE role = ''counsellor''';
  END IF;
END $$;

-- 4. Seed 10 counsellor directory rows ----------------------------------------
INSERT INTO school_counsellors (username, name, email, phone) VALUES
    ('scounsellor1',  'Anjali Mehta',   'anjali.mehta@school.edu',   '9876544001'),
    ('scounsellor2',  'Rohan Kapoor',   'rohan.kapoor@school.edu',   '9876544002'),
    ('scounsellor3',  'Neha Sharma',    'neha.sharma@school.edu',    '9876544003'),
    ('scounsellor4',  'Vikram Singh',   'vikram.singh@school.edu',   '9876544004'),
    ('scounsellor5',  'Pooja Verma',    'pooja.verma@school.edu',    '9876544005'),
    ('scounsellor6',  'Arjun Nair',     'arjun.nair@school.edu',     '9876544006'),
    ('scounsellor7',  'Simran Kaur',    'simran.kaur@school.edu',    '9876544007'),
    ('scounsellor8',  'Karan Malhotra', 'karan.malhotra@school.edu', '9876544008'),
    ('scounsellor9',  'Divya Rao',      'divya.rao@school.edu',      '9876544009'),
    ('scounsellor10', 'Aditya Joshi',   'aditya.joshi@school.edu',   '9876544010')
ON CONFLICT (username) DO UPDATE
SET name = EXCLUDED.name,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone;

-- 5. Admission allotment + workflow columns -----------------------------------
-- Allotment marks who owns the application; the workflow columns let the
-- counsellor desk see the latest admin action (status_detail) even though the
-- constrained `status` column only allows pending/approved/rejected.
ALTER TABLE school_admissions
  ADD COLUMN IF NOT EXISTS counsellor_id UUID,
  ADD COLUMN IF NOT EXISTS counsellor_name TEXT,
  ADD COLUMN IF NOT EXISTS counsellor_assigned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS status_detail TEXT,
  ADD COLUMN IF NOT EXISTS doc_status TEXT DEFAULT 'Pending',
  ADD COLUMN IF NOT EXISTS documents JSONB,
  ADD COLUMN IF NOT EXISTS test_score INT,
  ADD COLUMN IF NOT EXISTS interview_notes TEXT,
  ADD COLUMN IF NOT EXISTS fee_demanded NUMERIC,
  ADD COLUMN IF NOT EXISTS offer_valid_till TEXT,
  ADD COLUMN IF NOT EXISTS admission_no TEXT,
  ADD COLUMN IF NOT EXISTS student_username TEXT,
  ADD COLUMN IF NOT EXISTS enrolled_class TEXT,
  ADD COLUMN IF NOT EXISTS enrolled_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_school_admissions_counsellor
  ON school_admissions (counsellor_id);

-- 6. Backfill applications submitted before the counsellor system ------------
-- Distributes every currently unassigned application across the active
-- counsellor pool, then recomputes each counsellor's load counter. Re-running
-- is safe: only rows with a NULL counsellor_id are touched.
WITH unassigned AS (
  SELECT id, (row_number() OVER (ORDER BY created_at NULLS LAST, id)) - 1 AS rn
  FROM school_admissions
  WHERE counsellor_id IS NULL
),
pool AS (
  SELECT id,
         name,
         (row_number() OVER (
            ORDER BY assignments_count, last_assigned_at NULLS FIRST, name
         )) - 1 AS rn,
         count(*) OVER () AS total
  FROM school_counsellors
  WHERE is_active = TRUE
),
assign AS (
  SELECT u.id AS admission_id, p.id AS counsellor_id, p.name AS counsellor_name
  FROM unassigned u
  JOIN pool p ON (u.rn % p.total) = p.rn
)
UPDATE school_admissions a
SET counsellor_id = assign.counsellor_id,
    counsellor_name = assign.counsellor_name,
    counsellor_assigned_at = now()
FROM assign
WHERE a.id = assign.admission_id;

UPDATE school_counsellors c
SET assignments_count = COALESCE(sub.cnt, 0),
    last_assigned_at = COALESCE(sub.last_at, c.last_assigned_at)
FROM (
  SELECT counsellor_id,
         count(*) AS cnt,
         max(counsellor_assigned_at) AS last_at
  FROM school_admissions
  WHERE counsellor_id IS NOT NULL
  GROUP BY counsellor_id
) sub
WHERE c.id = sub.counsellor_id;

-- Quick verification helpers
DO $$
BEGIN
  RAISE NOTICE 'School counsellors ready: % accounts, % directory rows',
    (SELECT count(*) FROM public.users WHERE role = 'counsellor'),
    (SELECT count(*) FROM school_counsellors);
END $$;
