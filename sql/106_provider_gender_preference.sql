-- Add provider_gender_preference column to engagements table
-- This allows customers to specify preferred provider gender for on-demand bookings
-- Migration 106: Provider Gender Preference

ALTER TABLE public.engagements
  ADD COLUMN IF NOT EXISTS provider_gender_preference character varying(50) COLLATE pg_catalog."default" DEFAULT 'No Preference';

COMMENT ON COLUMN public.engagements.provider_gender_preference IS
  'Customer preference for provider gender (Male, Female, No Preference). Used for on-demand booking provider matching.';

-- Create index for efficient filtering during provider broadcast
CREATE INDEX IF NOT EXISTS idx_engagements_gender_preference 
  ON public.engagements(provider_gender_preference)
  WHERE provider_gender_preference IS NOT NULL 
    AND provider_gender_preference != 'No Preference';

-- Log migration
DO $$
BEGIN
  RAISE NOTICE 'Migration 106: Added provider_gender_preference column to engagements table';
END $$;
