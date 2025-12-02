-- ============================================
-- TEACHER/STAFF SALARY TABLE
-- ============================================
-- Run this in Supabase SQL Editor

-- Create teacher_salary table
CREATE TABLE IF NOT EXISTS teacher_salary (
  -- Primary Key
  salary_id SERIAL PRIMARY KEY,
  
  -- Foreign Key to teacher_details
  employee_id TEXT NOT NULL REFERENCES teacher_details(employee_id) ON DELETE CASCADE,
  
  -- Salary Components (Monthly)
  basic_salary DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  hra DECIMAL(10, 2) DEFAULT 0.00, -- House Rent Allowance
  travel_allowance DECIMAL(10, 2) DEFAULT 0.00,
  medical_allowance DECIMAL(10, 2) DEFAULT 0.00,
  special_allowance DECIMAL(10, 2) DEFAULT 0.00,
  other_allowances DECIMAL(10, 2) DEFAULT 0.00,
  
  -- Deductions
  provident_fund DECIMAL(10, 2) DEFAULT 0.00,
  professional_tax DECIMAL(10, 2) DEFAULT 0.00,
  income_tax DECIMAL(10, 2) DEFAULT 0.00,
  other_deductions DECIMAL(10, 2) DEFAULT 0.00,
  
  -- Calculated Fields
  gross_salary DECIMAL(10, 2) GENERATED ALWAYS AS (
    basic_salary + hra + travel_allowance + medical_allowance + 
    special_allowance + other_allowances
  ) STORED,
  
  total_deductions DECIMAL(10, 2) GENERATED ALWAYS AS (
    provident_fund + professional_tax + income_tax + other_deductions
  ) STORED,
  
  net_salary DECIMAL(10, 2) GENERATED ALWAYS AS (
    basic_salary + hra + travel_allowance + medical_allowance + 
    special_allowance + other_allowances - 
    (provident_fund + professional_tax + income_tax + other_deductions)
  ) STORED,
  
  -- Bank Details
  bank_name TEXT,
  account_number TEXT,
  ifsc_code TEXT,
  branch_name TEXT,
  
  -- Payment Details
  payment_mode TEXT DEFAULT 'Bank Transfer' CHECK (payment_mode IN ('Bank Transfer', 'Cheque', 'Cash', 'UPI')),
  
  -- Effective Date
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  is_active BOOLEAN DEFAULT true,
  
  -- Metadata
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by TEXT,
  updated_by TEXT,
  
  -- Constraints
  CONSTRAINT unique_active_salary UNIQUE (employee_id, is_active),
  CONSTRAINT valid_date_range CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- Enable Row Level Security
ALTER TABLE teacher_salary ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow teachers to view their own salary
CREATE POLICY "Allow teachers to view own salary"
ON teacher_salary FOR SELECT
TO authenticated
USING (
  employee_id IN (
    SELECT employee_id FROM teacher_details 
    WHERE teacher_id = current_user
  )
);

-- RLS Policy: Allow HR and Admin to view all salaries
CREATE POLICY "Allow HR and Admin to view all salaries"
ON teacher_salary FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- RLS Policy: Allow HR and Admin to insert/update/delete salaries
CREATE POLICY "Allow HR and Admin to manage salaries"
ON teacher_salary FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users 
    WHERE username = current_user 
    AND role IN ('HR', 'admin')
  )
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_salary_employee_id ON teacher_salary(employee_id);
CREATE INDEX IF NOT EXISTS idx_salary_active ON teacher_salary(is_active);
CREATE INDEX IF NOT EXISTS idx_salary_effective_from ON teacher_salary(effective_from);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_salary_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER teacher_salary_updated_at
BEFORE UPDATE ON teacher_salary
FOR EACH ROW
EXECUTE FUNCTION update_salary_updated_at();

-- Create trigger to ensure only one active salary per employee
CREATE OR REPLACE FUNCTION ensure_single_active_salary()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- Deactivate all other active salaries for this employee
    UPDATE teacher_salary 
    SET is_active = false, effective_to = CURRENT_DATE
    WHERE employee_id = NEW.employee_id 
    AND is_active = true 
    AND salary_id != NEW.salary_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ensure_single_active_salary_trigger
BEFORE INSERT OR UPDATE ON teacher_salary
FOR EACH ROW
EXECUTE FUNCTION ensure_single_active_salary();

-- Insert sample salary data
INSERT INTO teacher_salary (
  employee_id, basic_salary, hra, travel_allowance, medical_allowance, 
  special_allowance, provident_fund, professional_tax, income_tax,
  bank_name, account_number, ifsc_code, branch_name, payment_mode,
  effective_from, is_active
) VALUES
(
  'EMP001', 60000.00, 20000.00, 5000.00, 3000.00, 
  2000.00, 3000.00, 200.00, 0.00,
  'State Bank of India', '1234567890123', 'SBIN0001234', 'Dehradun Main Branch', 'Bank Transfer',
  '2024-01-01', true
),
(
  'EMP002', 55000.00, 18000.00, 4000.00, 3000.00,
  2000.00, 2750.00, 200.00, 0.00,
  'HDFC Bank', '2345678901234', 'HDFC0001235', 'Dehradun Branch', 'Bank Transfer',
  '2024-01-01', true
),
(
  'EMP003', 45000.00, 15000.00, 3000.00, 2500.00,
  1500.00, 2250.00, 200.00, 0.00,
  'ICICI Bank', '3456789012345', 'ICIC0001236', 'Rajpur Road Branch', 'Bank Transfer',
  '2024-01-01', true
),
(
  'EMP004', 75000.00, 25000.00, 6000.00, 4000.00,
  3000.00, 3750.00, 200.00, 0.00,
  'Punjab National Bank', '4567890123456', 'PUNB0001237', 'Clock Tower Branch', 'Bank Transfer',
  '2024-01-01', true
),
(
  'EMP005', 50000.00, 16000.00, 4000.00, 3000.00,
  2000.00, 2500.00, 200.00, 0.00,
  'Axis Bank', '5678901234567', 'UTIB0001238', 'Paltan Bazaar Branch', 'Bank Transfer',
  '2024-01-01', true
);

-- Create view for easy salary summary
CREATE OR REPLACE VIEW teacher_salary_summary AS
SELECT 
  ts.employee_id,
  td.name,
  td.designation,
  td.department,
  ts.basic_salary,
  ts.hra,
  ts.travel_allowance,
  ts.medical_allowance,
  ts.special_allowance,
  ts.other_allowances,
  ts.gross_salary,
  ts.provident_fund,
  ts.professional_tax,
  ts.income_tax,
  ts.other_deductions,
  ts.total_deductions,
  ts.net_salary,
  ts.bank_name,
  ts.account_number,
  ts.ifsc_code,
  ts.payment_mode,
  ts.effective_from,
  ts.is_active
FROM teacher_salary ts
JOIN teacher_details td ON ts.employee_id = td.employee_id
WHERE ts.is_active = true;

COMMENT ON TABLE teacher_salary IS 'Stores salary and payroll information for teachers/staff';
COMMENT ON VIEW teacher_salary_summary IS 'Active salary details with teacher information';
