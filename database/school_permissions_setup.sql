-- ============================================================================
-- SCHOOL PERMISSIONS, MARKS LOCKS & MAKER-CHECKER (SP10)
-- ============================================================================

-- 1. ROLE PERMISSIONS MATRIX
CREATE TABLE IF NOT EXISTS school_role_permissions (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    role TEXT NOT NULL,
    feature TEXT NOT NULL,
    permission TEXT NOT NULL CHECK (permission IN ('view', 'edit', 'approve', 'none')),
    updated_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(institute_id, role, feature)
);

-- 2. MARKS DEADLINE & LOCK REGISTER
CREATE TABLE IF NOT EXISTS school_marks_locks (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    exam_id TEXT NOT NULL,
    class_id TEXT NOT NULL,
    subject TEXT NOT NULL DEFAULT 'All',
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    locked_at TIMESTAMPTZ,
    locked_by TEXT,
    unlocked_at TIMESTAMPTZ,
    unlocked_by TEXT,
    unlock_reason TEXT,
    deadline TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(institute_id, exam_id, class_id, subject)
);

-- Backward compatible for databases created before updated_at was tracked.
ALTER TABLE school_marks_locks
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. MAKER-CHECKER SENSITIVE ACTION REQUESTS
CREATE TABLE IF NOT EXISTS school_maker_checker_requests (
    id TEXT PRIMARY KEY,
    institute_id TEXT NOT NULL DEFAULT 'SHIV-SCH',
    request_type TEXT NOT NULL CHECK (request_type IN ('payroll_lock', 'fee_structure', 'marks_bulk_upload', 'discipline_suspension')),
    entity_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    maker_username TEXT NOT NULL,
    maker_role TEXT NOT NULL,
    checker_username TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    action_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT
);

-- RLS POLICIES
ALTER TABLE school_role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_marks_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_maker_checker_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Multi-school isolation permissions" ON school_role_permissions
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);

CREATE POLICY "Multi-school isolation marks locks" ON school_marks_locks
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);

CREATE POLICY "Multi-school isolation maker checker" ON school_maker_checker_requests
    FOR ALL USING (institute_id = CURRENT_SETTING('app.current_institute_id', true) OR CURRENT_SETTING('app.current_institute_id', true) IS NULL);
