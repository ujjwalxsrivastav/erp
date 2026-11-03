-- ============================================================
-- MIGRATION 20: Conductor Advanced Features (Trip & Alerts)
-- ============================================================

-- 1. Add Status tracking to transport_buses
ALTER TABLE transport_buses ADD COLUMN IF NOT EXISTS trip_status TEXT DEFAULT 'At Depot' CHECK (trip_status IN ('At Depot', 'In Transit', 'Maintenance'));
ALTER TABLE transport_buses ADD COLUMN IF NOT EXISTS last_trip_start TIMESTAMPTZ;
ALTER TABLE transport_buses ADD COLUMN IF NOT EXISTS last_trip_end TIMESTAMPTZ;

-- 2. Create transport_alerts table for SOS/Breakdown/Delay
CREATE TABLE IF NOT EXISTS transport_alerts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  bus_id UUID REFERENCES transport_buses(id) ON DELETE CASCADE,
  reported_by TEXT NOT NULL, -- conductor username
  alert_type TEXT NOT NULL CHECK (alert_type IN ('Delay', 'Breakdown', 'Accident', 'Other')),
  description TEXT,
  status TEXT DEFAULT 'Active' CHECK (status IN ('Active', 'Resolved')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by TEXT -- transport officer username
);

-- 3. RLS Policies for transport_alerts
ALTER TABLE transport_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read transport alerts" ON transport_alerts FOR SELECT USING (true);
CREATE POLICY "Conductors can insert transport alerts" ON transport_alerts FOR INSERT WITH CHECK (true);
CREATE POLICY "Officers can update transport alerts" ON transport_alerts FOR UPDATE USING (true);
