-- ============================================================================
-- STORAGE BUCKET SETUP FOR ADMISSION DOCUMENTS
-- ============================================================================
-- Run this AFTER creating the bucket in Supabase Dashboard
-- Dashboard > Storage > New Bucket > "admission-documents" > Make it PUBLIC
-- ============================================================================

-- Step 1: Create the bucket (if not exists)
-- NOTE: This might fail if bucket already exists - that's okay
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'admission-documents', 
    'admission-documents', 
    true,
    5242880, -- 5MB limit
    ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['application/pdf']::text[];

-- Step 2: Drop existing policies (if any)
DROP POLICY IF EXISTS "Allow public uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public downloads" ON storage.objects;
DROP POLICY IF EXISTS "admission_docs_upload" ON storage.objects;
DROP POLICY IF EXISTS "admission_docs_select" ON storage.objects;

-- Step 3: Create policy to allow PUBLIC uploads to this bucket
CREATE POLICY "admission_docs_upload" ON storage.objects
    FOR INSERT 
    WITH CHECK (bucket_id = 'admission-documents');

-- Step 4: Create policy to allow PUBLIC read/download
CREATE POLICY "admission_docs_select" ON storage.objects
    FOR SELECT 
    USING (bucket_id = 'admission-documents');

-- Step 5: Allow updates (for re-uploads)
DROP POLICY IF EXISTS "admission_docs_update" ON storage.objects;
CREATE POLICY "admission_docs_update" ON storage.objects
    FOR UPDATE 
    USING (bucket_id = 'admission-documents');

-- Step 6: Allow deletes (for cleanup)
DROP POLICY IF EXISTS "admission_docs_delete" ON storage.objects;
CREATE POLICY "admission_docs_delete" ON storage.objects
    FOR DELETE 
    USING (bucket_id = 'admission-documents');

-- ============================================================================
-- VERIFICATION
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Storage Bucket Policies Applied!';
    RAISE NOTICE '📁 Bucket: admission-documents';
    RAISE NOTICE '🔓 Public uploads enabled';
    RAISE NOTICE '🔓 Public downloads enabled';
END $$;
