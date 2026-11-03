-- ============================================================
-- MIGRATION 24: Bus Maintenance & Fuel Tracking
-- ============================================================

-- Create storage bucket for maintenance receipts
INSERT INTO storage.buckets (id, name, public)
VALUES ('bus-maintenance', 'bus-maintenance', true)
ON CONFLICT (id) DO NOTHING;

-- Policy to allow public viewing
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'bus-maintenance' );

-- Policy to allow uploads
CREATE POLICY "Authenticated users can upload receipts" 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'bus-maintenance' AND auth.role() = 'authenticated' );

-- Table: bus_services
CREATE TABLE IF NOT EXISTS bus_services (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bus_id UUID REFERENCES transport_buses(id) ON DELETE CASCADE,
  service_date DATE NOT NULL,
  service_type TEXT NOT NULL,
  description TEXT,
  cost NUMERIC(10, 2),
  receipt_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Table: bus_fuel_history
CREATE TABLE IF NOT EXISTS bus_fuel_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bus_id UUID REFERENCES transport_buses(id) ON DELETE CASCADE,
  fill_date DATE NOT NULL,
  fuel_liters NUMERIC(10, 2) NOT NULL,
  cost NUMERIC(10, 2) NOT NULL,
  odometer_reading NUMERIC(12, 2) NOT NULL, -- current km
  previous_odometer NUMERIC(12, 2), -- previous km (if any)
  mileage_calculated NUMERIC(10, 2), -- computed km/l
  receipt_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
