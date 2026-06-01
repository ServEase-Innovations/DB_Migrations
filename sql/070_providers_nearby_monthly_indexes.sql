-- Optional indexes to speed up POST /nearby-monthly.
-- For zero-downtime prod deploys, recreate with CONCURRENTLY manually during low traffic.

-- Active providers with coordinates (partial index keeps it small)
CREATE INDEX IF NOT EXISTS idx_serviceprovider_active_lat_lng
  ON serviceprovider ("isactive", "latitude", "longitude")
  WHERE "isactive" = true AND "latitude" IS NOT NULL AND "longitude" IS NOT NULL;

-- Role lookup for EXISTS subquery
CREATE INDEX IF NOT EXISTS idx_serviceprovider_roles_spid_role
  ON serviceprovider_roles (serviceproviderid, role);

-- Weekly slots by provider
CREATE INDEX IF NOT EXISTS idx_provider_weekly_slots_spid
  ON provider_weekly_slots (serviceproviderid);

-- Booked availability in a date window
CREATE INDEX IF NOT EXISTS idx_pa_spid_date_status
  ON provider_availability (serviceproviderid, date, status)
  WHERE status = 'BOOKED';

-- Engagements overlapping a date range (adjust columns to match your planner stats)
CREATE INDEX IF NOT EXISTS idx_engagements_spid_active_dates
  ON engagements (serviceproviderid, active, start_date, end_date)
  WHERE active = true;

-- Previous booking lookup for a customer
CREATE INDEX IF NOT EXISTS idx_engagements_customer_spid
  ON engagements ("customerid", "serviceproviderid", "end_date" DESC NULLS LAST);
