-- Nanny / Caregiver ON_DEMAND rate card — idempotent
-- Pricing:
--   Min 4 hours  → ₹399 flat
--   8 hours      → ₹799 flat
--   Extra hours  → ₹150 / hr beyond the 4-hour minimum package

INSERT INTO pricing_plan (
  service_type, booking_type, code, name, unit,
  base_rate_min, base_rate_max, constraints_json, is_active
) VALUES
  (
    'NANNY', 'ON_DEMAND', 'NANNY_HOURLY',
    'Nanny — on demand (min 4 h)', 'HOUR',
    399, 799,
    '{
      "minHours": 4,
      "minPackageRate": 399,
      "fullDayHours": 8,
      "fullDayRate": 799,
      "extraHourlyRate": 150
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

-- Rules for NANNY_HOURLY
-- Rule 1: Minimum 4-hour package → ₹399 flat
-- Rule 2: Full-day 8-hour package → ₹799 flat
INSERT INTO pricing_rule (plan_id, rule_type, priority, condition_json, effect_json, is_active)
SELECT p.plan_id, v.rule_type, v.priority, v.condition_json::jsonb, v.effect_json::jsonb, TRUE
FROM pricing_plan p
CROSS JOIN (VALUES
  ('FIXED_PACKAGE', 30, '{"kind":"MIN_HOURS_PACKAGE","hoursMin":4,"hoursMax":7}', '{"amount":399,"unit":"PACKAGE","label":"Min 4-hour nanny visit — ₹399"}'),
  ('FIXED_DAY_PACKAGE', 25, '{"kind":"FULL_DAY_HOURS","hoursMin":8,"hoursMax":8}', '{"amount":799,"unit":"DAY","label":"Full-day nanny (8 hr) — ₹799"}')
) AS v(rule_type, priority, condition_json, effect_json)
WHERE p.code = 'NANNY_HOURLY'
  AND NOT EXISTS (
    SELECT 1 FROM pricing_rule r
    WHERE r.plan_id = p.plan_id AND r.rule_type = v.rule_type
      AND r.condition_json = v.condition_json::jsonb
  );
