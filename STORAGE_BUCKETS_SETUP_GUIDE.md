# Quick Setup Guide - Storage Buckets

## ❌ Current Error
```
StorageException(message: Bucket not found, statusCode: 404, error: Bucket not found)
```

This means the storage buckets don't exist in your Supabase project yet.

## ✅ Solution: Create Storage Buckets Manually

### Step-by-Step Instructions

#### 1. Open Supabase Dashboard
- Go to https://supabase.com/dashboard
- Select your project

#### 2. Navigate to Storage
- Click on **Storage** in the left sidebar
- You'll see a list of existing buckets (if any)

#### 3. Create 'assignments' Bucket

1. Click the **"New bucket"** button (top right)
2. Fill in the details:
   - **Name**: `assignments`
   - **Public bucket**: ✅ **Check this box** (Important!)
   - **File size limit**: Leave default or set to 50MB
   - **Allowed MIME types**: Leave empty (allows all types)
3. Click **"Create bucket"**

#### 4. Set Policies for 'assignments' Bucket

After creating the bucket:

1. Click on the `assignments` bucket
2. Go to the **"Policies"** tab
3. Click **"New policy"**

**Policy 1: Upload Policy**
- Template: Select "Custom"
- Policy name: `Authenticated users can upload`
- Allowed operations: Check **INSERT**
- Target roles: Select **authenticated**
- Policy definition:
  ```sql
  (auth.role() = 'authenticated')
  ```
- Click **"Review"** then **"Save policy"**

**Policy 2: Read Policy**
- Click **"New policy"** again
- Template: Select "Custom"
- Policy name: `Public can read files`
- Allowed operations: Check **SELECT**
- Target roles: Select **public**
- Policy definition:
  ```sql
  true
  ```
- Click **"Review"** then **"Save policy"**

#### 5. Create 'study-materials' Bucket

Repeat Step 3 and Step 4 for the second bucket:

1. Click **"New bucket"**
2. Fill in:
   - **Name**: `study-materials`
   - **Public bucket**: ✅ **Check this box**
3. Click **"Create bucket"**
4. Set the same two policies as above

#### 6. Verify Buckets Are Created

In the Storage section, you should now see:
- ✅ `assignments`
- ✅ `study-materials`

Both should show as **Public** buckets.

### Alternative: Using SQL (Advanced)

If you prefer SQL, you can run this in the SQL Editor:

```sql
-- Note: This creates the buckets programmatically
-- You still need to set policies via the Dashboard

INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('assignments', 'assignments', true),
  ('study-materials', 'study-materials', true)
ON CONFLICT (id) DO NOTHING;
```

Then set the policies using the Dashboard UI as described above.

## Testing After Setup

### Test 1: Upload Assignment
1. In your app, go to Teacher Dashboard
2. Select a subject → Select a class
3. Click "Upload Assignment"
4. Fill in the form and attach a PDF
5. Click "Create Assignment"
6. ✅ Should show: "Assignment uploaded successfully!"

### Test 2: Upload Study Material
1. Go to Teacher Dashboard
2. Select a subject → Select a class
3. Click "Upload Study Material"
4. Fill in the form and attach a file
5. Click "Upload Material"
6. ✅ Should show: "Study material uploaded successfully!"

## Troubleshooting

### Issue: "Bucket not found" still appears
**Solution:**
- Make sure bucket names are EXACTLY: `assignments` and `study-materials` (lowercase, with hyphen)
- Refresh your app (hot reload)
- Check Supabase Dashboard to confirm buckets exist

### Issue: "Permission denied" error
**Solution:**
- Verify policies are set correctly
- Make sure buckets are marked as PUBLIC
- Check that authenticated users have INSERT permission

### Issue: Files upload but can't be accessed
**Solution:**
- Verify SELECT policy is set to `true` for public access
- Make sure bucket is marked as PUBLIC

## Summary

You need to create 2 storage buckets:

| Bucket Name | Public | Policies Needed |
|------------|--------|-----------------|
| `assignments` | ✅ Yes | Upload (authenticated), Read (public) |
| `study-materials` | ✅ Yes | Upload (authenticated), Read (public) |

After creating these buckets with the correct policies, all file uploads will work seamlessly! 🎉
