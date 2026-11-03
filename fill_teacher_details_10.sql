-- ============================================================
-- TEACHER DETAILS - 10 Teachers ke liye Complete Data
-- Supabase SQL Editor mein run karo
-- RLS bypass ke liye SET session_replication_role = 'replica';
-- ============================================================

-- STEP 1: RLS bypass (Supabase superuser mode)
SET session_replication_role = 'replica';

-- STEP 2: Add teacher7 to teacher10 in users table
INSERT INTO "public"."users" ("username", "password", "role", "failed_login_count", "require_password_change")
VALUES 
  ('teacher7', 'teacher7', 'teacher', 0, false),
  ('teacher8', 'teacher8', 'teacher', 0, false),
  ('teacher9', 'teacher9', 'teacher', 0, false),
  ('teacher10', 'teacher10', 'teacher', 0, false)
ON CONFLICT (username) DO NOTHING;

-- STEP 3: teacher_details table fill karo (10 teachers)
INSERT INTO "public"."teacher_details" (
  "teacher_id", "employee_id", "name", "date_of_birth", "gender",
  "phone", "email", "address", "city", "state", "pincode",
  "emergency_contact_name", "emergency_contact_number", "emergency_contact_relation",
  "designation", "department", "subject", "date_of_joining", "employment_type", "reporting_to", "status",
  "highest_qualification", "university", "passing_year", "specialization",
  "total_experience_years",
  "previous_employer_1", "previous_role_1", "previous_duration_1",
  "previous_employer_2", "previous_role_2", "previous_duration_2",
  "aadhaar_number", "pan_number",
  "created_at", "updated_at"
)
VALUES 
(
  'teacher1', 'EMP001', 'Dr. Rajesh Kumar', '1985-01-15', 'Male',
  '+91-9876543210', 'rajesh.kumar@shivalik.edu', '123, Green Valley, Sector 5', 'Dehradun', 'Uttarakhand', '248001',
  'Ravi Kumar', '+91-9812300001', 'Brother',
  'Professor', 'CSE', 'Data Structures & Algorithms', '2018-08-01', 'Permanent', null, 'Active',
  'Ph.D. in Computer Science', 'IIT Delhi', 2015, 'Algorithms & Data Structures',
  12,
  'ABC University', 'Associate Professor', '2015 - 2018',
  'XYZ Institute', 'Assistant Professor', '2012 - 2015',
  '123456789012', 'ABCDE1234F',
  NOW(), NOW()
),
(
  'teacher2', 'EMP002', 'Prof. Priya Sharma', '1988-03-22', 'Female',
  '+91-9876543211', 'priya.sharma@shivalik.edu', '456, Park Avenue, Sector 7', 'Dehradun', 'Uttarakhand', '248002',
  'Rahul Sharma', '+91-9812300002', 'Husband',
  'Associate Professor', 'CSE', 'Database Management Systems', '2019-07-15', 'Permanent', 'EMP001', 'Active',
  'Ph.D. in Computer Science', 'NIT Trichy', 2017, 'Database Systems',
  10,
  'DEF College', 'Assistant Professor', '2017 - 2019',
  'GHI University', 'Lecturer', '2014 - 2017',
  '234567890123', 'BCDEF2345G',
  NOW(), NOW()
),
(
  'teacher3', 'EMP003', 'Dr. Amit Verma', '1990-06-10', 'Male',
  '+91-9876543212', 'amit.verma@shivalik.edu', '789, Hill View, Sector 3', 'Dehradun', 'Uttarakhand', '248003',
  'Sunita Verma', '+91-9812300003', 'Wife',
  'Assistant Professor', 'CSE', 'Operating Systems', '2020-01-10', 'Permanent', 'EMP001', 'Active',
  'Ph.D. in Software Engineering', 'IIT Roorkee', 2018, 'Distributed Systems',
  8,
  'JKL Institute', 'Lecturer', '2018 - 2020',
  null, null, null,
  '345678901234', 'CDEFG3456H',
  NOW(), NOW()
),
(
  'teacher4', 'EMP004', 'Prof. Neha Gupta', '1982-09-05', 'Female',
  '+91-9876543213', 'neha.gupta@shivalik.edu', '321, Lake Side, Sector 9', 'Dehradun', 'Uttarakhand', '248004',
  'Kiran Patel', '+91-9812300004', 'Sister',
  'HOD', 'CSE', 'Computer Networks', '2015-06-01', 'Permanent', null, 'Active',
  'Ph.D. in Computer Science', 'IIT Bombay', 2012, 'Network Security',
  15,
  'MNO University', 'Professor', '2012 - 2015',
  'PQR College', 'Associate Professor', '2009 - 2012',
  '456789012345', 'DEFGH4567I',
  NOW(), NOW()
),
(
  'teacher5', 'EMP005', 'Dr. Vikram Singh', '1992-11-20', 'Male',
  '+91-9876543214', 'vikram.singh@shivalik.edu', '654, Mountain View, Sector 11', 'Dehradun', 'Uttarakhand', '248005',
  'Anjali Singh', '+91-9812300005', 'Mother',
  'Assistant Professor', 'CSE', 'Artificial Intelligence', '2021-03-15', 'Permanent', 'EMP004', 'Active',
  'Ph.D. in Artificial Intelligence', 'IIT Hyderabad', 2019, 'Machine Learning',
  6,
  'STU Research Lab', 'Research Scientist', '2019 - 2021',
  null, null, null,
  '567890123456', 'EFGHI5678J',
  NOW(), NOW()
),
(
  'teacher6', 'EMP006', 'Prof. Sunita Rawat', '1987-04-18', 'Female',
  '+91-9876543215', 'sunita.rawat@shivalik.edu', '987, River View, Sector 2', 'Haridwar', 'Uttarakhand', '249401',
  'Mohan Rawat', '+91-9812300006', 'Father',
  'Associate Professor', 'BSH', 'Mathematics', '2017-08-20', 'Permanent', 'EMP004', 'Active',
  'M.Phil in Applied Mathematics', 'HNB Garhwal University', 2013, 'Applied Mathematics',
  9,
  'VWX College', 'Lecturer', '2013 - 2017',
  null, null, null,
  '678901234567', 'FGHIJ6789K',
  NOW(), NOW()
),
(
  'teacher7', 'EMP007', 'Dr. Arun Tiwari', '1983-07-25', 'Male',
  '+91-9876543216', 'arun.tiwari@shivalik.edu', '246, Tech Park, Sector 14', 'Dehradun', 'Uttarakhand', '248007',
  'Kavita Tiwari', '+91-9812300007', 'Wife',
  'Assistant Professor', 'BSH', 'Engineering Physics', '2016-09-01', 'Permanent', 'EMP001', 'Active',
  'Ph.D. in Applied Physics', 'BHU Varanasi', 2014, 'Quantum Physics',
  10,
  'YZA University', 'Research Fellow', '2014 - 2016',
  'BCD Institute', 'Demonstrator', '2012 - 2014',
  '789012345678', 'GHIJK7890L',
  NOW(), NOW()
),
(
  'teacher8', 'EMP008', 'Prof. Meena Joshi', '1986-12-08', 'Female',
  '+91-9876543217', 'meena.joshi@shivalik.edu', '135, Green Meadows, Sector 6', 'Rishikesh', 'Uttarakhand', '249201',
  'Govind Joshi', '+91-9812300008', 'Husband',
  'Assistant Professor', 'BSH', 'English & Communication Skills', '2019-01-07', 'Permanent', 'EMP001', 'Active',
  'M.Phil in English', 'Allahabad University', 2012, 'Communication Skills',
  11,
  'EFG College', 'Lecturer', '2012 - 2019',
  null, null, null,
  '890123456789', 'HIJKL8901M',
  NOW(), NOW()
),
(
  'teacher9', 'EMP009', 'Dr. Rohit Pandey', '1989-02-14', 'Male',
  '+91-9876543218', 'rohit.pandey@shivalik.edu', '753, Valley Road, Sector 16', 'Dehradun', 'Uttarakhand', '248009',
  'Rekha Pandey', '+91-9812300009', 'Mother',
  'Associate Professor', 'ECE', 'Electronics & Circuits', '2018-06-01', 'Permanent', 'EMP004', 'Active',
  'Ph.D. in Electronics', 'NIT Allahabad', 2016, 'VLSI & Embedded Systems',
  8,
  'HIJ Technologies', 'Design Engineer', '2016 - 2018',
  null, null, null,
  '901234567890', 'IJKLM9012N',
  NOW(), NOW()
),
(
  'teacher10', 'EMP010', 'Prof. Anita Bisht', '1991-08-30', 'Female',
  '+91-9876543219', 'anita.bisht@shivalik.edu', '864, Pine Grove, Sector 18', 'Dehradun', 'Uttarakhand', '248010',
  'Suresh Bisht', '+91-9812300010', 'Father',
  'Assistant Professor', 'CSE', 'Software Engineering', '2022-01-15', 'Contract', 'EMP001', 'Active',
  'M.Tech in Software Engineering', 'MNIT Jaipur', 2015, 'Agile Development & DevOps',
  7,
  'KLM Infosystems', 'Software Developer', '2015 - 2020',
  'NOP Solutions', 'Senior Developer', '2020 - 2022',
  '012345678901', 'JKLMN0123O',
  NOW(), NOW()
)
ON CONFLICT (teacher_id) DO UPDATE SET
  employee_id = EXCLUDED.employee_id,
  name = EXCLUDED.name,
  date_of_birth = EXCLUDED.date_of_birth,
  gender = EXCLUDED.gender,
  phone = EXCLUDED.phone,
  email = EXCLUDED.email,
  address = EXCLUDED.address,
  city = EXCLUDED.city,
  state = EXCLUDED.state,
  pincode = EXCLUDED.pincode,
  emergency_contact_name = EXCLUDED.emergency_contact_name,
  emergency_contact_number = EXCLUDED.emergency_contact_number,
  emergency_contact_relation = EXCLUDED.emergency_contact_relation,
  designation = EXCLUDED.designation,
  department = EXCLUDED.department,
  subject = EXCLUDED.subject,
  date_of_joining = EXCLUDED.date_of_joining,
  employment_type = EXCLUDED.employment_type,
  reporting_to = EXCLUDED.reporting_to,
  status = EXCLUDED.status,
  highest_qualification = EXCLUDED.highest_qualification,
  university = EXCLUDED.university,
  passing_year = EXCLUDED.passing_year,
  specialization = EXCLUDED.specialization,
  total_experience_years = EXCLUDED.total_experience_years,
  previous_employer_1 = EXCLUDED.previous_employer_1,
  previous_role_1 = EXCLUDED.previous_role_1,
  previous_duration_1 = EXCLUDED.previous_duration_1,
  previous_employer_2 = EXCLUDED.previous_employer_2,
  previous_role_2 = EXCLUDED.previous_role_2,
  previous_duration_2 = EXCLUDED.previous_duration_2,
  aadhaar_number = EXCLUDED.aadhaar_number,
  pan_number = EXCLUDED.pan_number,
  updated_at = NOW();

-- STEP 4: RLS wapas on karo
SET session_replication_role = 'DEFAULT';

-- Verify karo
SELECT teacher_id, name, employee_id, designation, department, status 
FROM teacher_details 
ORDER BY employee_id;
