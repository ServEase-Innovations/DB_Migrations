-- Allow partial provider creation by relaxing NOT NULL on profile fields (idempotent).

DO $relax$
DECLARE
  col text;
  cols text[] := ARRAY[
    'buildingname', 'emailid', 'firstname', 'isactive', 'lastname',
    'locality', 'mobileno', 'pincode', 'rating', 'street'
  ];
BEGIN
  FOREACH col IN ARRAY cols LOOP
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'serviceprovider'
        AND column_name = col
        AND is_nullable = 'NO'
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.serviceprovider ALTER COLUMN %I DROP NOT NULL',
        col
      );
    END IF;
  END LOOP;
END;
$relax$;
