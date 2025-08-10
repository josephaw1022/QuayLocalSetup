#!/usr/bin/env bash
set -euo pipefail

REG_HOST=quayregistry.localhost
REG_PORT=80
REG="${REG_HOST}:${REG_PORT}"
CONF_DIR=/etc/containers/registries.conf.d
CONF_FILE="${CONF_DIR}/quay-local.conf"

# require root
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

mkdir -p "$CONF_DIR"

# Write drop-in for Podman/containers-common (idempotent)
cat > "$CONF_FILE" <<EOF
# Mark local Quay as insecure (HTTP) so Podman won't try TLS:443
[[registry]]
location = "${REG}"
insecure = true
blocked = false
EOF

# Ensure /etc/hosts has a loopback for the hostname
grep -qE "^[^#]*[[:space:]]${REG_HOST}(\$|[[:space:]])" /etc/hosts \
  || echo "127.0.0.1 ${REG_HOST}" >> /etc/hosts

echo "Configured insecure registry: ${REG}"
echo "Now login with the port:"
echo
echo "  docker login ${REG} --tls-verify=false"
echo "  # or if you're using the docker wrapper:"
echo "  docker login ${REG}    # (podman-docker will honor the config)"
