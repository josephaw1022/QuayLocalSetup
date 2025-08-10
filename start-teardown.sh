#!/usr/bin/env bash
set -euo pipefail

echo "Tearing down Quay stack..."

# Containers to remove
containers=(
  quay            # Quay registry
  clair           # Clair scanner
  quay-postgres   # Quay DB
  clair-postgres  # Clair DB
  quay-redis      # Redis/Valkey
  quay-config-ui  # Quay config UI
  keycloak        # Keycloak for authentication
)

# Volumes to remove
volumes=(
  quay-config
  quay-data
  clair-config
  clair-data
  quay-postgres-data
  clair-postgres-data
  quay-redis-data
  keycloak-data
)

# Stop and remove containers
for c in "${containers[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${c}$"; then
    echo "Stopping and removing container: $c"
    docker rm -f "$c"
  else
    echo "Container not found: $c"
  fi
done

# Remove volumes
for v in "${volumes[@]}"; do
  if docker volume ls --format '{{.Name}}' | grep -q "^${v}$"; then
    echo "Removing volume: $v"
    docker volume rm -f "$v"
  else
    echo "Volume not found: $v"
  fi
done

echo "Quay stack teardown complete."
