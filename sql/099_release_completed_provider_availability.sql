-- Stale BOOKED rows from completed/cancelled engagements block new accepts.
DELETE FROM public.provider_availability pa
USING public.engagements e
WHERE e.engagement_id = pa.engagement_id
  AND pa.status = 'BOOKED'
  AND UPPER(COALESCE(e.engagement_status, '')) IN ('CANCELLED', 'COMPLETED', 'CLOSED', 'EXPIRED');
