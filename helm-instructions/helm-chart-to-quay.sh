#!/usr/bin/env bash
set -euo pipefail

read -rp "Quay username: " QUAY_USER
read -srp "Quay password: " QUAY_PASS; echo

REG_HOST="quayregistry.localhost"   # your local Quay (HTTP)
CHART_NAME="demochart"

echo "Logging out of ${REG_HOST}..."
helm registry logout "${REG_HOST}" || true

echo "Logging in to ${REG_HOST} as ${QUAY_USER} (plain HTTP)..."
helm registry login "${REG_HOST}" --username "${QUAY_USER}" --password "${QUAY_PASS}" --plain-http

# workspace
WORKDIR="$(mktemp -d -t quay-helm-XXXX)"
pushd "${WORKDIR}" >/dev/null || exit 1
trap 'popd >/dev/null; rm -rf "${WORKDIR}"' EXIT

# make a tiny chart and package it
helm create "${CHART_NAME}" >/dev/null
VER="$(awk -F': *' '/^version:/{print $2; exit}' "${CHART_NAME}/Chart.yaml")"
helm package "${CHART_NAME}" >/dev/null   # -> demochart-${VER}.tgz

PKG="${CHART_NAME}-${VER}.tgz"
DEST="oci://${REG_HOST}/${QUAY_USER}"

# push to Quay via native OCI
echo "Pushing ${PKG} to ${DEST} ..."
helm push "${PKG}" "${DEST}" --plain-http

# verify by pulling back, then remove artifact
rm -f "${PKG}"
helm pull "oci://${REG_HOST}/${QUAY_USER}/${CHART_NAME}" --version "${VER}" --plain-http >/dev/null

echo "Done."
