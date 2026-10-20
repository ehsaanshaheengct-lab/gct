#!/usr/bin/env bash
# Local "Supabase-lite" for development and end-to-end tests WITHOUT Docker:
# PostgreSQL + the real Supabase Auth (GoTrue) + PostgREST + a small gateway (gateway.mjs).
# Same migrations and seed as Supabase Cloud. Not for production.
#
#   tool/local_supabase/start.sh          # reset the database and start everything
#   tool/local_supabase/start.sh stop     # stop the services
#
# Needs: PostgreSQL 15+ running locally, Node.js, and the release binaries in $SB_BIN (default /opt/sb):
#   postgrest  (github.com/PostgREST/postgrest/releases, linux-static-x64)
#   auth/auth + auth/migrations  (github.com/supabase/auth/releases, auth-<ver>-x86.tar.gz)
# Writes apps/office/env.local.json and apps/driver/env.local.json (git-ignored).
set -euo pipefail
export NO_PROXY=127.0.0.1,localhost no_proxy=127.0.0.1,localhost
cd "$(dirname "$0")/../.."
ROOT=$(pwd)
HERE=tool/local_supabase
BIN=${SB_BIN:-/opt/sb}
DB=${DB:-wasa_local}
DATA=$HERE/.data
JWT_SECRET=local-dev-jwt-secret-not-for-production-0123456789
mkdir -p "$DATA"

as_pg() { if [ "$(id -u)" = 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi; }
psql_file() { as_pg psql -X -q -v ON_ERROR_STOP=1 -d "$DB" < "$1"; }

stop() {
  for svc in gateway postgrest auth; do
    if [ -f "$DATA/$svc.pid" ]; then kill "$(cat "$DATA/$svc.pid")" 2>/dev/null || true; rm -f "$DATA/$svc.pid"; fi
  done
  # leftovers from an interrupted run
  pkill -f "$BIN/auth/auth serve" 2>/dev/null || true
  pkill -f "^$BIN/postgrest" 2>/dev/null || true
  pkill -f "node $HERE/gateway.mjs" 2>/dev/null || true
  sleep 1
}
stop
[ "${1:-}" = stop ] && { echo "stopped"; exit 0; }

echo "== database $DB"
as_pg dropdb --if-exists --force "$DB"
as_pg createdb "$DB"
sed "s/current_database_placeholder/$DB/" $HERE/bootstrap.sql > "$DATA/bootstrap.sql"
psql_file "$DATA/bootstrap.sql"

echo "== Supabase Auth migrations"
export GOTRUE_DB_DRIVER=postgres
export DATABASE_URL="postgres://supabase_auth_admin:local-auth-admin@127.0.0.1:5432/$DB?search_path=auth"
export GOTRUE_DB_MIGRATIONS_PATH=$BIN/auth/migrations
export API_EXTERNAL_URL=http://127.0.0.1:54321/auth/v1
export GOTRUE_SITE_URL=http://127.0.0.1:8088
export GOTRUE_JWT_SECRET=$JWT_SECRET GOTRUE_JWT_EXP=3600 GOTRUE_JWT_AUD=authenticated
export GOTRUE_JWT_DEFAULT_GROUP_NAME=authenticated GOTRUE_JWT_ADMIN_ROLES=service_role
export GOTRUE_DISABLE_SIGNUP=true GOTRUE_EXTERNAL_EMAIL_ENABLED=true GOTRUE_MAILER_AUTOCONFIRM=true
export GOTRUE_API_HOST=127.0.0.1 PORT=9999 GOTRUE_LOG_LEVEL=warn
"$BIN/auth/auth" migrate > "$DATA/auth-migrate.log" 2>&1 || { tail -20 "$DATA/auth-migrate.log"; exit 1; }

echo "== app migrations + seed"
for f in supabase/migrations/*.sql; do echo "   $(basename "$f")"; psql_file "$f"; done
psql_file supabase/seed.sql
rm -rf "$DATA/storage"

echo "== starting services"
nohup "$BIN/auth/auth" serve > "$DATA/auth.log" 2>&1 & echo $! > "$DATA/auth.pid"
PGRST_DB_URI="postgres://authenticator:local-authenticator@127.0.0.1:5432/$DB" \
PGRST_DB_SCHEMAS=public PGRST_DB_ANON_ROLE=anon PGRST_JWT_SECRET=$JWT_SECRET \
PGRST_DB_EXTRA_SEARCH_PATH=public,extensions PGRST_SERVER_PORT=3000 PGRST_LOG_LEVEL=warn \
  nohup "$BIN/postgrest" > "$DATA/postgrest.log" 2>&1 & echo $! > "$DATA/postgrest.pid"
STORAGE_DIR="$ROOT/$DATA/storage" nohup node $HERE/gateway.mjs > "$DATA/gateway.log" 2>&1 & echo $! > "$DATA/gateway.pid"

# legacy-style anon key: a JWT with role=anon signed with the local secret
ANON_KEY=$(node -e '
const c=require("crypto"),b=o=>Buffer.from(JSON.stringify(o)).toString("base64url");
const h=b({alg:"HS256",typ:"JWT"}),p=b({role:"anon",iss:"supabase-local",iat:1700000000,exp:2000000000});
console.log(h+"."+p+"."+c.createHmac("sha256",process.argv[1]).update(h+"."+p).digest("base64url"))' "$JWT_SECRET")
for app in office driver; do
  printf '{\n  "SUPABASE_URL": "http://127.0.0.1:54321",\n  "SUPABASE_ANON_KEY": "%s",\n  "LOGIN_DOMAIN": "wasabhakkar.demo"\n}\n' "$ANON_KEY" > apps/$app/env.local.json
done
echo "$ANON_KEY" > "$DATA/anon_key"

for i in $(seq 1 30); do
  if curl -sf -o /dev/null http://127.0.0.1:54321/auth/v1/health \
     && [ "$(curl -s -o /dev/null -w '%{http_code}' -H "apikey: $ANON_KEY" http://127.0.0.1:54321/rest/v1/tehsils)" = 401 ]; then
    echo "READY: http://127.0.0.1:54321  (apps/*/env.local.json written)"; exit 0
  fi
  sleep 1
done
echo "services did not start; see $DATA/*.log"; tail -5 "$DATA"/*.log; exit 1
