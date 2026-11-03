-- ============================================================
-- MIGRATION 27: Enterprise Finance Module — Full Architecture
-- Double-Entry Accounting | Ledgers | Fee Engine | Audit Trail
-- ============================================================

-- ============================================================
-- 1. FINANCIAL YEAR MANAGEMENT
-- ============================================================
CREATE TABLE IF NOT EXISTS financial_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,               -- e.g. '2025-26'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'closed', 'locked', 'archived')),
    is_current BOOLEAN DEFAULT false,
    opening_balance_carried BOOLEAN DEFAULT false,
    closed_at TIMESTAMP,
    closed_by TEXT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 2. CHART OF ACCOUNTS (CoA)
-- ============================================================
CREATE TABLE IF NOT EXISTS chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_code TEXT NOT NULL UNIQUE,     -- e.g. '1001', '2001'
    account_name TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK (account_type IN ('asset', 'liability', 'equity', 'revenue', 'expense')),
    parent_id UUID REFERENCES chart_of_accounts(id),
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    is_locked BOOLEAN DEFAULT false,
    normal_balance TEXT DEFAULT 'debit' CHECK (normal_balance IN ('debit', 'credit')),
    opening_balance NUMERIC(15, 2) DEFAULT 0,
    current_balance NUMERIC(15, 2) DEFAULT 0,
    financial_year_id UUID REFERENCES financial_years(id),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 3. GENERAL LEDGER
-- ============================================================
CREATE TABLE IF NOT EXISTS general_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES chart_of_accounts(id),
    journal_entry_id UUID,  -- linked after journal_entries is created
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    debit_amount NUMERIC(15, 2) DEFAULT 0,
    credit_amount NUMERIC(15, 2) DEFAULT 0,
    balance NUMERIC(15, 2) DEFAULT 0,
    narration TEXT,
    reference_type TEXT,    -- 'fee_payment', 'refund', 'scholarship', 'expense', 'manual'
    reference_id TEXT,      -- ID of the source document
    financial_year_id UUID REFERENCES financial_years(id),
    posted_by TEXT,
    is_auto_posted BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 4. JOURNAL ENTRIES
-- ============================================================
CREATE TABLE IF NOT EXISTS journal_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_number TEXT NOT NULL UNIQUE,   -- auto-generated: JE-2025-0001
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    entry_type TEXT DEFAULT 'standard' CHECK (entry_type IN ('standard', 'adjusting', 'closing', 'reversing', 'correction', 'recurring')),
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'pending_approval', 'approved', 'posted', 'rejected', 'reversed')),
    total_debit NUMERIC(15, 2) DEFAULT 0,
    total_credit NUMERIC(15, 2) DEFAULT 0,
    narration TEXT,
    reference_type TEXT,
    reference_id TEXT,
    attachments JSONB,
    financial_year_id UUID REFERENCES financial_years(id),
    created_by TEXT,
    approved_by TEXT,
    approved_at TIMESTAMP,
    posted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- Journal Entry Lines (individual debit/credit lines)
CREATE TABLE IF NOT EXISTS journal_entry_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id UUID NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES chart_of_accounts(id),
    debit_amount NUMERIC(15, 2) DEFAULT 0,
    credit_amount NUMERIC(15, 2) DEFAULT 0,
    narration TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- Now add FK to general_ledger
ALTER TABLE general_ledger
    DROP CONSTRAINT IF EXISTS general_ledger_journal_entry_id_fkey;
ALTER TABLE general_ledger
    ADD CONSTRAINT general_ledger_journal_entry_id_fkey
    FOREIGN KEY (journal_entry_id) REFERENCES journal_entries(id);

-- ============================================================
-- 5. FEE HEAD CONFIGURATION
-- ============================================================
CREATE TABLE IF NOT EXISTS fee_heads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,            -- e.g. 'TUI', 'ADM', 'LAB'
    name TEXT NOT NULL,                   -- 'Tuition Fee'
    category TEXT DEFAULT 'academic',     -- academic, hostel, transport, exam, misc
    description TEXT,
    is_refundable BOOLEAN DEFAULT false,
    is_taxable BOOLEAN DEFAULT false,
    tax_percentage NUMERIC(5, 2) DEFAULT 0,
    gst_hsn_code TEXT,
    is_optional BOOLEAN DEFAULT false,
    scholarship_applicable BOOLEAN DEFAULT true,
    late_fine_applicable BOOLEAN DEFAULT true,
    ledger_account_id UUID REFERENCES chart_of_accounts(id),
    is_active BOOLEAN DEFAULT true,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 6. FEE STRUCTURE TEMPLATES
-- ============================================================
CREATE TABLE IF NOT EXISTS fee_structures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,                   -- 'B.Tech CSE Sem-1 2025-26'
    description TEXT,
    department TEXT,
    course TEXT,
    semester TEXT,
    academic_year TEXT,
    category TEXT,                        -- General, SC/ST, OBC, EWS
    fee_type TEXT DEFAULT 'semester' CHECK (fee_type IN ('semester', 'annual', 'one_time', 'recurring', 'installment')),
    total_amount NUMERIC(15, 2) DEFAULT 0,
    installments_allowed BOOLEAN DEFAULT false,
    max_installments INT DEFAULT 1,
    is_template BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    financial_year_id UUID REFERENCES financial_years(id),
    created_by TEXT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- Fee structure line items (links fee heads to structures)
CREATE TABLE IF NOT EXISTS fee_structure_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_structure_id UUID NOT NULL REFERENCES fee_structures(id) ON DELETE CASCADE,
    fee_head_id UUID NOT NULL REFERENCES fee_heads(id),
    amount NUMERIC(15, 2) NOT NULL,
    due_date DATE,
    is_mandatory BOOLEAN DEFAULT true,
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 7. STUDENT FEE ALLOCATION (what each student owes)
-- ============================================================
CREATE TABLE IF NOT EXISTS student_fee_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    fee_structure_id UUID REFERENCES fee_structures(id),
    fee_head_id UUID NOT NULL REFERENCES fee_heads(id),
    original_amount NUMERIC(15, 2) NOT NULL,
    concession_amount NUMERIC(15, 2) DEFAULT 0,
    scholarship_amount NUMERIC(15, 2) DEFAULT 0,
    fine_amount NUMERIC(15, 2) DEFAULT 0,
    net_amount NUMERIC(15, 2) NOT NULL,   -- original - concession - scholarship + fine
    paid_amount NUMERIC(15, 2) DEFAULT 0,
    balance_amount NUMERIC(15, 2) NOT NULL, -- net_amount - paid_amount
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'paid', 'overdue', 'waived', 'cancelled')),
    due_date DATE,
    semester TEXT,
    academic_year TEXT,
    financial_year_id UUID REFERENCES financial_years(id),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 8. RECEIPTS
-- ============================================================
CREATE TABLE IF NOT EXISTS fee_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_number TEXT NOT NULL UNIQUE,    -- auto: REC-2025-0001
    student_id TEXT NOT NULL,
    receipt_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount NUMERIC(15, 2) NOT NULL,
    payment_mode TEXT DEFAULT 'cash' CHECK (payment_mode IN ('cash', 'cheque', 'upi', 'neft', 'rtgs', 'card', 'online', 'dd')),
    payment_reference TEXT,               -- UPI ref / cheque no / txn id
    bank_name TEXT,
    cheque_number TEXT,
    cheque_date DATE,
    status TEXT DEFAULT 'completed' CHECK (status IN ('completed', 'pending', 'bounced', 'cancelled', 'reversed')),
    remarks TEXT,
    journal_entry_id UUID REFERENCES journal_entries(id),
    financial_year_id UUID REFERENCES financial_years(id),
    collected_by TEXT,
    cancelled_by TEXT,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- Receipt line items (which fee allocations are covered)
CREATE TABLE IF NOT EXISTS fee_receipt_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id UUID NOT NULL REFERENCES fee_receipts(id) ON DELETE CASCADE,
    allocation_id UUID NOT NULL REFERENCES student_fee_allocations(id),
    fee_head_id UUID NOT NULL REFERENCES fee_heads(id),
    amount NUMERIC(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 9. SCHOLARSHIPS & CONCESSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS scholarships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    scholarship_type TEXT DEFAULT 'percentage' CHECK (scholarship_type IN ('percentage', 'fixed', 'full')),
    value NUMERIC(15, 2) NOT NULL,       -- percentage or fixed amount
    category TEXT,                       -- merit, government, category, employee_ward
    description TEXT,
    applicable_fee_heads JSONB,          -- list of fee head IDs this applies to
    max_recipients INT,
    current_recipients INT DEFAULT 0,
    financial_year_id UUID REFERENCES financial_years(id),
    is_active BOOLEAN DEFAULT true,
    created_by TEXT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS student_scholarships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    scholarship_id UUID NOT NULL REFERENCES scholarships(id),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'revoked')),
    approved_amount NUMERIC(15, 2) DEFAULT 0,
    applied_at TIMESTAMP DEFAULT now(),
    approved_by TEXT,
    approved_at TIMESTAMP,
    rejection_reason TEXT,
    remarks TEXT,
    academic_year TEXT,
    financial_year_id UUID REFERENCES financial_years(id),
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS concessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    fee_head_id UUID REFERENCES fee_heads(id),
    concession_type TEXT DEFAULT 'percentage' CHECK (concession_type IN ('percentage', 'fixed')),
    value NUMERIC(15, 2) NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    approved_by TEXT,
    approved_at TIMESTAMP,
    academic_year TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 10. FINES & PENALTIES
-- ============================================================
CREATE TABLE IF NOT EXISTS fine_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    fine_type TEXT DEFAULT 'fixed' CHECK (fine_type IN ('fixed', 'percentage', 'daily', 'slab')),
    amount NUMERIC(15, 2),
    percentage NUMERIC(5, 2),
    daily_rate NUMERIC(10, 2),
    slab_config JSONB,                   -- for slab-based fines
    max_fine NUMERIC(15, 2),
    applicable_to TEXT DEFAULT 'late_fee', -- late_fee, library, hostel, discipline
    grace_period_days INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS student_fines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    fine_rule_id UUID REFERENCES fine_rules(id),
    allocation_id UUID REFERENCES student_fee_allocations(id),
    fine_type TEXT NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'waived')),
    waived_by TEXT,
    waived_at TIMESTAMP,
    paid_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 11. REFUND MANAGEMENT
-- ============================================================
CREATE TABLE IF NOT EXISTS refund_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id TEXT NOT NULL,
    refund_type TEXT NOT NULL,            -- security_deposit, admission_cancel, hostel, overpayment
    amount NUMERIC(15, 2) NOT NULL,
    reason TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'processing', 'completed', 'rejected')),
    receipt_id UUID REFERENCES fee_receipts(id),
    bank_account_details JSONB,
    approved_by TEXT,
    approved_at TIMESTAMP,
    processed_at TIMESTAMP,
    rejection_reason TEXT,
    journal_entry_id UUID REFERENCES journal_entries(id),
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 12. VENDOR & EXPENSE MANAGEMENT
-- ============================================================
CREATE TABLE IF NOT EXISTS vendors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact_person TEXT,
    phone TEXT,
    email TEXT,
    address TEXT,
    gst_number TEXT,
    pan_number TEXT,
    bank_details JSONB,
    category TEXT,                        -- stationery, maintenance, IT, catering
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_number TEXT NOT NULL UNIQUE,
    vendor_id UUID REFERENCES vendors(id),
    department TEXT,
    category TEXT NOT NULL,
    description TEXT,
    amount NUMERIC(15, 2) NOT NULL,
    tax_amount NUMERIC(15, 2) DEFAULT 0,
    total_amount NUMERIC(15, 2) NOT NULL,
    payment_mode TEXT,
    payment_reference TEXT,
    invoice_number TEXT,
    invoice_date DATE,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'rejected')),
    approved_by TEXT,
    approved_at TIMESTAMP,
    paid_at TIMESTAMP,
    account_id UUID REFERENCES chart_of_accounts(id),
    journal_entry_id UUID REFERENCES journal_entries(id),
    financial_year_id UUID REFERENCES financial_years(id),
    created_by TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 13. BANK & CASH MANAGEMENT
-- ============================================================
CREATE TABLE IF NOT EXISTS bank_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_name TEXT NOT NULL,
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    ifsc_code TEXT,
    branch TEXT,
    account_type TEXT DEFAULT 'current',  -- current, savings
    opening_balance NUMERIC(15, 2) DEFAULT 0,
    current_balance NUMERIC(15, 2) DEFAULT 0,
    coa_account_id UUID REFERENCES chart_of_accounts(id),
    is_primary BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bank_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_account_id UUID NOT NULL REFERENCES bank_accounts(id),
    transaction_date DATE NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('deposit', 'withdrawal', 'transfer', 'cheque', 'charge')),
    amount NUMERIC(15, 2) NOT NULL,
    balance_after NUMERIC(15, 2),
    reference TEXT,
    description TEXT,
    is_reconciled BOOLEAN DEFAULT false,
    reconciled_with UUID,                -- matched ledger entry
    reconciled_at TIMESTAMP,
    reconciled_by TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 14. DEPARTMENT BUDGETS
-- ============================================================
CREATE TABLE IF NOT EXISTS department_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department TEXT NOT NULL,
    financial_year_id UUID REFERENCES financial_years(id),
    total_budget NUMERIC(15, 2) NOT NULL,
    allocated_amount NUMERIC(15, 2) DEFAULT 0,
    spent_amount NUMERIC(15, 2) DEFAULT 0,
    remaining_amount NUMERIC(15, 2),
    status TEXT DEFAULT 'active',
    approved_by TEXT,
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 15. APPROVAL WORKFLOWS
-- ============================================================
CREATE TABLE IF NOT EXISTS approval_workflows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_type TEXT NOT NULL,          -- refund, scholarship, expense, fee_waiver, concession
    reference_id UUID NOT NULL,
    reference_type TEXT NOT NULL,
    current_level INT DEFAULT 1,
    max_levels INT DEFAULT 2,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'approved', 'rejected', 'escalated')),
    initiated_by TEXT,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS approval_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workflow_id UUID NOT NULL REFERENCES approval_workflows(id) ON DELETE CASCADE,
    step_level INT NOT NULL,
    approver_role TEXT NOT NULL,
    approver_username TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'skipped')),
    comments TEXT,
    acted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 16. AUDIT LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS finance_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL,           -- fee_receipt, journal_entry, refund, etc.
    entity_id UUID,
    action TEXT NOT NULL,                -- create, update, delete, approve, reject
    old_values JSONB,
    new_values JSONB,
    performed_by TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    description TEXT,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 17. NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS finance_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id TEXT NOT NULL,
    recipient_type TEXT DEFAULT 'student', -- student, accountant, admin
    notification_type TEXT NOT NULL,       -- due_reminder, payment_success, refund_approved
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 18. SEED DEFAULT CHART OF ACCOUNTS
-- ============================================================
INSERT INTO financial_years (name, start_date, end_date, is_current, status)
VALUES ('2025-26', '2025-04-01', '2026-03-31', true, 'active')
ON CONFLICT DO NOTHING;

-- Assets
INSERT INTO chart_of_accounts (account_code, account_name, account_type, normal_balance, description) VALUES
('1000', 'Assets', 'asset', 'debit', 'All asset accounts'),
('1001', 'Cash in Hand', 'asset', 'debit', 'Physical cash'),
('1002', 'Bank Account - Primary', 'asset', 'debit', 'Primary bank account'),
('1003', 'Bank Account - Secondary', 'asset', 'debit', 'Secondary bank account'),
('1004', 'Accounts Receivable - Students', 'asset', 'debit', 'Student fee receivables'),
('1005', 'Security Deposits Held', 'asset', 'debit', 'Refundable security deposits'),
('1006', 'Prepaid Expenses', 'asset', 'debit', 'Expenses paid in advance')
ON CONFLICT (account_code) DO NOTHING;

-- Liabilities
INSERT INTO chart_of_accounts (account_code, account_name, account_type, normal_balance, description) VALUES
('2000', 'Liabilities', 'liability', 'credit', 'All liability accounts'),
('2001', 'Accounts Payable - Vendors', 'liability', 'credit', 'Outstanding vendor payments'),
('2002', 'Security Deposits Payable', 'liability', 'credit', 'Refundable deposits liability'),
('2003', 'GST Payable', 'liability', 'credit', 'GST collected'),
('2004', 'Advance Fee Received', 'liability', 'credit', 'Fees received in advance'),
('2005', 'Salary Payable', 'liability', 'credit', 'Outstanding salary payments')
ON CONFLICT (account_code) DO NOTHING;

-- Equity
INSERT INTO chart_of_accounts (account_code, account_name, account_type, normal_balance, description) VALUES
('3000', 'Equity', 'equity', 'credit', 'Owners equity'),
('3001', 'Retained Earnings', 'equity', 'credit', 'Accumulated surplus'),
('3002', 'Capital Fund', 'equity', 'credit', 'Institution capital')
ON CONFLICT (account_code) DO NOTHING;

-- Revenue
INSERT INTO chart_of_accounts (account_code, account_name, account_type, normal_balance, description) VALUES
('4000', 'Revenue', 'revenue', 'credit', 'All revenue accounts'),
('4001', 'Tuition Fee Revenue', 'revenue', 'credit', 'Tuition fee income'),
('4002', 'Admission Fee Revenue', 'revenue', 'credit', 'Admission fee income'),
('4003', 'Development Fee Revenue', 'revenue', 'credit', 'Development fee income'),
('4004', 'Lab Fee Revenue', 'revenue', 'credit', 'Lab fee income'),
('4005', 'Examination Fee Revenue', 'revenue', 'credit', 'Exam fee income'),
('4006', 'Hostel Fee Revenue', 'revenue', 'credit', 'Hostel fee income'),
('4007', 'Transport Fee Revenue', 'revenue', 'credit', 'Transport fee income'),
('4008', 'Library Fine Revenue', 'revenue', 'credit', 'Library fine income'),
('4009', 'Late Fee Fine Revenue', 'revenue', 'credit', 'Late fee penalty income'),
('4010', 'Miscellaneous Revenue', 'revenue', 'credit', 'Other income'),
('4011', 'ID Card Fee Revenue', 'revenue', 'credit', 'ID card fee income'),
('4012', 'Security Deposit Revenue', 'revenue', 'credit', 'Security deposit collections')
ON CONFLICT (account_code) DO NOTHING;

-- Expenses
INSERT INTO chart_of_accounts (account_code, account_name, account_type, normal_balance, description) VALUES
('5000', 'Expenses', 'expense', 'debit', 'All expense accounts'),
('5001', 'Salary Expense', 'expense', 'debit', 'Staff salaries'),
('5002', 'Scholarship Expense', 'expense', 'debit', 'Scholarships given'),
('5003', 'Utility Expense', 'expense', 'debit', 'Electricity, water, etc.'),
('5004', 'Maintenance Expense', 'expense', 'debit', 'Building and infrastructure'),
('5005', 'Stationery Expense', 'expense', 'debit', 'Office supplies'),
('5006', 'IT Infrastructure Expense', 'expense', 'debit', 'Technology costs'),
('5007', 'Transport Operating Expense', 'expense', 'debit', 'Bus operation costs'),
('5008', 'Hostel Operating Expense', 'expense', 'debit', 'Hostel operation costs'),
('5009', 'Refund Expense', 'expense', 'debit', 'Fee refunds'),
('5010', 'Event Expense', 'expense', 'debit', 'Cultural and sports events'),
('5011', 'Insurance Expense', 'expense', 'debit', 'Insurance premiums')
ON CONFLICT (account_code) DO NOTHING;

-- ============================================================
-- 19. SEED DEFAULT FEE HEADS
-- ============================================================
INSERT INTO fee_heads (code, name, category, is_refundable, scholarship_applicable, late_fine_applicable, display_order) VALUES
('TUI', 'Tuition Fee', 'academic', false, true, true, 1),
('ADM', 'Admission Fee', 'academic', false, false, true, 2),
('DEV', 'Development Fee', 'academic', false, true, true, 3),
('LAB', 'Lab Fee', 'academic', false, true, true, 4),
('EXM', 'Examination Fee', 'academic', false, false, true, 5),
('LIB', 'Library Fee', 'academic', false, true, false, 6),
('IDC', 'ID Card Fee', 'academic', false, false, false, 7),
('SEC', 'Security Deposit', 'academic', true, false, false, 8),
('HST', 'Hostel Fee', 'hostel', false, true, true, 9),
('MSS', 'Mess Charges', 'hostel', false, false, true, 10),
('TRN', 'Transport Fee', 'transport', false, true, true, 11),
('SPT', 'Sports Fee', 'academic', false, false, false, 12),
('MED', 'Medical Fee', 'academic', false, false, false, 13),
('MSC', 'Miscellaneous Fee', 'misc', false, false, false, 14)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 20. SEED DEFAULT FINE RULES
-- ============================================================
INSERT INTO fine_rules (name, fine_type, amount, applicable_to, grace_period_days) VALUES
('Standard Late Fee', 'fixed', 500, 'late_fee', 7),
('Daily Late Fine', 'daily', 50, 'late_fee', 15),
('Library Overdue Fine', 'daily', 10, 'library', 0),
('Hostel Damage Penalty', 'fixed', 2000, 'hostel', 0)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 21. CREATE INDEXES FOR PERFORMANCE
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_gl_account ON general_ledger(account_id);
CREATE INDEX IF NOT EXISTS idx_gl_date ON general_ledger(transaction_date);
CREATE INDEX IF NOT EXISTS idx_gl_fy ON general_ledger(financial_year_id);
CREATE INDEX IF NOT EXISTS idx_sfa_student ON student_fee_allocations(student_id);
CREATE INDEX IF NOT EXISTS idx_sfa_status ON student_fee_allocations(status);
CREATE INDEX IF NOT EXISTS idx_receipts_student ON fee_receipts(student_id);
CREATE INDEX IF NOT EXISTS idx_receipts_date ON fee_receipts(receipt_date);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON finance_audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON finance_audit_logs(performed_by);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON finance_notifications(recipient_id, is_read);
CREATE INDEX IF NOT EXISTS idx_je_status ON journal_entries(status);
CREATE INDEX IF NOT EXISTS idx_je_date ON journal_entries(entry_date);

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
