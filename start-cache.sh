#!/usr/bin/env bash

CONTAINER_NAME=quay-redis
VOLUME_NAME=quay-redis-data

# Stop and remove container if it exists
if podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping and removing existing container: ${CONTAINER_NAME}"
    podman stop "${CONTAINER_NAME}"
    podman rm -f "${CONTAINER_NAME}"
fi

# Remove old volume if it exists
if podman volume ls --format "{{.Name}}" | grep -q "^${VOLUME_NAME}$"; then
    echo "Removing old volume: ${VOLUME_NAME}"
    podman volume rm -f "${VOLUME_NAME}"
fi

# Create new Valkey container
echo "Creating fresh Valkey container..."
podman run -d \
  --name "${CONTAINER_NAME}" \
  --restart always \
  -v "${VOLUME_NAME}":/data:Z \
  -p 6379:6379 \
  --health-cmd='valkey-cli ping | grep -q PONG' \
  --health-interval=30s \
  --health-retries=3 \
  --health-timeout=5s \
  docker.io/valkey/valkey:8.1.3 \
  valkey-server --appendonly yes


echo "Valkey is running."
echo "Connection info:"
echo "  Host: quay-redis"
echo "  Port: 6379"
echo "  Password: (none)"
