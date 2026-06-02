-- Service-day tracking tables used by payments/reviews flows.

CREATE TABLE IF NOT EXISTS public.service_days (
  service_day_id BIGSERIAL PRIMARY KEY,
  engagement_id BIGINT NOT NULL,
  service_date DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'SCHEDULED',
  started_at TIMESTAMP(6),
  completed_at TIMESTAMP(6),
  otp_verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP(6) DEFAULT NOW(),
  updated_at TIMESTAMP(6) DEFAULT NOW()
);

DO $fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_service_days_engagement'
  ) THEN
    ALTER TABLE public.service_days
      ADD CONSTRAINT fk_service_days_engagement
      FOREIGN KEY (engagement_id)
      REFERENCES public.engagements (engagement_id)
      ON DELETE CASCADE;
  END IF;
END;
$fk$;

CREATE UNIQUE INDEX IF NOT EXISTS ux_service_days_engagement_date
  ON public.service_days (engagement_id, service_date);

CREATE INDEX IF NOT EXISTS idx_service_days_date
  ON public.service_days (service_date);

CREATE INDEX IF NOT EXISTS idx_service_days_status
  ON public.service_days (status);

CREATE TABLE IF NOT EXISTS public.service_day_otps (
  otp_id BIGSERIAL PRIMARY KEY,
  service_day_id BIGINT,
  otp_code VARCHAR(6),
  expires_at TIMESTAMP(6),
  verified_at TIMESTAMP(6),
  created_at TIMESTAMP(6) NOT NULL DEFAULT NOW()
);

DO $fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_service_day_otps_day'
  ) THEN
    ALTER TABLE public.service_day_otps
      ADD CONSTRAINT fk_service_day_otps_day
      FOREIGN KEY (service_day_id)
      REFERENCES public.service_days (service_day_id)
      ON DELETE CASCADE;
  END IF;
END;
$fk$;

CREATE INDEX IF NOT EXISTS idx_service_day_otps_day
  ON public.service_day_otps (service_day_id);
