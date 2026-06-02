-- V2 booking / nearby-monthly use visit length on engagements (payments + providers).

ALTER TABLE public.engagements
  ADD COLUMN IF NOT EXISTS duration_minutes integer DEFAULT 60;

COMMENT ON COLUMN public.engagements.duration_minutes IS
  'Visit length in minutes; used for slot booking and provider_availability overlap.';

-- Backfill from epoch range when present (cap 24h)
UPDATE public.engagements e
SET duration_minutes = sub.mins
FROM (
  SELECT
    engagement_id,
    GREATEST(
      1,
      LEAST(1440, ((end_epoch - start_epoch) / 60)::integer)
    ) AS mins
  FROM public.engagements
  WHERE duration_minutes IS NULL
    AND start_epoch IS NOT NULL
    AND end_epoch IS NOT NULL
    AND end_epoch > start_epoch
) sub
WHERE e.engagement_id = sub.engagement_id;

UPDATE public.engagements
SET duration_minutes = 60
WHERE duration_minutes IS NULL;
