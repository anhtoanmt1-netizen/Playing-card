#!/usr/bin/env bash
# Chạy kiểm thử CSDL trên một Postgres CỤC BỘ (không phải Supabase thật).
# Dùng: PGHOST=... PGPORT=... PGUSER=postgres bash supabase/tests/run-db-tests.sh
set -euo pipefail
cd "$(dirname "$0")"
DB="wc_test_$$"
psql -v ON_ERROR_STOP=1 -qc "create database $DB" postgres
trap 'psql -qc "drop database if exists $DB with (force)" postgres >/dev/null' EXIT
export PGDATABASE=$DB
psql -v ON_ERROR_STOP=1 -q -f 00_supabase_stub.sql
for f in ../migrations/*.sql; do echo "-> migration $(basename "$f")"; psql -v ON_ERROR_STOP=1 -q -f "$f"; done
psql -v ON_ERROR_STOP=1 -q -f 10_foundation_tests.sql
bash ./20_concurrency_test.sh
