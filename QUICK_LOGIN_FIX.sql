-- ============================================
-- QUICK LOGIN FIX - Run this in Supabase SQL Editor
-- ============================================

-- Step 0: Drop existing functions with different parameter names
DROP FUNCTION IF EXISTS public.verify_password(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.check_device_rate_limit(TEXT, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS public.log_device_login_attempt(TEXT, TEXT, TEXT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS public.check_ip_rate_limit(TEXT, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS public.log_ip_login_attempt(TEXT, TEXT, TEXT, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS public.secure_login_v3(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_ip_status(TEXT);
DROP FUNCTION IF EXISTS public.get_remaining_login_attempts(TEXT);

-- Step 1: Make sure verify_password function exists
CREATE OR REPLACE FUNCTION public.verify_password(
  p_input_password TEXT,
  p_stored_password TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  -- If stored password is bcrypt hashed (starts with $2)
  IF p_stored_password LIKE '$2%' THEN
    RETURN public.crypt(p_input_password, p_stored_password) = p_stored_password;
  ELSE
    -- Plain text comparison (for legacy passwords)
    RETURN p_input_password = p_stored_password;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.verify_password TO anon, authenticated;

-- Step 2: Make sure device rate limit functions exist
CREATE TABLE IF NOT EXISTS public.device_login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint TEXT NOT NULL,
  username TEXT,
  ip_address TEXT,
  user_agent TEXT,
  success BOOLEAN NOT NULL DEFAULT false,
  attempted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_login_fingerprint ON public.device_login_attempts(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_device_login_time ON public.device_login_attempts(attempted_at DESC);

ALTER TABLE public.device_login_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "device_login_all" ON public.device_login_attempts;
CREATE POLICY "device_login_all" ON public.device_login_attempts FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- Step 3: Check device rate limit function
CREATE OR REPLACE FUNCTION public.check_device_rate_limit(
  p_device_fingerprint TEXT,
  p_max_attempts INTEGER DEFAULT 5,
  p_window_minutes INTEGER DEFAULT 60
)
RETURNS TABLE(
  is_blocked BOOLEAN,
  failed_attempts INTEGER,
  block_remaining_minutes INTEGER
) AS $$
DECLARE
  v_failed_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_failed_count 
  FROM public.device_login_attempts
  WHERE device_fingerprint = p_device_fingerprint 
    AND success = false
    AND attempted_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  IF v_failed_count >= p_max_attempts THEN
    RETURN QUERY SELECT true, v_failed_count, 60;
  ELSE
    RETURN QUERY SELECT false, v_failed_count, 0;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_device_rate_limit TO anon, authenticated;

-- Step 4: Log device login attempt
CREATE OR REPLACE FUNCTION public.log_device_login_attempt(
  p_device_fingerprint TEXT,
  p_username TEXT,
  p_ip_address TEXT,
  p_user_agent TEXT,
  p_success BOOLEAN
) RETURNS VOID AS $$
BEGIN
  INSERT INTO public.device_login_attempts (device_fingerprint, username, ip_address, user_agent, success)
  VALUES (p_device_fingerprint, p_username, p_ip_address, p_user_agent, p_success);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.log_device_login_attempt TO anon, authenticated;

-- Step 5: IP rate limiting tables and functions
CREATE TABLE IF NOT EXISTS public.ip_login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL,
  username TEXT,
  device_fingerprint TEXT,
  success BOOLEAN NOT NULL DEFAULT false,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  blocked_until TIMESTAMPTZ,
  user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_ip_login_ip ON public.ip_login_attempts(ip_address);
ALTER TABLE public.ip_login_attempts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ip_login_all" ON public.ip_login_attempts;
CREATE POLICY "ip_login_all" ON public.ip_login_attempts FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

CREATE TABLE IF NOT EXISTS public.blocked_ips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL UNIQUE,
  reason TEXT,
  blocked_by TEXT,
  blocked_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_permanent BOOLEAN DEFAULT false
);

ALTER TABLE public.blocked_ips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "blocked_ips_select" ON public.blocked_ips;
CREATE POLICY "blocked_ips_select" ON public.blocked_ips FOR SELECT TO anon, authenticated USING (true);

-- Step 6: Check IP rate limit
CREATE OR REPLACE FUNCTION public.check_ip_rate_limit(
  p_ip_address TEXT,
  p_max_attempts INTEGER DEFAULT 10,
  p_window_minutes INTEGER DEFAULT 60
)
RETURNS TABLE(
  is_blocked BOOLEAN,
  failed_attempts INTEGER,
  block_remaining_minutes INTEGER,
  block_reason TEXT
) AS $$
DECLARE
  v_failed_count INTEGER;
  v_permanent_block RECORD;
BEGIN
  -- Check permanent blocks
  SELECT * INTO v_permanent_block FROM public.blocked_ips
  WHERE ip_address = p_ip_address AND (is_permanent = true OR expires_at > NOW());
  
  IF v_permanent_block.id IS NOT NULL THEN
    RETURN QUERY SELECT true, 999, 9999, COALESCE(v_permanent_block.reason, 'IP is blocked');
    RETURN;
  END IF;
  
  -- Count failures
  SELECT COUNT(*) INTO v_failed_count FROM public.ip_login_attempts
  WHERE ip_address = p_ip_address AND success = false
    AND attempted_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  IF v_failed_count >= p_max_attempts THEN
    RETURN QUERY SELECT true, v_failed_count, 60, 'Rate limit exceeded'::TEXT;
  ELSE
    RETURN QUERY SELECT false, v_failed_count, 0, NULL::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_ip_rate_limit TO anon, authenticated;

-- Step 7: Log IP attempt
CREATE OR REPLACE FUNCTION public.log_ip_login_attempt(
  p_ip_address TEXT,
  p_username TEXT,
  p_device_fingerprint TEXT,
  p_user_agent TEXT,
  p_success BOOLEAN
) RETURNS VOID AS $$
BEGIN
  INSERT INTO public.ip_login_attempts (ip_address, username, device_fingerprint, user_agent, success)
  VALUES (p_ip_address, p_username, p_device_fingerprint, p_user_agent, p_success);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.log_ip_login_attempt TO anon, authenticated;

-- Step 8: Secure Login V3
CREATE OR REPLACE FUNCTION public.secure_login_v3(
  p_username TEXT,
  p_password TEXT,
  p_device_fingerprint TEXT DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_user RECORD;
  v_device_rate_limit RECORD;
  v_ip_rate_limit RECORD;
  v_device TEXT;
  v_ip TEXT;
BEGIN
  v_device := COALESCE(NULLIF(TRIM(p_device_fingerprint), ''), md5(COALESCE(p_ip_address, 'x') || COALESCE(p_user_agent, 'x')));
  v_ip := COALESCE(NULLIF(TRIM(p_ip_address), ''), 'unknown');
  
  -- Validate inputs
  IF p_username IS NULL OR TRIM(p_username) = '' OR p_password IS NULL OR TRIM(p_password) = '' THEN
    PERFORM public.log_ip_login_attempt(v_ip, p_username, v_device, p_user_agent, false);
    PERFORM public.log_device_login_attempt(v_device, p_username, v_ip, p_user_agent, false);
    RETURN json_build_object('success', false, 'message', 'Username and password are required', 'role', null);
  END IF;
  
  -- Check IP rate limit
  SELECT * INTO v_ip_rate_limit FROM public.check_ip_rate_limit(v_ip, 10, 60);
  IF v_ip_rate_limit.is_blocked THEN
    RETURN json_build_object('success', false, 'message', 'IP blocked. Try again later.', 'role', null, 'rate_limited', true);
  END IF;
  
  -- Check device rate limit
  SELECT * INTO v_device_rate_limit FROM public.check_device_rate_limit(v_device, 5, 60);
  IF v_device_rate_limit.is_blocked THEN
    PERFORM public.log_ip_login_attempt(v_ip, p_username, v_device, p_user_agent, false);
    RETURN json_build_object('success', false, 'message', 'Device blocked. Try again later.', 'role', null, 'rate_limited', true);
  END IF;
  
  -- Find user
  SELECT username, password, role INTO v_user FROM public.users WHERE username = LOWER(TRIM(p_username));
  
  -- Verify credentials
  IF v_user.username IS NULL OR NOT public.verify_password(p_password, v_user.password) THEN
    PERFORM public.log_device_login_attempt(v_device, p_username, v_ip, p_user_agent, false);
    PERFORM public.log_ip_login_attempt(v_ip, p_username, v_device, p_user_agent, false);
    RETURN json_build_object('success', false, 'message', 'Invalid username or password', 'role', null);
  END IF;
  
  -- SUCCESS
  PERFORM public.log_device_login_attempt(v_device, v_user.username, v_ip, p_user_agent, true);
  PERFORM public.log_ip_login_attempt(v_ip, v_user.username, v_device, p_user_agent, true);
  
  RETURN json_build_object('success', true, 'message', 'Login successful', 'role', v_user.role);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_login_v3 TO anon, authenticated;

-- Step 9: Get IP status
CREATE OR REPLACE FUNCTION public.get_ip_status(p_ip_address TEXT)
RETURNS JSON AS $$
DECLARE
  v_rate_limit RECORD;
BEGIN
  SELECT * INTO v_rate_limit FROM public.check_ip_rate_limit(p_ip_address);
  RETURN json_build_object(
    'ip', p_ip_address,
    'is_blocked', v_rate_limit.is_blocked,
    'remaining_attempts', GREATEST(0, 10 - COALESCE(v_rate_limit.failed_attempts, 0))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_ip_status TO anon, authenticated;

-- Step 10: Get remaining attempts
CREATE OR REPLACE FUNCTION public.get_remaining_login_attempts(p_device_fingerprint TEXT)
RETURNS JSON AS $$
DECLARE
  v_rate_limit RECORD;
BEGIN
  SELECT * INTO v_rate_limit FROM public.check_device_rate_limit(p_device_fingerprint, 5, 60);
  IF v_rate_limit.is_blocked THEN
    RETURN json_build_object('remaining_attempts', 0, 'is_blocked', true, 'message', 'Device blocked');
  ELSE
    RETURN json_build_object('remaining_attempts', 5 - v_rate_limit.failed_attempts, 'is_blocked', false);
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_remaining_login_attempts TO anon, authenticated;

-- Done!
SELECT '✅ All login functions created/updated! Try logging in now.' as status;
