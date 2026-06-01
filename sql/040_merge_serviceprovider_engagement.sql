-- Dev consolidation: migrate serviceprovider_engagement → engagements, repoint FKs, drop legacy table.
-- Idempotent: safe to re-run after partial failure (uses legacy_spe_id on engagements).

DO $merge$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'serviceprovider_engagement'
  ) THEN
    RAISE NOTICE 'merge_serviceprovider_engagement: legacy table already removed';
    RETURN;
  END IF;

  -- Union view from engagement_canonical_legacy.sql blocks DROP TABLE until removed.
  DROP VIEW IF EXISTS public.v_engagement_bookings;

  ALTER TABLE public.engagements
    ADD COLUMN IF NOT EXISTS legacy_spe_id BIGINT;

  CREATE UNIQUE INDEX IF NOT EXISTS engagements_legacy_spe_id_key
    ON public.engagements (legacy_spe_id)
    WHERE legacy_spe_id IS NOT NULL;

  INSERT INTO public.engagements (
    customerid,
    serviceproviderid,
    responsibilities,
    booking_type,
    service_type,
    base_amount,
    start_date,
    end_date,
    task_status,
    active,
    assignment_status,
    address,
    latitude,
    longitude,
    created_at,
    legacy_spe_id
  )
  SELECT
    spe.customerid,
    spe.serviceproviderid,
    CASE
      WHEN spe.responsibilities IS NULL OR btrim(spe.responsibilities) = '' THEN '[]'::jsonb
      WHEN spe.responsibilities ~ '^\s*[\[{]' THEN spe.responsibilities::jsonb
      ELSE jsonb_build_array(jsonb_build_object('legacy_text', spe.responsibilities))
    END,
    COALESCE(NULLIF(UPPER(btrim(spe.bookingtype)), ''), 'ON_DEMAND'),
    spe.servicetype,
    COALESCE(spe.monthlyamount, 0)::numeric(10, 2),
    spe.startdate,
    spe.enddate,
    CASE
      WHEN UPPER(COALESCE(spe.taskstatus, '')) IN ('COMPLETED', 'CLOSED', 'DONE') THEN 'COMPLETED'
      WHEN UPPER(COALESCE(spe.taskstatus, '')) IN ('CANCELLED', 'CANCELED') THEN 'CANCELLED'
      ELSE COALESCE(NULLIF(btrim(spe.taskstatus), ''), 'COMPLETED')
    END,
    COALESCE(spe.isactive, true),
    CASE
      WHEN spe.serviceproviderid IS NOT NULL THEN 'ASSIGNED'
      ELSE 'UNASSIGNED'
    END,
    spe.address,
    NULL::double precision,
    NULL::double precision,
    spe.bookingdate,
    spe.id
  FROM public.serviceprovider_engagement spe
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.engagements e
    WHERE e.legacy_spe_id = spe.id
  );

  -- Repoint FK columns that still store legacy serviceprovider_engagement.id
  UPDATE public.booking_transaction bt
  SET engagement_id = e.engagement_id
  FROM public.engagements e
  WHERE e.legacy_spe_id = bt.engagement_id
    AND bt.engagement_id IS DISTINCT FROM e.engagement_id;

  UPDATE public.customer_holidays ch
  SET engagement_id = e.engagement_id
  FROM public.engagements e
  WHERE e.legacy_spe_id = ch.engagement_id
    AND ch.engagement_id IS DISTINCT FROM e.engagement_id;

  UPDATE public.customer_payments cp
  SET engagement_id = e.engagement_id
  FROM public.engagements e
  WHERE e.legacy_spe_id = cp.engagement_id
    AND cp.engagement_id IS DISTINCT FROM e.engagement_id;

  UPDATE public.customer_used_coupons cuc
  SET engagement_id = e.engagement_id
  FROM public.engagements e
  WHERE e.legacy_spe_id = cuc.engagement_id
    AND cuc.engagement_id IS DISTINCT FROM e.engagement_id;

  UPDATE public.provider_reviews pr
  SET engagement_id = e.engagement_id
  FROM public.engagements e
  WHERE pr.serviceprovider_engagement_id IS NOT NULL
    AND e.legacy_spe_id = pr.serviceprovider_engagement_id
    AND (pr.engagement_id IS NULL OR pr.engagement_id IS DISTINCT FROM e.engagement_id);

  -- Drop FKs to legacy table
  ALTER TABLE public.booking_transaction
    DROP CONSTRAINT IF EXISTS fkkivwnnxvqx05mibfdqqlwjtxl;

  ALTER TABLE public.customer_holidays
    DROP CONSTRAINT IF EXISTS fkbwd4f3r07gcppsbem0fjyotp5;

  ALTER TABLE public.customer_payments
    DROP CONSTRAINT IF EXISTS fkraud38jxwghhw4mdfiakim2om;

  ALTER TABLE public.customer_used_coupons
    DROP CONSTRAINT IF EXISTS fkgv3frrq5tfuprorv55f82m0en;

  ALTER TABLE public.provider_reviews
    DROP CONSTRAINT IF EXISTS fk_review_on_demand;

  ALTER TABLE public.provider_reviews
    DROP CONSTRAINT IF EXISTS one_experience_only;

  DROP INDEX IF EXISTS public.idx_reviews_on_demand;

  ALTER TABLE public.provider_reviews
    DROP COLUMN IF EXISTS serviceprovider_engagement_id;

  ALTER TABLE public.serviceprovider_engagement
    DROP CONSTRAINT IF EXISTS fkh2c2wulrpu6ymcxnkkhiqnsyl;

  ALTER TABLE public.serviceprovider_engagement
    DROP CONSTRAINT IF EXISTS fkl0h091exkleq4l5p7wsyfnhvw;

  DROP TABLE public.serviceprovider_engagement;

  -- Canonical FKs (engagements only)
  ALTER TABLE public.booking_transaction
    DROP CONSTRAINT IF EXISTS booking_transaction_engagement_id_fkey;

  ALTER TABLE public.booking_transaction
    ADD CONSTRAINT booking_transaction_engagement_id_fkey
    FOREIGN KEY (engagement_id)
    REFERENCES public.engagements (engagement_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

  ALTER TABLE public.customer_holidays
    DROP CONSTRAINT IF EXISTS customer_holidays_engagement_id_fkey;

  ALTER TABLE public.customer_holidays
    ADD CONSTRAINT customer_holidays_engagement_id_fkey
    FOREIGN KEY (engagement_id)
    REFERENCES public.engagements (engagement_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

  ALTER TABLE public.customer_payments
    DROP CONSTRAINT IF EXISTS customer_payments_engagement_id_fkey;

  ALTER TABLE public.customer_payments
    ADD CONSTRAINT customer_payments_engagement_id_fkey
    FOREIGN KEY (engagement_id)
    REFERENCES public.engagements (engagement_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

  ALTER TABLE public.customer_used_coupons
    DROP CONSTRAINT IF EXISTS customer_used_coupons_engagement_id_fkey;

  ALTER TABLE public.customer_used_coupons
    ADD CONSTRAINT customer_used_coupons_engagement_id_fkey
    FOREIGN KEY (engagement_id)
    REFERENCES public.engagements (engagement_id)
    ON UPDATE NO ACTION
    ON DELETE NO ACTION;

  ALTER TABLE public.engagements
    DROP COLUMN IF EXISTS legacy_spe_id;

  DROP INDEX IF EXISTS public.engagements_legacy_spe_id_key;

  CREATE OR REPLACE VIEW public.v_engagement_bookings AS
  SELECT
    e.engagement_id AS booking_ref_id,
    'engagements'::text AS booking_source,
    e.customerid,
    e.serviceproviderid,
    e.booking_type,
    e.service_type,
    e.task_status,
    e.assignment_status,
    e.start_date,
    e.end_date,
    e.created_at
  FROM public.engagements e;

  COMMENT ON TABLE public.engagements IS
    'Canonical booking table for all booking_type values (ON_DEMAND, SHORT_TERM, MONTHLY).';

  RAISE NOTICE 'merge_serviceprovider_engagement: legacy table merged and dropped';
END;
$merge$;
