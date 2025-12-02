-- ============================================================================
-- STORAGE BUCKETS SETUP FOR ERP SYSTEM
-- ============================================================================
-- This file contains SQL commands to create storage buckets in Supabase
-- Run these commands in Supabase Dashboard > Storage
-- ============================================================================

-- IMPORTANT: Storage buckets cannot be created via SQL in Supabase
-- You must create them manually in the Supabase Dashboard
-- Follow these steps:

-- ============================================================================
-- STEP 1: Create 'assignments' Bucket
-- ============================================================================
-- 1. Go to Supabase Dashboard > Storage
-- 2. Click "New bucket"
-- 3. Bucket name: assignments
-- 4. Make it PUBLIC (check the box)
-- 5. Click "Create bucket"

-- After creating the bucket, set these policies:

-- Policy 1: Allow authenticated users to upload
INSERT INTO storage.policies (name, bucket_id, definition)
VALUES (
  'Authenticated users can upload assignments',
  'assignments',
  '(auth.role() = ''authenticated'')'
);

-- Policy 2: Allow public read access
INSERT INTO storage.policies (name, bucket_id, definition, operation)
VALUES (
  'Public can read assignments',
  'assignments',
  'true',
  'SELECT'
);

-- ============================================================================
-- STEP 2: Create 'study-materials' Bucket
-- ============================================================================
-- 1. Go to Supabase Dashboard > Storage
-- 2. Click "New bucket"
-- 3. Bucket name: study-materials
-- 4. Make it PUBLIC (check the box)
-- 5. Click "Create bucket"

-- After creating the bucket, set these policies:

-- Policy 1: Allow authenticated users to upload
INSERT INTO storage.policies (name, bucket_id, definition)
VALUES (
  'Authenticated users can upload study materials',
  'study-materials',
  '(auth.role() = ''authenticated'')'
);

-- Policy 2: Allow public read access
INSERT INTO storage.policies (name, bucket_id, definition, operation)
VALUES (
  'Public can read study materials',
  'study-materials',
  'true',
  'SELECT'
);

-- ============================================================================
-- ALTERNATIVE: Use Supabase Dashboard UI for Policies
-- ============================================================================
-- If the above SQL doesn't work, set policies manually in Dashboard:
--
-- For BOTH buckets (assignments and study-materials):
--
-- Upload Policy:
-- - Policy name: "Authenticated users can upload"
-- - Allowed operation: INSERT
-- - Target roles: authenticated
-- - Policy definition: (auth.role() = 'authenticated')
--
-- Read Policy:
-- - Policy name: "Public can read files"
-- - Allowed operation: SELECT
-- - Target roles: public
-- - Policy definition: true
--
-- Delete Policy (Optional - for teachers to delete their own files):
-- - Policy name: "Users can delete their own files"
-- - Allowed operation: DELETE
-- - Target roles: authenticated
-- - Policy definition: (auth.uid()::text = (storage.foldername(name))[1])
-- ============================================================================

-- VERIFICATION QUERIES
-- Run these to verify buckets are created:

SELECT * FROM storage.buckets WHERE name IN ('assignments', 'study-materials');

-- Check policies:
SELECT * FROM storage.policies WHERE bucket_id IN ('assignments', 'study-materials');
