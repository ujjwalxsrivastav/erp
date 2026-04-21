-- ============================================
-- SUPABASE SECURITY FOUNDATION
-- 100% BACKWARD COMPATIBLE - NO DATA LOSS
-- ============================================
-- IMPORTANT: This script is SAFE to run
-- - No DELETE statements
-- - No DROP TABLE statements  
-- - All CREATE use IF NOT EXISTS
-- - All ALTER use IF EXISTS checks
-- - Current auth flow will continue working
-- ============================================

-- ============================================
-- STEP 1: Enable Required Extensions (SAFE)
-- ============================================

-- pgcrypto is needed for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- uuid-ossp for secure UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- STEP 2: Create Security Audit Tables (NEW)
-- These are NEW tables, won't affect existing
-- ============================================

-- Login attempts tracking (for rate limiting & security monitoring)
CREATE TABLE IF NOT EXISTS public.security_login_attempts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username TEXT NOT NULL,
  success BOOLEAN NOT NULL DEFAULT false,
  ip_address TEXT,
  user_agent TEXT,
  attempted_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_security_login_username 
  ON public.security_login_attempts(username);
CREATE INDEX IF NOT EXISTS idx_security_login_time 
  ON public.security_login_attempts(attempted_at DESC);

-- Security audit log (tracks sensitive operations)
CREATE TABLE IF NOT EXISTS public.security_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL, -- INSERT, UPDATE, DELETE
  record_id TEXT,
  username TEXT, -- who made the change
  old_data JSONB,
  new_data JSONB,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_table 
  ON public.security_audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_log_time 
  ON public.security_audit_log(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_user 
  ON public.security_audit_log(username);

-- ============================================
-- STEP 3: Password Hashing Function (NEW)
-- Used for new users, migrates old on login
-- ============================================

-- Function to hash passwords using bcrypt
CREATE OR REPLACE FUNCTION public.hash_password(plain_password TEXT)
RETURNS TEXT AS $$
BEGIN
  -- bcrypt with cost factor 10
  RETURN crypt(plain_password, gen_salt('bf', 10));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify passwords (works with both plain & hashed)
CREATE OR REPLACE FUNCTION public.verify_password(
  plain_password TEXT, 
  stored_password TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Check if password is hashed (bcrypt starts with $2)
  IF stored_password LIKE '$2%' THEN
    -- Verify against hash
    RETURN stored_password = crypt(plain_password, stored_password);
  ELSE
    -- Legacy plain text comparison
    RETURN stored_password = plain_password;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 4: Rate Limiting Function (NEW)
-- Prevents brute force attacks
-- ============================================

CREATE OR REPLACE FUNCTION public.check_login_rate_limit(
  p_username TEXT,
  p_max_attempts INTEGER DEFAULT 5,
  p_window_minutes INTEGER DEFAULT 15
)
RETURNS TABLE(
  is_blocked BOOLEAN,
  failed_attempts INTEGER,
  block_remaining_minutes INTEGER
) AS $$
DECLARE
  v_count INTEGER;
  v_oldest_attempt TIMESTAMPTZ;
BEGIN
  -- Count failed attempts in window
  SELECT COUNT(*), MIN(attempted_at)
  INTO v_count, v_oldest_attempt
  FROM public.security_login_attempts
  WHERE username = p_username
    AND success = false
    AND attempted_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  -- Calculate remaining block time
  IF v_count >= p_max_attempts AND v_oldest_attempt IS NOT NULL THEN
    RETURN QUERY SELECT 
      true,
      v_count,
      EXTRACT(MINUTES FROM (v_oldest_attempt + (p_window_minutes || ' minutes')::INTERVAL - NOW()))::INTEGER;
  ELSE
    RETURN QUERY SELECT false, v_count, 0;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: Secure Login Function (NEW RPC)
-- Call this instead of direct table query
-- ============================================

CREATE OR REPLACE FUNCTION public.secure_login(
  p_username TEXT,
  p_password TEXT
)
RETURNS JSON AS $$
DECLARE
  v_user RECORD;
  v_rate_limit RECORD;
  v_result JSON;
BEGIN
  -- Input validation
  IF p_username IS NULL OR p_username = '' OR 
     p_password IS NULL OR p_password = '' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username and password are required',
      'role', null
    );
  END IF;
  
  -- Check rate limit
  SELECT * INTO v_rate_limit 
  FROM public.check_login_rate_limit(p_username);
  
  IF v_rate_limit.is_blocked THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Too many failed attempts. Please try again in ' || 
                 v_rate_limit.block_remaining_minutes || ' minutes.',
      'role', null,
      'rate_limited', true
    );
  END IF;
  
  -- Find user (don't expose password in query result)
  SELECT username, password, role INTO v_user
  FROM users
  WHERE username = LOWER(TRIM(p_username));
  
  -- Check if user exists
  IF v_user.username IS NULL THEN
    -- Log failed attempt
    INSERT INTO public.security_login_attempts (username, success)
    VALUES (p_username, false);
    
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid username or password',
      'role', null
    );
  END IF;
  
  -- Verify password (handles both plain and hashed)
  IF NOT public.verify_password(p_password, v_user.password) THEN
    -- Log failed attempt
    INSERT INTO public.security_login_attempts (username, success)
    VALUES (p_username, false);
    
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid username or password',
      'role', null
    );
  END IF;
  
  -- SUCCESS! Log successful login
  INSERT INTO public.security_login_attempts (username, success)
  VALUES (p_username, true);
  
  -- Migrate plain text password to hashed (silently)
  IF v_user.password NOT LIKE '$2%' THEN
    UPDATE users 
    SET password = public.hash_password(p_password)
    WHERE username = v_user.username;
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'message', 'Login successful',
    'role', v_user.role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute to anon (for login screen)
GRANT EXECUTE ON FUNCTION public.secure_login TO anon;
GRANT EXECUTE ON FUNCTION public.secure_login TO authenticated;

-- ============================================
-- STEP 6: Secure Add User Function (NEW)
-- Hashes password automatically
-- ============================================

CREATE OR REPLACE FUNCTION public.secure_add_user(
  p_username TEXT,
  p_password TEXT,
  p_role TEXT
)
RETURNS JSON AS $$
DECLARE
  v_hashed_password TEXT;
BEGIN
  -- Validate role
  IF p_role NOT IN ('student', 'teacher', 'admin', 'staff', 'HR', 'hod') THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid role: ' || p_role
    );
  END IF;
  
  -- Hash the password
  v_hashed_password := public.hash_password(p_password);
  
  -- Insert user
  INSERT INTO users (username, password, role)
  VALUES (LOWER(TRIM(p_username)), v_hashed_password, p_role);
  
  -- Log the action
  INSERT INTO public.security_audit_log (table_name, operation, record_id, new_data)
  VALUES ('users', 'INSERT', p_username, 
          json_build_object('username', p_username, 'role', p_role)::jsonb);
  
  RETURN json_build_object(
    'success', true,
    'message', 'User created successfully',
    'username', p_username
  );
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Username already exists'
    );
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Error creating user: ' || SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_add_user TO authenticated;

-- ============================================
-- VERIFICATION QUERIES (Just for checking)
-- ============================================

-- Show all new security tables
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_name LIKE 'security%';

-- Test password hashing
-- SELECT public.hash_password('test123');

-- Test password verification
-- SELECT public.verify_password('test123', public.hash_password('test123'));

-- ============================================
-- SUCCESS!
-- ============================================

DO $$ 
BEGIN 
  RAISE NOTICE '';
  RAISE NOTICE '✅ Security Foundation Setup Complete!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 What was created:';
  RAISE NOTICE '   • security_login_attempts table (audit logins)';
  RAISE NOTICE '   • security_audit_log table (track changes)';
  RAISE NOTICE '   • hash_password() function';
  RAISE NOTICE '   • verify_password() function';  
  RAISE NOTICE '   • check_login_rate_limit() function';
  RAISE NOTICE '   • secure_login() RPC function';
  RAISE NOTICE '   • secure_add_user() RPC function';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️ IMPORTANT:';
  RAISE NOTICE '   • Current login still works (backward compatible)';
  RAISE NOTICE '   • Passwords are auto-migrated to hashed on next login';
  RAISE NOTICE '   • No data was deleted or modified';
  RAISE NOTICE '';
  RAISE NOTICE '👉 Next: Run 02_rls_policies_safe.sql';
END $$;
