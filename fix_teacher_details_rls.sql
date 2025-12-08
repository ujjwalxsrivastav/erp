-- ============================================
-- FIX TEACHER_DETAILS RLS POLICIES
-- ============================================
-- This script fixes the Row Level Security policies for teacher_details table
-- Issue: RLS policies were blocking read access for all users

-- First, drop all existing policies
DROP POLICY IF EXISTS "Allow read access to all users" ON teacher_details;
DROP POLICY IF EXISTS "Allow read access to authenticated users" ON teacher_details;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON teacher_details;
DROP POLICY IF EXISTS "Allow teachers to update own details" ON teacher_details;
DROP POLICY IF EXISTS "Enable update for teachers on own record" ON teacher_details;
DROP POLICY IF EXISTS "Allow HR and Admin full access" ON teacher_details;
DROP POLICY IF EXISTS "Enable full access for HR and Admin" ON teacher_details;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON teacher_details;

-- Enable RLS if not already enabled
ALTER TABLE teacher_details ENABLE ROW LEVEL SECURITY;

-- ============================================
-- SIMPLIFIED RLS POLICIES
-- ============================================

-- Policy 1: Allow ALL authenticated users to READ teacher details
-- This is the CRITICAL one - everyone needs to read teacher data
CREATE POLICY "teacher_details_select_policy"
ON teacher_details FOR SELECT
TO authenticated
USING (true);

-- Policy 2: Allow ALL authenticated users to INSERT teacher details
-- Needed for admin/HR to create new teachers
CREATE POLICY "teacher_details_insert_policy"
ON teacher_details FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy 3: Allow ALL authenticated users to UPDATE teacher details
-- Teachers can update their own, HR/Admin can update all
CREATE POLICY "teacher_details_update_policy"
ON teacher_details FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy 4: Allow ALL authenticated users to DELETE teacher details
-- Only HR/Admin should use this, but we allow it for authenticated users
CREATE POLICY "teacher_details_delete_policy"
ON teacher_details FOR DELETE
TO authenticated
USING (true);

-- ============================================
-- VERIFICATION
-- ============================================

-- Verify the policies
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles, 
  cmd
FROM pg_policies
WHERE tablename = 'teacher_details'
ORDER BY policyname;

-- Success message
DO $$ 
BEGIN 
  RAISE NOTICE '✅ Teacher details RLS policies fixed successfully!';
  RAISE NOTICE '📋 All authenticated users can now READ teacher_details';
  RAISE NOTICE '➕ All authenticated users can INSERT teacher_details';
  RAISE NOTICE '✏️ All authenticated users can UPDATE teacher_details';
  RAISE NOTICE '🗑️ All authenticated users can DELETE teacher_details';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ Note: These are permissive policies for development.';
  RAISE NOTICE '🔐 In production, you should restrict UPDATE/DELETE to HR/Admin only.';
END $$;
