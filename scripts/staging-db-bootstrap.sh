#!/bin/sh
# Staging-only database bootstrap. NEVER run against production.
set -eu
export LC_ALL=C

# Explicit one-shot V3 PvP flag activation; staging database only.
# Do not enable in production or keep this switch permanently on.
if [ "${STAGING_ENABLE_V3_ONCE:-false}" = "true" ]; then
  if [ "${DB_NAME:-}" != "futbol_card_staging" ] || [ "${ENVIRONMENT:-}" != "production" ]; then
    echo "[STAGING V3] ABORT: invalid database/environment" >&2
    exit 1
  fi
  export PGHOST="${DB_HOST:?}" PGPORT="${DB_PORT:?}" PGDATABASE="${DB_NAME:?}" PGUSER="${DB_USER:?}"
  export PGPASSWORD="${DB_PASSWORD:?}" PGSSLMODE=require PGCONNECT_TIMEOUT=15
  echo "[STAGING V3] Enabling simultaneous PvP and level power, staging only"
  psql -X -v ON_ERROR_STOP=1 -q -f /app/staging-enable-v3.sql
  echo "[STAGING V3] Rule version verified; starting Dart API"
  exec /app/futbol-card-server
fi

if [ "${STAGING_DB_BOOTSTRAP:-false}" != "true" ]; then
  exec /app/futbol-card-server
fi

if [ "${DB_NAME:-}" != "futbol_card_staging" ] || [ "${ENVIRONMENT:-}" != "production" ]; then
  echo "[STAGING INIT] ABORT: requires DB_NAME=futbol_card_staging and ENVIRONMENT=production" >&2
  exit 1
fi

for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD JWT_SECRET; do
  case "$var" in
    DB_HOST) value="${DB_HOST:-}" ;;
    DB_PORT) value="${DB_PORT:-}" ;;
    DB_NAME) value="${DB_NAME:-}" ;;
    DB_USER) value="${DB_USER:-}" ;;
    DB_PASSWORD) value="${DB_PASSWORD:-}" ;;
    JWT_SECRET) value="${JWT_SECRET:-}" ;;
  esac
  if [ -z "$value" ]; then
    echo "[STAGING INIT] ABORT: missing $var" >&2
    exit 1
  fi
done

export PGHOST="$DB_HOST" PGPORT="$DB_PORT" PGDATABASE="$DB_NAME" PGUSER="$DB_USER"
export PGPASSWORD="$DB_PASSWORD" PGSSLMODE=require
export PGCONNECT_TIMEOUT=15
PSQL="psql -X -v ON_ERROR_STOP=1 -q"

echo "[STAGING INIT] Verifying isolated staging database..."
# Never initialize on top of an untracked, nonempty schema.
has_history=$(psql -X -v ON_ERROR_STOP=1 -tAc "SELECT CASE WHEN to_regclass('public.staging_schema_migrations') IS NULL THEN 'no' ELSE 'yes' END")
if [ "$has_history" = "no" ]; then
  tables=$(psql -X -v ON_ERROR_STOP=1 -tAc "SELECT COUNT(*) FROM pg_catalog.pg_tables WHERE schemaname='public'")
  if [ "$tables" != "0" ]; then
    echo "[STAGING INIT] ABORT: database has existing tables but no migration history" >&2
    exit 1
  fi
  $PSQL -c "CREATE TABLE public.staging_schema_migrations(filename text primary key, sha256 text not null, applied_at timestamptz not null default now())"
fi

count=0
for file in /app/migrations/[0-9][0-9][0-9]_*.sql; do
  [ -f "$file" ] || { echo "[STAGING INIT] ABORT: no migration files" >&2; exit 1; }
  name=$(basename "$file")
  hash=$(sha256sum "$file" | cut -d ' ' -f 1)
  previous=$(psql -X -v ON_ERROR_STOP=1 -tAc "SELECT sha256 FROM public.staging_schema_migrations WHERE filename='$name'")
  if [ -n "$previous" ]; then
    if [ "$previous" != "$hash" ]; then
      echo "[STAGING INIT] ABORT: migration modified after application: $name" >&2
      exit 1
    fi
  else
    echo "[STAGING INIT] Applying $name"
    # -1 wraps the SQL migration AND its history record in one transaction.
    psql -X -v ON_ERROR_STOP=1 -q -1 -f "$file" -c "INSERT INTO public.staging_schema_migrations(filename, sha256) VALUES ('$name', '$hash')"
  fi
  count=$((count+1))
done

# Migration numbering intentionally skips 020. Verify the latest expected
# migration is present and recorded, rather than assuming count == 044.
if [ "$count" -lt 43 ]; then
  echo "[STAGING INIT] ABORT: expected at least 43 migration files, saw $count" >&2
  exit 1
fi
psql -X -v ON_ERROR_STOP=1 -tAc "SELECT EXISTS (SELECT 1 FROM public.staging_schema_migrations WHERE filename='044_daily_loop.sql')::text" | grep -qx true || {
  echo "[STAGING INIT] ABORT: latest migration 044 not recorded" >&2
  exit 1
}

psql -X -v ON_ERROR_STOP=1 -tAc "SELECT (to_regprocedure('public.advance_simultaneous_matches()') IS NOT NULL AND to_regprocedure('public.sweep_timed_out_matches()') IS NOT NULL AND to_regclass('public.users') IS NOT NULL)::text" | grep -qx true || {
  echo "[STAGING INIT] ABORT: critical PvP schema/function missing" >&2
  exit 1
}
# Staging-only opt-in after migrations have been recorded and verified.
if [ "${STAGING_ADAPTIVE_MATCHMAKING:-false}" = "true" ]; then
  if [ "${DB_NAME:-}" != "futbol_card_staging" ] || [ "${ENVIRONMENT:-}" != "production" ]; then
    echo "[STAGING MATCHMAKING] ABORT: invalid isolated staging database" >&2
    exit 1
  fi
  psql -X -v ON_ERROR_STOP=1 -q -c "UPDATE matchmaking_settings SET mode='adaptive' WHERE id=1 AND mode <> 'adaptive'"
  psql -X -v ON_ERROR_STOP=1 -tAc "SELECT mode FROM matchmaking_settings WHERE id=1" | grep -qx adaptive || {
    echo "[STAGING MATCHMAKING] ABORT: adaptive mode not activated" >&2
    exit 1
  }
  echo "[STAGING MATCHMAKING] Adaptive mode enabled (staging only)"
fi

echo "[STAGING INIT] Schema ready: $count migrations verified. Starting Dart API."
exec /app/futbol-card-server
