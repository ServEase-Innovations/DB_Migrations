-- Provider scheduling tables (used by providers service; not in legacy schema.sql snapshot).

CREATE TABLE IF NOT EXISTS public.provider_weekly_slots (
  id BIGSERIAL PRIMARY KEY,
  serviceproviderid BIGINT NOT NULL,
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  slot_start TIME NOT NULL,
  slot_end TIME NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.provider_daily_slots (
  id BIGSERIAL PRIMARY KEY,
  serviceproviderid BIGINT NOT NULL,
  slot_date DATE NOT NULL,
  slot_start TIMESTAMP NOT NULL,
  slot_end TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

DO $fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_provider_weekly_slots_serviceprovider'
  ) THEN
    ALTER TABLE public.provider_weekly_slots
      ADD CONSTRAINT fk_provider_weekly_slots_serviceprovider
      FOREIGN KEY (serviceproviderid)
      REFERENCES public.serviceprovider (serviceproviderid)
      ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_provider_daily_slots_serviceprovider'
  ) THEN
    ALTER TABLE public.provider_daily_slots
      ADD CONSTRAINT fk_provider_daily_slots_serviceprovider
      FOREIGN KEY (serviceproviderid)
      REFERENCES public.serviceprovider (serviceproviderid)
      ON DELETE CASCADE;
  END IF;
END;
$fk$;
