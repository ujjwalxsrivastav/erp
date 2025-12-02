-- ============================================
-- LEAVE MANAGEMENT & HOLIDAY CALENDAR TABLES
-- ============================================
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. TEACHER LEAVES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS teacher_leaves (
  leave_id SERIAL PRIMARY KEY,
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id) ON DELETE CASCADE,
  employee_id TEXT NOT NULL REFERENCES teacher_details(employee_id) ON DELETE CASCADE,
  
  -- Leave Details
  leave_type TEXT NOT NULL DEFAULT 'Sick Leave' CHECK (leave_type IN ('Sick Leave', 'Casual Leave', 'Emergency Leave')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  total_days INTEGER NOT NULL,
  reason TEXT NOT NULL,
  document_url TEXT,
  
  -- Status
  status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
  approved_by TEXT,
  approved_at TIMESTAMP WITH TIME ZONE,
  rejection_reason TEXT,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 2. TEACHER LEAVE BALANCE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS teacher_leave_balance (
  balance_id SERIAL PRIMARY KEY,
  teacher_id TEXT NOT NULL REFERENCES teacher_details(teacher_id) ON DELETE CASCADE,
  employee_id TEXT NOT NULL REFERENCES teacher_details(employee_id) ON DELETE CASCADE,
  
  -- Monthly Balance
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  year INTEGER NOT NULL,
  sick_leaves_total INTEGER DEFAULT 2,
  sick_leaves_used INTEGER DEFAULT 0,
  sick_leaves_remaining INTEGER GENERATED ALWAYS AS (sick_leaves_total - sick_leaves_used) STORED,
  
  -- Constraints
  UNIQUE(teacher_id, month, year),
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- 3. HOLIDAYS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS holidays (
  holiday_id SERIAL PRIMARY KEY,
  
  -- Holiday Details
  holiday_name TEXT NOT NULL,
  holiday_date DATE NOT NULL UNIQUE,
  description TEXT,
  holiday_type TEXT DEFAULT 'National' CHECK (holiday_type IN ('National', 'Religious', 'College', 'Custom')),
  
  -- Day Type
  is_holiday BOOLEAN DEFAULT true,
  is_working_day BOOLEAN DEFAULT false,
  
  -- Metadata
  created_by TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_leaves_teacher ON teacher_leaves(teacher_id);
CREATE INDEX IF NOT EXISTS idx_leaves_status ON teacher_leaves(status);
CREATE INDEX IF NOT EXISTS idx_leaves_date ON teacher_leaves(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_balance_teacher ON teacher_leave_balance(teacher_id);
CREATE INDEX IF NOT EXISTS idx_balance_month ON teacher_leave_balance(month, year);
CREATE INDEX IF NOT EXISTS idx_holidays_date ON holidays(holiday_date);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE teacher_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_leave_balance ENABLE ROW LEVEL SECURITY;
ALTER TABLE holidays ENABLE ROW LEVEL SECURITY;

-- Teachers can view their own leaves
CREATE POLICY "Teachers can view own leaves"
ON teacher_leaves FOR SELECT
TO authenticated
USING (teacher_id = current_user);

-- Teachers can insert their own leaves
CREATE POLICY "Teachers can apply for leave"
ON teacher_leaves FOR INSERT
TO authenticated
WITH CHECK (teacher_id = current_user);

-- HR and Admin can view all leaves
CREATE POLICY "HR and Admin can view all leaves"
ON teacher_leaves FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- HR and Admin can update leave status
CREATE POLICY "HR and Admin can update leaves"
ON teacher_leaves FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- Teachers can view their own balance
CREATE POLICY "Teachers can view own balance"
ON teacher_leave_balance FOR SELECT
TO authenticated
USING (teacher_id = current_user);

-- HR and Admin can view all balances
CREATE POLICY "HR and Admin can view all balances"
ON teacher_leave_balance FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- Everyone can view holidays
CREATE POLICY "Everyone can view holidays"
ON holidays FOR SELECT
TO authenticated
USING (true);

-- Only HR and Admin can manage holidays
CREATE POLICY "HR and Admin can manage holidays"
ON holidays FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- ============================================
-- TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_leave_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER teacher_leaves_updated_at
BEFORE UPDATE ON teacher_leaves
FOR EACH ROW
EXECUTE FUNCTION update_leave_updated_at();

CREATE TRIGGER teacher_leave_balance_updated_at
BEFORE UPDATE ON teacher_leave_balance
FOR EACH ROW
EXECUTE FUNCTION update_leave_updated_at();

CREATE TRIGGER holidays_updated_at
BEFORE UPDATE ON holidays
FOR EACH ROW
EXECUTE FUNCTION update_leave_updated_at();

-- ============================================
-- INSERT DEFAULT HOLIDAYS FOR 2025
-- ============================================
INSERT INTO holidays (holiday_name, holiday_date, description, holiday_type) VALUES
('New Year', '2025-01-01', 'New Year Day', 'National'),
('Republic Day', '2025-01-26', 'Republic Day of India', 'National'),
('Holi', '2025-03-14', 'Festival of Colors', 'Religious'),
('Eid ul-Fitr', '2025-03-31', 'End of Ramadan', 'Religious'),
('Good Friday', '2025-04-18', 'Good Friday', 'Religious'),
('Independence Day', '2025-08-15', 'Independence Day of India', 'National'),
('Janmashtami', '2025-08-16', 'Birth of Lord Krishna', 'Religious'),
('Gandhi Jayanti', '2025-10-02', 'Birth of Mahatma Gandhi', 'National'),
('Dussehra', '2025-10-02', 'Victory of Good over Evil', 'Religious'),
('Diwali', '2025-10-20', 'Festival of Lights', 'Religious'),
('Guru Nanak Jayanti', '2025-11-05', 'Birth of Guru Nanak', 'Religious'),
('Christmas', '2025-12-25', 'Birth of Jesus Christ', 'Religious')
ON CONFLICT (holiday_date) DO NOTHING;

-- ============================================
-- FUNCTION TO AUTO-CREATE MONTHLY BALANCE
-- ============================================
CREATE OR REPLACE FUNCTION ensure_monthly_leave_balance(
  p_teacher_id TEXT,
  p_employee_id TEXT,
  p_month INTEGER,
  p_year INTEGER
)
RETURNS void AS $$
BEGIN
  INSERT INTO teacher_leave_balance (teacher_id, employee_id, month, year)
  VALUES (p_teacher_id, p_employee_id, p_month, p_year)
  ON CONFLICT (teacher_id, month, year) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION TO UPDATE LEAVE BALANCE AFTER APPROVAL
-- ============================================
CREATE OR REPLACE FUNCTION update_leave_balance_on_approval()
RETURNS TRIGGER AS $$
DECLARE
  leave_month INTEGER;
  leave_year INTEGER;
BEGIN
  -- Only update if status changed to Approved
  IF NEW.status = 'Approved' AND (OLD.status IS NULL OR OLD.status != 'Approved') THEN
    leave_month := EXTRACT(MONTH FROM NEW.start_date);
    leave_year := EXTRACT(YEAR FROM NEW.start_date);
    
    -- Ensure balance record exists
    PERFORM ensure_monthly_leave_balance(NEW.teacher_id, NEW.employee_id, leave_month, leave_year);
    
    -- Update used leaves
    UPDATE teacher_leave_balance
    SET sick_leaves_used = sick_leaves_used + NEW.total_days
    WHERE teacher_id = NEW.teacher_id
      AND month = leave_month
      AND year = leave_year;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_balance_on_leave_approval
AFTER INSERT OR UPDATE ON teacher_leaves
FOR EACH ROW
EXECUTE FUNCTION update_leave_balance_on_approval();

COMMENT ON TABLE teacher_leaves IS 'Stores teacher leave applications';
COMMENT ON TABLE teacher_leave_balance IS 'Tracks monthly leave balance for teachers';
COMMENT ON TABLE holidays IS 'Stores college holidays and working day overrides';
