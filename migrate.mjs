/**
 * Serveaso DB_Migrations — single runner for shared Postgres DDL.
 *
 *   npm run migrate          # SQL + Prisma (manifest)
 *   npm run migrate:sql
 *   npm run migrate:prisma
 *   npm run migrate:tickets
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { spawnSync } from "child_process";
import pg from "pg";
import { createRequire } from "module";

const require = createRequire(import.meta.url);
const { loadMonorepoPostgresEnv, requirePostgresDatabaseName } = require("../scripts/postgres-env.cjs");

const MIGRATIONS_ROOT = path.dirname(fileURLToPath(import.meta.url));
const SQL_DIR = path.join(MIGRATIONS_ROOT, "sql");
const MANIFEST_PATH = path.join(MIGRATIONS_ROOT, "prisma", "services.manifest.json");
const SQL_DEPS_PATH = path.join(MIGRATIONS_ROOT, "sql-dependencies.json");

const MIGRATION_TABLE = "_serveaso_schema_migrations";

/** Resolve DB_Migrations root from monorepo (database/ submodule) or this repo. */
export function findMigrationsRoot(fromDir = process.cwd()) {
  let d = path.resolve(fromDir);
  while (d !== path.dirname(d)) {
    if (fs.existsSync(path.join(d, "migrate.mjs")) && fs.existsSync(path.join(d, "sql"))) {
      return d;
    }
    if (fs.existsSync(path.join(d, "database", "migrate.mjs"))) {
      return path.join(d, "database");
    }
    d = path.dirname(d);
  }
  return MIGRATIONS_ROOT;
}

/** @deprecated use findMigrationsRoot */
export function findRepoRoot(fromDir) {
  const root = findMigrationsRoot(fromDir);
  return fs.existsSync(path.join(root, "..", "services")) ? path.join(root, "..") : root;
}

function loadPgPool() {
  loadMonorepoPostgresEnv();
  const url = process.env.DATABASE_URL?.trim();
  if (url) {
    return new pg.Pool({ connectionString: url });
  }
  const database = requirePostgresDatabaseName();
  return new pg.Pool({
    host: process.env.POSTGRES_HOST || process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.POSTGRES_PORT || process.env.DB_PORT || 5432),
    user: process.env.POSTGRES_USER || process.env.DB_USER,
    password: process.env.POSTGRES_PASSWORD || process.env.DB_PASSWORD,
    database,
  });
}

export async function ensureMigrationTable(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS public.${MIGRATION_TABLE} (
      name VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

function loadSqlDependencies() {
  if (!fs.existsSync(SQL_DEPS_PATH)) {
    return { fileRequires: {}, sqlCreates: {}, prismaServices: {}, baseline: {} };
  }
  return JSON.parse(fs.readFileSync(SQL_DEPS_PATH, "utf8"));
}

export async function tableExists(pool, tableName) {
  const r = await pool.query(
    `SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = $1`,
    [tableName]
  );
  if (r.rows.length > 0) return true;
  const reg = await pool.query(`SELECT to_regclass($1) IS NOT NULL AS ok`, [
    `public.${tableName}`,
  ]);
  return reg.rows[0]?.ok === true;
}

async function columnExists(pool, tableName, columnName) {
  const r = await pool.query(
    `SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2`,
    [tableName, columnName]
  );
  if (r.rows.length > 0) return true;
  const pg = await pool.query(
    `SELECT 1
     FROM pg_attribute a
     JOIN pg_class c ON c.oid = a.attrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public' AND c.relname = $1
       AND a.attname = $2 AND a.attnum > 0 AND NOT a.attisdropped`,
    [tableName, columnName]
  );
  return pg.rows.length > 0;
}

export async function isSqlMigrationApplied(pool, file) {
  const { rows } = await pool.query(
    `SELECT 1 FROM public.${MIGRATION_TABLE} WHERE name = $1`,
    [file]
  );
  return rows.length > 0;
}

export async function listPendingSqlFiles(pool, sqlDir = SQL_DIR) {
  await ensureMigrationTable(pool);
  const files = fs.readdirSync(sqlDir).filter((f) => f.endsWith(".sql")).sort();
  const pending = [];
  for (const file of files) {
    if (!(await isSqlMigrationApplied(pool, file))) {
      pending.push(file);
    }
  }
  return pending;
}

async function applyOneSqlFile(pool, file, options = {}) {
  const sqlDir = options.sqlDir || SQL_DIR;
  const record = options.record !== false;
  const alreadyApplied = await isSqlMigrationApplied(pool, file);

  if (alreadyApplied && !options.repair) {
    return false;
  }

  const sql = fs.readFileSync(path.join(sqlDir, file), "utf8");
  const runsOutsideTxn = /CREATE\s+INDEX\s+CONCURRENTLY/i.test(sql);
  const client = await pool.connect();
  try {
    if (runsOutsideTxn) {
      await client.query(sql);
      if (record && !alreadyApplied) {
        await client.query(
          `INSERT INTO public.${MIGRATION_TABLE} (name) VALUES ($1)`,
          [file]
        );
      }
    } else {
      await client.query("BEGIN");
      await client.query(sql);
      if (record && !alreadyApplied) {
        await client.query(
          `INSERT INTO public.${MIGRATION_TABLE} (name) VALUES ($1)`,
          [file]
        );
      }
      await client.query("COMMIT");
    }
    console.log(`✅ ${file}${options.repair ? " (repair)" : ""}`);
    return true;
  } catch (err) {
    if (!runsOutsideTxn) {
      await client.query("ROLLBACK").catch(() => {});
    }
    throw new Error(`${file}: ${err.message}`);
  } finally {
    client.release();
  }
}

async function tablesMissing(pool, tableNames) {
  const missing = [];
  for (const t of tableNames) {
    if (!(await tableExists(pool, t))) {
      missing.push(t);
    }
  }
  return missing;
}

/** Coupons v2: UUID coupon_id on public.coupons + coupon_redemptions. */
async function couponsV2Ready(pool) {
  if (!(await tableExists(pool, "coupons"))) return false;
  if (!(await columnExists(pool, "coupons", "coupon_id"))) return false;
  return tableExists(pool, "coupon_redemptions");
}

async function recordMigrationOnly(pool, file) {
  if (await isSqlMigrationApplied(pool, file)) return;
  await pool.query(
    `INSERT INTO public.${MIGRATION_TABLE} (name) VALUES ($1) ON CONFLICT (name) DO NOTHING`,
    [file]
  );
  console.log(`✅ ${file} (recorded — schema already present)`);
}

async function ensureSqlPrereqFile(pool, prereqFile, sqlCreates) {
  const applied = await isSqlMigrationApplied(pool, prereqFile);

  if (prereqFile === "090_coupons_v2_schema.sql") {
    if (await couponsV2Ready(pool)) {
      if (!applied) await recordMigrationOnly(pool, prereqFile);
      return;
    }
    if (applied) {
      return;
    }
    const legacyCoupons =
      (await tableExists(pool, "coupons")) &&
      !(await columnExists(pool, "coupons", "coupon_id"));
    const label = legacyCoupons
      ? "legacy coupons → v2"
      : (await tablesMissing(pool, sqlCreates[prereqFile] || [])).join(", ") ||
        "repair";
    console.log(`▶ prerequisite SQL ${prereqFile} (${label}) …`);
    await applyOneSqlFile(pool, prereqFile, { repair: false });
    return;
  }

  const created = sqlCreates[prereqFile] || [];
  const missing = created.length ? await tablesMissing(pool, created) : [];

  if (missing.length === 0 && applied) {
    return;
  }
  if (missing.length === 0 && !applied) {
    await recordMigrationOnly(pool, prereqFile);
    return;
  }

  console.log(
    `▶ prerequisite SQL ${prereqFile}${missing.length ? ` (missing: ${missing.join(", ")})` : ""} …`
  );
  await applyOneSqlFile(pool, prereqFile, { repair: applied });
}

async function ensurePrismaServiceTables(pool, serviceName, prismaServices) {
  const spec = prismaServices[serviceName];
  if (!spec) {
    return;
  }
  const missing = await tablesMissing(pool, spec.tables || []);
  if (missing.length === 0) {
    return;
  }

  const manifest = loadPrismaManifest();
  const svc = (manifest.databases || [])
    .flatMap((db) => db.services || [])
    .find((s) => s.name === serviceName && s.migrate);

  if (!svc) {
    throw new Error(
      `Missing tables [${missing.join(", ")}] for ${serviceName} but Prisma migrate is disabled in services.manifest.json`
    );
  }

  console.log(`▶ prisma ${serviceName} (tables required: ${missing.join(", ")}) …`);
  await applyPrismaMigrations({ only: serviceName, pool });
}

/** Ensure baseline + SQL/Prisma prerequisites for all pending migrations. */
export async function ensureSqlDependencies(pool) {
  const deps = loadSqlDependencies();
  const pending = await listPendingSqlFiles(pool);
  if (pending.length === 0) {
    return;
  }

  const baselineTable = deps.baseline?.markerTable || "engagements";
  if (!(await tableExists(pool, baselineTable))) {
    throw new Error(
      `public.${baselineTable} is missing — run baseline first (payments schema.sql / npm run db:baseline)`
    );
  }

  const prereqSql = new Set();
  const prereqPrisma = new Set();

  for (const file of pending) {
    const req = deps.fileRequires?.[file];
    if (!req) continue;
    for (const s of req.ensureSql || []) {
      prereqSql.add(s);
    }
    for (const p of req.ensurePrisma || []) {
      prereqPrisma.add(p);
    }
  }

  for (const file of [...prereqSql].sort()) {
    await ensureSqlPrereqFile(pool, file, deps.sqlCreates || {});
  }
  for (const name of prereqPrisma) {
    await ensurePrismaServiceTables(pool, name, deps.prismaServices || {});
  }

  for (const file of pending) {
    const req = deps.fileRequires?.[file];
    if (!req) continue;

    for (const [table, column] of Object.entries(req.columnChecks || {})) {
      if (!(await tableExists(pool, table))) {
        throw new Error(`${file} requires public.${table} — prerequisite SQL did not create it`);
      }
      if (!(await columnExists(pool, table, column))) {
        throw new Error(
          `${file} requires public.${table}.${column} — run ${(req.ensureSql || []).find((f) => f.includes("090")) || "090_coupons_v2_schema.sql"}`
        );
      }
    }

    for (const table of req.tables || []) {
      if (req.columnChecks?.[table]) continue;
      if (!(await tableExists(pool, table))) {
        const hint = (req.ensureSql || []).concat(req.ensurePrisma || []).join(", ") || "baseline";
        throw new Error(`${file} requires public.${table} (expected from: ${hint})`);
      }
    }
  }
}

export async function applySqlMigrations(pool, options = {}) {
  const sqlDir = options.sqlDir || SQL_DIR;
  if (!fs.existsSync(sqlDir)) {
    throw new Error(`SQL migrations directory not found: ${sqlDir}`);
  }

  await ensureMigrationTable(pool);

  const files = fs.readdirSync(sqlDir).filter((f) => f.endsWith(".sql")).sort();
  const applied = [];
  const skipped = [];

  for (const file of files) {
    if (await isSqlMigrationApplied(pool, file)) {
      skipped.push(file);
      continue;
    }

    const didApply = await applyOneSqlFile(pool, file, { sqlDir });
    if (didApply) {
      applied.push(file);
    }
  }

  return { applied, skipped };
}

function loadPrismaManifest() {
  if (!fs.existsSync(MANIFEST_PATH)) return { databases: [] };
  return JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf8"));
}

function runPrisma(cwd, args, env) {
  const result = spawnSync("npx", ["prisma", ...args], {
    cwd,
    env,
    encoding: "utf8",
    shell: process.platform === "win32",
  });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.status !== 0) {
    const err = new Error(`prisma ${args.join(" ")} failed in ${cwd}`);
    err.stderr = result.stderr || "";
    err.stdout = result.stdout || "";
    throw err;
  }
}

function prismaOutputIncludes(err, code) {
  const text = `${err?.message || ""} ${err?.stderr || ""} ${err?.stdout || ""}`;
  return text.includes(code);
}

async function supportTicketTablesExist(pool) {
  const r = await pool.query(
    `SELECT 1 FROM information_schema.tables
     WHERE table_schema = 'public' AND table_name = 'support_tickets'`
  );
  return r.rows.length > 0;
}

async function ensureSupportTicketTables(pool, svc) {
  if (await supportTicketTablesExist(pool)) return;

  const migSql = path.join(
    MIGRATIONS_ROOT,
    svc.path,
    "migrations",
    svc.baselineMigration,
    "migration.sql"
  );
  if (!fs.existsSync(migSql)) {
    throw new Error(`Missing tickets migration SQL: ${migSql}`);
  }

  console.warn(
    `[tickets] Prisma history synced but tables missing — applying ${svc.baselineMigration} SQL…`
  );
  await pool.query(fs.readFileSync(migSql, "utf8"));
  console.log("[tickets] support_tickets tables created");
}


export function applyPrismaMigrationsForService(servicePath, env = process.env) {
  const cwd = path.isAbsolute(servicePath)
    ? servicePath
    : path.join(MIGRATIONS_ROOT, servicePath);

  runPrisma(cwd, ["migrate", "deploy"], env);
}

export async function applyPrismaMigrations(options = {}) {
  const manifest = loadPrismaManifest();
  const only = options.only;
  const pool = options.pool || loadPgPool();
  const env = {
    ...process.env,
    ...(options.databaseUrl ? { DATABASE_URL: options.databaseUrl } : {}),
  };
  const ran = [];

  try {
    for (const db of manifest.databases || []) {
      for (const svc of db.services || []) {
        if (!svc.migrate) {
          console.log(`⏭️  prisma/${svc.name} (skipped: ${svc.note || "disabled"})`);
          continue;
        }
        if (only && svc.name !== only) continue;

        const cwd = path.join(MIGRATIONS_ROOT, svc.path);
        console.log(`▶ prisma migrate deploy — ${svc.name} (${svc.path})`);

        // For tickets service, ensure tables exist BEFORE running migrations
        if (svc.name === "tickets" && svc.baselineMigration) {
          await ensureSupportTicketTables(pool, svc);
        }

        try {
          runPrisma(cwd, ["migrate", "deploy"], env);
        } catch (err) {
          if (!prismaOutputIncludes(err, "P3005") || !svc.baselineMigration) {
            throw err;
          }
          console.warn(
            `[${svc.name}] Database not empty; baselining ${svc.baselineMigration}…`
          );
          try {
            runPrisma(cwd, ["migrate", "resolve", "--applied", svc.baselineMigration], env);
          } catch (resolveErr) {
            if (!prismaOutputIncludes(resolveErr, "P3008")) {
              throw resolveErr;
            }
          }
          
          // After resolving baseline, ensure tables exist again
          if (svc.name === "tickets" && svc.baselineMigration) {
            await ensureSupportTicketTables(pool, svc);
          }
          
          runPrisma(cwd, ["migrate", "deploy"], env);
        }
        ran.push(svc.name);
      }
    }
  } finally {
    if (!options.pool) {
      await pool.end();
    }
  }

  return ran;
}

function runBaselineStep() {
  const script = path.join(MIGRATIONS_ROOT, "scripts", "apply-baseline.mjs");
  if (!fs.existsSync(script)) {
    throw new Error(`Baseline script not found: ${script}`);
  }
  console.log("▶ baseline (core schema from payments/schema.sql if needed) …");
  const result = spawnSync(process.execPath, [script], {
    cwd: MIGRATIONS_ROOT,
    env: process.env,
    stdio: "inherit",
  });
  if (result.status !== 0) {
    throw new Error("baseline failed — ensure services/payments submodule is checked out");
  }
}

async function main() {
  const cmd = process.argv[2] || "all";

  if (cmd === "sql" || cmd === "all") {
    runBaselineStep();
  }

  const pool = loadPgPool();

  try {
    if (cmd === "sql" || cmd === "all") {
      await ensureSqlDependencies(pool);
      const { applied, skipped } = await applySqlMigrations(pool);
      if (applied.length === 0 && skipped.length > 0) {
        console.log(`SQL: up to date (${skipped.length} already applied)`);
      } else if (applied.length === 0) {
        console.log("SQL: no migration files found");
      }
    }

    if (cmd === "prisma" || cmd === "all") {
      const only = process.argv[3];
      await applyPrismaMigrations({ only, pool });
    }

    if (!["sql", "prisma", "all"].includes(cmd)) {
      console.error("Usage: npm run migrate [sql|prisma|all] [serviceName]");
      process.exit(1);
    }
  } finally {
    await pool.end();
  }
}

const isMain =
  process.argv[1] &&
  path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));

if (isMain) {
  main().catch((err) => {
    console.error("❌ migration failed:", err.message);
    process.exit(1);
  });
}
