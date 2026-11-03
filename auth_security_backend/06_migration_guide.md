# 🔐 Auth Security Migration Guide

## 📋 Overview
Secure users table with device-based rate limiting (5 attempts/hour, 1-hour block).

---

## 🚀 Run SQL Scripts in Order

In Supabase SQL Editor, run these scripts **in order**:

1. `01_users_table_rls.sql` - RLS policies for users table
2. `02_device_rate_limiting.sql` - Device-based rate limiting
3. `03_secure_login_function.sql` - Secure login with rate limiting
4. `04_secure_add_user.sql` - Secure add user for HR/Admin
5. `05_additional_security.sql` - Extra security measures

---

## ✅ Verify Installation

```sql
SELECT proname FROM pg_proc WHERE proname IN (
  'secure_login_v2', 'check_device_rate_limit', 'secure_add_user_v2'
);
```

---

## 📱 Flutter Code Changes

### AuthService - Use secure_login_v2:
```dart
final response = await _supabase.rpc('secure_login_v2', params: {
  'p_username': username,
  'p_password': password,
  'p_device_fingerprint': deviceFingerprint,
});
```

### AdminService/HRService - Use secure_add_user_v2:
```dart
await _supabase.rpc('secure_add_user_v2', params: {
  'p_username': teacherId,
  'p_password': password,
  'p_role': 'teacher',
  'p_created_by': 'admin',
});
```

---

## 🛡️ Security Features

- **5 attempts/hour** per device
- **1-hour block** after 5 failures
- **Auto password hashing** (bcrypt)
- **Audit logging** for all changes

---

## 🧪 Test Rate Limiting

```sql
-- Check if blocked
SELECT * FROM public.check_device_rate_limit('test_device');
```

---

## 🔄 Rollback

```sql
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
```
