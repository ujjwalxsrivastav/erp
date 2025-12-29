-- ============================================
-- DATA MIGRATION: OLD TABLES → UNIFIED TABLE
-- ============================================
-- Run this AFTER running 01_create_unified_marks_table.sql
-- This migrates all existing data from 32 separate tables to student_marks

-- ============================================
-- YEAR 1 - SECTION A
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'A', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectiona_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'A', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectiona_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'A', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectiona_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'A', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectiona_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 1 - SECTION B
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'B', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectionb_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'B', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectionb_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'B', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectionb_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 1, 'B', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year1_sectionb_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 2 - SECTION A
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'A', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectiona_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'A', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectiona_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'A', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectiona_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'A', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectiona_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 2 - SECTION B
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'B', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectionb_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'B', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectionb_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'B', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectionb_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 2, 'B', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year2_sectionb_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 3 - SECTION A
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'A', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectiona_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'A', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectiona_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'A', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectiona_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'A', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectiona_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 3 - SECTION B
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'B', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectionb_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'B', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectionb_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'B', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectionb_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 3, 'B', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year3_sectionb_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 4 - SECTION A
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'A', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectiona_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'A', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectiona_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'A', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectiona_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'A', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectiona_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- YEAR 4 - SECTION B
-- ============================================

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'B', 'midterm', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectionb_midterm
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'B', 'endsem', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectionb_endsem
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'B', 'quiz', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectionb_quiz
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

INSERT INTO student_marks (student_id, subject_id, teacher_id, year, section, exam_type, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at)
SELECT student_id, subject_id, teacher_id, 4, 'B', 'assignment', marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at
FROM marks_year4_sectionb_assignment
ON CONFLICT (student_id, subject_id, exam_type) DO NOTHING;

-- ============================================
-- VERIFICATION
-- ============================================

-- Count migrated records
SELECT 
    'Total records migrated' as status,
    COUNT(*) as record_count 
FROM student_marks;

-- Breakdown by exam type
SELECT 
    exam_type,
    COUNT(*) as count
FROM student_marks
GROUP BY exam_type
ORDER BY exam_type;

-- Breakdown by year and section
SELECT 
    year,
    section,
    COUNT(*) as count
FROM student_marks
GROUP BY year, section
ORDER BY year, section;
