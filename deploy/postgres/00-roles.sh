#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v library_password="$LIBRARY_PASSWORD" \
  -v reservation_password="$RESERVATION_PASSWORD" \
  -v rating_password="$RATING_PASSWORD" <<'SQL'
CREATE ROLE library_app LOGIN PASSWORD :'library_password';
CREATE ROLE reservation_app LOGIN PASSWORD :'reservation_password';
CREATE ROLE rating_app LOGIN PASSWORD :'rating_password';
SQL
