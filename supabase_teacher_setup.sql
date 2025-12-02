-- ============================================
-- COMPREHENSIVE TEACHER/STAFF DETAILS TABLE
-- ============================================
-- Run this in Supabase SQL Editor

-- Drop existing table if you want to recreate (CAREFUL!)
-- DROP TABLE IF EXISTS teacher_details CASCADE;

-- Create enhanced teacher_details table with all HR information
CREATE TABLE IF NOT EXISTS teacher_details (
  -- Primary Keys
  teacher_id TEXT PRIMARY KEY,
  employee_id TEXT UNIQUE NOT NULL,
  
  -- Basic Information
  name TEXT NOT NULL,
  date_of_birth DATE,
  gender TEXT CHECK (gender IN ('Male', 'Female', 'Other')),
  
  -- Contact Information
  phone TEXT,
  email TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  pincode TEXT,
  
  -- Emergency Contact
  emergency_contact_name TEXT,
  emergency_contact_number TEXT,
  emergency_contact_relation TEXT,
  
  -- Professional Information
  designation TEXT NOT NULL, -- Professor, Associate Professor, Assistant Professor, Lecturer, HOD
  department TEXT NOT NULL,
  subject TEXT,
  date_of_joining DATE,
  employment_type TEXT CHECK (employment_type IN ('Permanent', 'Contract', 'Visiting', 'Guest')),
  reporting_to TEXT, -- Employee ID of reporting manager
  status TEXT DEFAULT 'Active' CHECK (status IN ('Active', 'On Leave', 'Resigned', 'Terminated', 'Retired')),
  
  -- Education & Qualifications
  highest_qualification TEXT,
  university TEXT,
  passing_year INTEGER,
  specialization TEXT,
  
  -- Experience
  total_experience_years INTEGER,
  previous_employer_1 TEXT,
  previous_role_1 TEXT,
  previous_duration_1 TEXT,
  previous_employer_2 TEXT,
  previous_role_2 TEXT,
  previous_duration_2 TEXT,
  previous_employer_3 TEXT,
  previous_role_3 TEXT,
  previous_duration_3 TEXT,
  
  -- Documents (URLs to uploaded documents)
  aadhaar_url TEXT,
  pan_url TEXT,
  degree_certificate_url TEXT,
  experience_letter_url TEXT,
  offer_letter_url TEXT,
  joining_letter_url TEXT,
  profile_photo_url TEXT,
  resume_url TEXT,
  
  -- Document Numbers
  aadhaar_number TEXT,
  pan_number TEXT,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by TEXT,
  updated_by TEXT
);

-- Enable Row Level Security
ALTER TABLE teacher_details ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow all authenticated users to read teacher details
CREATE POLICY "Allow read access to authenticated users"
ON teacher_details FOR SELECT
TO authenticated
USING (true);

-- RLS Policy: Allow teachers to update their own details
CREATE POLICY "Allow teachers to update own details"
ON teacher_details FOR UPDATE
TO authenticated
USING (teacher_id = current_user);

-- RLS Policy: Allow HR and Admin to insert/update/delete
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

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_teacher_employee_id ON teacher_details(employee_id);
CREATE INDEX IF NOT EXISTS idx_teacher_department ON teacher_details(department);
CREATE INDEX IF NOT EXISTS idx_teacher_status ON teacher_details(status);
CREATE INDEX IF NOT EXISTS idx_teacher_email ON teacher_details(email);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_teacher_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER teacher_details_updated_at
BEFORE UPDATE ON teacher_details
FOR EACH ROW
EXECUTE FUNCTION update_teacher_updated_at();

-- Insert comprehensive sample data
INSERT INTO teacher_details (
  teacher_id, employee_id, name, date_of_birth, gender,
  phone, email, address, city, state, pincode,
  emergency_contact_name, emergency_contact_number, emergency_contact_relation,
  designation, department, subject, date_of_joining, employment_type, reporting_to, status,
  highest_qualification, university, passing_year, specialization,
  total_experience_years,
  previous_employer_1, previous_role_1, previous_duration_1,
  previous_employer_2, previous_role_2, previous_duration_2,
  aadhaar_number, pan_number
) VALUES
(
  'teacher1', 'EMP001', 'Dr. Rajesh Kumar', '1985-01-15', 'Male',
  '+91 98765 43210', 'rajesh.kumar@shivalik.edu', 
  '123, Green Valley, Sector 5', 'Dehradun', 'Uttarakhand', '248001',
  'Ravi Kumar', '+91 98765 00000', 'Brother',
  'Professor', 'Computer Science', 'Data Structures', '2018-08-01', 'Permanent', NULL, 'Active',
  'Ph.D. in Computer Science', 'IIT Delhi', 2015, 'Algorithms & Data Structures',
  12,
  'ABC University', 'Associate Professor', '2015 - 2018',
  'XYZ Institute', 'Assistant Professor', '2012 - 2015',
  '123456789012', 'ABCDE1234F'
),
(
  'teacher2', 'EMP002', 'Dr. Priya Sharma', '1988-03-22', 'Female',
  '+91 98765 43211', 'priya.sharma@shivalik.edu',
  '456, Park Avenue, Sector 7', 'Dehradun', 'Uttarakhand', '248002',
  'Rahul Sharma', '+91 98765 00001', 'Husband',
  'Associate Professor', 'Electronics', 'Digital Electronics', '2019-07-15', 'Permanent', 'EMP001', 'Active',
  'Ph.D. in Electronics', 'NIT Trichy', 2017, 'VLSI Design',
  10,
  'DEF College', 'Assistant Professor', '2017 - 2019',
  'GHI University', 'Lecturer', '2014 - 2017',
  '234567890123', 'BCDEF2345G'
),
(
  'teacher3', 'EMP003', 'Prof. Amit Verma', '1990-06-10', 'Male',
  '+91 98765 43212', 'amit.verma@shivalik.edu',
  '789, Hill View, Sector 3', 'Dehradun', 'Uttarakhand', '248003',
  'Sunita Verma', '+91 98765 00002', 'Wife',
  'Assistant Professor', 'Mechanical', 'Thermodynamics', '2020-01-10', 'Permanent', 'EMP001', 'On Leave',
  'M.Tech in Mechanical Engineering', 'IIT Roorkee', 2018, 'Thermal Engineering',
  8,
  'JKL Institute', 'Lecturer', '2018 - 2020',
  NULL, NULL, NULL,
  '345678901234', 'CDEFG3456H'
),
(
  'teacher4', 'EMP004', 'Dr. Sneha Patel', '1982-09-05', 'Female',
  '+91 98765 43213', 'sneha.patel@shivalik.edu',
  '321, Lake Side, Sector 9', 'Dehradun', 'Uttarakhand', '248004',
  'Kiran Patel', '+91 98765 00003', 'Sister',
  'HOD', 'Computer Science', 'Software Engineering', '2015-06-01', 'Permanent', NULL, 'Active',
  'Ph.D. in Computer Science', 'IIT Bombay', 2012, 'Software Engineering',
  15,
  'MNO University', 'Professor', '2012 - 2015',
  'PQR College', 'Associate Professor', '2009 - 2012',
  '456789012345', 'DEFGH4567I'
),
(
  'teacher5', 'EMP005', 'Mr. Vikram Singh', '1992-11-20', 'Male',
  '+91 98765 43214', 'vikram.singh@shivalik.edu',
  '654, Mountain View, Sector 11', 'Dehradun', 'Uttarakhand', '248005',
  'Anjali Singh', '+91 98765 00004', 'Mother',
  'Admin Manager', 'Administration', 'General Administration', '2021-03-15', 'Permanent', 'EMP004', 'Active',
  'MBA in HR Management', 'Delhi University', 2016, 'Human Resources',
  6,
  'STU Corporation', 'HR Executive', '2016 - 2021',
  NULL, NULL, NULL,
  '567890123456', 'EFGHI5678J'
);

-- Create storage bucket for teacher documents
-- Note: Run this in Supabase Dashboard > Storage
-- Bucket name: teacher-documents
-- Public: No (Private)
-- File size limit: 10MB
-- Allowed MIME types: image/*, application/pdf

COMMENT ON TABLE teacher_details IS 'Comprehensive teacher/staff profile information with all HR details';
