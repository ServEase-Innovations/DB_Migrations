-- Initial support ticketing tables (also tracked in sql/schema.sql for reference)

CREATE TABLE IF NOT EXISTS public.support_tickets (
  ticket_id BIGSERIAL PRIMARY KEY,
  ticket_number VARCHAR(24) NOT NULL UNIQUE,
  customerid BIGINT NOT NULL,
  engagement_id BIGINT,
  serviceproviderid BIGINT,
  category VARCHAR(50) NOT NULL DEFAULT 'GENERAL',
  subject VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
  priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
  assigned_admin_email VARCHAR(255),
  sla_hours INT NOT NULL DEFAULT 48,
  sla_due_at TIMESTAMP WITHOUT TIME ZONE NOT NULL,
  resolved_at TIMESTAMP WITHOUT TIME ZONE,
  resolved_by VARCHAR(255),
  resolution_notes TEXT,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT support_tickets_status_check CHECK (
    status IN ('OPEN', 'IN_PROGRESS', 'WAITING_CUSTOMER', 'RESOLVED', 'CLOSED', 'CANCELLED')
  ),
  CONSTRAINT support_tickets_priority_check CHECK (
    priority IN ('LOW', 'MEDIUM', 'HIGH')
  )
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_customer ON public.support_tickets (customerid);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets (status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_priority ON public.support_tickets (priority);
CREATE INDEX IF NOT EXISTS idx_support_tickets_sla_due ON public.support_tickets (sla_due_at);
CREATE INDEX IF NOT EXISTS idx_support_tickets_engagement ON public.support_tickets (engagement_id);

CREATE TABLE IF NOT EXISTS public.support_ticket_comments (
  comment_id BIGSERIAL PRIMARY KEY,
  ticket_id BIGINT NOT NULL REFERENCES public.support_tickets (ticket_id) ON DELETE CASCADE,
  author_type VARCHAR(20) NOT NULL,
  author_id BIGINT,
  author_name VARCHAR(255),
  body TEXT NOT NULL,
  is_internal BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW(),
  CONSTRAINT support_ticket_comments_author_check CHECK (
    author_type IN ('CUSTOMER', 'ADMIN', 'SYSTEM')
  )
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_comments_ticket ON public.support_ticket_comments (ticket_id);

CREATE TABLE IF NOT EXISTS public.support_ticket_events (
  event_id BIGSERIAL PRIMARY KEY,
  ticket_id BIGINT NOT NULL REFERENCES public.support_tickets (ticket_id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  payload JSONB,
  created_by VARCHAR(255),
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_support_ticket_events_ticket ON public.support_ticket_events (ticket_id);
