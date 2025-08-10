#!/usr/bin/env bash

DEST_REG="quayregistry.localhost"   # your local Quay (HTTP on 80)

# Get username for this registry from existing podman login
get_login() {
  local reg="$1"

  # Preferred: podman builtin
  if podman login --get-login --tls-verify=false "$reg" >/dev/null 2>&1; then
    podman login --get-login --tls-verify=false "$reg"
    return 0
  fi

  # Fallback: parse auth.json
  local authfile="${REGISTRY_AUTH_FILE:-}"
  if [[ -z "${authfile}" ]]; then
    for p in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/containers/auth.json "$HOME/.config/containers/auth.json"; do
      [[ -f "$p" ]] && authfile="$p" && break
    done
  fi
  [[ -z "${authfile}" || ! -f "${authfile}" ]] && return 1

  if command -v jq >/dev/null 2>&1; then
    local b64
    b64="$(jq -r --arg reg "$reg" '.auths[$reg].auth // empty' "$authfile")"
  else
    # lightweight parser if jq unavailable
    local b64
    b64="$(awk -v r="\"$reg\"" '
      $0 ~ r { inreg=1 }
      inreg && /"auth"[[:space:]]*:/ { gsub(/[",]/,""); print $2; exit }
    ' "$authfile")"
  fi
  [[ -z "${b64:-}" ]] && return 1
  printf '%s' "$b64" | base64 -d 2>/dev/null | cut -d: -f1
}

ORG="$(get_login "$DEST_REG" || true)"
if [[ -z "${ORG:-}" ]]; then
  echo "ERR: no cached login for ${DEST_REG}. Set ORG env or run your login script first." >&2
  exit 1
fi

# ---- What to copy (src | dest repo:tag) ----
IMAGES=(
  # .NET 9 (MCR)
  "mcr.microsoft.com/dotnet/sdk:9.0                  | dotnet-sdk:9.0"
  "mcr.microsoft.com/dotnet/sdk:9.0-alpine           | dotnet-sdk:9.0-alpine"
  "mcr.microsoft.com/dotnet/aspnet:9.0               | dotnet-aspnet:9.0"
  "mcr.microsoft.com/dotnet/aspnet:9.0-alpine        | dotnet-aspnet:9.0-alpine"
  "mcr.microsoft.com/dotnet/runtime:9.0              | dotnet-runtime:9.0"

  # .NET 8 extra tags
  "mcr.microsoft.com/dotnet/sdk:8.0-jammy            | dotnet-sdk:8.0-jammy"
  "mcr.microsoft.com/dotnet/sdk:8.0.413-noble        | dotnet-sdk:8.0.413-noble"
  "mcr.microsoft.com/dotnet/sdk:8.0.413-bookworm-slim| dotnet-sdk:8.0.413-bookworm-slim"

  # UBI .NET 8 (latest)
  "registry.access.redhat.com/ubi8/dotnet-80:latest  | dotnet-sdk:ubi8-8.0-latest"

  # Quarkus-friendly Java build/runtime (UBI minimal variants)
  "docker.io/library/eclipse-temurin:21-ubi9-minimal | eclipse-temurin:21-ubi9-minimal"
  "docker.io/library/eclipse-temurin:17-ubi9-minimal | eclipse-temurin:17-ubi9-minimal"
  "docker.io/library/maven:3-eclipse-temurin-21      | maven:3-jdk21"

  # Node.js dev + extra tags
  "docker.io/library/node:22                         | node:22"
  "docker.io/library/node:22-alpine                  | node:22-alpine"
  "docker.io/library/node:lts                        | node:lts"
  "docker.io/library/node:lts-alpine                 | node:lts-alpine"
  "docker.io/library/node:24.5-alpine                | node:24.5-alpine"
  "docker.io/library/node:24-bullseye                | node:24-bullseye"
  "docker.io/library/node:24-bullseye-slim           | node:24-bullseye-slim"
  "docker.io/library/node:24-bookworm                | node:24-bookworm"

  # UBI Node.js 22
  "registry.access.redhat.com/ubi9/nodejs-22:latest  | nodejs-ubi9-22:9.6"
)


copy_one() {
  local mapping="$1"
  local src_image="${mapping%%|*}"; src_image="$(echo "$src_image" | xargs)"
  local dst_image="${mapping#*|}";  dst_image="$(echo "$dst_image" | xargs)"

  local dst_repo_tag="${DEST_REG}/${ORG}/${dst_image}"
  local dst_ref="docker://${dst_repo_tag}"

  # Skip if already present on destination
  if podman manifest inspect --tls-verify=false "${dst_ref}" >/dev/null 2>&1; then
    echo "skip  ${dst_repo_tag}"
    return 0
  fi

  echo "pull  ${src_image}"
  podman pull --arch amd64 "${src_image}" >/dev/null

  echo "push  ${dst_repo_tag}"
  podman push --tls-verify=false "${src_image}" "${dst_ref}" >/dev/null
}

for m in "${IMAGES[@]}"; do
  copy_one "$m"
done

echo "done  ${DEST_REG}/${ORG}/"
