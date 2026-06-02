# DB_Migrations

**Single source of truth** for Serveaso Postgres schema changes ([ServEase-Innovations/DB_Migrations](https://github.com/ServEase-Innovations/DB_Migrations)).

Microservices **do not** run DDL on startup. Apply migrations from CI or locally **before** deploying apps.

## Quick start

```bash
cd DB_Migrations   # or monorepo: cd database
cp .env.example .env   # edit DATABASE_URL
npm install
npm run setup          # fresh DB: baseline (payments schema.sql) + incremental migrations
npm run baseline       # first time only — full core tables from payments/schema.sql
npm run migrate        # SQL + Prisma (tickets)
```

### Environment

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | Preferred connection string |
| `POSTGRES_*` | Used when `DATABASE_URL` is unset |

## Layout

| Path | Purpose |
|------|---------|
| [`sql/`](sql/) | Ordered SQL patches → `_serveaso_schema_migrations` |
| [`prisma/tickets/`](prisma/tickets/) | Support ticket tables (`prisma migrate deploy`) |
| [`prisma/services.manifest.json`](prisma/services.manifest.json) | Which Prisma apps run on `serveaso` |
| [`migrate.mjs`](migrate.mjs) | Runner |

## Commands

```bash
npm run migrate          # all
npm run migrate:sql      # SQL only
npm run migrate:prisma   # Prisma per manifest
npm run migrate:tickets  # tickets Prisma only
```

## Rules

1. **All new DDL** goes in this repo — not in `payments` startup or `prisma db push` on shared DB.
2. **Never** `prisma db push` against production `serveaso`.
3. **Coupons** — add `prisma/coupons/` here when the schema is trimmed to promo tables only.
4. **Reviews** — separate database; not managed here unless added to the manifest.

## CI (example)

```yaml
- uses: actions/checkout@v4
  with:
    repository: ServEase-Innovations/DB_Migrations
- run: npm ci && npm run migrate
  env:
    DATABASE_URL: ${{ secrets.SERVEASO_DATABASE_URL }}
```

## Monorepo usage

Serveaso-BE includes this repo as the [`database/`](../database/) directory (submodule or copy). Root scripts:

```bash
npm run db:migrate
```

## Baseline reference

Greenfield / documentation snapshot (not applied by this runner):

`Serveaso-BE/services/payments/src/config/db/schema.sql`
