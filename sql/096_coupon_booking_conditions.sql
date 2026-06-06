-- Booking eligibility: first booking, Nth booking (e.g. 6th), or any customer.

ALTER TABLE public.coupons
  ADD COLUMN IF NOT EXISTS booking_condition VARCHAR(30) DEFAULT 'ANY';

ALTER TABLE public.coupons
  ADD COLUMN IF NOT EXISTS nth_booking INTEGER;

COMMENT ON COLUMN public.coupons.booking_condition IS 'ANY | FIRST_BOOKING | NTH_BOOKING';
COMMENT ON COLUMN public.coupons.nth_booking IS 'When booking_condition is NTH_BOOKING: visit number (e.g. 6 = customer''s 6th booking).';
