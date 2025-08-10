#!/usr/bin/env bash
set -euo pipefail

# Prompt for Quay credentials
read -rp "Quay Username: " DEST_USER
read -rsp "Quay Password: " DEST_PASS
echo

# Source (Docker Hub) and destination (your Quay)
SRC_REG="docker.io/library"
DEST_REG="quayregistry.localhost"   # your registry on port 80 (HTTP)
ORG="$DEST_USER"                    # org is your username
IMAGE="nginx"

# Variants to copy (one per OS family)
TAGS=(
  latest         # bookworm/mainline
  alpine         # alpine base
  alpine-slim    # alpine slim
  otel           # otel (bookworm)
  alpine-otel    # otel on alpine
  perl           # perl (bookworm)
  alpine-perl    # perl on alpine
)

copy_tag () {
  local tag="$1"
  local src="docker://${SRC_REG}/${IMAGE}:${tag}"
  local dst="docker://${DEST_REG}/${ORG}/${IMAGE}:${tag}"

  echo "➡️  Copying ${src}  →  ${dst}"
  skopeo copy --all \
    --src-tls-verify=false \
    --dest-tls-verify=false \
    --dest-creds "${DEST_USER}:${DEST_PASS}" \
    "${src}" "${dst}"
}

for tag in "${TAGS[@]}"; do
  copy_tag "$tag"
done

echo "✅ Finished copying nginx variants to ${DEST_REG}/${ORG}/${IMAGE}"
echo "   Pushed tags: ${TAGS[*]}"
