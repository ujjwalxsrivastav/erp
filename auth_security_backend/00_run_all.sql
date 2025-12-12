-- ============================================
-- COMPLETE AUTH SECURITY SETUP
-- Run this single file in Supabase SQL Editor
-- ============================================

-- PART 1: Users Table RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_anon_select" ON public.users;
DROP POLICY IF EXISTS "users_authenticated_all" ON public.users;
DROP POLICY IF EXISTS "anon_can_read_for_login" ON public.users;
DROP POLICY IF EXISTS "authenticated_can_read_users" ON public.users;
DROP POLICY IF EXISTS "authenticated_can_insert_users" ON public.users;

CREATE POLICY "anon_can_read_for_login" ON public.users FOR SELECT TO anon USING (true);
CREATE POLICY "authenticated_can_read_users" ON public.users FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated_can_insert_users" ON public.users FOR INSERT TO authenticated WITH CHECK (true);

-- PART 2: Device Login Attempts Table
CREATE TABLE IF NOT EXISTS public.device_login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint TEXT NOT NULL,
  username TEXT,
  ip_address TEXT,
  user_agent TEXT,
  success BOOLEAN NOT NULL DEFAULT false,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  blocked_until TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_device_login_fingerprint ON public.device_login_attempts(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_device_login_time ON public.device_login_attempts(attempted_at DESC);

ALTER TABLE public.device_login_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "device_login_all" ON public.device_login_attempts;
CREATE POLICY "device_login_all" ON public.device_login_attempts FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- PART 3: Device Rate Limiting Function
CREATE OR REPLACE FUNCTION public.check_device_rate_limit(
  p_device_fingerprint TEXT,
  p_max_attempts INTEGER DEFAULT 5,
  p_window_minutes INTEGER DEFAULT 60
)
RETURNS TABLE(is_blocked BOOLEAN, failed_attempts INTEGER, block_remaining_minutes INTEGER) AS $$
DECLARE
  v_failed_count INTEGER;
  v_block_until TIMESTAMPTZ;
BEGIN
  SELECT dla.blocked_until INTO v_block_until
  FROM public.device_login_attempts dla
  WHERE dla.device_fingerprint = p_device_fingerprint
    AND dla.blocked_until IS NOT NULL AND dla.blocked_until > NOW()
  ORDER BY dla.blocked_until DESC LIMIT 1;
  
  IF v_block_until IS NOT NULL THEN
    RETURN QUERY SELECT true, p_max_attempts, 
      GREATEST(0, EXTRACT(EPOCH FROM (v_block_until - NOW())) / 60)::INTEGER;
    RETURN;
  END IF;
  
  SELECT COUNT(*) INTO v_failed_count FROM public.device_login_attempts
  WHERE device_fingerprint = p_device_fingerprint AND success = false
    AND attempted_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  IF v_failed_count >= p_max_attempts THEN
    RETURN QUERY SELECT true, v_failed_count, 60;
  ELSE
    RETURN QUERY SELECT false, v_failed_count, 0;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_device_rate_limit TO anon, authenticated;

-- PART 4: Log Device Attempt Function
CREATE OR REPLACE FUNCTION public.log_device_login_attempt(
  p_device_fingerprint TEXT, p_username TEXT, p_ip_address TEXT, p_user_agent TEXT, p_success BOOLEAN
) RETURNS VOID AS $$
DECLARE v_failed_count INTEGER;
BEGIN
  INSERT INTO public.device_login_attempts (device_fingerprint, username, ip_address, user_agent, success)
  VALUES (p_device_fingerprint, p_username, p_ip_address, p_user_agent, p_success);
  
  IF NOT p_success THEN
    SELECT COUNT(*) INTO v_failed_count FROM public.device_login_attempts
    WHERE device_fingerprint = p_device_fingerprint AND success = false
      AND attempted_at > NOW() - INTERVAL '1 hour';
    
    IF v_failed_count >= 5 THEN
      INSERT INTO public.device_login_attempts (device_fingerprint, username, ip_address, user_agent, success, blocked_until)
      VALUES (p_device_fingerprint, p_username, p_ip_address, p_user_agent, false, NOW() + INTERVAL '1 hour');
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.log_device_login_attempt TO anon, authenticated;

-- PART 5: Secure Login V2
CREATE OR REPLACE FUNCTION public.secure_login_v2(
  p_username TEXT, p_password TEXT, p_device_fingerprint TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL, p_user_agent TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_user RECORD; v_rate_limit RECORD; v_device TEXT;
BEGIN
  v_device := COALESCE(p_device_fingerprint, md5(COALESCE(p_ip_address, 'x') || COALESCE(p_user_agent, 'x')));
  
  IF p_username IS NULL OR TRIM(p_username) = '' OR p_password IS NULL OR TRIM(p_password) = '' THEN
    PERFORM public.log_device_login_attempt(v_device, p_username, p_ip_address, p_user_agent, false);
    RETURN json_build_object('success', false, 'message', 'Username and password required', 'role', null);
  END IF;
  
  SELECT * INTO v_rate_limit FROM public.check_device_rate_limit(v_device, 5, 60);
  IF v_rate_limit.is_blocked THEN
    RETURN json_build_object('success', false, 'message', 'Device blocked for ' || v_rate_limit.block_remaining_minutes || ' minutes', 'role', null, 'rate_limited', true);
  END IF;
  
  SELECT username, password, role INTO v_user FROM public.users WHERE username = LOWER(TRIM(p_username));
  
  IF v_user.username IS NULL OR NOT public.verify_password(p_password, v_user.password) THEN
    PERFORM public.log_device_login_attempt(v_device, p_username, p_ip_address, p_user_agent, false);
    RETURN json_build_object('success', false, 'message', 'Invalid credentials', 'role', null);
  END IF;
  
  PERFORM public.log_device_login_attempt(v_device, v_user.username, p_ip_address, p_user_agent, true);
  
  IF v_user.password NOT LIKE '$2%' THEN
    UPDATE public.users SET password = public.hash_password(p_password) WHERE username = v_user.username;
  END IF;
  
  RETURN json_build_object('success', true, 'message', 'Login successful', 'role', v_user.role);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_login_v2 TO anon, authenticated;

-- PART 6: Secure Add User V2
CREATE OR REPLACE FUNCTION public.secure_add_user_v2(
  p_username TEXT, p_password TEXT, p_role TEXT, p_created_by TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
  v_hashed TEXT; v_clean TEXT; v_roles TEXT[] := ARRAY['student', 'teacher', 'admin', 'staff', 'HR', 'hod'];
BEGIN
  IF p_username IS NULL OR TRIM(p_username) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Username required');
  END IF;
  IF p_password IS NULL OR LENGTH(p_password) < 6 THEN
    RETURN json_build_object('success', false, 'message', 'Password min 6 chars');
  END IF;
  IF NOT (p_role = ANY(v_roles)) THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;
  
  v_clean := LOWER(TRIM(p_username));
  IF EXISTS (SELECT 1 FROM public.users WHERE username = v_clean) THEN
    RETURN json_build_object('success', false, 'message', 'Username exists');
  END IF;
  
  v_hashed := public.hash_password(p_password);
  INSERT INTO public.users (username, password, role) VALUES (v_clean, v_hashed, p_role);
  
  INSERT INTO public.security_audit_log (table_name, operation, record_id, username, new_data)
  VALUES ('users', 'INSERT', v_clean, COALESCE(p_created_by, 'system'), 
          json_build_object('username', v_clean, 'role', p_role)::jsonb);
  
  RETURN json_build_object('success', true, 'message', 'User created', 'username', v_clean);
EXCEPTION WHEN unique_violation THEN
  RETURN json_build_object('success', false, 'message', 'Username exists');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_add_user_v2 TO authenticated;

SELECT '✅ Auth security setup complete!' as status;
