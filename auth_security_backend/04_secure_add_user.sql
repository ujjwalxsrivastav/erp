-- ============================================
-- AUTH SECURITY: SECURE ADD USER FUNCTION
-- ============================================
-- Purpose: Single secure function for HR/Admin to add users
-- Features:
-- 1. Automatic password hashing (bcrypt)
-- 2. Input validation
-- 3. Role validation
-- 4. Duplicate checking
-- 5. Audit logging
-- ============================================

-- ============================================
-- STEP 1: Enhanced Secure Add User Function
-- ============================================
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
  v_valid_roles TEXT[] := ARRAY['student', 'teacher', 'admin', 'staff', 'HR', 'hod'];
BEGIN
  -- Input validation
  IF p_username IS NULL OR TRIM(p_username) = '' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username is required',
      'error_code', 'VALIDATION_ERROR'
    );
  END IF;
  
  IF p_password IS NULL OR TRIM(p_password) = '' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password is required',
      'error_code', 'VALIDATION_ERROR'
    );
  END IF;
  
  -- Password strength validation (minimum 6 characters)
  IF LENGTH(p_password) < 6 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must be at least 6 characters',
      'error_code', 'WEAK_PASSWORD'
    );
  END IF;
  
  -- Role validation
  IF p_role IS NULL OR NOT (p_role = ANY(v_valid_roles)) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid role. Valid roles: student, teacher, admin, staff, HR, hod',
      'error_code', 'INVALID_ROLE'
    );
  END IF;
  
  -- Clean and normalize username
  v_clean_username := LOWER(TRIM(p_username));
  
  -- Username format validation (alphanumeric and underscores only)
  IF v_clean_username !~ '^[a-z0-9_]+$' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username can only contain letters, numbers, and underscores',
      'error_code', 'INVALID_USERNAME'
    );
  END IF;
  
  -- Check if user already exists
  IF EXISTS (SELECT 1 FROM public.users WHERE username = v_clean_username) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username already exists',
      'error_code', 'DUPLICATE_USERNAME'
    );
  END IF;
  
  -- Hash the password using bcrypt
  v_hashed_password := public.hash_password(p_password);
  
  -- Insert the new user
  INSERT INTO public.users (username, password, role)
  VALUES (v_clean_username, v_hashed_password, p_role);
  
  -- Log the action in audit table
  INSERT INTO public.security_audit_log (
    table_name, 
    operation, 
    record_id, 
    username,
    new_data
  )
  VALUES (
    'users', 
    'INSERT', 
    v_clean_username,
    COALESCE(p_created_by, 'system'),
    json_build_object(
      'username', v_clean_username, 
      'role', p_role,
      'created_by', COALESCE(p_created_by, 'system'),
      'created_at', NOW()
    )::jsonb
  );
  
  RETURN json_build_object(
    'success', true,
    'message', 'User created successfully',
    'username', v_clean_username,
    'role', p_role
  );
  
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username already exists',
      'error_code', 'DUPLICATE_USERNAME'
    );
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Error creating user: ' || SQLERRM,
      'error_code', 'DATABASE_ERROR'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to authenticated users (HR/Admin)
GRANT EXECUTE ON FUNCTION public.secure_add_user_v2 TO authenticated;

-- ============================================
-- STEP 2: Bulk Add Users Function (for CSV import)
-- ============================================
CREATE OR REPLACE FUNCTION public.secure_bulk_add_users(
  p_users JSONB,  -- Array of {username, password, role}
  p_created_by TEXT
)
RETURNS JSON AS $$
DECLARE
  v_user JSONB;
  v_result JSON;
  v_success_count INTEGER := 0;
  v_fail_count INTEGER := 0;
  v_errors JSONB := '[]'::JSONB;
BEGIN
  -- Loop through each user
  FOR v_user IN SELECT * FROM jsonb_array_elements(p_users)
  LOOP
    -- Call secure_add_user_v2 for each user
    v_result := public.secure_add_user_v2(
      v_user->>'username',
      v_user->>'password',
      v_user->>'role',
      p_created_by
    );
    
    IF (v_result->>'success')::boolean THEN
      v_success_count := v_success_count + 1;
    ELSE
      v_fail_count := v_fail_count + 1;
      v_errors := v_errors || jsonb_build_object(
        'username', v_user->>'username',
        'error', v_result->>'message'
      );
    END IF;
  END LOOP;
  
  RETURN json_build_object(
    'success', v_fail_count = 0,
    'message', v_success_count || ' users created, ' || v_fail_count || ' failed',
    'success_count', v_success_count,
    'fail_count', v_fail_count,
    'errors', v_errors
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_bulk_add_users TO authenticated;

-- ============================================
-- STEP 3: Update User Password Function
-- ============================================
CREATE OR REPLACE FUNCTION public.secure_update_password(
  p_username TEXT,
  p_old_password TEXT,
  p_new_password TEXT
)
RETURNS JSON AS $$
DECLARE
  v_user RECORD;
  v_hashed_password TEXT;
BEGIN
  -- Input validation
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 6 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'New password must be at least 6 characters',
      'error_code', 'WEAK_PASSWORD'
    );
  END IF;
  
  -- Find user
  SELECT username, password INTO v_user
  FROM public.users
  WHERE username = LOWER(TRIM(p_username));
  
  IF v_user.username IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found',
      'error_code', 'USER_NOT_FOUND'
    );
  END IF;
  
  -- Verify old password
  IF NOT public.verify_password(p_old_password, v_user.password) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Current password is incorrect',
      'error_code', 'INVALID_PASSWORD'
    );
  END IF;
  
  -- Hash and update new password
  v_hashed_password := public.hash_password(p_new_password);
  
  UPDATE public.users 
  SET password = v_hashed_password
  WHERE username = v_user.username;
  
  -- Log the action
  INSERT INTO public.security_audit_log (table_name, operation, record_id, new_data)
  VALUES ('users', 'PASSWORD_CHANGED', v_user.username, 
          json_build_object('action', 'password_updated', 'updated_at', NOW())::jsonb);
  
  RETURN json_build_object(
    'success', true,
    'message', 'Password updated successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_update_password TO authenticated;

-- ============================================
-- STEP 4: Admin Reset Password Function
-- (For HR/Admin to reset user passwords)
-- ============================================
CREATE OR REPLACE FUNCTION public.admin_reset_password(
  p_username TEXT,
  p_new_password TEXT,
  p_admin_username TEXT
)
RETURNS JSON AS $$
DECLARE
  v_hashed_password TEXT;
BEGIN
  -- Check if user exists
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE username = LOWER(TRIM(p_username))) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found',
      'error_code', 'USER_NOT_FOUND'
    );
  END IF;
  
  -- Password validation
  IF p_new_password IS NULL OR LENGTH(p_new_password) < 6 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must be at least 6 characters',
      'error_code', 'WEAK_PASSWORD'
    );
  END IF;
  
  -- Hash and update password
  v_hashed_password := public.hash_password(p_new_password);
  
  UPDATE public.users 
  SET password = v_hashed_password
  WHERE username = LOWER(TRIM(p_username));
  
  -- Log the action
  INSERT INTO public.security_audit_log (table_name, operation, record_id, username, new_data)
  VALUES ('users', 'PASSWORD_RESET', LOWER(TRIM(p_username)), p_admin_username,
          json_build_object('action', 'admin_password_reset', 'reset_by', p_admin_username, 'reset_at', NOW())::jsonb);
  
  RETURN json_build_object(
    'success', true,
    'message', 'Password reset successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_reset_password TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Secure add user functions created successfully!' as status;
