-- ============================================
-- ADD DEDUCTION COLUMNS TO TEACHER_LEAVES
-- ============================================

ALTER TABLE teacher_leaves 
ADD COLUMN IF NOT EXISTS deduction_amount DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN IF NOT EXISTS is_salary_deducted BOOLEAN DEFAULT false;

-- Create a view to calculate monthly payroll with deductions
CREATE OR REPLACE VIEW teacher_monthly_payroll AS
SELECT 
  ts.employee_id,
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
  ts.net_salary as base_net_salary,
  
  -- Calculate total leave deductions for the current month
  COALESCE((
    SELECT SUM(deduction_amount)
    FROM teacher_leaves tl
    WHERE tl.employee_id = ts.employee_id
    AND tl.status = 'Approved'
    AND tl.is_salary_deducted = true
    AND EXTRACT(MONTH FROM tl.start_date) = EXTRACT(MONTH FROM CURRENT_DATE)
    AND EXTRACT(YEAR FROM tl.start_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  ), 0) as current_month_leave_deductions,
  
  -- Final Net Salary after leave deductions
  (ts.net_salary - COALESCE((
    SELECT SUM(deduction_amount)
    FROM teacher_leaves tl
    WHERE tl.employee_id = ts.employee_id
    AND tl.status = 'Approved'
    AND tl.is_salary_deducted = true
    AND EXTRACT(MONTH FROM tl.start_date) = EXTRACT(MONTH FROM CURRENT_DATE)
    AND EXTRACT(YEAR FROM tl.start_date) = EXTRACT(YEAR FROM CURRENT_DATE)
  ), 0)) as final_net_salary

FROM teacher_salary ts
WHERE ts.is_active = true;
