-- Step 1: Drop the existing role check constraint
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;

-- Step 2: Add new constraint that includes 'HR' role
ALTER TABLE users ADD CONSTRAINT users_role_check 
CHECK (role IN ('student', 'teacher', 'admin', 'staff', 'HR'));

-- Step 3: Insert HR user
INSERT INTO "public"."users" ("username", "password", "role") 
VALUES ('hr1', 'hr1', 'HR')
ON CONFLICT (username) DO NOTHING;
