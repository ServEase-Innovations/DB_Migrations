-- Nanny / Caregiver SHORT_TERM daily rate card — idempotent
-- Pricing:
--   7-day package rate: ₹4,999 for 8 hours/day
--   Prorated per day: (4999 / 7) ≈ ₹714.14 / day (for 8 hours)
--   For 4 hours/day: half of 8 hours rate, i.e., ₹2499.50 for 7 days ≈ ₹357.07 / day

INSERT INTO pricing_plan (
  service_type, booking_type, code, name, unit,
  base_rate_min, base_rate_max, constraints_json, is_active
) VALUES
  (
    'NANNY', 'SHORT_TERM', 'NANNY_DAILY',
    'Nanny — short term daily', 'DAY',
    2499.50, 4999.00,
    '{
      "sevenDayPkgRate": 4999.00,
      "maxDurationDays": 15
     }'::jsonb,
    TRUE
  )
ON CONFLICT (service_type, booking_type, code) DO UPDATE SET
  name              = EXCLUDED.name,
  unit              = EXCLUDED.unit,
  base_rate_min     = EXCLUDED.base_rate_min,
  base_rate_max     = EXCLUDED.base_rate_max,
  constraints_json  = EXCLUDED.constraints_json,
  is_active         = EXCLUDED.is_active,
  updated_at        = NOW();
