-- ============================================================
-- MIGRATION 17: Add Transport Officer User
-- ============================================================

-- 1. Drop existing role constraint and recreate it allowing transport_officer
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('student', 'teacher', 'admin', 'HR', 'hod', 'admissiondean', 'counsellor', 'temp_student', 'warden', 'transport_officer', 'superadmin'));

-- 2. Insert transportofficer1 into users table
INSERT INTO users (username, password, role)
VALUES (
  'transportofficer1',
  'transport@123',
  'transport_officer'
)
ON CONFLICT (username) DO UPDATE
  SET role       = EXCLUDED.role,
      password   = EXCLUDED.password;
