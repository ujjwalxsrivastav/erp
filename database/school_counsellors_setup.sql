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

-- 5. Admission allotment columns ---------------------------------------------
ALTER TABLE school_admissions
  ADD COLUMN IF NOT EXISTS counsellor_id UUID,
  ADD COLUMN IF NOT EXISTS counsellor_name TEXT,
  ADD COLUMN IF NOT EXISTS counsellor_assigned_at TIMESTAMPTZ;

-- Quick verification helpers
DO $$
BEGIN
  RAISE NOTICE 'School counsellors ready: % accounts, % directory rows',
    (SELECT count(*) FROM public.users WHERE role = 'counsellor'),
    (SELECT count(*) FROM school_counsellors);
END $$;
