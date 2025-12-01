-- ============================================
-- ERP MARKS TABLES - COMPLETE SQL SCRIPT
-- ============================================
-- This script creates separate marks tables for each year, section, and exam type
-- Run this in Supabase SQL Editor

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- YEAR 1 - SECTION A
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year1_sectiona_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year1_sectiona_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year1_sectiona_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year1_sectiona_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 1 - SECTION B
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year1_sectionb_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year1_sectionb_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year1_sectionb_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year1_sectionb_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 2 - SECTION A
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year2_sectiona_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year2_sectiona_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year2_sectiona_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year2_sectiona_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 2 - SECTION B
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year2_sectionb_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year2_sectionb_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year2_sectionb_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year2_sectionb_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 3 - SECTION A
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year3_sectiona_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year3_sectiona_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year3_sectiona_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year3_sectiona_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 3 - SECTION B
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year3_sectionb_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year3_sectionb_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year3_sectionb_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year3_sectionb_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 4 - SECTION A
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year4_sectiona_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year4_sectiona_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year4_sectiona_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year4_sectiona_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- YEAR 4 - SECTION B
-- ============================================

CREATE TABLE IF NOT EXISTS marks_year4_sectionb_midterm (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year4_sectionb_endsem (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year4_sectionb_quiz (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

CREATE TABLE IF NOT EXISTS marks_year4_sectionb_assignment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL,
    subject_id TEXT NOT NULL,
    teacher_id TEXT NOT NULL,
    marks_obtained NUMERIC(5,2) NOT NULL,
    total_marks NUMERIC(5,2) NOT NULL DEFAULT 100,
    percentage NUMERIC(5,2) GENERATED ALWAYS AS ((marks_obtained / total_marks) * 100) STORED,
    grade TEXT,
    remarks TEXT,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, subject_id)
);

-- ============================================
-- CREATE INDEXES FOR ALL TABLES
-- ============================================

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename LIKE 'marks_year%'
    LOOP
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_student ON %I(student_id)', tbl, tbl);
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_subject ON %I(subject_id)', tbl, tbl);
        EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_teacher ON %I(teacher_id)', tbl, tbl);
        RAISE NOTICE 'Created indexes for table: %', tbl;
    END LOOP;
END $$;

-- ============================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOR tbl IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename LIKE 'marks_year%'
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
        RAISE NOTICE 'Enabled RLS for table: %', tbl;
    END LOOP;
END $$;

-- ============================================
-- VERIFICATION QUERY
-- ============================================

-- Run this to verify all tables were created
SELECT 
    tablename,
    schemaname
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename LIKE 'marks_year%'
ORDER BY tablename;
