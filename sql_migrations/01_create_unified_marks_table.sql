-- ============================================
-- UNIFIED MARKS TABLE CREATION
-- ============================================
-- Consolidates 32 separate marks tables into 1 unified table
-- Run this in Supabase SQL Editor FIRST

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- CREATE UNIFIED STUDENT_MARKS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS student_marks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    year INTEGER NOT NULL CHECK (year BETWEEN 1 AND 4),
    section TEXT NOT NULL CHECK (UPPER(section) IN ('A', 'B')),
    exam_type TEXT NOT NULL CHECK (exam_type IN ('midterm', 'endsem', 'quiz', 'assignment')),
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS (
        CASE WHEN total_marks > 0 THEN (marks_obtained / total_marks) * 100 ELSE 0 END
    ) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- One mark per student per subject per exam type (regardless of year/section as that's derived from student)
    UNIQUE(student_id, subject_id, exam_type)
);

-- Add helpful comments
COMMENT ON TABLE student_marks IS 'Unified marks table storing all student exam results';
COMMENT ON COLUMN student_marks.exam_type IS 'Type of exam: midterm, endsem, quiz, or assignment';
COMMENT ON COLUMN student_marks.year IS 'Academic year (1-4)';
COMMENT ON COLUMN student_marks.section IS 'Class section (A or B)';

-- ============================================
-- CREATE INDEXES FOR PERFORMANCE
-- ============================================

-- Primary lookup: by student
CREATE INDEX IF NOT EXISTS idx_student_marks_student_id ON student_marks(student_id);

-- Teacher's view: by teacher
CREATE INDEX IF NOT EXISTS idx_student_marks_teacher_id ON student_marks(teacher_id);

-- Subject lookup
CREATE INDEX IF NOT EXISTS idx_student_marks_subject_id ON student_marks(subject_id);

-- Class-wise lookup: year + section combination
CREATE INDEX IF NOT EXISTS idx_student_marks_year_section ON student_marks(year, section);

-- Exam type filter
CREATE INDEX IF NOT EXISTS idx_student_marks_exam_type ON student_marks(exam_type);

-- Composite index for common queries (student's marks by exam type)
CREATE INDEX IF NOT EXISTS idx_student_marks_student_exam ON student_marks(student_id, exam_type);

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================

ALTER TABLE student_marks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Policy: Allow all operations for authenticated users (simplified)
CREATE POLICY "Allow all for authenticated users" ON student_marks
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- ============================================
-- CREATE UPDATED_AT TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION update_student_marks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_student_marks_timestamp
    BEFORE UPDATE ON student_marks
    FOR EACH ROW
    EXECUTE FUNCTION update_student_marks_updated_at();

-- ============================================
-- VERIFICATION
-- ============================================

SELECT 'student_marks table created successfully!' AS status;

-- Check table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'student_marks'
ORDER BY ordinal_position;
