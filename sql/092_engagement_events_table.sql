-- Ensure engagement lifecycle events table exists for payments service.
-- This table is written by services/payments/src/services/engagementLifecycle.js.

CREATE TABLE IF NOT EXISTS public.engagement_events (
  event_id SERIAL PRIMARY KEY,
  engagement_id BIGINT NOT NULL,
  from_status VARCHAR(50),
  to_status VARCHAR(50) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  actor_type VARCHAR(50) NOT NULL,
  actor_id INTEGER,
  metadata JSONB,
  created_at TIMESTAMP(6) NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_engagement_events_engagement
    FOREIGN KEY (engagement_id)
    REFERENCES public.engagements (engagement_id)
    ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_engagement_events_engagement_id
  ON public.engagement_events (engagement_id);

CREATE INDEX IF NOT EXISTS idx_engagement_events_created_at
  ON public.engagement_events (created_at);
