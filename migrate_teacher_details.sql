-- ============================================
-- TEACHER DETAILS TABLE - MIGRATION SCRIPT
-- ============================================
-- This script adds new columns to existing teacher_details table
-- Run this in Supabase SQL Editor

-- Add new columns if they don't exist
ALTER TABLE teacher_details 
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS gender TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS state TEXT,
ADD COLUMN IF NOT EXISTS pincode TEXT,
ADD COLUMN IF NOT EXISTS emergency_contact_name TEXT,
ADD COLUMN IF NOT EXISTS emergency_contact_number TEXT,
ADD COLUMN IF NOT EXISTS emergency_contact_relation TEXT,
ADD COLUMN IF NOT EXISTS designation TEXT,
ADD COLUMN IF NOT EXISTS date_of_joining DATE,
ADD COLUMN IF NOT EXISTS employment_type TEXT,
ADD COLUMN IF NOT EXISTS reporting_to TEXT,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Active',
ADD COLUMN IF NOT EXISTS highest_qualification TEXT,
ADD COLUMN IF NOT EXISTS university TEXT,
ADD COLUMN IF NOT EXISTS passing_year INTEGER,
ADD COLUMN IF NOT EXISTS specialization TEXT,
ADD COLUMN IF NOT EXISTS total_experience_years INTEGER,
ADD COLUMN IF NOT EXISTS previous_employer_1 TEXT,
ADD COLUMN IF NOT EXISTS previous_role_1 TEXT,
ADD COLUMN IF NOT EXISTS previous_duration_1 TEXT,
ADD COLUMN IF NOT EXISTS previous_employer_2 TEXT,
ADD COLUMN IF NOT EXISTS previous_role_2 TEXT,
ADD COLUMN IF NOT EXISTS previous_duration_2 TEXT,
ADD COLUMN IF NOT EXISTS previous_employer_3 TEXT,
ADD COLUMN IF NOT EXISTS previous_role_3 TEXT,
ADD COLUMN IF NOT EXISTS previous_duration_3 TEXT,
ADD COLUMN IF NOT EXISTS aadhaar_url TEXT,
ADD COLUMN IF NOT EXISTS pan_url TEXT,
ADD COLUMN IF NOT EXISTS degree_certificate_url TEXT,
ADD COLUMN IF NOT EXISTS experience_letter_url TEXT,
ADD COLUMN IF NOT EXISTS offer_letter_url TEXT,
ADD COLUMN IF NOT EXISTS joining_letter_url TEXT,
ADD COLUMN IF NOT EXISTS resume_url TEXT,
ADD COLUMN IF NOT EXISTS aadhaar_number TEXT,
ADD COLUMN IF NOT EXISTS pan_number TEXT,
ADD COLUMN IF NOT EXISTS created_by TEXT,
ADD COLUMN IF NOT EXISTS updated_by TEXT;

-- Add constraints
DO $$ 
BEGIN
  -- Add gender constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'teacher_details_gender_check'
  ) THEN
    ALTER TABLE teacher_details 
    ADD CONSTRAINT teacher_details_gender_check 
    CHECK (gender IN ('Male', 'Female', 'Other'));
  END IF;

  -- Add employment_type constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'teacher_details_employment_type_check'
  ) THEN
    ALTER TABLE teacher_details 
    ADD CONSTRAINT teacher_details_employment_type_check 
    CHECK (employment_type IN ('Permanent', 'Contract', 'Visiting', 'Guest'));
  END IF;

  -- Add status constraint if not exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'teacher_details_status_check'
  ) THEN
    ALTER TABLE teacher_details 
    ADD CONSTRAINT teacher_details_status_check 
    CHECK (status IN ('Active', 'On Leave', 'Resigned', 'Terminated', 'Retired'));
  END IF;
END $$;

-- Rename 'subject' to keep it, but add 'designation' as main field
-- Update existing data to have designation
UPDATE teacher_details 
SET designation = COALESCE(designation, 'Professor')
WHERE designation IS NULL;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_teacher_employee_id ON teacher_details(employee_id);
CREATE INDEX IF NOT EXISTS idx_teacher_department ON teacher_details(department);
CREATE INDEX IF NOT EXISTS idx_teacher_status ON teacher_details(status);
CREATE INDEX IF NOT EXISTS idx_teacher_email ON teacher_details(email);

-- Drop old policies if they exist and recreate
DROP POLICY IF EXISTS "Allow read access to all users" ON teacher_details;
DROP POLICY IF EXISTS "Allow teachers to update own details" ON teacher_details;
DROP POLICY IF EXISTS "Allow HR and Admin full access" ON teacher_details;

-- Create new RLS policies
CREATE POLICY "Allow read access to authenticated users"
ON teacher_details FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Allow teachers to update own details"
ON teacher_details FOR UPDATE
TO authenticated
USING (teacher_id = current_user);

CREATE POLICY "Allow HR and Admin full access"
ON teacher_details FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- Create or replace trigger function
CREATE OR REPLACE FUNCTION update_teacher_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS teacher_details_updated_at ON teacher_details;

CREATE TRIGGER teacher_details_updated_at
BEFORE UPDATE ON teacher_details
FOR EACH ROW
EXECUTE FUNCTION update_teacher_updated_at();

-- Update existing sample data with comprehensive information
UPDATE teacher_details 
SET 
  date_of_birth = '1985-01-15',
  gender = 'Male',
  address = '123, Green Valley, Sector 5',
  city = 'Dehradun',
  state = 'Uttarakhand',
  pincode = '248001',
  emergency_contact_name = 'Ravi Kumar',
  emergency_contact_number = '+91 98765 00000',
  emergency_contact_relation = 'Brother',
  designation = 'Professor',
  date_of_joining = '2018-08-01',
  employment_type = 'Permanent',
  status = 'Active',
  highest_qualification = 'Ph.D. in Computer Science',
  university = 'IIT Delhi',
  passing_year = 2015,
  specialization = 'Algorithms & Data Structures',
  total_experience_years = 12,
  previous_employer_1 = 'ABC University',
  previous_role_1 = 'Associate Professor',
  previous_duration_1 = '2015 - 2018',
  previous_employer_2 = 'XYZ Institute',
  previous_role_2 = 'Assistant Professor',
  previous_duration_2 = '2012 - 2015',
  aadhaar_number = '123456789012',
  pan_number = 'ABCDE1234F'
WHERE employee_id = 'EMP001';

UPDATE teacher_details 
SET 
  date_of_birth = '1988-03-22',
  gender = 'Female',
  address = '456, Park Avenue, Sector 7',
  city = 'Dehradun',
  state = 'Uttarakhand',
  pincode = '248002',
  emergency_contact_name = 'Rahul Sharma',
  emergency_contact_number = '+91 98765 00001',
  emergency_contact_relation = 'Husband',
  designation = 'Associate Professor',
  date_of_joining = '2019-07-15',
  employment_type = 'Permanent',
  reporting_to = 'EMP001',
  status = 'Active',
  highest_qualification = 'Ph.D. in Electronics',
  university = 'NIT Trichy',
  passing_year = 2017,
  specialization = 'VLSI Design',
  total_experience_years = 10,
  previous_employer_1 = 'DEF College',
  previous_role_1 = 'Assistant Professor',
  previous_duration_1 = '2017 - 2019',
  previous_employer_2 = 'GHI University',
  previous_role_2 = 'Lecturer',
  previous_duration_2 = '2014 - 2017',
  aadhaar_number = '234567890123',
  pan_number = 'BCDEF2345G'
WHERE employee_id = 'EMP002';

UPDATE teacher_details 
SET 
  date_of_birth = '1990-06-10',
  gender = 'Male',
  address = '789, Hill View, Sector 3',
  city = 'Dehradun',
  state = 'Uttarakhand',
  pincode = '248003',
  emergency_contact_name = 'Sunita Verma',
  emergency_contact_number = '+91 98765 00002',
  emergency_contact_relation = 'Wife',
  designation = 'Assistant Professor',
  date_of_joining = '2020-01-10',
  employment_type = 'Permanent',
  reporting_to = 'EMP001',
  status = 'On Leave',
  highest_qualification = 'M.Tech in Mechanical Engineering',
  university = 'IIT Roorkee',
  passing_year = 2018,
  specialization = 'Thermal Engineering',
  total_experience_years = 8,
  previous_employer_1 = 'JKL Institute',
  previous_role_1 = 'Lecturer',
  previous_duration_1 = '2018 - 2020',
  aadhaar_number = '345678901234',
  pan_number = 'CDEFG3456H'
WHERE employee_id = 'EMP003';

UPDATE teacher_details 
SET 
  date_of_birth = '1982-09-05',
  gender = 'Female',
  address = '321, Lake Side, Sector 9',
  city = 'Dehradun',
  state = 'Uttarakhand',
  pincode = '248004',
  emergency_contact_name = 'Kiran Patel',
  emergency_contact_number = '+91 98765 00003',
  emergency_contact_relation = 'Sister',
  designation = 'HOD',
  date_of_joining = '2015-06-01',
  employment_type = 'Permanent',
  status = 'Active',
  highest_qualification = 'Ph.D. in Computer Science',
  university = 'IIT Bombay',
  passing_year = 2012,
  specialization = 'Software Engineering',
  total_experience_years = 15,
  previous_employer_1 = 'MNO University',
  previous_role_1 = 'Professor',
  previous_duration_1 = '2012 - 2015',
  previous_employer_2 = 'PQR College',
  previous_role_2 = 'Associate Professor',
  previous_duration_2 = '2009 - 2012',
  aadhaar_number = '456789012345',
  pan_number = 'DEFGH4567I'
WHERE employee_id = 'EMP004';

UPDATE teacher_details 
SET 
  date_of_birth = '1992-11-20',
  gender = 'Male',
  address = '654, Mountain View, Sector 11',
  city = 'Dehradun',
  state = 'Uttarakhand',
  pincode = '248005',
  emergency_contact_name = 'Anjali Singh',
  emergency_contact_number = '+91 98765 00004',
  emergency_contact_relation = 'Mother',
  designation = 'Admin Manager',
  department = 'Administration',
  subject = 'General Administration',
  date_of_joining = '2021-03-15',
  employment_type = 'Permanent',
  reporting_to = 'EMP004',
  status = 'Active',
  highest_qualification = 'MBA in HR Management',
  university = 'Delhi University',
  passing_year = 2016,
  specialization = 'Human Resources',
  total_experience_years = 6,
  previous_employer_1 = 'STU Corporation',
  previous_role_1 = 'HR Executive',
  previous_duration_1 = '2016 - 2021',
  aadhaar_number = '567890123456',
  pan_number = 'EFGHI5678J'
WHERE employee_id = 'EMP005';

-- Success message
DO $$ 
BEGIN 
  RAISE NOTICE 'Teacher details table migration completed successfully!';
END $$;
