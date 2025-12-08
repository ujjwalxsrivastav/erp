-- ============================================
-- QUICK TEST SCRIPT FOR TEACHER_DETAILS
-- ============================================
-- Run this in Supabase SQL Editor to verify everything is working

-- Test 1: Check if table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'teacher_details'
  ) THEN
    RAISE NOTICE '✅ Table teacher_details exists';
  ELSE
    RAISE NOTICE '❌ Table teacher_details does NOT exist';
  END IF;
END $$;

-- Test 2: Check if RLS is enabled
SELECT 
  tablename,
  CASE 
    WHEN rowsecurity THEN '✅ RLS Enabled'
    ELSE '❌ RLS Disabled'
  END as rls_status
FROM pg_tables 
WHERE tablename = 'teacher_details';

-- Test 3: Count total records
SELECT 
  COUNT(*) as total_teachers,
  CASE 
    WHEN COUNT(*) > 0 THEN '✅ Data exists'
    ELSE '❌ No data found'
  END as data_status
FROM teacher_details;

-- Test 4: Show sample data
SELECT 
  teacher_id,
  employee_id,
  name,
  department,
  designation,
  status
FROM teacher_details
ORDER BY employee_id
LIMIT 10;

-- Test 5: Check active policies
SELECT 
  policyname,
  cmd as operation,
  CASE 
    WHEN permissive = 'PERMISSIVE' THEN '✅ Permissive'
    ELSE '⚠️ Restrictive'
  END as policy_type
FROM pg_policies 
WHERE tablename = 'teacher_details'
ORDER BY policyname;

-- Test 6: Check table columns
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'teacher_details'
ORDER BY ordinal_position;

-- Final Summary
DO $$
DECLARE
  record_count INTEGER;
  policy_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO record_count FROM teacher_details;
  SELECT COUNT(*) INTO policy_count FROM pg_policies WHERE tablename = 'teacher_details';
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '📊 TEACHER_DETAILS TABLE SUMMARY';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Total Records: %', record_count;
  RAISE NOTICE 'Total RLS Policies: %', policy_count;
  RAISE NOTICE '';
  
  IF record_count > 0 AND policy_count > 0 THEN
    RAISE NOTICE '✅ Everything looks good!';
    RAISE NOTICE '👉 Data should be fetchable in your app now';
  ELSIF record_count = 0 THEN
    RAISE NOTICE '⚠️ No data in table - need to insert teacher records';
  ELSIF policy_count = 0 THEN
    RAISE NOTICE '⚠️ No RLS policies - run fix_teacher_details_rls.sql first';
  END IF;
  
  RAISE NOTICE '========================================';
END $$;
