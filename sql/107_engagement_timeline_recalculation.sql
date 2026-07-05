-- Migration 107: Engagement Timeline Recalculation
-- Description: Add columns to track actual service start/end times and enable
--              timeline recalculation when service provider starts service early.
-- Author: Kiro AI
-- Date: 2026-07-04
-- JIRA: [FEATURE-XXX] Dynamic Booking Timeline Recalculation

-- ============================================================================
-- FORWARD MIGRATION
-- ============================================================================

-- Add timeline tracking columns to engagements table
ALTER TABLE public.engagements
  ADD COLUMN IF NOT EXISTS actual_start_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS actual_end_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS duration_minutes INTEGER DEFAULT 60,
  ADD COLUMN IF NOT EXISTS is_timeline_recalculated BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS early_start_minutes INTEGER DEFAULT 0;

-- Add column comments for documentation
COMMENT ON COLUMN public.engagements.actual_start_epoch IS 
  'Unix epoch timestamp (seconds) when service actually started. Captured when booking transitions to IN_PROGRESS. May differ from scheduled start_epoch if provider arrives early.';

COMMENT ON COLUMN public.engagements.actual_end_epoch IS 
  'Recalculated end epoch: actual_start_epoch + (duration_minutes * 60). Used for extension calculations.';

COMMENT ON COLUMN public.engagements.duration_minutes IS 
  'Originally booked service duration in minutes. Preserved during timeline recalculation. Calculated from (end_epoch - start_epoch) / 60.';

COMMENT ON COLUMN public.engagements.is_timeline_recalculated IS 
  'Flag indicating whether timeline has been recalculated based on actual start time. When true, use actual_start_epoch and actual_end_epoch for display and calculations.';

COMMENT ON COLUMN public.engagements.early_start_minutes IS 
  'Number of minutes service started before scheduled start_epoch. Positive value indicates early start. Calculated as (start_epoch - actual_start_epoch) / 60.';

-- Create indexes for timeline queries
CREATE INDEX IF NOT EXISTS idx_engagements_actual_start 
  ON public.engagements(actual_start_epoch) 
  WHERE actual_start_epoch IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_engagements_timeline_recalc
  ON public.engagements(is_timeline_recalculated)
  WHERE is_timeline_recalculated = true;

-- Composite index for common query patterns
CREATE INDEX IF NOT EXISTS idx_engagements_status_timeline
  ON public.engagements(task_status, is_timeline_recalculated, actual_end_epoch)
  WHERE task_status = 'IN_PROGRESS';


-- Add timeline tracking to service_days table
ALTER TABLE public.service_days
  ADD COLUMN IF NOT EXISTS actual_started_at TIMESTAMP WITHOUT TIME ZONE,
  ADD COLUMN IF NOT EXISTS actual_start_epoch BIGINT,
  ADD COLUMN IF NOT EXISTS actual_end_epoch BIGINT;

-- Add column comments
COMMENT ON COLUMN public.service_days.actual_started_at IS 
  'Timestamp when service day actually started (may differ from scheduled start_time). Captured when provider clicks "Start Service".';

COMMENT ON COLUMN public.service_days.actual_start_epoch IS 
  'Unix epoch timestamp (seconds) when service day actually started. Used for day-level timeline tracking.';

COMMENT ON COLUMN public.service_days.actual_end_epoch IS 
  'Calculated end epoch for the service day based on actual start time and duration.';

-- Create index for service day timeline queries
CREATE INDEX IF NOT EXISTS idx_service_days_actual_start
  ON public.service_days(actual_start_epoch)
  WHERE actual_start_epoch IS NOT NULL;

-- ============================================================================
-- DATA BACKFILL (Optional - for historical data)
-- ============================================================================

-- Backfill duration_minutes for existing engagements
-- This calculates the original booked duration from start_epoch and end_epoch
UPDATE public.engagements
SET duration_minutes = GREATEST(
  ROUND((end_epoch - start_epoch)::NUMERIC / 60)::INTEGER,
  15  -- Minimum 15 minutes
)
WHERE duration_minutes IS NULL
  AND start_epoch IS NOT NULL
  AND end_epoch IS NOT NULL
  AND end_epoch > start_epoch;

-- Backfill actual_start_epoch for historical completed services
-- This uses the started_at timestamp from service_days if available
WITH service_day_starts AS (
  SELECT 
    sd.engagement_id,
    MIN(EXTRACT(EPOCH FROM sd.started_at)::BIGINT) AS first_actual_start
  FROM public.service_days sd
  WHERE sd.started_at IS NOT NULL
    AND sd.status IN ('IN_PROGRESS', 'COMPLETED')
  GROUP BY sd.engagement_id
)
UPDATE public.engagements e
SET 
  actual_start_epoch = sds.first_actual_start,
  is_timeline_recalculated = false  -- Mark as NOT recalculated (historical data)
FROM service_day_starts sds
WHERE e.engagement_id = sds.first_actual_start
  AND e.actual_start_epoch IS NULL
  AND e.task_status IN ('IN_PROGRESS', 'COMPLETED');

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify columns were added successfully
DO $$
BEGIN
  ASSERT (
    SELECT COUNT(*) = 5
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'engagements'
      AND column_name IN (
        'actual_start_epoch',
        'actual_end_epoch',
        'duration_minutes',
        'is_timeline_recalculated',
        'early_start_minutes'
      )
  ), 'Expected 5 new columns in engagements table';

  ASSERT (
    SELECT COUNT(*) = 3
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'service_days'
      AND column_name IN (
        'actual_started_at',
        'actual_start_epoch',
        'actual_end_epoch'
      )
  ), 'Expected 3 new columns in service_days table';

  RAISE NOTICE 'Migration 107: All columns created successfully';
END $$;

-- ============================================================================
-- ROLLBACK SCRIPT (Run this to undo the migration)
-- ============================================================================
/*
-- Drop indexes
DROP INDEX IF EXISTS public.idx_engagements_actual_start;
DROP INDEX IF EXISTS public.idx_engagements_timeline_recalc;
DROP INDEX IF EXISTS public.idx_engagements_status_timeline;
DROP INDEX IF EXISTS public.idx_service_days_actual_start;

-- Remove columns from engagements table
ALTER TABLE public.engagements
  DROP COLUMN IF EXISTS actual_start_epoch,
  DROP COLUMN IF EXISTS actual_end_epoch,
  DROP COLUMN IF EXISTS duration_minutes,
  DROP COLUMN IF EXISTS is_timeline_recalculated,
  DROP COLUMN IF EXISTS early_start_minutes;

-- Remove columns from service_days table
ALTER TABLE public.service_days
  DROP COLUMN IF EXISTS actual_started_at,
  DROP COLUMN IF EXISTS actual_start_epoch,
  DROP COLUMN IF EXISTS actual_end_epoch;

-- Verify rollback
SELECT 'Rollback complete' AS status;
*/
