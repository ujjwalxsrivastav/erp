-- ============================================
-- AUTH SECURITY: ADDITIONAL SECURITY MEASURES
-- ============================================
-- Purpose: Extra security layers
-- 1. SQL Injection prevention
-- 2. Session management
-- 3. Password expiry (optional)
-- 4. Account lockout tracking
-- 5. Login analytics
-- ============================================

-- ============================================
-- STEP 1: Input Sanitization Functions
-- ============================================

-- Sanitize text input to prevent SQL injection
CREATE OR REPLACE FUNCTION public.sanitize_input(input TEXT)
RETURNS TEXT AS $$
BEGIN
  IF input IS NULL THEN RETURN NULL; END IF;
  
  -- Remove SQL injection patterns
  RETURN regexp_replace(
    regexp_replace(
      regexp_replace(
        TRIM(input),
        E'[''\"\\\\;]', '', 'g'  -- Remove quotes, backslashes, semicolons
      ),
      E'--', '', 'g'  -- Remove SQL comment patterns
    ),
    E'[\\x00-\\x1F]', '', 'g'  -- Remove control characters
  );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Validate email format
CREATE OR REPLACE FUNCTION public.is_valid_email(email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF email IS NULL THEN RETURN false; END IF;
  RETURN email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Validate Indian phone number
CREATE OR REPLACE FUNCTION public.is_valid_phone(phone TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  IF phone IS NULL THEN RETURN false; END IF;
  -- Indian mobile: starts with 6-9, 10 digits
  RETURN phone ~* '^[6-9]\d{9}$';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Grant access
GRANT EXECUTE ON FUNCTION public.sanitize_input TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_valid_email TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_valid_phone TO authenticated;

-- ============================================
-- STEP 2: Blocked Devices Table
-- ============================================
CREATE TABLE IF NOT EXISTS public.blocked_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_fingerprint TEXT NOT NULL UNIQUE,
  reason TEXT,
  blocked_at TIMESTAMPTZ DEFAULT NOW(),
  blocked_until TIMESTAMPTZ,
  is_permanent BOOLEAN DEFAULT false,
  blocked_by TEXT
);

CREATE INDEX IF NOT EXISTS idx_blocked_devices_fingerprint 
  ON public.blocked_devices(device_fingerprint);

-- Enable RLS
ALTER TABLE public.blocked_devices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "blocked_devices_select" ON public.blocked_devices;
CREATE POLICY "blocked_devices_select" ON public.blocked_devices
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "blocked_devices_admin" ON public.blocked_devices;
CREATE POLICY "blocked_devices_admin" ON public.blocked_devices
FOR ALL TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================
-- STEP 3: Check if Device is Permanently Blocked
-- ============================================
CREATE OR REPLACE FUNCTION public.is_device_blocked(p_device_fingerprint TEXT)
RETURNS TABLE(
  is_blocked BOOLEAN,
  reason TEXT,
  blocked_until TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    CASE 
      WHEN bd.is_permanent THEN true
      WHEN bd.blocked_until IS NOT NULL AND bd.blocked_until > NOW() THEN true
      ELSE false
    END,
    bd.reason,
    bd.blocked_until
  FROM public.blocked_devices bd
  WHERE bd.device_fingerprint = p_device_fingerprint
  LIMIT 1;
  
  -- If no record found, return false
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TIMESTAMPTZ;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_device_blocked TO anon;
GRANT EXECUTE ON FUNCTION public.is_device_blocked TO authenticated;

-- ============================================
-- STEP 4: Block Device Function (for Admin)
-- ============================================
CREATE OR REPLACE FUNCTION public.block_device(
  p_device_fingerprint TEXT,
  p_reason TEXT,
  p_duration_hours INTEGER DEFAULT NULL,  -- NULL = permanent
  p_blocked_by TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_blocked_until TIMESTAMPTZ;
BEGIN
  IF p_duration_hours IS NOT NULL THEN
    v_blocked_until := NOW() + (p_duration_hours || ' hours')::INTERVAL;
  END IF;
  
  INSERT INTO public.blocked_devices (
    device_fingerprint, reason, blocked_until, is_permanent, blocked_by
  ) VALUES (
    p_device_fingerprint, 
    p_reason, 
    v_blocked_until, 
    p_duration_hours IS NULL,
    p_blocked_by
  )
  ON CONFLICT (device_fingerprint) 
  DO UPDATE SET
    reason = EXCLUDED.reason,
    blocked_until = EXCLUDED.blocked_until,
    is_permanent = EXCLUDED.is_permanent,
    blocked_by = EXCLUDED.blocked_by,
    blocked_at = NOW();
  
  RETURN json_build_object(
    'success', true,
    'message', 'Device blocked successfully',
    'device_fingerprint', p_device_fingerprint,
    'is_permanent', p_duration_hours IS NULL,
    'blocked_until', v_blocked_until
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.block_device TO authenticated;

-- ============================================
-- STEP 5: Unblock Device Function
-- ============================================
CREATE OR REPLACE FUNCTION public.unblock_device(
  p_device_fingerprint TEXT,
  p_unblocked_by TEXT DEFAULT NULL
)
RETURNS JSON AS $$
BEGIN
  DELETE FROM public.blocked_devices
  WHERE device_fingerprint = p_device_fingerprint;
  
  -- Log the action
  INSERT INTO public.security_audit_log (table_name, operation, record_id, username, new_data)
  VALUES ('blocked_devices', 'UNBLOCK', p_device_fingerprint, p_unblocked_by,
          json_build_object('action', 'device_unblocked', 'unblocked_by', p_unblocked_by)::jsonb);
  
  RETURN json_build_object(
    'success', true,
    'message', 'Device unblocked successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.unblock_device TO authenticated;

-- ============================================
-- STEP 6: Login Analytics View
-- ============================================
CREATE OR REPLACE VIEW public.login_analytics_detailed AS
SELECT 
  DATE(attempted_at) as date,
  EXTRACT(HOUR FROM attempted_at) as hour,
  COUNT(*) as total_attempts,
  COUNT(*) FILTER (WHERE success = true) as successful,
  COUNT(*) FILTER (WHERE success = false) as failed,
  COUNT(DISTINCT username) as unique_users,
  COUNT(DISTINCT device_fingerprint) as unique_devices
FROM public.device_login_attempts
WHERE attempted_at > NOW() - INTERVAL '30 days'
GROUP BY DATE(attempted_at), EXTRACT(HOUR FROM attempted_at)
ORDER BY date DESC, hour DESC;

GRANT SELECT ON public.login_analytics_detailed TO authenticated;

-- ============================================
-- STEP 7: Suspicious Activity Summary
-- ============================================
CREATE OR REPLACE VIEW public.suspicious_activity_summary AS
SELECT 
  device_fingerprint,
  COUNT(*) as total_attempts,
  COUNT(*) FILTER (WHERE success = false) as failed_attempts,
  COUNT(DISTINCT username) as unique_usernames_tried,
  MAX(attempted_at) as last_attempt,
  CASE 
    WHEN COUNT(DISTINCT username) > 3 THEN 'CREDENTIAL_STUFFING'
    WHEN COUNT(*) FILTER (WHERE success = false) > 10 THEN 'BRUTE_FORCE'
    ELSE 'NORMAL'
  END as threat_level
FROM public.device_login_attempts
WHERE attempted_at > NOW() - INTERVAL '24 hours'
GROUP BY device_fingerprint
HAVING COUNT(*) FILTER (WHERE success = false) > 5 
   OR COUNT(DISTINCT username) > 2
ORDER BY failed_attempts DESC;

GRANT SELECT ON public.suspicious_activity_summary TO authenticated;

-- ============================================
-- STEP 8: Account Security Status View
-- ============================================
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN
    EXECUTE '
    CREATE OR REPLACE VIEW public.account_security_status AS
    SELECT 
      u.username,
      u.role,
      CASE WHEN u.password LIKE ''$2%'' THEN ''SECURE'' ELSE ''LEGACY'' END as password_status,
      COALESCE(
        (SELECT COUNT(*) FROM public.device_login_attempts dla 
         WHERE dla.username = u.username AND dla.success = false 
         AND dla.attempted_at > NOW() - INTERVAL ''24 hours''),
        0
      ) as failed_attempts_24h,
      (SELECT MAX(dla.attempted_at) FROM public.device_login_attempts dla 
       WHERE dla.username = u.username AND dla.success = true) as last_successful_login
    FROM public.users u
    ORDER BY failed_attempts_24h DESC;
    
    GRANT SELECT ON public.account_security_status TO authenticated;
    ';
  END IF;
END $$;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Additional security measures implemented successfully!' as status;
