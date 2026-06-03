-- Coupons service (Sequelize) expects UUID coupon_id + coupon_redemptions.
-- Baseline payments schema has legacy coupons(id bigint). Rename legacy and create v2.

DO $migrate$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'coupons'
      AND column_name = 'coupon_id'
  ) THEN
    RAISE NOTICE '090: coupons v2 already present — skipping';
    RETURN;
  END IF;

  -- Drop FKs that reference legacy public.coupons(id)
  ALTER TABLE IF EXISTS public.customer_payments
    DROP CONSTRAINT IF EXISTS fkm97i2iuqhktsnicqlpdubttre;

  ALTER TABLE IF EXISTS public.customer_used_coupons
    DROP CONSTRAINT IF EXISTS fka8biu5lk7k8h263pl45s6v539;

  ALTER TABLE IF EXISTS public.service_provider_used_coupons
    DROP CONSTRAINT IF EXISTS fka8biu5lk7k8h263pl45s6v540;

  ALTER TABLE IF EXISTS public.service_provider_used_coupons
    DROP CONSTRAINT IF EXISTS service_provider_used_coupons_coupon_id_fkey;

  DROP TABLE IF EXISTS public.coupon_redemptions CASCADE;

  -- Recover from a failed prior run (legacy renamed but v2 create aborted)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'coupons_legacy'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'coupons'
  )
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'coupons' AND column_name = 'coupon_id'
  ) THEN
    DROP TABLE public.coupons CASCADE;
    RAISE NOTICE '090: dropped partial coupons table from failed migration';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'coupons'
  )
  AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'coupons' AND column_name = 'coupon_id'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public' AND table_name = 'coupons_legacy'
    ) THEN
      DROP TABLE public.coupons_legacy CASCADE;
      RAISE NOTICE '090: dropped stale coupons_legacy before rename';
    END IF;
    ALTER TABLE public.coupons RENAME TO coupons_legacy;
    BEGIN
      ALTER TABLE public.coupons_legacy RENAME CONSTRAINT coupons_pkey TO coupons_legacy_pkey;
    EXCEPTION
      WHEN undefined_object THEN
        NULL;
    END;
    BEGIN
      ALTER TABLE public.coupons_legacy
        RENAME CONSTRAINT ukctujg6iiegcw3kgrm2at8p871 TO coupons_legacy_coupon_code_key;
    EXCEPTION
      WHEN undefined_object THEN
        NULL;
    END;
    RAISE NOTICE '090: renamed legacy coupons → coupons_legacy';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ServiceType') THEN
    CREATE TYPE public."ServiceType" AS ENUM ('COOK', 'MAID', 'NANNY');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'DiscountType') THEN
    CREATE TYPE public."DiscountType" AS ENUM ('PERCENTAGE', 'FLAT');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'coupons'
  ) THEN
  CREATE TABLE public.coupons (
    coupon_id UUID NOT NULL,
    created_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    service_type public."ServiceType" NOT NULL,
    coupon_code TEXT NOT NULL,
    description TEXT,
    discount_type public."DiscountType" NOT NULL,
    start_date TIMESTAMP(3) NOT NULL,
    end_date TIMESTAMP(3) NOT NULL,
    usage_limit INTEGER,
    minimum_order_value DOUBLE PRECISION,
    usage_per_user INTEGER,
    city TEXT,
    discount_value DOUBLE PRECISION NOT NULL,
    CONSTRAINT coupons_v2_pkey PRIMARY KEY (coupon_id),
    CONSTRAINT coupons_v2_coupon_code_key UNIQUE (coupon_code)
  );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'coupon_redemptions'
  ) THEN
  CREATE TABLE public.coupon_redemptions (
    redemption_id UUID NOT NULL,
    coupon_id UUID NOT NULL,
    user_id BIGINT NOT NULL,
    engagement_id BIGINT,
    status VARCHAR(20) NOT NULL DEFAULT 'RESERVED',
    discount_amount DOUBLE PRECISION NOT NULL,
    reserved_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    applied_at TIMESTAMPTZ(6),
    released_at TIMESTAMPTZ(6),
    expires_at TIMESTAMPTZ(6) NOT NULL,
    metadata JSONB,
    CONSTRAINT coupon_redemptions_pkey PRIMARY KEY (redemption_id),
    CONSTRAINT coupon_redemptions_coupon_id_fkey
      FOREIGN KEY (coupon_id) REFERENCES public.coupons (coupon_id)
      ON DELETE CASCADE ON UPDATE NO ACTION
  );
  END IF;

  CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_coupon_status
    ON public.coupon_redemptions (coupon_id, status);

  CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_user_coupon_status
    ON public.coupon_redemptions (user_id, coupon_id, status);

  CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_engagement
    ON public.coupon_redemptions (engagement_id);

  CREATE UNIQUE INDEX IF NOT EXISTS uq_coupon_redemptions_coupon_user_engagement
    ON public.coupon_redemptions (coupon_id, user_id, engagement_id);

  RAISE NOTICE '090: coupons v2 + coupon_redemptions created';
END;
$migrate$;
