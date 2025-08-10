#!/usr/bin/env bash
set -euo pipefail

# ---------- Quay Postgres ----------
QUAY_CONT=quay-postgres
QUAY_VOL=quay-postgres-data
QUAY_USER=quayuser
QUAY_PASS=quaypass
QUAY_DB=quaydb
QUAY_PORT=5432
PG_IMAGE=docker.io/postgres:16

# Stop & remove Quay DB
if docker ps -a --format "{{.Names}}" | grep -q "^${QUAY_CONT}$"; then
  docker rm -f "${QUAY_CONT}" || true
fi
if docker volume ls --format "{{.Name}}" | grep -q "^${QUAY_VOL}$"; then
  docker volume rm -f "${QUAY_VOL}" || true
fi

docker run -d \
  --name "${QUAY_CONT}" \
  --restart always \
  -e POSTGRES_USER="${QUAY_USER}" \
  -e POSTGRES_PASSWORD="${QUAY_PASS}" \
  -e POSTGRES_DB="${QUAY_DB}" \
  -v "${QUAY_VOL}":/var/lib/postgresql/data:Z \
  -p ${QUAY_PORT}:5432 \
  --health-cmd="pg_isready -U \"${QUAY_USER}\" -d \"${QUAY_DB}\" -h localhost || exit 1" \
  --health-interval=5m \
  --health-retries=3 \
  --health-timeout=15s \
  --health-start-period=20s \
  "${PG_IMAGE}"

echo "Waiting for Quay Postgres on ${QUAY_PORT}..."
until docker exec "${QUAY_CONT}" pg_isready -U "${QUAY_USER}" -d "${QUAY_DB}" -h 127.0.0.1 >/dev/null 2>&1; do
  sleep 1
done

# Quay requires pg_trgm
docker exec "${QUAY_CONT}" psql -U "${QUAY_USER}" -d "${QUAY_DB}" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"

# ---------- Clair Postgres ----------
CLAIR_CONT=clair-postgres
CLAIR_VOL=clair-postgres-data
CLAIR_USER=clair
CLAIR_PASS=clairpass
CLAIR_DB=clair
CLAIR_PORT=5433

# Stop & remove Clair DB
if docker ps -a --format "{{.Names}}" | grep -q "^${CLAIR_CONT}$"; then
  docker rm -f "${CLAIR_CONT}" || true
fi
if docker volume ls --format "{{.Name}}" | grep -q "^${CLAIR_VOL}$"; then
  docker volume rm -f "${CLAIR_VOL}" || true
fi

docker run -d \
  --name "${CLAIR_CONT}" \
  --restart always \
  -e POSTGRES_USER="${CLAIR_USER}" \
  -e POSTGRES_PASSWORD="${CLAIR_PASS}" \
  -e POSTGRES_DB="${CLAIR_DB}" \
  -v "${CLAIR_VOL}":/var/lib/postgresql/data:Z \
  -p ${CLAIR_PORT}:5432 \
  --health-cmd="pg_isready -U \"${CLAIR_USER}\" -d \"${CLAIR_DB}\" -h localhost || exit 1" \
  --health-interval=5m \
  --health-retries=3 \
  --health-timeout=15s \
  --health-start-period=20s \
  "${PG_IMAGE}"

echo "Waiting for Clair Postgres on ${CLAIR_PORT}..."
until docker exec "${CLAIR_CONT}" pg_isready -U "${CLAIR_USER}" -d "${CLAIR_DB}" -h 127.0.0.1 >/dev/null 2>&1; do
  sleep 1
done

# ---------- Output connection info ----------
echo
echo "Quay DB:"
echo "  Host: localhost"
echo "  Port: ${QUAY_PORT}"
echo "  User: ${QUAY_USER}"
echo "  Pass: ${QUAY_PASS}"
echo "  DB:   ${QUAY_DB}"
echo "  DB_URI (Quay config.yaml): postgresql://${QUAY_USER}:${QUAY_PASS}@host.containers.internal/${QUAY_DB}"

echo
echo "Clair DB:"
echo "  Host: localhost"
echo "  Port: ${CLAIR_PORT}"
echo "  User: ${CLAIR_USER}"
echo "  Pass: ${CLAIR_PASS}"
echo "  DB:   ${CLAIR_DB}"
echo "  Conn (Clair config.yaml):  host=localhost port=${CLAIR_PORT} user=${CLAIR_USER} password=${CLAIR_PASS} dbname=${CLAIR_DB} sslmode=disable"

echo
echo "✅ Two separate Postgres containers are up."
