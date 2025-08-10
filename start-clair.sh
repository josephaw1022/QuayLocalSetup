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

PSK="87434f1ee095c448b241c4379ea0047396904f5da42c14bdef606b47869a7961"

mkdir -p "$CLAIR_DIR"

# --- slimmer Clair config (reduced updaters + 30m update cadence) ---
cat > "${CLAIR_DIR}/config.yaml" <<EOF
log_level: info
introspection_addr: ""
http_listen_addr: ":${CLAIR_PORT}"

indexer:
  connstring: "host=host.containers.internal port=5433 user=${CLAIR_USER} password=${CLAIR_PASS} dbname=${CLAIR_DB} sslmode=disable"
  migrations: true
  # keep these conservative so startup isn't noisy
  scanlock_retry: 10
  layer_scan_concurrency: 2
  airgap: false

matcher:
  connstring: "host=host.containers.internal port=5433 user=${CLAIR_USER} password=${CLAIR_PASS} dbname=${CLAIR_DB} sslmode=disable"
  migrations: true



notifier:
  connstring: "host=host.containers.internal port=5433 user=${CLAIR_USER} password=${CLAIR_PASS} dbname=${CLAIR_DB} sslmode=disable"
  migrations: true
  poll_interval: "15s"
  delivery_interval: "5s"
  webhook:
    target: "http://host.containers.internal:8080/secscan/notification"
    callback: "http://localhost:${CLAIR_PORT}/notifier/api/v1/notification"

auth:
  psk:
    key: "${PSK}"
    iss: ["quay"]

metrics:
  name: "prometheus"
EOF

# ----- start Clair (host net as before) -----
podman rm -f "$CLAIR_CONT" >/dev/null 2>&1 || true

podman run -d \
  --name "$CLAIR_CONT" \
  --restart always \
  --network host \
  -v "${CLAIR_DIR}:/config:Z" \
  -e CLAIR_CONF=/config/config.yaml \
  -e CLAIR_MODE=combo \
  "$CLAIR_IMAGE"

sleep 2
podman logs --tail=80 "$CLAIR_CONT" || true

