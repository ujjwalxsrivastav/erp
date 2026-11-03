-- ============================================================================
-- USERS — INSTITUTION COLUMN + ROLE CLEANUP
--
-- 1. Adds users.institution ('school' | 'college') so the Admin → Manage
--    Users screen can list each institution's accounts separately.
-- 2. Backfills institution for existing accounts (school_students are
--    school; everything else stays college).
-- 3. Removes HR / HOD / Staff accounts — those roles are no longer
--    supported in the admin panel.
-- 4. Tightens the role CHECK constraint to student / teacher / admin.
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- 1. Institution column -------------------------------------------------------
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS institution TEXT NOT NULL DEFAULT 'college';

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_institution_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_institution_check
  CHECK (institution IN ('school', 'college'));

CREATE INDEX IF NOT EXISTS users_institution_role_idx
  ON public.users (institution, role);

-- 2. Backfill ----------------------------------------------------------------
UPDATE public.users u
SET institution = 'school'
WHERE u.role IN ('student', 'teacher')
  AND EXISTS (
    SELECT 1 FROM public.school_students s WHERE s.username = u.username
  );

-- 3. Remove unsupported roles ------------------------------------------------
--    Accounts first; profile rows for them are left untouched so no history
--    (attendance, homework, etc.) is lost if they are re-created later.
DELETE FROM public.users WHERE role IN ('staff', 'hod', 'HR');

-- 4. Tighten the role constraint --------------------------------------------
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users
  ADD CONSTRAINT users_role_check
  CHECK (role IN ('student', 'teacher', 'admin'));

-- Keep the secure RPCs in step with the new role list.
CREATE OR REPLACE FUNCTION public.secure_add_user_v2(
  p_username TEXT,
  p_password TEXT,
  p_role TEXT,
  p_created_by TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_hashed_password TEXT;
  v_clean_username TEXT;
  v_valid_roles TEXT[] := ARRAY['student', 'teacher', 'admin'];
BEGIN
  IF p_username IS NULL OR TRIM(p_username) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Username is required');
  END IF;
  IF p_password IS NULL OR TRIM(p_password) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Password is required');
  END IF;
  IF LENGTH(p_password) < 6 THEN
    RETURN json_build_object('success', false, 'message', 'Password must be at least 6 characters');
  END IF;
  IF p_role IS NULL OR NOT (p_role = ANY(v_valid_roles)) THEN
    RETURN json_build_object('success', false, 'message', 'Unsupported role: ' || COALESCE(p_role, ''));
  END IF;

  v_clean_username := LOWER(TRIM(p_username));
  IF v_clean_username !~ '^[a-z0-9_]+$' THEN
    RETURN json_build_object('success', false, 'message', 'Username can only contain letters, numbers, and underscores');
  END IF;
  IF EXISTS (SELECT 1 FROM public.users WHERE username = v_clean_username) THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  END IF;

  v_hashed_password := public.hash_password(p_password);

  INSERT INTO public.users (username, password, role, institution)
  VALUES (
    v_clean_username,
    v_hashed_password,
    p_role,
    CASE WHEN p_role = 'admin' THEN 'college' ELSE 'school' END
  );

  RETURN json_build_object(
    'success', true,
    'message', 'User created successfully',
    'username', v_clean_username,
    'role', p_role
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'message', 'Username already exists');
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', 'Error creating user: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMIT;
