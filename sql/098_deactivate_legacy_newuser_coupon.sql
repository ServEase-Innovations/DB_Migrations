-- Legacy UI placeholder NEWUSER is not a real coupon; deactivate if present.
UPDATE public.coupons
SET "isActive" = false
WHERE UPPER(TRIM(coupon_code)) = 'NEWUSER';
