-- ============================================
-- FEES MANAGEMENT SYSTEM - COMPLETE DATABASE
-- ============================================

-- 1. Main Student Fees Table (All 11 students)
CREATE TABLE student_fees (
    student_id VARCHAR(20) PRIMARY KEY,
    base_fee DECIMAL(10, 2) NOT NULL DEFAULT 134000.00,
    total_fee DECIMAL(10, 2) NOT NULL,
    paid_amount DECIMAL(10, 2) DEFAULT 0.00,
    pending_amount DECIMAL(10, 2) NOT NULL,
    academic_year VARCHAR(10) NOT NULL DEFAULT '2024-25',
    last_payment_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Bus Fee Enrollment Table
CREATE TABLE bus_fee_enrollment (
    student_id VARCHAR(20) PRIMARY KEY,
    bus_fee DECIMAL(10, 2) NOT NULL DEFAULT 20000.00,
    enrolled_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Hostel Fee Enrollment Table
CREATE TABLE hostel_fee_enrollment (
    student_id VARCHAR(20) PRIMARY KEY,
    hostel_fee DECIMAL(10, 2) NOT NULL DEFAULT 100000.00,
    enrolled_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Payment Transactions Table
CREATE TABLE fee_transactions (
    transaction_id SERIAL PRIMARY KEY,
    student_id VARCHAR(20) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'razorpay',
    razorpay_order_id VARCHAR(100),
    razorpay_payment_id VARCHAR(100),
    razorpay_signature VARCHAR(200),
    payment_status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'success', 'failed'
    academic_year VARCHAR(10) NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INSERT DATA FOR ALL 11 STUDENTS
-- ============================================

-- Insert all 11 students with base fee
INSERT INTO student_fees (student_id, base_fee, total_fee, pending_amount, academic_year) VALUES
('BT24CSE154', 134000.00, 134000.00, 134000.00, '2024-25'),
('BT24CSE155', 134000.00, 134000.00, 134000.00, '2024-25'),
('BT24CSE156', 134000.00, 134000.00, 134000.00, '2024-25'),
('BT24CSE157', 134000.00, 134000.00, 134000.00, '2024-25'),
('BT24CSE158', 134000.00, 234000.00, 234000.00, '2024-25'), -- Has hostel
('BT24CSE159', 134000.00, 234000.00, 234000.00, '2024-25'), -- Has hostel
('BT24CSE160', 134000.00, 234000.00, 234000.00, '2024-25'), -- Has hostel
('BT24CSE161', 134000.00, 154000.00, 154000.00, '2024-25'), -- Has bus
('BT24CSE162', 134000.00, 154000.00, 154000.00, '2024-25'), -- Has bus
('BT24CSE163', 134000.00, 134000.00, 134000.00, '2024-25'),
('BT24CSE164', 134000.00, 134000.00, 134000.00, '2024-25');

-- Insert bus enrollment (2 students)
INSERT INTO bus_fee_enrollment (student_id, bus_fee) VALUES
('BT24CSE161', 20000.00),
('BT24CSE162', 20000.00);

-- Insert hostel enrollment (3 students)
INSERT INTO hostel_fee_enrollment (student_id, hostel_fee) VALUES
('BT24CSE158', 100000.00),
('BT24CSE159', 100000.00),
('BT24CSE160', 100000.00);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX idx_student_fees_year ON student_fees(academic_year);
CREATE INDEX idx_transactions_student ON fee_transactions(student_id, academic_year);
CREATE INDEX idx_transactions_status ON fee_transactions(payment_status);

-- ============================================
-- FUNCTION TO UPDATE FEES AFTER PAYMENT
-- ============================================
CREATE OR REPLACE FUNCTION update_student_fees_after_payment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update if payment is successful
    IF NEW.payment_status = 'success' THEN
        UPDATE student_fees
        SET 
            paid_amount = paid_amount + NEW.amount,
            pending_amount = total_fee - (paid_amount + NEW.amount),
            last_payment_date = NEW.payment_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE student_id = NEW.student_id 
        AND academic_year = NEW.academic_year;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER trigger_update_fees_after_payment
AFTER INSERT OR UPDATE ON fee_transactions
FOR EACH ROW
EXECUTE FUNCTION update_student_fees_after_payment();

-- ============================================
-- USEFUL QUERIES
-- ============================================

-- Get student's complete fee details
-- SELECT 
--     sf.*,
--     bf.bus_fee,
--     hf.hostel_fee
-- FROM student_fees sf
-- LEFT JOIN bus_fee_enrollment bf ON sf.student_id = bf.student_id
-- LEFT JOIN hostel_fee_enrollment hf ON sf.student_id = hf.student_id
-- WHERE sf.student_id = 'BT24CSE161';

-- Get payment history for a student
-- SELECT * FROM fee_transactions 
-- WHERE student_id = 'BT24CSE161' 
-- ORDER BY payment_date DESC;
