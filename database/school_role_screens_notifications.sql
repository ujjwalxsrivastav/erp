-- Apply in Supabase SQL Editor before deploying notification references.
-- This is additive; do not rerun or edit already-applied setup scripts.
ALTER TABLE public.school_notifications
  ADD COLUMN IF NOT EXISTS ref_type TEXT,
  ADD COLUMN IF NOT EXISTS ref_id TEXT;

CREATE INDEX IF NOT EXISTS idx_school_notifications_unread
  ON public.school_notifications (user_id, is_read, created_at DESC);

-- Existing project convention grants the app roles table access. Keep RLS
-- enabled only when per-user policies are deployed with authenticated claims.
GRANT SELECT, INSERT, UPDATE ON public.school_notifications
  TO anon, authenticated, service_role;
