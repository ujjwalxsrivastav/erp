-- ============================================================================
-- DUAL-MODE ERP (COLLEGE + SCHOOL) - SUPABASE MIGRATION SCRIPT
-- ============================================================================

-- Step 1: Add institute_type to users table if not exists
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS institute_type TEXT DEFAULT 'college';

-- Step 2: Drop existing role check constraints so they don't block existing or new roles
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT c.conname
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE t.relname = 'users'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%role%'
    ) LOOP
        EXECUTE 'ALTER TABLE public.users DROP CONSTRAINT IF EXISTS ' || quote_ident(r.conname);
    END LOOP;
END $$;

-- Step 3: Add flexible check constraint with NOT VALID (so existing rows are NOT failed)
ALTER TABLE public.users ADD CONSTRAINT users_role_check 
    CHECK (
        LOWER(role) IN (
            'student', 'teacher', 'admin', 'staff', 'hr', 'hod', 
            'parent', 'accountant', 'librarian', 'transport', 'receptionist', 'principal'
        ) 
        OR role IN ('HR', 'HOD')
    ) NOT VALID;

-- Step 4: Insert / Seed Default School Users
INSERT INTO public.users (username, password, role, institute_type)
VALUES 
    ('sstudent1', 'sstudent1', 'student', 'school'),
    ('steacher1', 'steacher1', 'teacher', 'school'),
    ('sadmin1', 'sadmin1', 'admin', 'school'),
    ('parent1', 'parent1', 'parent', 'school')
ON CONFLICT (username) DO UPDATE 
SET 
    password = EXCLUDED.password,
    role = EXCLUDED.role,
    institute_type = EXCLUDED.institute_type;

-- Update existing college users to institute_type = 'college'
UPDATE public.users SET institute_type = 'college' WHERE institute_type IS NULL;

-- Step 5: Institutes table (Tenant Root)
CREATE TABLE IF NOT EXISTS institutes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('college', 'school')),
    address TEXT,
    logo_url TEXT,
    contact_email TEXT,
    contact_phone TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO institutes (code, name, type, address, contact_email)
VALUES 
    ('SHIV-COL', 'Shivalik College of Engineering', 'college', 'Dehradun, Uttarakhand', 'info@shivalik.org'),
    ('SHIV-SCH', 'Shivalik International School', 'school', 'Dehradun, Uttarakhand', 'school@shivalik.org')
ON CONFLICT (code) DO NOTHING;

-- Step 6: School Classes & Sections
CREATE TABLE IF NOT EXISTS school_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    name TEXT NOT NULL,             -- e.g. 'Class 10'
    section TEXT NOT NULL,          -- e.g. 'A'
    class_teacher_id TEXT,
    academic_year TEXT DEFAULT '2024-2025',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(name, section, academic_year)
);

INSERT INTO school_classes (name, section, academic_year)
VALUES 
    ('Class 9', 'A', '2024-2025'),
    ('Class 9', 'B', '2024-2025'),
    ('Class 10', 'A', '2024-2025'),
    ('Class 10', 'B', '2024-2025'),
    ('Class 11', 'Science', '2024-2025'),
    ('Class 11', 'Commerce', '2024-2025')
ON CONFLICT DO NOTHING;

-- Step 7: School Homework / Assignments
CREATE TABLE IF NOT EXISTS school_homework (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    subject TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    due_date DATE NOT NULL,
    teacher_username TEXT,
    attachment_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO school_homework (class_name, section, subject, title, description, due_date, teacher_username)
VALUES 
    ('Class 10', 'A', 'Mathematics', 'Chapter 5 Exercise 5.3', 'Complete questions 1 through 15', CURRENT_DATE + INTERVAL '2 days', 'steacher1'),
    ('Class 10', 'A', 'Science', 'Diagram of Human Heart', 'Draw and label 4 chambers on A4 sheet', CURRENT_DATE + INTERVAL '3 days', 'steacher1'),
    ('Class 10', 'A', 'English', 'Essay on Renewable Energy', '500 words essay with outline', CURRENT_DATE + INTERVAL '5 days', 'steacher1')
ON CONFLICT DO NOTHING;

-- Step 8: School Attendance
CREATE TABLE IF NOT EXISTS school_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    student_id TEXT NOT NULL,
    student_name TEXT,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    marked_by TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(student_id, date)
);

-- Step 9: School Marks & Gradebook
CREATE TABLE IF NOT EXISTS school_marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    student_id TEXT NOT NULL,
    student_name TEXT,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    subject TEXT NOT NULL,
    exam_type TEXT NOT NULL, -- 'Unit Test 1', 'Mid Term', 'Half Yearly', 'Annual'
    marks_obtained NUMERIC NOT NULL,
    total_marks NUMERIC NOT NULL,
    grade TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO school_marks (student_id, student_name, class_name, section, subject, exam_type, marks_obtained, total_marks, grade)
VALUES 
    ('sstudent1', 'Aarav Sharma', 'Class 10', 'A', 'Mathematics', 'Mid Term', 45, 50, 'A+'),
    ('sstudent1', 'Aarav Sharma', 'Class 10', 'A', 'Science', 'Mid Term', 38, 50, 'B+'),
    ('sstudent1', 'Aarav Sharma', 'Class 10', 'A', 'English', 'Mid Term', 42, 50, 'A'),
    ('sstudent1', 'Aarav Sharma', 'Class 10', 'A', 'Social Studies', 'Mid Term', 40, 50, 'A')
ON CONFLICT DO NOTHING;

-- Step 10: School Circulars & Notices
CREATE TABLE IF NOT EXISTS school_circulars (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'General', -- 'General', 'Exam', 'Fee', 'Event', 'Holiday'
    target_audience TEXT DEFAULT 'all',      -- 'all', 'parents', 'students', 'teachers'
    published_by TEXT,
    attachment_url TEXT,
    published_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO school_circulars (title, content, category, published_by)
VALUES 
    ('Annual Sports Day 2024', 'The Annual Sports Day will be held on 25th November. All students are encouraged to participate.', 'Event', 'Principal'),
    ('Half-Yearly Examination Schedule', 'Half-Yearly examinations commence from 10th December. Timetable published.', 'Exam', 'Exam Cell'),
    ('Winter Vacation Notice', 'School will observe winter break from 25th Dec to 5th Jan.', 'Holiday', 'Principal')
ON CONFLICT DO NOTHING;

-- Step 11: School Transport
CREATE TABLE IF NOT EXISTS school_transport (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    route_name TEXT NOT NULL,
    bus_number TEXT NOT NULL,
    driver_name TEXT NOT NULL,
    driver_phone TEXT NOT NULL,
    pickup_time TEXT,
    stops JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO school_transport (route_name, bus_number, driver_name, driver_phone, pickup_time, stops)
VALUES 
    ('Route A - North Sector', 'HR-01-2345', 'Ramesh Kumar', '9876543210', '07:30 AM', '["School", "Sector 14", "Sector 18", "Sector 22", "Sector 28"]'::jsonb),
    ('Route B - South Sector', 'HR-02-6789', 'Suresh Sharma', '9876543211', '07:45 AM', '["School", "Model Town", "Civil Lines", "Railway Station", "Patel Nagar"]'::jsonb)
ON CONFLICT DO NOTHING;

-- Step 12: School Admissions
CREATE TABLE IF NOT EXISTS school_admissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institute_code TEXT DEFAULT 'SHIV-SCH',
    student_name TEXT NOT NULL,
    parent_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    class_applying TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO school_admissions (student_name, parent_name, phone, class_applying, status)
VALUES 
    ('Rahul Mehta', 'Suresh Mehta', '9876500001', 'Class 6', 'pending'),
    ('Sanya Joshi', 'Rajan Joshi', '9876500002', 'Class 9', 'approved')
ON CONFLICT DO NOTHING;

-- Step 13: Parent Student Links
CREATE TABLE IF NOT EXISTS parent_student_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_username TEXT NOT NULL,
    student_username TEXT NOT NULL,
    relation TEXT DEFAULT 'parent',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(parent_username, student_username)
);

INSERT INTO parent_student_links (parent_username, student_username, relation)
VALUES 
    ('parent1', 'sstudent1', 'Father')
ON CONFLICT DO NOTHING;

-- Success verification


SELECT 'Dual-Mode ERP migration completed successfully!' AS result;



                                                                                  
                                                                                     