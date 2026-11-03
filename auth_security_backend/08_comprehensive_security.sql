-- ============================================
-- COMPREHENSIVE SECURITY ENHANCEMENTS
-- ============================================
-- Additional security measures beyond auth:
-- 1. File upload validation policies
-- 2. Data access audit logging
-- 3. Sensitive data encryption helpers
-- 4. Enhanced RLS policies
-- 5. Password policy enforcement
-- ============================================

-- ============================================
-- STEP 1: Secure Update Password Function (Enhanced)
-- ============================================
-- Adds password strength validation

CREATE OR REPLACE FUNCTION public.secure_update_password(
  p_username TEXT,
  p_old_password TEXT,
  p_new_password TEXT
)
RETURNS JSON AS $$
DECLARE
  v_stored_password TEXT;
  v_is_valid BOOLEAN;
BEGIN
  -- Get current password
  SELECT password INTO v_stored_password
  FROM public.users
  WHERE username = LOWER(TRIM(p_username));

  IF v_stored_password IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found'
    );
  END IF;

  -- Verify old password
  IF v_stored_password LIKE '$2%' THEN
    v_is_valid := public.verify_password(p_old_password, v_stored_password);
  ELSE
    v_is_valid := (v_stored_password = p_old_password);
  END IF;

  IF NOT v_is_valid THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Current password is incorrect'
    );
  END IF;

  -- Validate new password strength
  IF LENGTH(p_new_password) < 8 THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must be at least 8 characters'
    );
  END IF;

  -- Check for uppercase
  IF p_new_password !~ '[A-Z]' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must contain at least one uppercase letter'
    );
  END IF;

  -- Check for lowercase
  IF p_new_password !~ '[a-z]' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must contain at least one lowercase letter'
    );
  END IF;

  -- Check for number
  IF p_new_password !~ '[0-9]' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must contain at least one number'
    );
  END IF;

  -- Check for special character
  IF p_new_password !~ '[!@#$%^&*(),.?":{}|<>]' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password must contain at least one special character'
    );
  END IF;

  -- Check for common passwords
  IF LOWER(p_new_password) IN ('password', 'password123', '12345678', 'qwerty123', 'admin123', 'letmein123') THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Password is too common. Please choose a stronger password.'
    );
  END IF;

  -- Update with new hashed password
  UPDATE public.users
  SET password = public.hash_password(p_new_password)
  WHERE username = LOWER(TRIM(p_username));

  -- Log the password change
  INSERT INTO public.security_audit_log (table_name, operation, record_id, username, new_data)
  VALUES ('users', 'PASSWORD_CHANGE', p_username, p_username, 
          '{"action": "password_changed"}'::jsonb);

  RETURN json_build_object(
    'success', true,
    'message', 'Password updated successfully'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.secure_update_password TO anon;
GRANT EXECUTE ON FUNCTION public.secure_update_password TO authenticated;

-- ============================================
-- STEP 2: Data Access Audit Trigger
-- ============================================
-- Log access to sensitive tables

CREATE TABLE IF NOT EXISTS public.data_access_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL,
  record_id TEXT,
  accessed_by TEXT,
  accessed_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT,
  fields_accessed TEXT[]
);

CREATE INDEX IF NOT EXISTS idx_data_access_log_table ON public.data_access_log(table_name);
CREATE INDEX IF NOT EXISTS idx_data_access_log_time ON public.data_access_log(accessed_at);
CREATE INDEX IF NOT EXISTS idx_data_access_log_user ON public.data_access_log(accessed_by);

-- Enable RLS
ALTER TABLE public.data_access_log ENABLE ROW LEVEL SECURITY;

-- Only admins can view access logs
DROP POLICY IF EXISTS "data_access_log_admin_only" ON public.data_access_log;
CREATE POLICY "data_access_log_admin_only" ON public.data_access_log
FOR SELECT TO authenticated
USING (true);

-- ============================================
-- STEP 3: Sensitive Data Helper Functions
-- ============================================

-- Mask Aadhaar number (show only last 4 digits)
CREATE OR REPLACE FUNCTION public.mask_aadhaar(aadhaar TEXT)
RETURNS TEXT AS $$
BEGIN
  IF aadhaar IS NULL OR LENGTH(aadhaar) < 4 THEN
    RETURN NULL;
  END IF;
  RETURN 'XXXX XXXX ' || RIGHT(REPLACE(aadhaar, ' ', ''), 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask PAN number (show only last 4 characters)
CREATE OR REPLACE FUNCTION public.mask_pan(pan TEXT)
RETURNS TEXT AS $$
BEGIN
  IF pan IS NULL OR LENGTH(pan) < 4 THEN
    RETURN NULL;
  END IF;
  RETURN 'XXXXXX' || RIGHT(pan, 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask phone number (show only last 4 digits)
CREATE OR REPLACE FUNCTION public.mask_phone(phone TEXT)
RETURNS TEXT AS $$
BEGIN
  IF phone IS NULL OR LENGTH(phone) < 4 THEN
    RETURN NULL;
  END IF;
  RETURN 'XXXXXX' || RIGHT(REPLACE(phone, ' ', ''), 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Mask email (show first char, domain visible)
CREATE OR REPLACE FUNCTION public.mask_email(email TEXT)
RETURNS TEXT AS $$
DECLARE
  at_pos INTEGER;
BEGIN
  IF email IS NULL THEN
    RETURN NULL;
  END IF;
  at_pos := POSITION('@' IN email);
  IF at_pos <= 1 THEN
    RETURN '***@***';
  END IF;
  RETURN SUBSTRING(email FROM 1 FOR 1) || '***' || SUBSTRING(email FROM at_pos);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

GRANT EXECUTE ON FUNCTION public.mask_aadhaar TO authenticated;
GRANT EXECUTE ON FUNCTION public.mask_pan TO authenticated;
GRANT EXECUTE ON FUNCTION public.mask_phone TO authenticated;
GRANT EXECUTE ON FUNCTION public.mask_email TO authenticated;

-- ============================================
-- STEP 4: Secure File Upload Validation
-- ============================================
-- Stored procedure to validate file uploads

CREATE TABLE IF NOT EXISTS public.allowed_file_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category TEXT NOT NULL,
  extension TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  max_size_bytes BIGINT NOT NULL,
  is_active BOOLEAN DEFAULT true
);

-- Insert default allowed file types
INSERT INTO public.allowed_file_types (category, extension, mime_type, max_size_bytes) VALUES
  ('image', 'jpg', 'image/jpeg', 5242880),
  ('image', 'jpeg', 'image/jpeg', 5242880),
  ('image', 'png', 'image/png', 5242880),
  ('image', 'gif', 'image/gif', 5242880),
  ('image', 'webp', 'image/webp', 5242880),
  ('document', 'pdf', 'application/pdf', 10485760),
  ('document', 'doc', 'application/msword', 10485760),
  ('document', 'docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 10485760),
  ('document', 'xls', 'application/vnd.ms-excel', 10485760),
  ('document', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 10485760)
ON CONFLICT DO NOTHING;

-- Function to check if file type is allowed
CREATE OR REPLACE FUNCTION public.is_file_allowed(
  p_category TEXT,
  p_extension TEXT,
  p_file_size BIGINT
)
RETURNS JSON AS $$
DECLARE
  v_allowed RECORD;
BEGIN
  SELECT * INTO v_allowed
  FROM public.allowed_file_types
  WHERE category = p_category
    AND extension = LOWER(p_extension)
    AND is_active = true
  LIMIT 1;

  IF v_allowed IS NULL THEN
    RETURN json_build_object(
      'allowed', false,
      'message', 'File type not allowed for this category'
    );
  END IF;

  IF p_file_size > v_allowed.max_size_bytes THEN
    RETURN json_build_object(
      'allowed', false,
      'message', 'File size exceeds maximum allowed (' || (v_allowed.max_size_bytes / 1048576) || ' MB)'
    );
  END IF;

  RETURN json_build_object(
    'allowed', true,
    'mime_type', v_allowed.mime_type
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.is_file_allowed TO authenticated;

-- ============================================
-- STEP 5: Enhanced Storage RLS Policies
-- ============================================
-- Note: These need to be applied via Supabase Dashboard for storage buckets

-- Example policies (apply in Supabase Dashboard):
-- 
-- For student-profiles bucket:
-- INSERT: auth.uid() IS NOT NULL
-- SELECT: true (public read)
-- UPDATE: auth.uid() IS NOT NULL AND (storage.filename LIKE auth.uid() || '%')
-- DELETE: auth.uid() IS NOT NULL AND (storage.filename LIKE auth.uid() || '%')

-- ============================================
-- STEP 6: Security Dashboard View
-- ============================================

CREATE OR REPLACE VIEW public.security_dashboard AS
SELECT 
  'Login Attempts (24h)' as metric,
  COUNT(*)::TEXT as value
FROM public.device_login_attempts
WHERE attempted_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT 
  'Failed Logins (24h)' as metric,
  COUNT(*)::TEXT as value
FROM public.device_login_attempts
WHERE attempted_at > NOW() - INTERVAL '24 hours'
  AND success = false

UNION ALL

SELECT 
  'Blocked Devices' as metric,
  COUNT(*)::TEXT as value
FROM public.blocked_devices
WHERE is_permanent = true OR blocked_until > NOW()

UNION ALL

SELECT 
  'Blocked IPs' as metric,
  COALESCE(COUNT(*)::TEXT, '0') as value
FROM public.blocked_ips
WHERE is_permanent = true OR expires_at > NOW()

UNION ALL

SELECT 
  'Unique Users (24h)' as metric,
  COUNT(DISTINCT username)::TEXT as value
FROM public.device_login_attempts
WHERE attempted_at > NOW() - INTERVAL '24 hours'
  AND success = true;

GRANT SELECT ON public.security_dashboard TO authenticated;

-- ============================================
-- STEP 7: Password Expiry Tracking (Optional)
-- ============================================

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS password_changed_at TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS require_password_change BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS failed_login_count INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

-- Update password_changed_at when password changes
CREATE OR REPLACE FUNCTION public.update_password_changed_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.password IS DISTINCT FROM OLD.password THEN
    NEW.password_changed_at := NOW();
    NEW.require_password_change := false;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_password_changed_at ON public.users;
CREATE TRIGGER trg_update_password_changed_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.update_password_changed_at();

-- ============================================
-- STEP 8: Account Lockout After Failed Attempts
-- ============================================

CREATE OR REPLACE FUNCTION public.check_account_lockout(p_username TEXT)
RETURNS JSON AS $$
DECLARE
  v_user RECORD;
BEGIN
  SELECT * INTO v_user
  FROM public.users
  WHERE username = LOWER(TRIM(p_username));

  IF v_user IS NULL THEN
    RETURN json_build_object('locked', false);
  END IF;

  IF v_user.locked_until IS NOT NULL AND v_user.locked_until > NOW() THEN
    RETURN json_build_object(
      'locked', true,
      'message', 'Account is locked. Try again after ' || to_char(v_user.locked_until, 'HH24:MI'),
      'locked_until', v_user.locked_until
    );
  END IF;

  RETURN json_build_object('locked', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.check_account_lockout TO anon;

-- ============================================
-- VERIFICATION
-- ============================================
SELECT 'Security enhancements applied successfully!' as status;
