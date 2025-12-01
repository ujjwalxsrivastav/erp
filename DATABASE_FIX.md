# 🔧 DATABASE SETUP FIX

## ❌ Error Encountered

```
ERROR: 23514: new row for relation "user_accounts" violates check constraint "user_type_check"
DETAIL: Failing row contains (17, admin, admin123, 3, null, null, null, t, 2025-11-21 11:34:13.793536+00).
```

---

## 🎯 Root Cause

The `user_accounts` table has a check constraint that requires **either** `student_id` OR `staff_id` to be NOT NULL:

```sql
CONSTRAINT user_type_check CHECK (
    (student_id IS NOT NULL AND staff_id IS NULL) OR
    (student_id IS NULL AND staff_id IS NOT NULL)
)
```

The admin account was trying to insert with **both** `student_id` and `staff_id` as NULL, which violated this constraint.

---

## ✅ Solution Applied

### Before (Error):
```sql
-- Only 5 staff members (teachers)
INSERT INTO staff (...) VALUES
    ('Dr. Rajesh Kumar', ...),  -- staff_id = 1
    ('Prof. Priya Sharma', ...), -- staff_id = 2
    ('Dr. Amit Singh', ...),     -- staff_id = 3
    ('Prof. Neha Gupta', ...),   -- staff_id = 4
    ('Dr. Vikram Patel', ...);   -- staff_id = 5

-- Admin trying to use NULL staff_id ❌
INSERT INTO user_accounts (username, password_hash, role_id, staff_id) VALUES
    ('admin', 'admin123', 3, NULL);  -- ERROR!
```

### After (Fixed):
```sql
-- Added 6th staff member for admin
INSERT INTO staff (...) VALUES
    ('Dr. Rajesh Kumar', ...),      -- staff_id = 1
    ('Prof. Priya Sharma', ...),    -- staff_id = 2
    ('Dr. Amit Singh', ...),        -- staff_id = 3
    ('Prof. Neha Gupta', ...),      -- staff_id = 4
    ('Dr. Vikram Patel', ...),      -- staff_id = 5
    ('Admin User', 'admin@shivalik.edu', '9876543215', 3, NULL, 'System Administrator', 5); -- staff_id = 6 ✅

-- Admin now linked to staff_id = 6 ✅
INSERT INTO user_accounts (username, password_hash, role_id, staff_id) VALUES
    ('admin', 'admin123', 3, 6);  -- SUCCESS!
```

---

## 📝 Changes Made

### File: `supabase_complete_setup.sql`

**Line 404-405**: Added admin staff record
```sql
('Admin User', 'admin@shivalik.edu', '9876543215', 3, NULL, 'System Administrator', 5)
```

**Line 443**: Updated admin user account to reference staff_id = 6
```sql
('admin', 'admin123', 3, 6)  -- Changed from NULL to 6
```

---

## 🎉 Result

Now the database setup will work correctly!

### User Accounts Created:
- **11 Students**: BT24CSE154 to BT24CSE164 (linked to student_id)
- **5 Teachers**: teacher1 to teacher5 (linked to staff_id 1-5)
- **1 Admin**: admin (linked to staff_id 6) ✅

---

## 🚀 Next Steps

1. **Run the Fixed SQL Script**
   - Go to Supabase SQL Editor
   - Copy the entire `supabase_complete_setup.sql` content
   - Run it
   - Should complete successfully! ✅

2. **Verify Setup**
   ```sql
   SELECT 'Students' as table_name, COUNT(*) as count FROM students
   UNION ALL
   SELECT 'Staff', COUNT(*) FROM staff
   UNION ALL
   SELECT 'User Accounts', COUNT(*) FROM user_accounts;
   ```

   **Expected Results:**
   - Students: 11
   - Staff: 6 (5 teachers + 1 admin)
   - User Accounts: 17 (11 students + 5 teachers + 1 admin)

3. **Test Login**
   ```
   Admin: admin / admin123 ✅
   Teacher: teacher1 / teacher1 ✅
   Student: BT24CSE154 / BT24CSE154 ✅
   ```

---

## 💡 Why This Happened

The check constraint ensures that every user account is linked to **either** a student **or** a staff member (not both, not neither). This maintains data integrity and makes it easy to identify user types.

For admin users, we need to create a staff record first (with role_id = 3 for admin), then link the user account to that staff record.

---

## ✅ Status

**FIXED!** ✅

The SQL script is now corrected and ready to run without errors!

---

**Fixed by**: Antigravity AI  
**Date**: November 21, 2025  
**File Updated**: `supabase_complete_setup.sql`
