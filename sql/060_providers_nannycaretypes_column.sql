-- Optional: types of nanny care (API field nannyCareType[] stored as comma-separated text).
ALTER TABLE serviceprovider
  ADD COLUMN IF NOT EXISTS nannycaretypes TEXT;
