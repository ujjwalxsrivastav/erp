-- ============================================
-- FIX: ADD FOREIGN KEY RELATIONSHIP
-- ============================================
-- Run this to add foreign key constraint from student_marks to subjects table
-- This enables the relationship query syntax in Supabase

-- Add foreign key constraint for subject_id
ALTER TABLE student_marks 
ADD CONSTRAINT fk_student_marks_subject 
FOREIGN KEY (subject_id) REFERENCES subjects(subject_id);

-- Verify the constraint was added
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint 
WHERE conname = 'fk_student_marks_subject';

-- Alternative: If subjects table doesn't exist or IDs don't match,
-- use this query style in Dart code instead:
-- .select('*')
-- Then manually fetch subjects in a separate query
