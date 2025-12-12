-- ============================================
-- AUTH SECURITY: DEVICE-BASED RATE LIMITING
-- ============================================
-- Purpose: Protect against brute force attacks
-- - 5 failed attempts per hour per device (IP + user agent)
-- - Block device for 1 hour after 5 failed attempts
-- - Track all login attempts for security monitoring
-- ============================================

-- ============================================
-- STEP 1: Enhanced Login Attempts Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.device_login_attempts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint TEXT NOT NULL, -- Hash of IP + User Agent
  username TEXT,
  ip_address TEXT,
  user_agent TEXT,
  success BOOLEAN NOT NULL DEFAULT false,
  attempted_at TIMESTAMPTZ DEFAULT NOW(),
  blocked_until TIMESTAMPTZ
);

-- Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_device_login_fingerprint 
  ON public.device_login_attempts(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_device_login_time 
  ON public.device_login_attempts(attempted_at DESC);
CREATE INDEX IF NOT EXISTS idx_device_login_blocked 
  ON public.device_login_attempts(device_fingerprint, blocked_until);

-- Enable RLS
ALTER TABLE public.device_login_attempts ENABLE ROW LEVEL SECURITY;

-- Allow inserts from anon (for login screen)
DROP POLICY IF EXISTS "device_login_attempts_insert" ON public.device_login_attempts;
CREATE POLICY "device_login_attempts_insert" ON public.device_login_attempts
FOR INSERT TO anon, authenticated
WITH CHECK (true);

-- Allow reads for rate limit checking
DROP POLICY IF EXISTS "device_login_attempts_select" ON public.device_login_attempts;
CREATE POLICY "device_login_attempts_select" ON public.device_login_attempts
FOR SELECT TO anon, authenticated
USING (true);

-- ============================================
-- STEP 2: Device Rate Limiting Function
-- 5 attempts per hour per device
-- ============================================
CREATE OR REPLACE FUNCTION public.check_device_rate_limit(
  p_device_fingerprint TEXT,
  p_max_attempts INTEGER DEFAULT 5,
  p_window_minutes INTEGER DEFAULT 60  -- 1 hour window
)
RETURNS TABLE(
  is_blocked BOOLEAN,
  failed_attempts INTEGER,
  block_remaining_minutes INTEGER,
  block_until TIMESTAMPTZ
) AS $$
DECLARE
  v_failed_count INTEGER;
  v_block_until TIMESTAMPTZ;
  v_remaining_minutes INTEGER;
BEGIN
  -- Check if device is currently blocked
  SELECT dla.blocked_until INTO v_block_until
  FROM public.device_login_attempts dla
  WHERE dla.device_fingerprint = p_device_fingerprint
    AND dla.blocked_until IS NOT NULL
    AND dla.blocked_until > NOW()
  ORDER BY dla.blocked_until DESC
  LIMIT 1;
  
  IF v_block_until IS NOT NULL THEN
    v_remaining_minutes := GREATEST(0, EXTRACT(EPOCH FROM (v_block_until - NOW())) / 60)::INTEGER;
    RETURN QUERY SELECT true, p_max_attempts, v_remaining_minutes, v_block_until;
    RETURN;
  END IF;
  
  -- Count failed attempts in the last hour
  SELECT COUNT(*) INTO v_failed_count
  FROM public.device_login_attempts
  WHERE device_fingerprint = p_device_fingerprint
    AND success = false
    AND attempted_at > NOW() - (p_window_minutes || ' minutes')::INTERVAL;
  
  -- If reached max attempts, calculate block time
  IF v_failed_count >= p_max_attempts THEN
    v_block_until := NOW() + INTERVAL '1 hour';
    v_remaining_minutes := 60;
    RETURN QUERY SELECT true, v_failed_count, v_remaining_minutes, v_block_until;
  ELSE
    RETURN QUERY SELECT false, v_failed_count, 0, NULL::TIMESTAMPTZ;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_device_rate_limit TO anon;
GRANT EXECUTE ON FUNCTION public.check_device_rate_limit TO authenticated;

-- ============================================
-- STEP 3: Log Device Login Attempt
-- ============================================
CREATE OR REPLACE FUNCTION public.log_device_login_attempt(
  p_device_fingerprint TEXT,
  p_username TEXT,
  p_ip_address TEXT,
  p_user_agent TEXT,
  p_success BOOLEAN
)
RETURNS VOID AS $$
DECLARE
  v_failed_count INTEGER;
BEGIN
  -- Insert the attempt
  INSERT INTO public.device_login_attempts (
    device_fingerprint, username, ip_address, user_agent, success
  ) VALUES (
    p_device_fingerprint, p_username, p_ip_address, p_user_agent, p_success
  );
  
  -- If failed, check if we need to block the device
  IF NOT p_success THEN
    SELECT COUNT(*) INTO v_failed_count
    FROM public.device_login_attempts
    WHERE device_fingerprint = p_device_fingerprint
      AND success = false
      AND attempted_at > NOW() - INTERVAL '1 hour';
    
    -- If 5 or more failures, mark device as blocked
    IF v_failed_count >= 5 THEN
      INSERT INTO public.device_login_attempts (
        device_fingerprint, username, ip_address, user_agent, success, blocked_until
      ) VALUES (
        p_device_fingerprint, p_username, p_ip_address, p_user_agent, false, NOW() + INTERVAL '1 hour'
      );
    END IF;
  ELSE
    -- On successful login, clear the block (optional - depends on your policy)
    -- Uncomment below if you want successful login to reset the block
    -- DELETE FROM public.device_login_attempts 
    -- WHERE device_fingerprint = p_device_fingerprint AND blocked_until IS NOT NULL;
    NULL;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.log_device_login_attempt TO anon;
GRANT EXECUTE ON FUNCTION public.log_device_login_attempt TO authenticated;

-- ============================================
-- STEP 4: Cleanup old attempts (run periodically)
-- ============================================
CREATE OR REPLACE FUNCTION public.cleanup_old_login_attempts()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.device_login_attempts
  WHERE attempted_at < NOW() - INTERVAL '7 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- STEP 5: Suspicious Activity Detection
-- ============================================
CREATE OR REPLACE FUNCTION public.detect_suspicious_device(p_device_fingerprint TEXT)
RETURNS TABLE(
  is_suspicious BOOLEAN,
  reason TEXT,
  total_failed_attempts INTEGER,
  unique_usernames_tried INTEGER
) AS $$
DECLARE
  v_failed_count INTEGER;
  v_unique_users INTEGER;
BEGIN
  -- Count failed attempts in last 24 hours
  SELECT COUNT(*), COUNT(DISTINCT username)
  INTO v_failed_count, v_unique_users
  FROM public.device_login_attempts
  WHERE device_fingerprint = p_device_fingerprint
    AND success = false
    AND attempted_at > NOW() - INTERVAL '24 hours';
  
  -- Suspicious patterns:
  -- 1. More than 10 failed attempts in 24 hours
  -- 2. Trying more than 3 different usernames (credential stuffing)
  IF v_failed_count > 10 OR v_unique_users > 3 THEN
    RETURN QUERY SELECT 
      true,
      CASE 
        WHEN v_unique_users > 3 THEN 'Possible credential stuffing - tried ' || v_unique_users || ' different usernames'
        ELSE 'High number of failed attempts: ' || v_failed_count
      END,
      v_failed_count,
      v_unique_users;
  ELSE
    RETURN QUERY SELECT false, 'No suspicious activity', v_failed_count, v_unique_users;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.detect_suspicious_device TO authenticated;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Device-based rate limiting implemented successfully!' as status;
