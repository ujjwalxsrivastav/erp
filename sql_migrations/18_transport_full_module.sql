-- ============================================================
-- MIGRATION 18: Full Transport Module - Routes, Buses, Student Requests
-- ============================================================

-- 1. Create transport_routes table
CREATE TABLE IF NOT EXISTS transport_routes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  route_name TEXT NOT NULL UNIQUE,
  route_description TEXT,
  pickup_points TEXT[], -- Array of stop names
  estimated_time TEXT, -- e.g. '45 mins'
  distance_km NUMERIC(5,1),
  fare NUMERIC(8,2) DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create transport_buses table
CREATE TABLE IF NOT EXISTS transport_buses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bus_number INT NOT NULL UNIQUE,
  vehicle_no TEXT, -- e.g. 'HP-01-1234'
  route_id UUID REFERENCES transport_routes(id) ON DELETE SET NULL,
  capacity INT DEFAULT 40,
  current_occupancy INT DEFAULT 0,
  driver_name TEXT,
  driver_phone TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create student_transport_requests table
CREATE TABLE IF NOT EXISTS student_transport_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id TEXT NOT NULL,
  student_name TEXT NOT NULL,
  route_id UUID REFERENCES transport_routes(id) ON DELETE CASCADE,
  bus_id UUID REFERENCES transport_buses(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  processed_by TEXT, -- transport officer username
  remarks TEXT,
  is_active BOOLEAN DEFAULT TRUE
);

-- 4. Insert 3 routes
INSERT INTO transport_routes (route_name, route_description, pickup_points, estimated_time, distance_km, fare) VALUES
(
  'Paonta Sahib',
  'Via NH7 - Paonta Sahib to Shivalik College',
  ARRAY['Paonta Sahib Bus Stand', 'Yamuna Bridge', 'Industrial Area', 'Shivalik College'],
  '45 mins',
  28.5,
  1500.00
),
(
  'Clock Tower',
  'City Route - Clock Tower to Shivalik College',
  ARRAY['Clock Tower', 'Mall Road', 'University Gate', 'Shivalik College'],
  '25 mins',
  12.0,
  800.00
),
(
  'ISBT',
  'ISBT Dehradun to Shivalik College',
  ARRAY['ISBT Dehradun', 'Rajpur Road', 'Ballupur Chowk', 'Shivalik College'],
  '35 mins',
  18.0,
  1000.00
)
ON CONFLICT (route_name) DO NOTHING;

-- 5. Insert 6 buses (2 per route)
-- Paonta Sahib: Bus 1, Bus 2
INSERT INTO transport_buses (bus_number, vehicle_no, route_id, capacity, driver_name, driver_phone) VALUES
(1, 'HP-01-A-1001', (SELECT id FROM transport_routes WHERE route_name = 'Paonta Sahib'), 40, 'Ramesh Kumar', '9876543210'),
(2, 'HP-01-A-1002', (SELECT id FROM transport_routes WHERE route_name = 'Paonta Sahib'), 40, 'Suresh Sharma', '9876543211')
ON CONFLICT (bus_number) DO NOTHING;

-- Clock Tower: Bus 3, Bus 4
INSERT INTO transport_buses (bus_number, vehicle_no, route_id, capacity, driver_name, driver_phone) VALUES
(3, 'HP-01-B-2001', (SELECT id FROM transport_routes WHERE route_name = 'Clock Tower'), 35, 'Vikram Singh', '9876543212'),
(4, 'HP-01-B-2002', (SELECT id FROM transport_routes WHERE route_name = 'Clock Tower'), 35, 'Deepak Thakur', '9876543213')
ON CONFLICT (bus_number) DO NOTHING;

-- ISBT: Bus 5, Bus 6
INSERT INTO transport_buses (bus_number, vehicle_no, route_id, capacity, driver_name, driver_phone) VALUES
(5, 'HP-01-C-3001', (SELECT id FROM transport_routes WHERE route_name = 'ISBT'), 45, 'Ajay Verma', '9876543214'),
(6, 'HP-01-C-3002', (SELECT id FROM transport_routes WHERE route_name = 'ISBT'), 45, 'Manoj Rawat', '9876543215')
ON CONFLICT (bus_number) DO NOTHING;

-- 6. RLS Policies
ALTER TABLE transport_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_buses ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_transport_requests ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read routes and buses
CREATE POLICY "Anyone can read transport routes" ON transport_routes FOR SELECT USING (true);
CREATE POLICY "Anyone can read transport buses" ON transport_buses FOR SELECT USING (true);
CREATE POLICY "Anyone can read transport requests" ON student_transport_requests FOR SELECT USING (true);

-- Allow inserts and updates
CREATE POLICY "Anyone can insert transport requests" ON student_transport_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can update transport requests" ON student_transport_requests FOR UPDATE USING (true);
CREATE POLICY "Anyone can update transport buses" ON transport_buses FOR UPDATE USING (true);
