-- ============================================
-- TEACHER DETAILS TABLE SETUP
-- ============================================
-- Run this in Supabase SQL Editor

-- Create teacher_details table
CREATE TABLE IF NOT EXISTS teacher_details (
  teacher_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  employee_id TEXT UNIQUE NOT NULL,
  subject TEXT NOT NULL,
  department TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  qualification TEXT,
  profile_photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE teacher_details ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow all users to read teacher details
CREATE POLICY "Allow read access to all users"
ON teacher_details FOR SELECT
USING (true);

-- RLS Policy: Allow teachers to update their own details
CREATE POLICY "Allow teachers to update own details"
ON teacher_details FOR UPDATE
USING (teacher_id = current_user);

-- Insert sample data for teacher1 to teacher5 (Indian names)
INSERT INTO teacher_details (teacher_id, name, employee_id, subject, department, phone, email, qualification, profile_photo_url) VALUES
('teacher1', 'Dr. Rajesh Kumar', 'EMP001', 'Data Structures', 'CSE', '+91-9876543210', 'rajesh.kumar@shivalik.edu', 'PhD in Computer Science', NULL),
('teacher2', 'Prof. Priya Sharma', 'EMP002', 'Database Management', 'CSE', '+91-9876543211', 'priya.sharma@shivalik.edu', 'M.Tech in CSE', NULL),
('teacher3', 'Dr. Amit Verma', 'EMP003', 'Operating Systems', 'CSE', '+91-9876543212', 'amit.verma@shivalik.edu', 'PhD in Software Engineering', NULL),
('teacher4', 'Prof. Neha Gupta', 'EMP004', 'Computer Networks', 'CSE', '+91-9876543213', 'neha.gupta@shivalik.edu', 'M.Tech in Networks', NULL),
('teacher5', 'Dr. Vikram Singh', 'EMP005', 'Artificial Intelligence', 'CSE', '+91-9876543214', 'vikram.singh@shivalik.edu', 'PhD in AI & ML', NULL);

-- Create storage bucket for teacher profile photos
-- Note: Run this in Supabase Dashboard > Storage
-- Bucket name: teacher-profiles
-- Public: Yes
-- File size limit: 5MB
-- Allowed MIME types: image/*

COMMENT ON TABLE teacher_details IS 'Stores teacher profile information';
