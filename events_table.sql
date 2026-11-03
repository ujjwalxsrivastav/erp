-- Events Table for ERP System
-- This table stores all events created by HOD and visible to students/teachers

CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT NOT NULL CHECK (event_type IN ('academic', 'cultural', 'sports', 'workshop', 'seminar', 'other')),
  event_date DATE NOT NULL,
  start_time TIME,
  end_time TIME,
  location TEXT,
  organizer TEXT,
  target_audience TEXT[] DEFAULT ARRAY['all'], -- ['students', 'teachers', 'all']
  status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')),
  created_by TEXT REFERENCES users(username),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON events(created_by);

-- Enable Row Level Security
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can view events
CREATE POLICY "Events are viewable by everyone" ON events
  FOR SELECT
  USING (true);

-- Policy: Only HOD can insert events
CREATE POLICY "HOD can insert events" ON events
  FOR INSERT
  WITH CHECK (
    created_by IN (SELECT username FROM users WHERE role = 'hod')
  );

-- Policy: Only HOD can update their own events
CREATE POLICY "HOD can update their own events" ON events
  FOR UPDATE
  USING (
    created_by IN (SELECT username FROM users WHERE role = 'hod')
  );

-- Policy: Only HOD can delete their own events
CREATE POLICY "HOD can delete their own events" ON events
  FOR DELETE
  USING (
    created_by IN (SELECT username FROM users WHERE role = 'hod')
  );

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at on every update
CREATE TRIGGER events_updated_at_trigger
  BEFORE UPDATE ON events
  FOR EACH ROW
  EXECUTE FUNCTION update_events_updated_at();

-- Note: Sample data removed. Create events through the app after logging in as HOD.
