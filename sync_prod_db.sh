#!/bin/bash
# Refresh the local development database from a production snapshot.
#
# One way, always. Production is read with pg_dump and is never written to;
# the only thing this script writes is the local database. Local edits are
# expected to be discarded by the next run - that is the point of having it.
# Run it whenever the local catalog has drifted from what is live.
#
#   ./sync_prod_db.sh          refresh, asking before dropping the local DB
#   ./sync_prod_db.sh -y       refresh without asking
#   ./sync_prod_db.sh --dump-only   take a snapshot, restore nothing
#
# The production credential is read from the running app's environment at
# call time and never written to disk or into this file.

set -euo pipefail

APP="${FLY_APP:-lumenviae}"
DB_APP="${FLY_DB_APP:-lumenviae-db}"
PROXY_PORT="${PROXY_PORT:-15432}"

LOCAL_HOST="${LOCAL_HOST:-localhost}"
LOCAL_USER="${LOCAL_USER:-postgres}"
LOCAL_PASSWORD="${LOCAL_PASSWORD:-postgres}"
LOCAL_DB="${LOCAL_DB:-lumen_viae_dev}"

SNAPSHOT_DIR="priv/repo/snapshots"
SNAPSHOT="$SNAPSHOT_DIR/prod-$(date +%Y%m%d-%H%M%S).sql"

# Production runs a newer Postgres than the local server, and pg_dump refuses
# to dump a server newer than itself. Homebrew's keg-only libpq carries an
# up-to-date client, so prefer it and fall back to whatever is on PATH.
# The dump is plain SQL rather than the custom format so a newer dump can be
# replayed into the older local server.
LIBPQ_BIN="/opt/homebrew/opt/libpq/bin"
if [[ -x "$LIBPQ_BIN/pg_dump" ]]; then
  PG_DUMP="$LIBPQ_BIN/pg_dump"
  PSQL="$LIBPQ_BIN/psql"
  CREATEDB="$LIBPQ_BIN/createdb"
  DROPDB="$LIBPQ_BIN/dropdb"
else
  PG_DUMP="pg_dump"
  PSQL="psql"
  CREATEDB="createdb"
  DROPDB="dropdb"
fi

ASSUME_YES=0
DUMP_ONLY=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --dump-only) DUMP_ONLY=1 ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# The restore target must be a local database. A mistyped or inherited
# LOCAL_HOST cannot be allowed to point the drop-and-restore at anything
# reachable over the network.
case "$LOCAL_HOST" in
  localhost|127.0.0.1|::1) ;;
  *)
    echo "Refusing to run: LOCAL_HOST is '$LOCAL_HOST', which is not local." >&2
    echo "This script only ever restores into a database on this machine." >&2
    exit 1
    ;;
esac

cleanup() {
  if [[ -n "${PROXY_PID:-}" ]] && kill -0 "$PROXY_PID" 2>/dev/null; then
    kill "$PROXY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "Reading the production connection from $APP..."
DB_URL="$(fly ssh console --app "$APP" -C "printenv DATABASE_URL" 2>/dev/null | tr -d '\r' | grep '^postgres://' | tail -1)"

if [[ -z "$DB_URL" ]]; then
  echo "Could not read DATABASE_URL from $APP. Is 'fly' authenticated?" >&2
  exit 1
fi

# postgres://user:pass@host:port/dbname?params
without_scheme="${DB_URL#postgres://}"
credentials="${without_scheme%%@*}"
after_at="${without_scheme#*@}"
REMOTE_USER="${credentials%%:*}"
REMOTE_PASSWORD="${credentials#*:}"
host_and_path="${after_at%%\?*}"
REMOTE_DB="${host_and_path##*/}"

echo "Opening a proxy to $DB_APP on port $PROXY_PORT..."
fly proxy "$PROXY_PORT:5432" --app "$DB_APP" >/dev/null 2>&1 &
PROXY_PID=$!

for _ in $(seq 1 30); do
  if nc -z 127.0.0.1 "$PROXY_PORT" 2>/dev/null; then break; fi
  sleep 0.5
done

if ! nc -z 127.0.0.1 "$PROXY_PORT" 2>/dev/null; then
  echo "The proxy to $DB_APP never came up on port $PROXY_PORT." >&2
  exit 1
fi

mkdir -p "$SNAPSHOT_DIR"

echo "Dumping $REMOTE_DB (read only)..."
PGPASSWORD="$REMOTE_PASSWORD" "$PG_DUMP" \
  --host=127.0.0.1 \
  --port="$PROXY_PORT" \
  --username="$REMOTE_USER" \
  --dbname="$REMOTE_DB" \
  --format=plain \
  --no-owner \
  --no-privileges \
  --file="$SNAPSHOT"

echo "Snapshot written: $SNAPSHOT ($(du -h "$SNAPSHOT" | cut -f1))"
cleanup

if [[ "$DUMP_ONLY" == "1" ]]; then
  echo "Dump only, nothing restored."
  exit 0
fi

if [[ "$ASSUME_YES" != "1" ]]; then
  echo
  echo "About to DROP and recreate '$LOCAL_DB' on $LOCAL_HOST."
  echo "Anything currently in the local database is lost."
  read -r -p "Continue? [y/N] " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]] || { echo "Stopped."; exit 0; }
fi

export PGPASSWORD="$LOCAL_PASSWORD"

echo "Recreating $LOCAL_DB..."
"$DROPDB" --host="$LOCAL_HOST" --username="$LOCAL_USER" --if-exists "$LOCAL_DB"
"$CREATEDB" --host="$LOCAL_HOST" --username="$LOCAL_USER" "$LOCAL_DB"

# A modern pg_dump emits session settings the older local server has never
# heard of, and an unknown SET aborts the restore. transaction_timeout
# arrived in Postgres 17; drop it rather than relaxing ON_ERROR_STOP, so a
# genuine failure still stops the restore.
sed -i '' '/^SET transaction_timeout = /d' "$SNAPSHOT"

echo "Restoring..."
"$PSQL" \
  --host="$LOCAL_HOST" \
  --username="$LOCAL_USER" \
  --dbname="$LOCAL_DB" \
  --quiet \
  --set=ON_ERROR_STOP=1 \
  --file="$SNAPSHOT" >/dev/null

echo
echo "Done. '$LOCAL_DB' now matches production as of $(date '+%Y-%m-%d %H:%M')."
echo "Edits made locally stay local; nothing in this script writes to production."
