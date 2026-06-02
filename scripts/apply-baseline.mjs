/**
 * One-time baseline for an empty `serveaso` database.
 * Applies services/payments/src/config/db/schema.sql then records it in
 * _serveaso_schema_migrations so npm run db:migrate can apply incremental SQL + Prisma.
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import pg from "pg";
import { findMigrationsRoot, ensureMigrationTable } from "../migrate.mjs";

const BASELINE_NAME = "000_baseline_payments_schema.sql";
const __dirname = path.dirname(fileURLToPath(import.meta.url));

function findSchemaPath() {
  const root = findMigrationsRoot(path.join(__dirname, ".."));
  const monorepoRoot = fs.existsSync(path.join(root, "..", "services", "payments"))
    ? path.join(root, "..")
    : root;
  const schemaPath = path.join(
    monorepoRoot,
    "services",
    "payments",
    "src",
    "config",
    "db",
    "schema.sql"
  );
  if (!fs.existsSync(schemaPath)) {
    throw new Error(`Baseline schema not found: ${schemaPath}`);
  }
  return schemaPath;
}

function loadPool() {
  const url = process.env.DATABASE_URL;
  if (url) return new pg.Pool({ connectionString: url });
  return new pg.Pool({
    host: process.env.POSTGRES_HOST || "127.0.0.1",
    port: Number(process.env.POSTGRES_PORT || 5432),
    user: process.env.POSTGRES_USER || "serveaso",
    password: process.env.POSTGRES_PASSWORD || "serveaso",
    database: process.env.POSTGRES_DB || "serveaso",
  });
}

async function main() {
  const pool = loadPool();
  const schemaPath = findSchemaPath();
  const sql = fs.readFileSync(schemaPath, "utf8");

  try {
    await ensureMigrationTable(pool);
    const { rows: core } = await pool.query(
      `SELECT EXISTS (
         SELECT 1 FROM information_schema.tables
         WHERE table_schema = 'public' AND table_name = 'engagements'
       ) AS has_engagements`
    );
    if (core[0].has_engagements) {
      await pool.query(
        `INSERT INTO public._serveaso_schema_migrations (name) VALUES ($1) ON CONFLICT DO NOTHING`,
        [BASELINE_NAME]
      );
      console.log("Core schema present — skipping baseline apply");
      return;
    }

    const { rows } = await pool.query(
      `SELECT 1 FROM public._serveaso_schema_migrations WHERE name = $1`,
      [BASELINE_NAME]
    );
    if (rows.length) {
      console.log(`Baseline flag set but engagements missing — re-applying (${BASELINE_NAME})`);
    } else {
      console.log(`Applying baseline from ${schemaPath} …`);
    }
    await pool.query(`
      CREATE SEQUENCE IF NOT EXISTS wallets_wallet_id_seq;
      CREATE SEQUENCE IF NOT EXISTS wallet_transactions_transaction_id_seq;
    `);
    await pool.query(sql);
    await pool.query(
      `INSERT INTO public._serveaso_schema_migrations (name) VALUES ($1)`,
      [BASELINE_NAME]
    );
    console.log("✅ Baseline schema applied");
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  console.error("❌ Baseline failed:", err.message);
  process.exit(1);
});
