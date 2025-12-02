# Assignment Submissions Setup - Quick Guide

## ⚡ Step 1: Run This SQL (Database Tables)

Copy paste this in Supabase SQL Editor:

```sql
-- Create assignment_submissions table
CREATE TABLE IF NOT EXISTS assignment_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assignment_id UUID NOT NULL,
    student_id TEXT NOT NULL,
    file_url TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'submitted',
    grade NUMERIC,
    feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(assignment_id, student_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_submissions_assignment ON assignment_submissions(assignment_id);
CREATE INDEX IF NOT EXISTS idx_submissions_student ON assignment_submissions(student_id);
CREATE INDEX IF NOT EXISTS idx_submissions_status ON assignment_submissions(status);

-- Enable Row Level Security
ALTER TABLE assignment_submissions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Students can submit assignments"
ON assignment_submissions FOR INSERT
WITH CHECK (auth.uid()::text = student_id);

CREATE POLICY "Students can view their submissions"
ON assignment_submissions FOR SELECT
USING (auth.uid()::text = student_id);

CREATE POLICY "Teachers can view submissions"
ON assignment_submissions FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM assignments
        WHERE assignments.id = assignment_submissions.assignment_id
        AND assignments.teacher_id = auth.uid()::text
    )
);

CREATE POLICY "Teachers can grade submissions"
ON assignment_submissions FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM assignments
        WHERE assignments.id = assignment_submissions.assignment_id
        AND assignments.teacher_id = auth.uid()::text
    )
);

-- Add id column to assignments table if needed
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name='assignments' AND column_name='id') THEN
        ALTER TABLE assignments ADD COLUMN id UUID DEFAULT uuid_generate_v4();
    END IF;
END $$;
```

## 📦 Step 2: Create Storage Bucket (Supabase Dashboard)

1. **Go to Storage** in Supabase Dashboard
2. **Click "New bucket"**
3. Fill in:
   ```
   Name: assignment-submissions
   ☑️ Public bucket (CHECK THIS!)
   ```
4. **Click "Create bucket"**

## 🔐 Step 3: Set Bucket Policies (Supabase Dashboard)

After creating bucket:

1. Click on **assignment-submissions** bucket
2. Go to **Policies** tab
3. Click **"New Policy"**

**Policy 1 - Upload:**
```
Policy name: Allow authenticated uploads
Operation: INSERT
Policy definition: true
```
Click **Review** → **Save**

**Policy 2 - Read:**
```
Policy name: Allow public reads
Operation: SELECT  
Policy definition: true
```
Click **Review** → **Save**

## ✅ Verify Setup

In Storage, you should now have:
```
✅ Assignments (public)
✅ study-materials (public)  
✅ assignment-submissions (public) ← NEW
```

## 🎯 Features Now Available

### For Students:
1. **Download assignments** - Click download button
2. **Submit solutions** - Click submit button (before due date)
3. **Auto compression** - Files automatically compressed before upload
4. **Status tracking** - See if submitted or overdue
5. **Due date check** - Can't submit after deadline

### For Teachers:
1. **View submissions** - See who submitted
2. **Grade assignments** - Add marks and feedback
3. **Track status** - See submission statistics

## 🔧 Troubleshooting

### "Bucket not found" error?
- Make sure bucket name is EXACTLY: `assignment-submissions` (lowercase, with hyphen)
- Check it's marked as PUBLIC
- Hot reload the app (press 'r' in terminal)

### "Permission denied" error?
- Verify both policies are set
- Check RLS is enabled on assignment_submissions table
- Make sure user is authenticated

### Submit button not working?
- Check if assignment has 'id' field in database
- Verify due date is in future
- Check console for error messages

## 📝 Summary

Ab students:
- ✅ Assignments download kar sakte hain
- ✅ Solutions upload kar sakte hain (due date se pehle)
- ✅ Files automatically compress hoti hain
- ✅ Submission status dekh sakte hain
- ❌ Due date ke baad submit nahi kar sakte

Sab kuch real-time mein work karega! 🎉
