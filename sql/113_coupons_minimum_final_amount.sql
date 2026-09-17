-- Migration 113: Add minimum_final_amount to coupons table
-- Purpose: Allow coupons to enforce a minimum final price (e.g., ₹1 for testing)
-- Date: 2026-08-16
-- Related: Test coupons TESTCOOK1, TESTMAID1, TESTNANNY1

-- Add the column if it doesn't exist
ALTER TABLE coupons 
ADD COLUMN IF NOT EXISTS minimum_final_amount FLOAT DEFAULT NULL;

-- Add comment to explain the column
COMMENT ON COLUMN coupons.minimum_final_amount IS 
'Minimum final amount after discount (e.g., 1 for ₹1). When set, discount will be capped to ensure final amount does not go below this value.';

-- Update existing test coupons to have minimum_final_amount = 1
UPDATE coupons 
SET minimum_final_amount = 1 
WHERE coupon_code IN ('TESTCOOK1', 'TESTMAID1', 'TESTNANNY1')
  AND minimum_final_amount IS NULL;

-- Verify the migration
DO $$
DECLARE
  test_coupon_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO test_coupon_count
  FROM coupons 
  WHERE coupon_code IN ('TESTCOOK1', 'TESTMAID1', 'TESTNANNY1')
    AND minimum_final_amount = 1;
  
  RAISE NOTICE 'Migration 113 complete: % test coupons updated with minimum_final_amount = 1', test_coupon_count;
END $$;
