# ERP Database Schema - Marks Tables Design

## Overview
This document outlines the database schema for storing student marks with separate tables for each year, section, and exam type combination.

## Table Naming Convention
Format: `marks_year{Y}_section{S}_{exam_type}`

Examples:
- `marks_year1_sectionA_midterm`
- `marks_year1_sectionA_endsem`
- `marks_year1_sectionB_midterm`
- `marks_year2_sectionA_midterm`

## Base Table Structure
Each marks table will have the following columns:

```sql
CREATE TABLE marks_year{Y}_section{S}_{exam_type} (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id TEXT NOT NULL REFERENCES student_details(student_id),
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

-- Index for faster queries
CREATE INDEX idx_marks_year{Y}_section{S}_{exam_type}_student 
ON marks_year{Y}_section{S}_{exam_type}(student_id);

CREATE INDEX idx_marks_year{Y}_section{S}_{exam_type}_subject 
ON marks_year{Y}_section{S}_{exam_type}(subject_id);
```

## Required Tables for Initial Setup

### Year 1 - Section A
1. `marks_year1_sectionA_midterm`
2. `marks_year1_sectionA_endsem`
3. `marks_year1_sectionA_quiz`
4. `marks_year1_sectionA_assignment`

### Year 1 - Section B
1. `marks_year1_sectionB_midterm`
2. `marks_year1_sectionB_endsem`
3. `marks_year1_sectionB_quiz`
4. `marks_year1_sectionB_assignment`

### Year 2 - Section A
1. `marks_year2_sectionA_midterm`
2. `marks_year2_sectionA_endsem`
3. `marks_year2_sectionA_quiz`
4. `marks_year2_sectionA_assignment`

### Year 2 - Section B
1. `marks_year2_sectionB_midterm`
2. `marks_year2_sectionB_endsem`
3. `marks_year2_sectionB_quiz`
4. `marks_year2_sectionB_assignment`

### Year 3 - Section A
1. `marks_year3_sectionA_midterm`
2. `marks_year3_sectionA_endsem`
3. `marks_year3_sectionA_quiz`
4. `marks_year3_sectionA_assignment`

### Year 3 - Section B
1. `marks_year3_sectionB_midterm`
2. `marks_year3_sectionB_endsem`
3. `marks_year3_sectionB_quiz`
4. `marks_year3_sectionB_assignment`

### Year 4 - Section A
1. `marks_year4_sectionA_midterm`
2. `marks_year4_sectionA_endsem`
3. `marks_year4_sectionA_quiz`
4. `marks_year4_sectionA_assignment`

### Year 4 - Section B
1. `marks_year4_sectionB_midterm`
2. `marks_year4_sectionB_endsem`
3. `marks_year4_sectionB_quiz`
4. `marks_year4_sectionB_assignment`

## SQL Script to Create All Tables

```sql
-- Function to create marks table dynamically
CREATE OR REPLACE FUNCTION create_marks_table(
    p_year INTEGER,
    p_section TEXT,
    p_exam_type TEXT
) RETURNS VOID AS $$
DECLARE
    table_name TEXT;
    exam_type_normalized TEXT;
BEGIN
    -- Normalize exam type (remove spaces, lowercase)
    exam_type_normalized := LOWER(REPLACE(p_exam_type, ' ', ''));
    
    -- Generate table name
    table_name := 'marks_year' || p_year || '_section' || LOWER(p_section) || '_' || exam_type_normalized;
    
    -- Create table
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            student_id TEXT NOT NULL REFERENCES student_details(student_id),
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
        )', table_name);
    
    -- Create indexes
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_student ON %I(student_id)', 
        table_name, table_name);
    EXECUTE format('CREATE INDEX IF NOT EXISTS idx_%I_subject ON %I(subject_id)', 
        table_name, table_name);
    
    RAISE NOTICE 'Created table: %', table_name;
END;
$$ LANGUAGE plpgsql;

-- Create all tables for 4 years, 2 sections, 4 exam types
DO $$
DECLARE
    year_num INTEGER;
    section_letter TEXT;
    exam_type TEXT;
BEGIN
    FOR year_num IN 1..4 LOOP
        FOR section_letter IN SELECT unnest(ARRAY['A', 'B']) LOOP
            FOR exam_type IN SELECT unnest(ARRAY['Mid Term', 'End Semester', 'Quiz', 'Assignment']) LOOP
                PERFORM create_marks_table(year_num, section_letter, exam_type);
            END LOOP;
        END LOOP;
    END LOOP;
END $$;
```

## Helper View for Unified Queries

```sql
-- Create a view that unions all marks tables for easier querying
CREATE OR REPLACE VIEW all_marks AS
SELECT 
    1 as year, 
    'A' as section, 
    'Mid Term' as exam_type, 
    * 
FROM marks_year1_sectiona_midterm
UNION ALL
SELECT 
    1 as year, 
    'A' as section, 
    'End Semester' as exam_type, 
    * 
FROM marks_year1_sectiona_endsem
-- ... (repeat for all tables)
;
```

## Benefits of This Approach

1. **Performance**: Smaller tables = faster queries
2. **Data Isolation**: Each class/exam combination is completely separate
3. **Easy Reporting**: Can query specific table for specific report
4. **Scalability**: Can add new tables as needed for new years/sections
5. **Backup/Archive**: Easy to archive old year data

## Migration Strategy

1. Run the SQL script in Supabase SQL Editor
2. Update application code to use dynamic table names
3. Test with one year/section first
4. Roll out to all years/sections

## Maintenance

- Add new tables when new sections are created
- Archive old tables when students graduate
- Regular backups of individual tables
