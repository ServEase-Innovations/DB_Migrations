import { createRequire } from "module";
import { defineConfig } from "prisma/config";

const require = createRequire(import.meta.url);
const { syncPostgresDbAliases, buildDatabaseUrl } = require("../../../scripts/postgres-env.cjs");

syncPostgresDbAliases(process.env);
const databaseUrl = buildDatabaseUrl(process.env);
process.env.DATABASE_URL = databaseUrl;

export default defineConfig({
  schema: "schema.prisma",
  migrations: {
    path: "migrations",
  },
  datasource: {
    url: databaseUrl,
  },
});
