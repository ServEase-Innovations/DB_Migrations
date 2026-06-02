-- 094_epoch_db_columns.sql
-- Idempotent epoch-column migration for remaining DB-level tables.
-- Safe to run multiple times.

/* -------------------------------------------------------------------------- */
/* service_days + service_day_otps                                              */
/* -------------------------------------------------------------------------- */

ALTER TABLE IF EXISTS public.service_days
  ADD COLUMN IF NOT EXISTS service_date_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS started_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS completed_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS updated_at_epoch BIGINT;

UPDATE public.service_days
SET
  service_date_epoch = COALESCE(
    service_date_epoch,
    FLOOR(EXTRACT(EPOCH FROM (service_date::timestamp)))::bigint
  ),
  started_at_epoch = COALESCE(
    started_at_epoch,
    CASE WHEN started_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM started_at))::bigint END
  ),
  completed_at_epoch = COALESCE(
    completed_at_epoch,
    CASE WHEN completed_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM completed_at))::bigint END
  ),
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  ),
  updated_at_epoch = COALESCE(
    updated_at_epoch,
    CASE WHEN updated_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM updated_at))::bigint END
  )
WHERE
  service_date_epoch IS NULL
  OR started_at_epoch IS NULL
  OR completed_at_epoch IS NULL
  OR created_at_epoch IS NULL
  OR updated_at_epoch IS NULL;

ALTER TABLE IF EXISTS public.service_day_otps
  ADD COLUMN IF NOT EXISTS expires_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS verified_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT;

UPDATE public.service_day_otps
SET
  expires_at_epoch = COALESCE(
    expires_at_epoch,
    CASE WHEN expires_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM expires_at))::bigint END
  ),
  verified_at_epoch = COALESCE(
    verified_at_epoch,
    CASE WHEN verified_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM verified_at))::bigint END
  ),
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  )
WHERE
  expires_at_epoch IS NULL
  OR verified_at_epoch IS NULL
  OR created_at_epoch IS NULL;

/* -------------------------------------------------------------------------- */
/* provider_daily_slots + provider_weekly_slots                                */
/* -------------------------------------------------------------------------- */

ALTER TABLE IF EXISTS public.provider_daily_slots
  ADD COLUMN IF NOT EXISTS slot_date_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS slot_start_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS slot_end_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS updated_at_epoch BIGINT;

UPDATE public.provider_daily_slots
SET
  slot_date_epoch = COALESCE(
    slot_date_epoch,
    FLOOR(EXTRACT(EPOCH FROM (slot_date::timestamp)))::bigint
  ),
  slot_start_epoch = COALESCE(
    slot_start_epoch,
    CASE WHEN slot_start IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM slot_start))::bigint END
  ),
  slot_end_epoch = COALESCE(
    slot_end_epoch,
    CASE WHEN slot_end IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM slot_end))::bigint END
  ),
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  ),
  updated_at_epoch = COALESCE(
    updated_at_epoch,
    CASE WHEN updated_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM updated_at))::bigint END
  )
WHERE
  slot_date_epoch IS NULL
  OR slot_start_epoch IS NULL
  OR slot_end_epoch IS NULL
  OR created_at_epoch IS NULL
  OR updated_at_epoch IS NULL;

ALTER TABLE IF EXISTS public.provider_weekly_slots
  ADD COLUMN IF NOT EXISTS slot_start_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS slot_end_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS updated_at_epoch BIGINT;

-- Weekly slots are time-of-day windows; anchor to Unix epoch date for compatibility.
UPDATE public.provider_weekly_slots
SET
  slot_start_epoch = COALESCE(
    slot_start_epoch,
    FLOOR(EXTRACT(EPOCH FROM (TIMESTAMP '1970-01-01' + slot_start)))::bigint
  ),
  slot_end_epoch = COALESCE(
    slot_end_epoch,
    FLOOR(EXTRACT(EPOCH FROM (TIMESTAMP '1970-01-01' + slot_end)))::bigint
  ),
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  ),
  updated_at_epoch = COALESCE(
    updated_at_epoch,
    CASE WHEN updated_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM updated_at))::bigint END
  )
WHERE
  slot_start_epoch IS NULL
  OR slot_end_epoch IS NULL
  OR created_at_epoch IS NULL
  OR updated_at_epoch IS NULL;

/* -------------------------------------------------------------------------- */
/* support_tickets + support_ticket_comments + support_ticket_events           */
/* -------------------------------------------------------------------------- */

ALTER TABLE IF EXISTS public.support_tickets
  ADD COLUMN IF NOT EXISTS sla_due_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS resolved_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS updated_at_epoch BIGINT;

UPDATE public.support_tickets
SET
  sla_due_at_epoch = COALESCE(
    sla_due_at_epoch,
    CASE WHEN sla_due_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM sla_due_at))::bigint END
  ),
  resolved_at_epoch = COALESCE(
    resolved_at_epoch,
    CASE WHEN resolved_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM resolved_at))::bigint END
  ),
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  ),
  updated_at_epoch = COALESCE(
    updated_at_epoch,
    CASE WHEN updated_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM updated_at))::bigint END
  )
WHERE
  sla_due_at_epoch IS NULL
  OR resolved_at_epoch IS NULL
  OR created_at_epoch IS NULL
  OR updated_at_epoch IS NULL;

ALTER TABLE IF EXISTS public.support_ticket_comments
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT;

UPDATE public.support_ticket_comments
SET created_at_epoch = COALESCE(
  created_at_epoch,
  CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
)
WHERE created_at_epoch IS NULL;

ALTER TABLE IF EXISTS public.support_ticket_events
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT;

UPDATE public.support_ticket_events
SET created_at_epoch = COALESCE(
  created_at_epoch,
  CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
)
WHERE created_at_epoch IS NULL;

/* -------------------------------------------------------------------------- */
/* coupons + coupon_redemptions + in_app_notifications                         */
/* -------------------------------------------------------------------------- */

ALTER TABLE IF EXISTS public.coupons
  ADD COLUMN IF NOT EXISTS start_date_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS end_date_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT;

UPDATE public.coupons
SET
  start_date_epoch = COALESCE(
    start_date_epoch,
    CASE WHEN start_date IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM start_date))::bigint END
  ),
  end_date_epoch = COALESCE(
    end_date_epoch,
    CASE WHEN end_date IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM end_date))::bigint END
  ),
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  )
WHERE
  start_date_epoch IS NULL
  OR end_date_epoch IS NULL
  OR created_at_epoch IS NULL;

ALTER TABLE IF EXISTS public.coupon_redemptions
  ADD COLUMN IF NOT EXISTS reserved_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS applied_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS released_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS expires_at_epoch BIGINT;

UPDATE public.coupon_redemptions
SET
  reserved_at_epoch = COALESCE(
    reserved_at_epoch,
    CASE WHEN reserved_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM reserved_at))::bigint END
  ),
  applied_at_epoch = COALESCE(
    applied_at_epoch,
    CASE WHEN applied_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM applied_at))::bigint END
  ),
  released_at_epoch = COALESCE(
    released_at_epoch,
    CASE WHEN released_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM released_at))::bigint END
  ),
  expires_at_epoch = COALESCE(
    expires_at_epoch,
    CASE WHEN expires_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM expires_at))::bigint END
  )
WHERE
  reserved_at_epoch IS NULL
  OR applied_at_epoch IS NULL
  OR released_at_epoch IS NULL
  OR expires_at_epoch IS NULL;

ALTER TABLE IF EXISTS public.in_app_notifications
  ADD COLUMN IF NOT EXISTS created_at_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS read_at_epoch BIGINT;

UPDATE public.in_app_notifications
SET
  created_at_epoch = COALESCE(
    created_at_epoch,
    CASE WHEN created_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM created_at))::bigint END
  ),
  read_at_epoch = COALESCE(
    read_at_epoch,
    CASE WHEN read_at IS NOT NULL THEN FLOOR(EXTRACT(EPOCH FROM read_at))::bigint END
  )
WHERE
  created_at_epoch IS NULL
  OR read_at_epoch IS NULL;

/* -------------------------------------------------------------------------- */
/* optional indexes on epoch columns                                           */
/* -------------------------------------------------------------------------- */

CREATE INDEX IF NOT EXISTS idx_service_days_service_date_epoch
  ON public.service_days (service_date_epoch);

CREATE INDEX IF NOT EXISTS idx_provider_daily_slots_slot_start_epoch
  ON public.provider_daily_slots (slot_start_epoch);

CREATE INDEX IF NOT EXISTS idx_support_tickets_sla_due_at_epoch
  ON public.support_tickets (sla_due_at_epoch);

CREATE INDEX IF NOT EXISTS idx_in_app_notifications_created_at_epoch
  ON public.in_app_notifications (created_at_epoch DESC);
