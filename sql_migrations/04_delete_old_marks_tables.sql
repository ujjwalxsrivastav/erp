-- ============================================
-- DELETE OLD MARKS TABLES (32 Tables)
-- ============================================
-- Run this AFTER verifying that student_marks table is working correctly
-- This will permanently delete all old marks tables

-- ============================================
-- DROP ALL OLD MARKS TABLES
-- ============================================

-- Year 1 - Section A
DROP TABLE IF EXISTS marks_year1_sectiona_midterm;
DROP TABLE IF EXISTS marks_year1_sectiona_endsem;
DROP TABLE IF EXISTS marks_year1_sectiona_quiz;
DROP TABLE IF EXISTS marks_year1_sectiona_assignment;

-- Year 1 - Section B
DROP TABLE IF EXISTS marks_year1_sectionb_midterm;
DROP TABLE IF EXISTS marks_year1_sectionb_endsem;
DROP TABLE IF EXISTS marks_year1_sectionb_quiz;
DROP TABLE IF EXISTS marks_year1_sectionb_assignment;

-- Year 2 - Section A
DROP TABLE IF EXISTS marks_year2_sectiona_midterm;
DROP TABLE IF EXISTS marks_year2_sectiona_endsem;
DROP TABLE IF EXISTS marks_year2_sectiona_quiz;
DROP TABLE IF EXISTS marks_year2_sectiona_assignment;

-- Year 2 - Section B
DROP TABLE IF EXISTS marks_year2_sectionb_midterm;
DROP TABLE IF EXISTS marks_year2_sectionb_endsem;
DROP TABLE IF EXISTS marks_year2_sectionb_quiz;
DROP TABLE IF EXISTS marks_year2_sectionb_assignment;

-- Year 3 - Section A
DROP TABLE IF EXISTS marks_year3_sectiona_midterm;
DROP TABLE IF EXISTS marks_year3_sectiona_endsem;
DROP TABLE IF EXISTS marks_year3_sectiona_quiz;
DROP TABLE IF EXISTS marks_year3_sectiona_assignment;

-- Year 3 - Section B
DROP TABLE IF EXISTS marks_year3_sectionb_midterm;
DROP TABLE IF EXISTS marks_year3_sectionb_endsem;
DROP TABLE IF EXISTS marks_year3_sectionb_quiz;
DROP TABLE IF EXISTS marks_year3_sectionb_assignment;

-- Year 4 - Section A
DROP TABLE IF EXISTS marks_year4_sectiona_midterm;
DROP TABLE IF EXISTS marks_year4_sectiona_endsem;
DROP TABLE IF EXISTS marks_year4_sectiona_quiz;
DROP TABLE IF EXISTS marks_year4_sectiona_assignment;

-- Year 4 - Section B
DROP TABLE IF EXISTS marks_year4_sectionb_midterm;
DROP TABLE IF EXISTS marks_year4_sectionb_endsem;
DROP TABLE IF EXISTS marks_year4_sectionb_quiz;
DROP TABLE IF EXISTS marks_year4_sectionb_assignment;

-- ============================================
-- VERIFICATION
-- ============================================

-- Check that no old marks tables exist anymore
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename LIKE 'marks_year%'
ORDER BY tablename;

-- This should return empty result if all tables were deleted successfully

-- Verify student_marks table exists and has data
SELECT 
    'student_marks' as table_name,
    COUNT(*) as record_count 
FROM student_marks;
