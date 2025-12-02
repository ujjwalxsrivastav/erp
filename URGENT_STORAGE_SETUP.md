# 🚀 URGENT: Storage Buckets Setup (5 Minutes)

## ⚠️ Current Problem
Your app is showing this error:
```
Bucket not found (404)
```

## ✅ Quick Fix (Follow These Exact Steps)

### Step 1: Go to Supabase Dashboard
1. Open browser: https://supabase.com/dashboard
2. Login to your account
3. Click on your ERP project

### Step 2: Create First Bucket - 'assignments'

1. **Click "Storage"** in left sidebar (icon looks like a folder)
2. **Click "New bucket"** button (green button, top right)
3. Fill in the form:
   ```
   Name: assignments
   ☑️ Public bucket (CHECK THIS BOX!)
   ```
4. **Click "Create bucket"**

### Step 3: Set Policies for 'assignments'

1. Click on the **assignments** bucket you just created
2. Click **"Policies"** tab at the top
3. Click **"New Policy"** button
4. Click **"For full customization"** (bottom option)

**First Policy - Upload:**
```
Policy name: Allow authenticated uploads
SELECT operation: INSERT
Policy definition: true
```
Click **"Review"** → **"Save policy"**

**Second Policy - Read:**
Click **"New Policy"** again
```
Policy name: Allow public reads  
SELECT operation: SELECT
Policy definition: true
```
Click **"Review"** → **"Save policy"**

### Step 4: Create Second Bucket - 'study-materials'

1. Go back to Storage (click "Storage" in sidebar)
2. **Click "New bucket"** again
3. Fill in:
   ```
   Name: study-materials
   ☑️ Public bucket (CHECK THIS BOX!)
   ```
4. **Click "Create bucket"**

### Step 5: Set Policies for 'study-materials'

Repeat Step 3 for this bucket:
- Same two policies (upload and read)
- Same settings

### Step 6: Verify Setup

In Storage section, you should see:
```
✅ assignments (public)
✅ study-materials (public)
```

### Step 7: Test in App

1. **Hot reload your app** (press 'r' in terminal)
2. Go to Teacher → Subject → Class → Upload Assignment
3. Try uploading a PDF
4. Should work now! ✅

## 📝 Hindi Instructions (हिंदी में)

### स्टेप 1: Supabase Dashboard खोलो
1. Browser में जाओ: https://supabase.com/dashboard
2. Login करो
3. अपना ERP project select करो

### स्टेप 2: पहला Bucket बनाओ
1. Left sidebar में **"Storage"** पे क्लिक करो
2. **"New bucket"** button (green) पे क्लिक करो
3. Form भरो:
   - Name: `assignments`
   - **Public bucket का checkbox ✅ CHECK करो** (बहुत जरूरी!)
4. **"Create bucket"** पे क्लिक करो

### स्टेप 3: Policies Set करो
1. अभी बनाए हुए **assignments** bucket पे क्लिक करो
2. ऊपर **"Policies"** tab पे जाओ
3. **"New Policy"** button दबाओ
4. **"For full customization"** चुनो

**पहली Policy:**
- Policy name: `Allow authenticated uploads`
- Operation में **INSERT** select करो
- Policy definition में लिखो: `true`
- **"Review"** फिर **"Save policy"** दबाओ

**दूसरी Policy:**
- फिर से **"New Policy"** दबाओ
- Policy name: `Allow public reads`
- Operation में **SELECT** select करो
- Policy definition में लिखो: `true`
- **"Review"** फिर **"Save policy"** दबाओ

### स्टेप 4: दूसरा Bucket बनाओ
1. वापस Storage पे जाओ
2. फिर से **"New bucket"** दबाओ
3. Name: `study-materials`
4. **Public bucket checkbox ✅ CHECK करो**
5. **"Create bucket"** दबाओ

### स्टेप 5: इसके लिए भी Policies Set करो
- Step 3 जैसा ही करो
- दोनों policies (upload और read) बनाओ

### स्टेप 6: Check करो
Storage में दिखना चाहिए:
```
✅ assignments (public)
✅ study-materials (public)
```

### स्टेप 7: App में Test करो
1. App को hot reload करो (terminal में 'r' press करो)
2. Teacher → Subject → Class → Upload Assignment
3. PDF upload करके देखो
4. Ab kaam karega! ✅

## ⚡ Quick Checklist

- [ ] Opened Supabase Dashboard
- [ ] Created `assignments` bucket (public ✅)
- [ ] Set 2 policies for `assignments` (INSERT + SELECT)
- [ ] Created `study-materials` bucket (public ✅)
- [ ] Set 2 policies for `study-materials` (INSERT + SELECT)
- [ ] Hot reloaded the app
- [ ] Tested file upload

## 🆘 Still Not Working?

### Check These:
1. **Bucket names are EXACTLY:**
   - `assignments` (not "assignment" or "Assignments")
   - `study-materials` (with hyphen, not underscore)

2. **Both buckets are PUBLIC:**
   - Look for "public" label next to bucket name

3. **Policies are set:**
   - Each bucket should have 2 policies
   - One for INSERT, one for SELECT

4. **Hot reload the app:**
   - Press 'r' in the terminal where Flutter is running

## 📸 What It Should Look Like

In Supabase Storage section:
```
Storage
  📁 assignments (public)
     Policies: 2
  📁 study-materials (public)
     Policies: 2
```

## ⏱️ Time Required
- Creating buckets: 2 minutes
- Setting policies: 3 minutes
- **Total: 5 minutes**

After this, all file uploads (assignments, study materials) will work perfectly! 🎉
