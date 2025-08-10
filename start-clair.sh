#!/usr/bin/env bash
set -euo pipefail

PG_CONT=quay-postgres
PG_SUPER=quayuser
CLAIR_DB=clair
CLAIR_USER=clair
CLAIR_PASS='clairpass'
CLAIR_PORT=6060
CLAIR_CONT=clair
CLAIR_IMAGE=quay.io/projectquay/clair:4.7.2
CLAIR_DIR=./clair-config

# ----- start Clair (host net as before) -----
docker rm -f "$CLAIR_CONT" >/dev/null 2>&1 || true

docker run -d \
  --name "$CLAIR_CONT" \
  --restart always \
  --network host \
  -v "${CLAIR_DIR}:/config:Z" \
  -e CLAIR_CONF=/config/config.yaml \
  -e CLAIR_MODE=combo \
  "$CLAIR_IMAGE"

sleep 2
docker logs --tail=80 "$CLAIR_CONT" || true

