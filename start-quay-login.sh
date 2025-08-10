#!/usr/bin/env bash
set -euo pipefail

REGISTRY="quayregistry.localhost"

# Prompt for credentials
read -rp "Quay Username: " USERNAME
read -rsp "Quay Password: " PASSWORD
echo

# Log in to Quay (skip TLS verification)
echo "$PASSWORD" | docker login "$REGISTRY" \
  --username "$USERNAME" \
  --password-stdin \
  --tls-verify=false

echo "✅ Logged into $REGISTRY as $USERNAME"
