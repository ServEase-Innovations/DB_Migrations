import { defineConfig } from "prisma/config";

function requireDatabaseUrl() {
  const url = process.env.DATABASE_URL?.trim();
  if (url) return url;

  const host = process.env.POSTGRES_HOST || "127.0.0.1";
  const port = process.env.POSTGRES_PORT || "5432";
  const user = process.env.POSTGRES_USER || "serveaso";
  const password = process.env.POSTGRES_PASSWORD || "";
  const database = (process.env.POSTGRES_DB || "").trim() || "serveaso";
  return `postgresql://${encodeURIComponent(user)}:${encodeURIComponent(password)}@${host}:${port}/${database}`;
}

const databaseUrl = requireDatabaseUrl();
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
