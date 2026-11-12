-- Add booking_type column to coupons table
-- This allows coupons to specify which booking type they apply to: MONTHLY, ONDEMAND, or SHORTTERM

ALTER TABLE coupons
ADD COLUMN IF NOT EXISTS booking_type VARCHAR(20) CHECK (booking_type IN ('MONTHLY', 'ONDEMAND', 'SHORTTERM'));

COMMENT ON COLUMN coupons.booking_type IS 'Booking type this coupon applies to (MONTHLY/ONDEMAND/SHORTTERM)';

-- Optional: Set default values for existing coupons based on coupon_code patterns
-- UPDATE coupons SET booking_type = 'MONTHLY' WHERE coupon_code LIKE '%MONTHLY%' AND booking_type IS NULL;
-- UPDATE coupons SET booking_type = 'ONDEMAND' WHERE coupon_code LIKE '%ONDEMAND%' AND booking_type IS NULL;
-- UPDATE coupons SET booking_type = 'SHORTTERM' WHERE coupon_code LIKE '%SHORTTERM%' AND booking_type IS NULL;
