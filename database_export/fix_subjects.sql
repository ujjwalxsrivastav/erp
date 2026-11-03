-- ============================================
-- FIX: Insert subjects data
-- Run this in Supabase SQL Editor
-- ============================================

-- Insert subjects for each teacher
INSERT INTO subjects (subject_id, subject_name, teacher_id, department, created_at) VALUES
('SUB001', 'Data Structures', 'teacher1', 'CSE', NOW()),
('SUB002', 'Database Management', 'teacher2', 'CSE', NOW()),
('SUB003', 'Operating Systems', 'teacher3', 'CSE', NOW()),
('SUB004', 'Computer Networks', 'teacher4', 'CSE', NOW()),
('SUB005', 'Artificial Intelligence', 'teacher5', 'CSE', NOW()),
('SUB006', 'DSA', 'teacher6', 'CSE', NOW())
ON CONFLICT (subject_id) DO NOTHING;

-- Map students to subjects (Year 1 Section A students to all subjects)
INSERT INTO student_subjects (student_id, subject_id, teacher_id)
SELECT sd.student_id, s.subject_id, s.teacher_id
FROM student_details sd
CROSS JOIN subjects s
WHERE sd.year = 1 AND sd.section = 'A'
ON CONFLICT (student_id, subject_id) DO NOTHING;

-- Map students to subjects (Year 1 Section B students to all subjects)
INSERT INTO student_subjects (student_id, subject_id, teacher_id)
SELECT sd.student_id, s.subject_id, s.teacher_id
FROM student_details sd
CROSS JOIN subjects s
WHERE sd.year = 1 AND sd.section = 'B'
ON CONFLICT (student_id, subject_id) DO NOTHING;

-- Verify
SELECT COUNT(*) as total_subjects FROM subjects;
SELECT COUNT(*) as total_mappings FROM student_subjects;

-- Show all subjects
SELECT * FROM subjects;
