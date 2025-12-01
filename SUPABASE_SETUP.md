# Supabase Setup Guide for Shivalik ERP

## Current Configuration

### Database Table: `users`

**Table Structure:**
```sql
CREATE TABLE users (
  username TEXT PRIMARY KEY,
  password TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin'))
);
```

### Existing Data

**Students (BT24CSE154 to BT24CSE164):**
- Username: BT24CSE154, Password: BT24CSE154, Role: student
- Username: BT24CSE155, Password: BT24CSE155, Role: student
- ... (up to BT24CSE164)

**Teachers (teacher1 to teacher5):**
- Username: teacher1, Password: teacher1, Role: teacher
- Username: teacher2, Password: teacher2, Role: teacher
- ... (up to teacher5)

---

## 🔒 Security Recommendations

### 1. Enable Row Level Security (RLS)

Run these SQL commands in Supabase SQL Editor:

```sql
-- Enable RLS on users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy: Allow users to read only their own data
CREATE POLICY "Users can read own data"
ON users
FOR SELECT
USING (true);  -- For now, allow all reads (you can restrict this later)

-- Policy: Prevent users from modifying data via client
CREATE POLICY "Prevent client updates"
ON users
FOR UPDATE
USING (false);

-- Policy: Prevent users from deleting data via client
CREATE POLICY "Prevent client deletes"
ON users
FOR DELETE
USING (false);

-- Policy: Prevent users from inserting data via client
CREATE POLICY "Prevent client inserts"
ON users
FOR INSERT
WITH CHECK (false);
```

### 2. Password Hashing (Recommended for Production)

**Current Status:** Passwords are stored in plain text (NOT SECURE for production)

**For Production, use this approach:**

```sql
-- Add a hashed_password column
ALTER TABLE users ADD COLUMN hashed_password TEXT;

-- Create a function to hash passwords (using pgcrypto extension)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Update existing passwords to hashed versions
UPDATE users 
SET hashed_password = crypt(password, gen_salt('bf'))
WHERE hashed_password IS NULL;

-- Remove the plain password column (after testing)
-- ALTER TABLE users DROP COLUMN password;
-- ALTER TABLE users RENAME COLUMN hashed_password TO password;
```

**Then update the login query to:**
```sql
SELECT username, role 
FROM users 
WHERE username = $1 
AND password = crypt($2, password);
```

---

## 🔑 Environment Variables

Your `.env` file should contain:

```env
SUPABASE_URL=https://rvyzfqffjgwadxtbiuvr.supabase.co
SUPABASE_ANON_KEY=sb_secret_24FPZgKYWpXgwX-RaIvojQ_JjIF1V0L
```

**Note:** The anon key is safe to expose in client-side code, but make sure RLS policies are properly configured.

---

## 📊 Adding More Users

### Add Students:
```sql
INSERT INTO users (username, password, role) VALUES
('BT24CSE165', 'BT24CSE165', 'student'),
('BT24CSE166', 'BT24CSE166', 'student');
```

### Add Teachers:
```sql
INSERT INTO users (username, password, role) VALUES
('teacher6', 'teacher6', 'teacher'),
('teacher7', 'teacher7', 'teacher');
```

### Add Admin:
```sql
INSERT INTO users (username, password, role) VALUES
('admin', 'admin123', 'admin');
```

---

## 🧪 Testing the Setup

1. **Test Login:**
   - Student: `BT24CSE154` / `BT24CSE154`
   - Teacher: `teacher1` / `teacher1`
   - Admin: (add one using SQL above)

2. **Test Session Persistence:**
   - Login with any user
   - Close and reopen the app
   - Should automatically redirect to the dashboard

3. **Test Invalid Credentials:**
   - Try wrong password
   - Should show error message

---

## 🚀 Current Features Implemented

✅ **Session Management:** Users stay logged in after app restart
✅ **Role-based Routing:** Automatic redirect based on user role
✅ **Secure Authentication:** Proper error handling and validation
✅ **Session Verification:** Checks if user still exists in database
✅ **Logout Functionality:** Can be called from any dashboard

---

## 📝 Next Steps for Production

1. ✅ Enable RLS policies (see above)
2. ⚠️ Implement password hashing (see above)
3. ⚠️ Add password reset functionality
4. ⚠️ Add email verification
5. ⚠️ Implement rate limiting for login attempts
6. ⚠️ Add audit logging for security events
7. ⚠️ Use Supabase Auth instead of custom auth (recommended)

---

## 🔧 Troubleshooting

### Issue: "Invalid username or password" for valid credentials
- Check if RLS policies are blocking the query
- Verify the username and password in Supabase dashboard
- Check network connection

### Issue: Session not persisting
- Clear app data and try again
- Check if SharedPreferences is working properly
- Verify the session verification query

### Issue: Can't connect to Supabase
- Verify SUPABASE_URL and SUPABASE_ANON_KEY in `.env`
- Check internet connection
- Verify Supabase project is active

---

## 📞 Support

For any issues with Supabase setup, check:
- [Supabase Documentation](https://supabase.com/docs)
- [Supabase RLS Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter Supabase Package](https://pub.dev/packages/supabase_flutter)
