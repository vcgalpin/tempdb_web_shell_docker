#!/usr/bin/env bash
set -euo pipefail

export OPAMSWITCH="${OPAMSWITCH:-5.1.1}"

export PGDATA=/opt/postgres-data
export PGPORT=5432
export PGSOCKETDIR=/tmp

POSTGRES_DB="${POSTGRES_DB:-linksdb}"
POSTGRES_USER="${POSTGRES_USER:-linksuser}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-change_me}"

APP_DIR=/opt/app
DUMP_FILE=/opt/app/sql/xps_dcc_app.sql

mkdir -p "${PGDATA}" "${PGSOCKETDIR}"

if [ ! -f "${DUMP_FILE}" ]; then
  echo "SQL dump not found: ${DUMP_FILE}"
  exit 1
fi

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
  echo "Initialising PostgreSQL data directory..."
  initdb -D "${PGDATA}" --encoding=UTF8 --locale=en_US.UTF-8
fi

echo "Starting PostgreSQL..."
pg_ctl -D "${PGDATA}" -l "${PGDATA}/postgres.log" -o "-p ${PGPORT} -k ${PGSOCKETDIR}" start

echo "Waiting for PostgreSQL..."
until pg_isready -h "${PGSOCKETDIR}" -p "${PGPORT}" >/dev/null 2>&1; do
  sleep 1
done

echo "PostgreSQL is ready."

ROLE_EXISTS=$(psql -h "${PGSOCKETDIR}" -p "${PGPORT}" -d postgres -tAc \
  "SELECT 1 FROM pg_roles WHERE rolname='${POSTGRES_USER}'" || true)

if [ "${ROLE_EXISTS}" != "1" ]; then
  echo "Creating role ${POSTGRES_USER}..."
  psql -h "${PGSOCKETDIR}" -p "${PGPORT}" -d postgres -v ON_ERROR_STOP=1 -c \
    "CREATE ROLE ${POSTGRES_USER} LOGIN PASSWORD '${POSTGRES_PASSWORD}';"
fi

DB_EXISTS=$(psql -h "${PGSOCKETDIR}" -p "${PGPORT}" -d postgres -tAc \
  "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" || true)

if [ "${DB_EXISTS}" != "1" ]; then
  echo "Creating database ${POSTGRES_DB}..."
  psql -h "${PGSOCKETDIR}" -p "${PGPORT}" -d postgres -v ON_ERROR_STOP=1 -c \
    "CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};"

  echo "Loading SQL dump..."
  psql -h "${PGSOCKETDIR}" -p "${PGPORT}" -d "${POSTGRES_DB}" -v ON_ERROR_STOP=1 -f "${DUMP_FILE}"
fi

export PGHOST="${PGSOCKETDIR}"
export PGDATABASE="${POSTGRES_DB}"
export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"

SHELL_RC=/tmp/tempdb_web_shell_rc

cat > "${SHELL_RC}" <<EOF
export OPAMSWITCH="${OPAMSWITCH}"
eval "\$(opam env --switch=${OPAMSWITCH})"
export PGHOST="${PGHOST}"
export PGDATABASE="${PGDATABASE}"
export PGUSER="${PGUSER}"
export PGPASSWORD="${PGPASSWORD}"
cd "${APP_DIR}"

echo
echo "tempdb_web_shell is ready."
echo
echo "Useful commands:"
echo "  Start the web app:"
echo "    linx --config=config.debug.0.9.8 src/startXPS.links"
echo
echo "  Start the Links REPL:"
echo "    linx"
echo
echo "  Connect to PostgreSQL:"
echo '    psql -h /tmp -p 5432 -d "\$POSTGRES_DB" -U "\$POSTGRES_USER"'
echo
echo "  Show current directory:"
echo "    pwd"
echo
echo "  Show repo status:"
echo "    git status"
echo
echo "  Show PostgreSQL tables:"
echo '    psql -h /tmp -p 5432 -d "\$POSTGRES_DB" -U "\$POSTGRES_USER" -c "\\dt"'
echo
EOF

echo
echo "Opening shell in ${APP_DIR} ..."
echo

exec bash --rcfile "${SHELL_RC}" -i

