-- ============================================
-- SIMPLE FIX: Just Add Teacher Data
-- ============================================
-- Run ONLY this in Supabase SQL Editor

-- Insert sample teachers
INSERT INTO teacher_details (
  teacher_id,
  employee_id,
  name,
  gender,
  phone,
  email,
  department,
  designation,
  subject,
  status
) VALUES
('teacher1', 'teacher1', 'Dr. Rajesh Kumar', 'Male', '+91 98765 43210', 'rajesh.kumar@shivalik.edu', 'Computer Science', 'Professor', 'Data Structures', 'Active'),
('teacher2', 'teacher2', 'Dr. Priya Sharma', 'Female', '+91 98765 43211', 'priya.sharma@shivalik.edu', 'Mathematics', 'Associate Professor', 'Calculus', 'Active'),
('teacher3', 'teacher3', 'Mr. Amit Verma', 'Male', '+91 98765 43212', 'amit.verma@shivalik.edu', 'Physics', 'Assistant Professor', 'Quantum Mechanics', 'Active'),
('teacher4', 'teacher4', 'Ms. Neha Gupta', 'Female', '+91 98765 43213', 'neha.gupta@shivalik.edu', 'English', 'Lecturer', 'Literature', 'Active'),
('teacher5', 'teacher5', 'Dr. Suresh Patel', 'Male', '+91 98765 43214', 'suresh.patel@shivalik.edu', 'Chemistry', 'Professor', 'Organic Chemistry', 'Active')
ON CONFLICT (teacher_id) DO NOTHING;

-- Verify
SELECT teacher_id, employee_id, name, department FROM teacher_details;
