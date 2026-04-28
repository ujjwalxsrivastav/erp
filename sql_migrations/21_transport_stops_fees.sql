-- ============================================================
-- MIGRATION 21: Transport Stops & Automatic Fee/Bus Allocation
-- ============================================================

-- Add stop name and fee tracking to transport requests
ALTER TABLE student_transport_requests ADD COLUMN IF NOT EXISTS stop_name TEXT;
ALTER TABLE student_transport_requests ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(10,2) DEFAULT 0;
ALTER TABLE student_transport_requests ADD COLUMN IF NOT EXISTS fee_status TEXT DEFAULT 'not_paid' CHECK (fee_status IN ('not_paid', 'paid'));

-- Create bus_fee_enrollment if it doesn't exist (it is used in fee module)
CREATE TABLE IF NOT EXISTS bus_fee_enrollment (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id TEXT UNIQUE NOT NULL,
  bus_fee NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for bus_fee_enrollment
ALTER TABLE bus_fee_enrollment ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read bus_fee_enrollment" ON bus_fee_enrollment FOR SELECT USING (true);
CREATE POLICY "Anyone can modify bus_fee_enrollment" ON bus_fee_enrollment FOR ALL USING (true);
