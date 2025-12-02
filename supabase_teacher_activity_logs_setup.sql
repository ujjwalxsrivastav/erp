-- ============================================
-- TEACHER/STAFF ACTIVITY LOGS TABLE
-- ============================================
-- Run this in Supabase SQL Editor

-- Create teacher_activity_logs table
CREATE TABLE IF NOT EXISTS teacher_activity_logs (
  -- Primary Key
  log_id SERIAL PRIMARY KEY,
  
  -- Foreign Key to teacher_details
  employee_id TEXT NOT NULL REFERENCES teacher_details(employee_id) ON DELETE CASCADE,
  
  -- Activity Details
  activity_type TEXT NOT NULL CHECK (activity_type IN (
    'Profile Created',
    'Profile Updated',
    'Salary Revised',
    'Document Uploaded',
    'Document Deleted',
    'Status Changed',
    'Department Transfer',
    'Designation Changed',
    'Leave Applied',
    'Leave Approved',
    'Leave Rejected',
    'Attendance Marked',
    'Performance Review',
    'Training Completed',
    'Other'
  )),
  
  activity_title TEXT NOT NULL,
  activity_description TEXT,
  
  -- Change Details (JSON for flexibility)
  old_value JSONB,
  new_value JSONB,
  
  -- Metadata
  performed_by TEXT, -- Username of person who performed the action
  performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address TEXT,
  user_agent TEXT
);

-- Enable Row Level Security
ALTER TABLE teacher_activity_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow teachers to view their own activity logs
CREATE POLICY "Allow teachers to view own activity logs"
ON teacher_activity_logs FOR SELECT
TO authenticated
USING (
  employee_id IN (
    SELECT employee_id FROM teacher_details 
    WHERE teacher_id = current_user
  )
);

-- RLS Policy: Allow HR and Admin to view all activity logs
CREATE POLICY "Allow HR and Admin to view all activity logs"
ON teacher_activity_logs FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- RLS Policy: Allow HR and Admin to insert activity logs
CREATE POLICY "Allow HR and Admin to insert activity logs"
ON teacher_activity_logs FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_activity_employee_id ON teacher_activity_logs(employee_id);
CREATE INDEX IF NOT EXISTS idx_activity_type ON teacher_activity_logs(activity_type);
CREATE INDEX IF NOT EXISTS idx_activity_performed_at ON teacher_activity_logs(performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_performed_by ON teacher_activity_logs(performed_by);

-- Create function to automatically log profile updates
CREATE OR REPLACE FUNCTION log_teacher_profile_update()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO teacher_activity_logs (
    employee_id,
    activity_type,
    activity_title,
    activity_description,
    old_value,
    new_value,
    performed_by
  ) VALUES (
    NEW.employee_id,
    'Profile Updated',
    'Profile Information Changed',
    'Employee profile was updated',
    to_jsonb(OLD),
    to_jsonb(NEW),
    NEW.updated_by
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_teacher_profile_update_trigger
AFTER UPDATE ON teacher_details
FOR EACH ROW
WHEN (OLD.* IS DISTINCT FROM NEW.*)
EXECUTE FUNCTION log_teacher_profile_update();

-- Create function to automatically log salary changes
CREATE OR REPLACE FUNCTION log_teacher_salary_change()
RETURNS TRIGGER AS $$
DECLARE
  emp_id TEXT;
BEGIN
  emp_id := COALESCE(NEW.employee_id, OLD.employee_id);
  
  IF TG_OP = 'INSERT' THEN
    INSERT INTO teacher_activity_logs (
      employee_id,
      activity_type,
      activity_title,
      activity_description,
      new_value,
      performed_by
    ) VALUES (
      emp_id,
      'Salary Revised',
      'Salary Structure Created',
      'New salary structure was created',
      to_jsonb(NEW),
      NEW.created_by
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO teacher_activity_logs (
      employee_id,
      activity_type,
      activity_title,
      activity_description,
      old_value,
      new_value,
      performed_by
    ) VALUES (
      emp_id,
      'Salary Revised',
      'Salary Structure Updated',
      format('Salary revised from ₹%s to ₹%s', OLD.net_salary, NEW.net_salary),
      to_jsonb(OLD),
      to_jsonb(NEW),
      NEW.updated_by
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_teacher_salary_change_trigger
AFTER INSERT OR UPDATE ON teacher_salary
FOR EACH ROW
EXECUTE FUNCTION log_teacher_salary_change();

-- Insert sample activity logs
INSERT INTO teacher_activity_logs (
  employee_id, activity_type, activity_title, activity_description, performed_by, performed_at
) VALUES
('EMP001', 'Profile Updated', 'Contact Information Changed', 'Phone number and email updated', 'hr1', NOW() - INTERVAL '2 hours'),
('EMP001', 'Salary Revised', 'Annual Increment Applied', 'Salary increased by 10%', 'hr1', NOW() - INTERVAL '1 week'),
('EMP002', 'Document Uploaded', 'PAN Card Uploaded', 'PAN Card document uploaded successfully', 'EMP002', NOW() - INTERVAL '2 weeks'),
('EMP003', 'Status Changed', 'Status Updated to On Leave', 'Employee status changed from Active to On Leave', 'hr1', NOW() - INTERVAL '1 month'),
('EMP004', 'Department Transfer', 'Promoted to HOD', 'Moved to Computer Science as HOD', 'admin1', NOW() - INTERVAL '3 months'),
('EMP005', 'Profile Created', 'New Employee Onboarded', 'Employee profile created in the system', 'hr1', NOW() - INTERVAL '6 months'),
('EMP002', 'Training Completed', 'Completed AI Workshop', 'Successfully completed 3-day AI workshop', 'EMP002', NOW() - INTERVAL '1 month'),
('EMP001', 'Performance Review', 'Annual Performance Review', 'Excellent performance rating received', 'EMP004', NOW() - INTERVAL '2 months');

-- Create view for recent activity
CREATE OR REPLACE VIEW teacher_recent_activity AS
SELECT 
  tal.log_id,
  tal.employee_id,
  td.name as employee_name,
  tal.activity_type,
  tal.activity_title,
  tal.activity_description,
  tal.performed_by,
  tal.performed_at,
  CASE 
    WHEN tal.performed_at > NOW() - INTERVAL '1 hour' THEN 'Just now'
    WHEN tal.performed_at > NOW() - INTERVAL '1 day' THEN 
      EXTRACT(HOUR FROM (NOW() - tal.performed_at))::TEXT || ' hours ago'
    WHEN tal.performed_at > NOW() - INTERVAL '1 week' THEN 
      EXTRACT(DAY FROM (NOW() - tal.performed_at))::TEXT || ' days ago'
    WHEN tal.performed_at > NOW() - INTERVAL '1 month' THEN 
      EXTRACT(WEEK FROM (NOW() - tal.performed_at))::TEXT || ' weeks ago'
    ELSE 
      EXTRACT(MONTH FROM (NOW() - tal.performed_at))::TEXT || ' months ago'
  END as time_ago
FROM teacher_activity_logs tal
JOIN teacher_details td ON tal.employee_id = td.employee_id
ORDER BY tal.performed_at DESC;

COMMENT ON TABLE teacher_activity_logs IS 'Tracks all activities and changes related to teacher/staff records';
COMMENT ON VIEW teacher_recent_activity IS 'Recent activity logs with human-readable timestamps';
