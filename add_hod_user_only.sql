-- Step 1: First update the role constraint to include 'hod'
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE users ADD CONSTRAINT users_role_check 
CHECK (role IN ('student', 'teacher', 'admin', 'staff', 'HR', 'hod'));

-- Step 2: Now insert ONLY the HOD user (if not already exists)
INSERT INTO "public"."users" ("username", "password", "role") 
VALUES ('hod1', 'hod1', 'hod')
ON CONFLICT (username) DO NOTHING;

-- Step 3: Verify the HOD user was created
SELECT username, role FROM users WHERE role = 'hod';
