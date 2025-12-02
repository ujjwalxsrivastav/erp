-- ============================================================================
-- ASSIGNMENT SUBMISSIONS TABLE SETUP
-- ============================================================================
-- Run this SQL in Supabase SQL Editor
-- ============================================================================

-- Step 1: Check if assignments table has id column and its type
-- If assignments.id doesn't exist or is integer, we'll use TEXT for assignment_id

-- Create assignment_submissions table
CREATE TABLE IF NOT EXISTS assignment_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assignment_id TEXT NOT NULL,  -- Using TEXT to be compatible with any ID type
    student_id TEXT NOT NULL,
    file_url TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'submitted', -- 'submitted', 'graded', 'late'
    grade NUMERIC,
    feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(assignment_id, student_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_submissions_student ON assignment_submissions(student_id);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON assignment_submissions(status);
CREATE INDEX IF NOT EXISTS idx_submissions_submitted_at ON assignment_submissions(submitted_at DESC);

-- Enable Row Level Security
ALTER TABLE assignment_submissions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Students can submit assignments" ON assignment_submissions;
DROP POLICY IF EXISTS "Students can view their submissions" ON assignment_submissions;
DROP POLICY IF EXISTS "Teachers can view submissions" ON assignment_submissions;
DROP POLICY IF EXISTS "Teachers can grade submissions" ON assignment_submissions;

-- RLS Policy 1: Students can insert their own submissions
CREATE POLICY "Students can submit assignments"
ON assignment_submissions FOR INSERT
WITH CHECK (auth.uid()::text = student_id);

-- RLS Policy 2: Students can view their own submissions
CREATE POLICY "Students can view their submissions"
ON assignment_submissions FOR SELECT
USING (auth.uid()::text = student_id);

-- RLS Policy 3: Teachers can view all submissions
-- (Simplified - you can add more specific checks if needed)
CREATE POLICY "Teachers can view submissions"
ON assignment_submissions FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM teacher_details
        WHERE teacher_id = auth.uid()::text
    )
);

-- RLS Policy 4: Teachers can update submissions (for grading)
CREATE POLICY "Teachers can grade submissions"
ON assignment_submissions FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM teacher_details
        WHERE teacher_id = auth.uid()::text
    )
);

-- ============================================================================
-- IMPORTANT: Storage Bucket Setup
-- ============================================================================
-- You MUST create this bucket manually in Supabase Dashboard:
--
-- 1. Go to Storage in Supabase Dashboard
-- 2. Click "New bucket"
-- 3. Name: assignment-submissions
-- 4. Check "Public bucket"
-- 5. Click "Create bucket"
--
-- Then set these policies:
-- - Upload Policy: Allow authenticated users (INSERT)
-- - Read Policy: Allow public (SELECT)
-- ============================================================================

-- Verify table was created
SELECT 
    'assignment_submissions table created successfully!' as message,
    COUNT(*) as row_count 
FROM assignment_submissions;
