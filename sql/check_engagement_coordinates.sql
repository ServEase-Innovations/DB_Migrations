-- Check Engagement Coordinates for Tracking
-- This script helps verify that engagements have latitude/longitude set
-- for ETA calculation and route display

-- ============================================
-- 1. Check how many engagements have coordinates
-- ============================================

SELECT 
  'Total Engagements' as metric,
  COUNT(*) as count
FROM engagements

UNION ALL

SELECT 
  'With Coordinates' as metric,
  COUNT(*) as count
FROM engagements
WHERE latitude IS NOT NULL AND longitude IS NOT NULL

UNION ALL

SELECT 
  'Missing Coordinates' as metric,
  COUNT(*) as count
FROM engagements
WHERE latitude IS NULL OR longitude IS NULL

UNION ALL

SELECT 
  'Active Without Coordinates' as metric,
  COUNT(*) as count
FROM engagements
WHERE active = true 
  AND (latitude IS NULL OR longitude IS NULL);

-- ============================================
-- 2. Show active engagements missing coordinates
-- ============================================

SELECT 
  engagement_id,
  customerid,
  serviceproviderid,
  address,
  latitude,
  longitude,
  booking_type,
  task_status,
  start_date,
  end_date
FROM engagements
WHERE active = true 
  AND (latitude IS NULL OR longitude IS NULL)
ORDER BY start_date DESC
LIMIT 20;

-- ============================================
-- 3. Show recent engagements with coordinates (examples)
-- ============================================

SELECT 
  engagement_id,
  customerid,
  address,
  latitude,
  longitude,
  task_status,
  start_date
FROM engagements
WHERE latitude IS NOT NULL 
  AND longitude IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- 4. OPTIONAL: Backfill coordinates from customer address
-- ============================================
-- WARNING: Only use this if customer home address is acceptable
-- In most cases, booking location ≠ customer home
-- Uncomment only if needed:

/*
UPDATE engagements e
SET 
  latitude = c.latitude,
  longitude = c.longitude
FROM customer c
WHERE e.customerid = c.customerid
  AND e.latitude IS NULL
  AND c.latitude IS NOT NULL
  AND c.longitude IS NOT NULL;
*/

-- ============================================
-- 5. Sample update for testing
-- ============================================
-- Update a specific engagement for testing:

-- Example: Bangalore location (WeWork MG Road)
/*
UPDATE engagements 
SET 
  latitude = 12.9716,
  longitude = 77.5946,
  address = COALESCE(address, 'MG Road, Bangalore, Karnataka')
WHERE engagement_id = 353;
*/

-- ============================================
-- 6. Validate coordinate ranges
-- ============================================

SELECT 
  engagement_id,
  latitude,
  longitude,
  CASE 
    WHEN latitude < -90 OR latitude > 90 THEN 'Invalid latitude'
    WHEN longitude < -180 OR longitude > 180 THEN 'Invalid longitude'
    ELSE 'Valid'
  END as validation_status
FROM engagements
WHERE latitude IS NOT NULL 
  AND longitude IS NOT NULL
  AND (
    latitude < -90 OR latitude > 90 OR
    longitude < -180 OR longitude > 180
  );

-- ============================================
-- 7. Check engagements with tracking status
-- ============================================

SELECT 
  e.engagement_id,
  e.customerid,
  e.serviceproviderid,
  e.latitude,
  e.longitude,
  e.task_status,
  ets.tracking_status,
  ets.journey_started_at
FROM engagements e
LEFT JOIN engagement_tracking_status ets 
  ON e.engagement_id = ets.engagement_id
WHERE e.active = true
  AND ets.tracking_status IS NOT NULL
ORDER BY ets.journey_started_at DESC NULLS LAST
LIMIT 10;
