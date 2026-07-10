-- Nanny / Caregiver rate card — idempotent
-- Monthly plan: ₹16,999 flat per month (same structure as MAID_MONTHLY)

INSERT INTO pricing_plan (
  service_type, booking_type, code, name, unit,
  base_rate_min, base_rate_max, constraints_json, is_active
) VALUES
  (
    'NANNY', 'MONTHLY', 'NANNY_MONTHLY',
    'Nanny — monthly contract', 'MONTH',
    16999, 16999,
    '{
      "visitHoursDefault": 1,
      "includedVisitHours": 1,
      "incrementalHourDiscountPct": 5,
      "extraHourPromoPct": 5,
      "daysPerMonth": 30
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
