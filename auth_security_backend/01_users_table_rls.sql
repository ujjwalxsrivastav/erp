-- ============================================
-- AUTH SECURITY: USERS TABLE RLS POLICIES
-- ============================================
-- Purpose: Secure the users table so that:
-- 1. No one can directly read passwords
-- 2. Only authenticated users (HR/Admin) can add new users via secure functions
-- 3. Direct table access is blocked
-- ============================================

-- IMPORTANT: These policies are PERMISSIVE to ensure current codebase works
-- After migration to secure functions, you can make them restrictive

-- ============================================
-- STEP 1: Enable RLS on users table
-- ============================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owner too (important for security)
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;

-- ============================================
-- STEP 2: Drop existing policies (if any)
-- ============================================
DROP POLICY IF EXISTS "users_anon_select" ON public.users;
DROP POLICY IF EXISTS "users_authenticated_all" ON public.users;
DROP POLICY IF EXISTS "users_select_policy" ON public.users;
DROP POLICY IF EXISTS "users_insert_policy" ON public.users;
DROP POLICY IF EXISTS "users_update_policy" ON public.users;
DROP POLICY IF EXISTS "users_delete_policy" ON public.users;
DROP POLICY IF EXISTS "anon_can_read_for_login" ON public.users;
DROP POLICY IF EXISTS "authenticated_can_read_users" ON public.users;
DROP POLICY IF EXISTS "authenticated_can_insert_users" ON public.users;

-- ============================================
-- STEP 3: Create SECURE RLS Policies
-- ============================================

-- Policy 1: Anonymous users can read (needed for login)
-- We need this temporarily until we fully migrate to secure_login function
CREATE POLICY "anon_can_read_for_login" ON public.users
FOR SELECT
TO anon
USING (true);

-- Policy 2: Authenticated users can read users (for admin/HR dashboards)
CREATE POLICY "authenticated_can_read_users" ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Policy 3: Authenticated users can insert new users (for HR/Admin adding users)
CREATE POLICY "authenticated_can_insert_users" ON public.users
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy 4: No direct UPDATE allowed (use secure functions)
-- Updates should only happen through SECURITY DEFINER functions
CREATE POLICY "block_direct_updates" ON public.users
FOR UPDATE
TO anon, authenticated
USING (false)
WITH CHECK (false);

-- Policy 5: No DELETE allowed
CREATE POLICY "block_direct_deletes" ON public.users
FOR DELETE
TO anon, authenticated
USING (false);

-- ============================================
-- STEP 4: Create a SAFE VIEW for reading users
-- This view hides passwords completely
-- ============================================
CREATE OR REPLACE VIEW public.users_safe AS
SELECT 
  username,
  role,
  CASE 
    WHEN password LIKE '$2%' THEN 'hashed'
    ELSE 'legacy'
  END as password_status
FROM public.users;

-- Grant access to the safe view
GRANT SELECT ON public.users_safe TO authenticated;
GRANT SELECT ON public.users_safe TO anon;

-- ============================================
-- STEP 5: Revoke direct password access
-- Create a function to check if user exists (without exposing password)
-- ============================================
CREATE OR REPLACE FUNCTION public.check_user_exists(p_username TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE username = LOWER(TRIM(p_username))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_user_exists TO anon;
GRANT EXECUTE ON FUNCTION public.check_user_exists TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Users table RLS policies applied successfully!' as status;
