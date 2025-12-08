-- ============================================
-- COMPLETE FIX FOR TEACHER_DETAILS TABLE
-- ============================================
-- This script will:
-- 1. Fix RLS policies
-- 2. Insert teacher data
-- Run this ONCE in Supabase SQL Editor

-- ============================================
-- STEP 1: FIX RLS POLICIES
-- ============================================

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow read access to all users" ON teacher_details;
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON teacher_details;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON teacher_details;
DROP POLICY IF EXISTS "Allow teachers to update own details" ON teacher_details;
DROP POLICY IF EXISTS "Enable update for teachers on own record" ON teacher_details;
DROP POLICY IF EXISTS "Allow HR and Admin full access" ON teacher_details;
DROP POLICY IF EXISTS "Enable full access for HR and Admin" ON teacher_details;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON teacher_details;
DROP POLICY IF EXISTS "teacher_details_select_policy" ON teacher_details;
DROP POLICY IF EXISTS "teacher_details_insert_policy" ON teacher_details;
DROP POLICY IF EXISTS "teacher_details_update_policy" ON teacher_details;
DROP POLICY IF EXISTS "teacher_details_delete_policy" ON teacher_details;

-- Enable RLS
ALTER TABLE teacher_details ENABLE ROW LEVEL SECURITY;

-- Create simple, permissive policies
CREATE POLICY "teacher_details_select_policy"
ON teacher_details FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "teacher_details_insert_policy"
ON teacher_details FOR INSERT
TO authenticated
WITH CHECK (true);

CREATE POLICY "teacher_details_update_policy"
ON teacher_details FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "teacher_details_delete_policy"
ON teacher_details FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- STEP 2: CLEAR EXISTING DATA (if any)
-- ============================================
-- This ensures no duplicate data
TRUNCATE TABLE teacher_details CASCADE;

-- ============================================
-- STEP 3: INSERT TEACHER DATA
-- ============================================

INSERT INTO teacher_details (
  teacher_id, name, employee_id, subject, department, phone, email, qualification,
  date_of_birth, gender, address, city, state, pincode,
  emergency_contact_name, emergency_contact_number, emergency_contact_relation,
  designation, date_of_joining, employment_type, reporting_to, status,
  highest_qualification, university, passing_year, specialization,
  total_experience_years,
  previous_employer_1, previous_role_1, previous_duration_1,
  previous_employer_2, previous_role_2, previous_duration_2,
  aadhaar_number, pan_number
) VALUES
(
  'teacher1', 'Dr. Rajesh Kumar', 'EMP001', 'Data Structures', 'CSE', 
  '+91-9876543210', 'rajesh.kumar@shivalik.edu', 'PhD in Computer Science',
  '1985-01-15', 'Male', '123, Green Valley, Sector 5', 'Dehradun', 'Uttarakhand', '248001',
  'Ravi Kumar', '+91 98765 00000', 'Brother',
  'Professor', '2018-08-01', 'Permanent', NULL, 'Active',
  'Ph.D. in Computer Science', 'IIT Delhi', 2015, 'Algorithms & Data Structures',
  12,
  'ABC University', 'Associate Professor', '2015 - 2018',
  'XYZ Institute', 'Assistant Professor', '2012 - 2015',
  '123456789012', 'ABCDE1234F'
),
(
  'teacher2', 'Prof. Priya Sharma', 'EMP002', 'Database Management', 'CSE',
  '+91-9876543211', 'priya.sharma@shivalik.edu', 'M.Tech in CSE',
  '1988-03-22', 'Female', '456, Park Avenue, Sector 7', 'Dehradun', 'Uttarakhand', '248002',
  'Rahul Sharma', '+91 98765 00001', 'Husband',
  'Associate Professor', '2019-07-15', 'Permanent', 'EMP001', 'Active',
  'Ph.D. in Electronics', 'NIT Trichy', 2017, 'VLSI Design',
  10,
  'DEF College', 'Assistant Professor', '2017 - 2019',
  'GHI University', 'Lecturer', '2014 - 2017',
  '234567890123', 'BCDEF2345G'
),
(
  'teacher3', 'Dr. Amit Verma', 'EMP003', 'Operating Systems', 'CSE',
  '+91-9876543212', 'amit.verma@shivalik.edu', 'PhD in Software Engineering',
  '1990-06-10', 'Male', '789, Hill View, Sector 3', 'Dehradun', 'Uttarakhand', '248003',
  'Sunita Verma', '+91 98765 00002', 'Wife',
  'Assistant Professor', '2020-01-10', 'Permanent', 'EMP001', 'On Leave',
  'M.Tech in Mechanical Engineering', 'IIT Roorkee', 2018, 'Thermal Engineering',
  8,
  'JKL Institute', 'Lecturer', '2018 - 2020',
  NULL, NULL, NULL,
  '345678901234', 'CDEFG3456H'
),
(
  'teacher4', 'Prof. Neha Gupta', 'EMP004', 'Computer Networks', 'CSE',
  '+91-9876543213', 'neha.gupta@shivalik.edu', 'M.Tech in Networks',
  '1982-09-05', 'Female', '321, Lake Side, Sector 9', 'Dehradun', 'Uttarakhand', '248004',
  'Kiran Patel', '+91 98765 00003', 'Sister',
  'HOD', '2015-06-01', 'Permanent', NULL, 'Active',
  'Ph.D. in Computer Science', 'IIT Bombay', 2012, 'Software Engineering',
  15,
  'MNO University', 'Professor', '2012 - 2015',
  'PQR College', 'Associate Professor', '2009 - 2012',
  '456789012345', 'DEFGH4567I'
),
(
  'teacher5', 'Dr. Vikram Singh', 'EMP005', 'General Administration', 'Administration',
  '+91-9876543214', 'vikram.singh@shivalik.edu', 'PhD in AI & ML',
  '1992-11-20', 'Male', '654, Mountain View, Sector 11', 'Dehradun', 'Uttarakhand', '248005',
  'Anjali Singh', '+91 98765 00004', 'Mother',
  'Admin Manager', '2021-03-15', 'Permanent', 'EMP004', 'Active',
  'MBA in HR Management', 'Delhi University', 2016, 'Human Resources',
  6,
  'STU Corporation', 'HR Executive', '2016 - 2021',
  NULL, NULL, NULL,
  '567890123456', 'EFGHI5678J'
),
(
  'teacher6', 'Ujjwal Srivastav', 'EMP006', 'DSA', 'CSE',
  '8881068415', 'ujjwalsvs123@gmail.com', 'Btech',
  NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL,
  'Professor', NULL, NULL, NULL, 'Active',
  NULL, NULL, NULL, NULL,
  NULL,
  NULL, NULL, NULL,
  NULL, NULL, NULL,
  NULL, NULL
);

-- ============================================
-- STEP 4: VERIFICATION
-- ============================================

-- Check record count
DO $$
DECLARE
  record_count INTEGER;
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO record_count FROM teacher_details;
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'teacher_details';
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅ TEACHER_DETAILS SETUP COMPLETE!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 Total Teachers: %', record_count;
  RAISE NOTICE '🔐 RLS Policies: %', policy_count;
  RAISE NOTICE '';
  
  IF record_count >= 5 THEN
    RAISE NOTICE '✅ Data inserted successfully!';
  ELSE
    RAISE NOTICE '⚠️ Expected at least 5 teachers, found %', record_count;
  END IF;
  
  IF policy_count >= 4 THEN
    RAISE NOTICE '✅ RLS policies configured correctly!';
  ELSE
    RAISE NOTICE '⚠️ Expected 4 policies, found %', policy_count;
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '👉 Now test in your Flutter app!';
  RAISE NOTICE '========================================';
END $$;

-- Show sample data
SELECT 
  teacher_id,
  name,
  employee_id,
  department,
  designation,
  status
FROM teacher_details
ORDER BY employee_id;
