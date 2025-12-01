-- ============================================
-- TIMETABLE SYSTEM SETUP
-- ============================================
-- Run this in Supabase SQL Editor

-- 1. Create subjects table
CREATE TABLE IF NOT EXISTS subjects (
  subject_id TEXT PRIMARY KEY,
  subject_name TEXT NOT NULL,
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id),
  department TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create student_subjects table (mapping students to subjects/teachers)
CREATE TABLE IF NOT EXISTS student_subjects (
  id SERIAL PRIMARY KEY,
  student_id TEXT NOT NULL REFERENCES student_details(student_id),
  subject_id TEXT NOT NULL REFERENCES subjects(subject_id),
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_id, subject_id)
);

-- 3. Create timetable table
CREATE TABLE IF NOT EXISTS timetable (
  id SERIAL PRIMARY KEY,
  day_of_week TEXT NOT NULL CHECK (day_of_week IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday')),
  time_slot TEXT NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  subject_id TEXT NOT NULL REFERENCES subjects(subject_id),
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id),
  room_number TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(day_of_week, time_slot)
);

-- Enable RLS
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE timetable ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Allow all users to read
CREATE POLICY "Allow read access to all users" ON subjects FOR SELECT USING (true);
CREATE POLICY "Allow read access to all users" ON student_subjects FOR SELECT USING (true);
CREATE POLICY "Allow read access to all users" ON timetable FOR SELECT USING (true);

-- Insert subjects (5 subjects for 5 teachers)
INSERT INTO subjects (subject_id, subject_name, teacher_id, department) VALUES
('SUB001', 'Data Structures', 'teacher1', 'CSE'),
('SUB002', 'Database Management', 'teacher2', 'CSE'),
('SUB003', 'Operating Systems', 'teacher3', 'CSE'),
('SUB004', 'Computer Networks', 'teacher4', 'CSE'),
('SUB005', 'Artificial Intelligence', 'teacher5', 'CSE');

-- Map all 11 students to all 5 subjects (all students study all subjects)
INSERT INTO student_subjects (student_id, subject_id, teacher_id)
SELECT s.student_id, sub.subject_id, sub.teacher_id
FROM student_details s
CROSS JOIN subjects sub
WHERE s.student_id IN ('BT24CSE154', 'BT24CSE155', 'BT24CSE156', 'BT24CSE157', 'BT24CSE158', 
                       'BT24CSE159', 'BT24CSE160', 'BT24CSE161', 'BT24CSE162', 'BT24CSE163', 'BT24CSE164');

-- Create timetable (Monday to Friday, 5 lectures per day, 9 AM to 5 PM)
-- Each lecture is ~1.5 hours with breaks

-- MONDAY
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number) VALUES
('Monday', 'Slot 1', '09:00', '10:30', 'SUB001', 'teacher1', 'Room 101'),
('Monday', 'Slot 2', '10:45', '12:15', 'SUB002', 'teacher2', 'Room 102'),
('Monday', 'Slot 3', '13:00', '14:30', 'SUB003', 'teacher3', 'Room 103'),
('Monday', 'Slot 4', '14:45', '16:15', 'SUB004', 'teacher4', 'Room 104'),
('Monday', 'Slot 5', '16:30', '17:00', 'SUB005', 'teacher5', 'Room 105');

-- TUESDAY
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number) VALUES
('Tuesday', 'Slot 1', '09:00', '10:30', 'SUB003', 'teacher3', 'Room 103'),
('Tuesday', 'Slot 2', '10:45', '12:15', 'SUB005', 'teacher5', 'Room 105'),
('Tuesday', 'Slot 3', '13:00', '14:30', 'SUB001', 'teacher1', 'Room 101'),
('Tuesday', 'Slot 4', '14:45', '16:15', 'SUB002', 'teacher2', 'Room 102'),
('Tuesday', 'Slot 5', '16:30', '17:00', 'SUB004', 'teacher4', 'Room 104');

-- WEDNESDAY
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number) VALUES
('Wednesday', 'Slot 1', '09:00', '10:30', 'SUB002', 'teacher2', 'Room 102'),
('Wednesday', 'Slot 2', '10:45', '12:15', 'SUB004', 'teacher4', 'Room 104'),
('Wednesday', 'Slot 3', '13:00', '14:30', 'SUB005', 'teacher5', 'Room 105'),
('Wednesday', 'Slot 4', '14:45', '16:15', 'SUB001', 'teacher1', 'Room 101'),
('Wednesday', 'Slot 5', '16:30', '17:00', 'SUB003', 'teacher3', 'Room 103');

-- THURSDAY
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number) VALUES
('Thursday', 'Slot 1', '09:00', '10:30', 'SUB004', 'teacher4', 'Room 104'),
('Thursday', 'Slot 2', '10:45', '12:15', 'SUB001', 'teacher1', 'Room 101'),
('Thursday', 'Slot 3', '13:00', '14:30', 'SUB002', 'teacher2', 'Room 102'),
('Thursday', 'Slot 4', '14:45', '16:15', 'SUB005', 'teacher5', 'Room 105'),
('Thursday', 'Slot 5', '16:30', '17:00', 'SUB003', 'teacher3', 'Room 103');

-- FRIDAY
INSERT INTO timetable (day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number) VALUES
('Friday', 'Slot 1', '09:00', '10:30', 'SUB005', 'teacher5', 'Room 105'),
('Friday', 'Slot 2', '10:45', '12:15', 'SUB003', 'teacher3', 'Room 103'),
('Friday', 'Slot 3', '13:00', '14:30', 'SUB004', 'teacher4', 'Room 104'),
('Friday', 'Slot 4', '14:45', '16:15', 'SUB003', 'teacher3', 'Room 103'),
('Friday', 'Slot 5', '16:30', '17:00', 'SUB001', 'teacher1', 'Room 101');

COMMENT ON TABLE subjects IS 'Stores subject information with assigned teachers';
COMMENT ON TABLE student_subjects IS 'Maps students to subjects and teachers';
COMMENT ON TABLE timetable IS 'Weekly timetable for all classes';
