-- Many roles per provider (COOK, MAID, NANNY, ...). Run once per environment.
CREATE TABLE IF NOT EXISTS serviceprovider_roles (
  serviceproviderid BIGINT NOT NULL,
  role VARCHAR(32) NOT NULL,
  PRIMARY KEY (serviceproviderid, role),
  CONSTRAINT fk_spr_provider FOREIGN KEY (serviceproviderid)
    REFERENCES "serviceprovider"("serviceproviderid") ON DELETE CASCADE
);

INSERT INTO serviceprovider_roles (serviceproviderid, role)
SELECT serviceproviderid, TRIM(housekeepingrole::text)
FROM serviceprovider
WHERE housekeepingrole IS NOT NULL AND TRIM(housekeepingrole::text) <> ''
ON CONFLICT DO NOTHING;
