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

const MIGRATIONS_ROOT = path.dirname(fileURLToPath(import.meta.url));
const SQL_DIR = path.join(MIGRATIONS_ROOT, "sql");
const MANIFEST_PATH = path.join(MIGRATIONS_ROOT, "prisma", "services.manifest.json");

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
  const url = process.env.DATABASE_URL;
  if (url) {
    return new pg.Pool({ connectionString: url });
  }
  return new pg.Pool({
    host: process.env.POSTGRES_HOST || process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.POSTGRES_PORT || process.env.DB_PORT || 5432),
    user: process.env.POSTGRES_USER || process.env.DB_USER,
    password: process.env.POSTGRES_PASSWORD || process.env.DB_PASSWORD,
    database: process.env.POSTGRES_DB || process.env.DB_NAME || "serveaso",
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
    const { rows } = await pool.query(
      `SELECT 1 FROM public.${MIGRATION_TABLE} WHERE name = $1`,
      [file]
    );
    if (rows.length) {
      skipped.push(file);
      continue;
    }

    const sql = fs.readFileSync(path.join(sqlDir, file), "utf8");
    const runsOutsideTxn = /CREATE\s+INDEX\s+CONCURRENTLY/i.test(sql);
    const client = await pool.connect();
    try {
      if (runsOutsideTxn) {
        await client.query(sql);
        await client.query(
          `INSERT INTO public.${MIGRATION_TABLE} (name) VALUES ($1)`,
          [file]
        );
      } else {
        await client.query("BEGIN");
        await client.query(sql);
        await client.query(
          `INSERT INTO public.${MIGRATION_TABLE} (name) VALUES ($1)`,
          [file]
        );
        await client.query("COMMIT");
      }
      applied.push(file);
      console.log(`✅ ${file}`);
    } catch (err) {
      if (!runsOutsideTxn) {
        await client.query("ROLLBACK").catch(() => {});
      }
      throw new Error(`${file}: ${err.message}`);
    } finally {
      client.release();
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
          runPrisma(cwd, ["migrate", "deploy"], env);
        }

        if (svc.name === "tickets" && svc.baselineMigration) {
          await ensureSupportTicketTables(pool, svc);
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

async function main() {
  const cmd = process.argv[2] || "all";
  const pool = loadPgPool();

  try {
    if (cmd === "sql" || cmd === "all") {
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
