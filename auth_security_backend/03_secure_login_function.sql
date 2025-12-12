-- ============================================
-- AUTH SECURITY: SECURE LOGIN FUNCTION
-- ============================================
-- Purpose: Single point of entry for all logins
-- Features:
-- 1. Device-based rate limiting (5 attempts/hour)
-- 2. Password hashing verification (bcrypt)
-- 3. Auto-migration of plain text passwords to hashed
-- 4. Input validation and sanitization
-- 5. Comprehensive audit logging
-- ============================================

-- ============================================
-- STEP 1: Secure Login Function with Device Rate Limiting
-- ============================================
CREATE OR REPLACE FUNCTION public.secure_login_v2(
  p_username TEXT,
  p_password TEXT,
  p_device_fingerprint TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_user RECORD;
  v_rate_limit RECORD;
  v_device_fingerprint TEXT;
BEGIN
  -- Generate device fingerprint if not provided
  v_device_fingerprint := COALESCE(
    p_device_fingerprint, 
    md5(COALESCE(p_ip_address, 'unknown') || COALESCE(p_user_agent, 'unknown'))
  );
  
  -- Input validation
  IF p_username IS NULL OR TRIM(p_username) = '' OR 
     p_password IS NULL OR TRIM(p_password) = '' THEN
    -- Log failed attempt
    PERFORM public.log_device_login_attempt(
      v_device_fingerprint, p_username, p_ip_address, p_user_agent, false
    );
    
    RETURN json_build_object(
      'success', false,
      'message', 'Username and password are required',
      'role', null,
      'error_code', 'VALIDATION_ERROR'
    );
  END IF;
  
  -- Check device rate limit FIRST (before any database lookup)
  SELECT * INTO v_rate_limit 
  FROM public.check_device_rate_limit(v_device_fingerprint, 5, 60);
  
  IF v_rate_limit.is_blocked THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Too many failed attempts. Device blocked for ' || 
                 v_rate_limit.block_remaining_minutes || ' minutes.',
      'role', null,
      'rate_limited', true,
      'block_remaining_minutes', v_rate_limit.block_remaining_minutes,
      'error_code', 'RATE_LIMITED'
    );
  END IF;
  
  -- Find user (case insensitive, trimmed)
  SELECT username, password, role INTO v_user
  FROM public.users
  WHERE username = LOWER(TRIM(p_username));
  
  -- User not found
  IF v_user.username IS NULL THEN
    -- Log failed attempt
    PERFORM public.log_device_login_attempt(
      v_device_fingerprint, p_username, p_ip_address, p_user_agent, false
    );
    
    -- Also log to security_login_attempts for backward compatibility
    INSERT INTO public.security_login_attempts (username, success, ip_address, user_agent)
    VALUES (p_username, false, p_ip_address, p_user_agent);
    
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid username or password',
      'role', null,
      'error_code', 'INVALID_CREDENTIALS'
    );
  END IF;
  
  -- Verify password (handles both plain and hashed)
  IF NOT public.verify_password(p_password, v_user.password) THEN
    -- Log failed attempt
    PERFORM public.log_device_login_attempt(
      v_device_fingerprint, p_username, p_ip_address, p_user_agent, false
    );
    
    INSERT INTO public.security_login_attempts (username, success, ip_address, user_agent)
    VALUES (p_username, false, p_ip_address, p_user_agent);
    
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid username or password',
      'role', null,
      'error_code', 'INVALID_CREDENTIALS'
    );
  END IF;
  
  -- SUCCESS! Log successful attempt
  PERFORM public.log_device_login_attempt(
    v_device_fingerprint, v_user.username, p_ip_address, p_user_agent, true
  );
  
  INSERT INTO public.security_login_attempts (username, success, ip_address, user_agent)
  VALUES (v_user.username, true, p_ip_address, p_user_agent);
  
  -- Auto-migrate plain text password to hashed (silent upgrade)
  IF v_user.password NOT LIKE '$2%' THEN
    UPDATE public.users 
    SET password = public.hash_password(p_password)
    WHERE username = v_user.username;
    
    -- Log the migration
    INSERT INTO public.security_audit_log (table_name, operation, record_id, new_data)
    VALUES ('users', 'PASSWORD_MIGRATED', v_user.username, 
            json_build_object('action', 'plain_to_bcrypt')::jsonb);
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Login successful',
    'role', v_user.role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.secure_login_v2 TO anon;
GRANT EXECUTE ON FUNCTION public.secure_login_v2 TO authenticated;

-- ============================================
-- STEP 2: Get Remaining Attempts Function
-- (For showing user how many attempts left)
-- ============================================
CREATE OR REPLACE FUNCTION public.get_remaining_login_attempts(
  p_device_fingerprint TEXT
)
RETURNS JSON AS $$
DECLARE
  v_rate_limit RECORD;
BEGIN
  SELECT * INTO v_rate_limit 
  FROM public.check_device_rate_limit(p_device_fingerprint, 5, 60);
  
  IF v_rate_limit.is_blocked THEN
    RETURN json_build_object(
      'remaining_attempts', 0,
      'is_blocked', true,
      'block_remaining_minutes', v_rate_limit.block_remaining_minutes,
      'message', 'Device blocked. Try again in ' || v_rate_limit.block_remaining_minutes || ' minutes.'
    );
  ELSE
    RETURN json_build_object(
      'remaining_attempts', 5 - v_rate_limit.failed_attempts,
      'is_blocked', false,
      'failed_attempts', v_rate_limit.failed_attempts,
      'message', CASE 
        WHEN v_rate_limit.failed_attempts = 0 THEN 'No failed attempts'
        ELSE (5 - v_rate_limit.failed_attempts)::TEXT || ' attempts remaining'
      END
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_remaining_login_attempts TO anon;
GRANT EXECUTE ON FUNCTION public.get_remaining_login_attempts TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Secure login function v2 created successfully!' as status;
