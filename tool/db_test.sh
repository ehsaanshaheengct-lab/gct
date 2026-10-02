#!/usr/bin/env bash
# Applies the Supabase migrations + seed to a throw-away local PostgreSQL database
# (with a small Supabase stand-in) and runs the SQL tests in supabase/tests/test_*.sql.
# Usage: tool/db_test.sh            (needs a local PostgreSQL 15+ server)
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-wasa_test}

run() {  # run psql as the postgres OS user when we are root
  if [ "$(id -u)" = 0 ]; then runuser -u postgres -- "$@"; else "$@"; fi
}
psql_file() { run psql -X -q -v ON_ERROR_STOP=1 -d "$DB" < "$1"; }

run dropdb --if-exists "$DB"
run createdb "$DB"
echo "== shim";       psql_file supabase/tests/shim.sql
for f in supabase/migrations/*.sql; do echo "== $(basename "$f")"; psql_file "$f"; done
echo "== seed.sql";   psql_file supabase/seed.sql
for f in supabase/tests/test_*.sql; do echo "== $(basename "$f")"; psql_file "$f"; done
echo "ALL DATABASE TESTS PASSED"
