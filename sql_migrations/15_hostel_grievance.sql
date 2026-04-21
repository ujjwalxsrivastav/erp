-- ============================================================================
-- PHASE 4: HOSTEL GRIEVANCE PORTAL
-- ============================================================================

CREATE TABLE IF NOT EXISTS hostel_grievances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id VARCHAR(20) REFERENCES student_details(student_id),
    student_name VARCHAR(100) NOT NULL,
    room_number VARCHAR(20),
    hostel_name VARCHAR(100),
    category VARCHAR(50) NOT NULL, -- maintenance, cleanliness, food, security, internet, roommate, other
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    is_anonymous BOOLEAN DEFAULT false,
    priority VARCHAR(20) DEFAULT 'medium', -- low, medium, high, urgent
    status VARCHAR(30) DEFAULT 'pending', -- pending, acknowledged, in_progress, resolved, dismissed
    warden_response TEXT,
    responded_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for fast student-wise and status-wise queries
CREATE INDEX IF NOT EXISTS idx_grievances_student ON hostel_grievances(student_id);
CREATE INDEX IF NOT EXISTS idx_grievances_status ON hostel_grievances(status);
CREATE INDEX IF NOT EXISTS idx_grievances_created ON hostel_grievances(created_at DESC);
