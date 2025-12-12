-- ============================================
-- IP-BASED RATE LIMITING & BLOCKING
-- Run this in Supabase SQL Editor
-- ============================================

-- 1. Create IP login attempts table
CREATE TABLE IF NOT EXISTS public.ip_login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL,
  username TEXT,
  device_fingerprint TEXT,
  success BOOLEAN NOT NULL DEFAULT false,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  blocked_until TIMESTAMPTZ,
  country_code TEXT,
  user_agent TEXT
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_ip_login_ip ON public.ip_login_attempts(ip_address);
CREATE INDEX IF NOT EXISTS idx_ip_login_time ON public.ip_login_attempts(attempted_at DESC);
CREATE INDEX IF NOT EXISTS idx_ip_login_blocked ON public.ip_login_attempts(blocked_until);

-- Enable RLS
ALTER TABLE public.ip_login_attempts ENABLE ROW LEVEL SECURITY;

-- Allow anon and authenticated to use this table (for logging)
DROP POLICY IF EXISTS "ip_login_all" ON public.ip_login_attempts;
CREATE POLICY "ip_login_all" ON public.ip_login_attempts 
  FOR ALL TO anon, authenticated 
  USING (true) WITH CHECK (true);

-- 2. Blocked IPs table (for permanent/manual blocks)
CREATE TABLE IF NOT EXISTS public.blocked_ips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address TEXT NOT NULL UNIQUE,
  reason TEXT,
  blocked_by TEXT,
  blocked_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_permanent BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_blocked_ips_ip ON public.blocked_ips(ip_address);
ALTER TABLE public.blocked_ips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blocked_ips_select" ON public.blocked_ips;
CREATE POLICY "blocked_ips_select" ON public.blocked_ips 
  FOR SELECT TO anon, authenticated USING (true);

-- 3. Check IP rate limit function
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
  v_block_until TIMESTAMPTZ;
  v_permanent_block RECORD;
BEGIN
  -- Check if IP is permanently blocked
  SELECT * INTO v_permanent_block
  FROM public.blocked_ips
  WHERE ip_address = p_ip_address
    AND (is_permanent = true OR expires_at > NOW());
  
  IF v_permanent_block.id IS NOT NULL THEN
    RETURN QUERY SELECT 
      true, 
      999, 
      CASE 
        WHEN v_permanent_block.is_permanent THEN 9999
        ELSE GREATEST(0, EXTRACT(EPOCH FROM (v_permanent_block.expires_at - NOW())) / 60)::INTEGER
      END,
      COALESCE(v_permanent_block.reason, 'IP is blocked');
    RETURN;
  END IF;
  
  -- Check if IP has existing temp block
  SELECT ila.blocked_until INTO v_block_until
  FROM public.ip_login_attempts ila
  WHERE ila.ip_address = p_ip_address
    AND ila.blocked_until IS NOT NULL 
    AND ila.blocked_until > NOW()
  ORDER BY ila.blocked_until DESC 
  LIMIT 1;
  
  IF v_block_until IS NOT NULL THEN
    RETURN QUERY SELECT 
      true, 
      p_max_attempts, 
      GREATEST(0, EXTRACT(EPOCH FROM (v_block_until - NOW())) / 60)::INTEGER,
      'Too many failed attempts from this IP';
    RETURN;
  END IF;
  
  -- Count recent failures from this IP
  SELECT COUNT(*) INTO v_failed_count 
  FROM public.ip_login_attempts
  WHERE ip_address = p_ip_address 
    AND success = false
    AND attempted_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  -- Check if exceeded limit
  IF v_failed_count >= p_max_attempts THEN
    RETURN QUERY SELECT true, v_failed_count, 60, 'Rate limit exceeded';
  ELSE
    RETURN QUERY SELECT false, v_failed_count, 0, NULL::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_ip_rate_limit TO anon, authenticated;

-- 4. Log IP login attempt
CREATE OR REPLACE FUNCTION public.log_ip_login_attempt(
  p_ip_address TEXT,
  p_username TEXT,
  p_device_fingerprint TEXT,
  p_user_agent TEXT,
  p_success BOOLEAN
) RETURNS VOID AS $$
DECLARE
  v_failed_count INTEGER;
BEGIN
  -- Insert the attempt
  INSERT INTO public.ip_login_attempts (
    ip_address, username, device_fingerprint, user_agent, success
  ) VALUES (
    p_ip_address, p_username, p_device_fingerprint, p_user_agent, p_success
  );
  
  -- If failed, check if we need to block this IP
  IF NOT p_success THEN
    SELECT COUNT(*) INTO v_failed_count 
    FROM public.ip_login_attempts
    WHERE ip_address = p_ip_address 
      AND success = false
      AND attempted_at > NOW() - INTERVAL '1 hour';
    
    -- Block IP for 1 hour after 10 failed attempts
    IF v_failed_count >= 10 THEN
      INSERT INTO public.ip_login_attempts (
        ip_address, username, device_fingerprint, user_agent, success, blocked_until
      ) VALUES (
        p_ip_address, p_username, p_device_fingerprint, p_user_agent, false, NOW() + INTERVAL '1 hour'
      );
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.log_ip_login_attempt TO anon, authenticated;

-- 5. Updated secure_login_v3 with IP blocking
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
  -- Sanitize inputs
  v_device := COALESCE(NULLIF(TRIM(p_device_fingerprint), ''), 
    md5(COALESCE(p_ip_address, 'x') || COALESCE(p_user_agent, 'x')));
  v_ip := COALESCE(NULLIF(TRIM(p_ip_address), ''), 'unknown');
  
  -- Validate required inputs
  IF p_username IS NULL OR TRIM(p_username) = '' OR 
     p_password IS NULL OR TRIM(p_password) = '' THEN
    PERFORM public.log_ip_login_attempt(v_ip, p_username, v_device, p_user_agent, false);
    PERFORM public.log_device_login_attempt(v_device, p_username, v_ip, p_user_agent, false);
    RETURN json_build_object(
      'success', false,
      'message', 'Username and password are required',
      'role', null
    );
  END IF;
  
  -- CHECK 1: IP-based rate limit (stricter - 10 attempts/hour per IP)
  SELECT * INTO v_ip_rate_limit 
  FROM public.check_ip_rate_limit(v_ip, 10, 60);
  
  IF v_ip_rate_limit.is_blocked THEN
    RETURN json_build_object(
      'success', false,
      'message', 'IP blocked: ' || COALESCE(v_ip_rate_limit.block_reason, 'Too many attempts') || 
                 '. Try again in ' || v_ip_rate_limit.block_remaining_minutes || ' minutes.',
      'role', null,
      'rate_limited', true,
      'block_type', 'ip',
      'block_remaining_minutes', v_ip_rate_limit.block_remaining_minutes
    );
  END IF;
  
  -- CHECK 2: Device-based rate limit (5 attempts/hour per device)
  SELECT * INTO v_device_rate_limit 
  FROM public.check_device_rate_limit(v_device, 5, 60);
  
  IF v_device_rate_limit.is_blocked THEN
    -- Also log IP attempt
    PERFORM public.log_ip_login_attempt(v_ip, p_username, v_device, p_user_agent, false);
    RETURN json_build_object(
      'success', false,
      'message', 'Device blocked for ' || v_device_rate_limit.block_remaining_minutes || ' minutes',
      'role', null,
      'rate_limited', true,
      'block_type', 'device',
      'block_remaining_minutes', v_device_rate_limit.block_remaining_minutes
    );
  END IF;
  
  -- Find user
  SELECT username, password, role INTO v_user
  FROM public.users
  WHERE username = LOWER(TRIM(p_username));
  
  -- User not found OR password mismatch (same message for security)
  IF v_user.username IS NULL OR NOT public.verify_password(p_password, v_user.password) THEN
    PERFORM public.log_device_login_attempt(v_device, p_username, v_ip, p_user_agent, false);
    PERFORM public.log_ip_login_attempt(v_ip, p_username, v_device, p_user_agent, false);
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid username or password',
      'role', null
    );
  END IF;
  
  -- SUCCESS - Log successful login
  PERFORM public.log_device_login_attempt(v_device, v_user.username, v_ip, p_user_agent, true);
  PERFORM public.log_ip_login_attempt(v_ip, v_user.username, v_device, p_user_agent, true);
  
  -- Auto-migrate plain text password to bcrypt
  IF v_user.password NOT LIKE '$2%' THEN
    UPDATE public.users 
    SET password = public.hash_password(p_password) 
    WHERE username = v_user.username;
  END IF;
  
  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Login successful',
    'role', v_user.role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_login_v3 TO anon, authenticated;

-- 6. Admin functions to manage IP blocks
CREATE OR REPLACE FUNCTION public.admin_block_ip(
  p_ip_address TEXT,
  p_reason TEXT DEFAULT 'Manual block',
  p_blocked_by TEXT DEFAULT 'admin',
  p_duration_hours INTEGER DEFAULT NULL,
  p_permanent BOOLEAN DEFAULT false
) RETURNS JSON AS $$
BEGIN
  INSERT INTO public.blocked_ips (ip_address, reason, blocked_by, expires_at, is_permanent)
  VALUES (
    p_ip_address, 
    p_reason, 
    p_blocked_by, 
    CASE WHEN p_permanent THEN NULL ELSE NOW() + (p_duration_hours || ' hours')::INTERVAL END,
    p_permanent
  )
  ON CONFLICT (ip_address) DO UPDATE SET
    reason = EXCLUDED.reason,
    blocked_by = EXCLUDED.blocked_by,
    blocked_at = NOW(),
    expires_at = EXCLUDED.expires_at,
    is_permanent = EXCLUDED.is_permanent;
  
  RETURN json_build_object('success', true, 'message', 'IP blocked successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.admin_unblock_ip(p_ip_address TEXT)
RETURNS JSON AS $$
BEGIN
  DELETE FROM public.blocked_ips WHERE ip_address = p_ip_address;
  
  -- Also clear temp blocks
  UPDATE public.ip_login_attempts 
  SET blocked_until = NULL 
  WHERE ip_address = p_ip_address;
  
  RETURN json_build_object('success', true, 'message', 'IP unblocked successfully');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.admin_block_ip TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_unblock_ip TO authenticated;

-- 7. Analytics view for IP monitoring
CREATE OR REPLACE VIEW public.ip_login_analytics AS
SELECT 
  ip_address,
  COUNT(*) as total_attempts,
  COUNT(*) FILTER (WHERE success = true) as successful_logins,
  COUNT(*) FILTER (WHERE success = false) as failed_logins,
  COUNT(DISTINCT username) as unique_usernames_tried,
  COUNT(DISTINCT device_fingerprint) as unique_devices,
  MAX(attempted_at) as last_attempt,
  CASE 
    WHEN COUNT(*) FILTER (WHERE success = false) > 5 
         AND COUNT(*) FILTER (WHERE success = true) = 0 
    THEN 'SUSPICIOUS'
    WHEN COUNT(*) FILTER (WHERE success = false) > 10 THEN 'HIGH_RISK'
    ELSE 'NORMAL'
  END as risk_level
FROM public.ip_login_attempts
WHERE attempted_at > NOW() - INTERVAL '24 hours'
GROUP BY ip_address
ORDER BY failed_logins DESC;

-- 8. Get IP status function
CREATE OR REPLACE FUNCTION public.get_ip_status(p_ip_address TEXT)
RETURNS JSON AS $$
DECLARE
  v_rate_limit RECORD;
  v_stats RECORD;
BEGIN
  SELECT * INTO v_rate_limit FROM public.check_ip_rate_limit(p_ip_address);
  
  SELECT 
    COUNT(*) FILTER (WHERE success = false AND attempted_at > NOW() - INTERVAL '1 hour') as recent_failures,
    COUNT(*) FILTER (WHERE success = true AND attempted_at > NOW() - INTERVAL '1 hour') as recent_success
  INTO v_stats
  FROM public.ip_login_attempts
  WHERE ip_address = p_ip_address;
  
  RETURN json_build_object(
    'ip', p_ip_address,
    'is_blocked', v_rate_limit.is_blocked,
    'block_reason', v_rate_limit.block_reason,
    'block_remaining_minutes', v_rate_limit.block_remaining_minutes,
    'recent_failures', COALESCE(v_stats.recent_failures, 0),
    'recent_success', COALESCE(v_stats.recent_success, 0),
    'remaining_attempts', GREATEST(0, 10 - COALESCE(v_rate_limit.failed_attempts, 0))
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_ip_status TO anon, authenticated;

-- Done!
SELECT '✅ IP-based blocking installed! Use secure_login_v3 instead of secure_login_v2' as status;
