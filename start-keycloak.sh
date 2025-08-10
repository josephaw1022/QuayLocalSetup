#!/usr/bin/env bash
set -euo pipefail

# --- config ---
KC_NAME=keycloak
KC_IMAGE=quay.io/keycloak/keycloak:latest
KC_VOL=keycloak-data
KC_HOST=localhost
KC_PORT=8080                 # host port -> container 8080
KC_ADMIN=admin
KC_PASS=admin

REALM=quay
CLIENT_ID=quay
QUAY_HOST=quayregistry.localhost

command -v jq >/dev/null || { echo "jq is required"; exit 1; }

# --- fresh start: remove container + volume, then recreate volume ---
if docker ps -a --format '{{.Names}}' | grep -qx "$KC_NAME"; then
  echo "Stopping/removing $KC_NAME..."
  docker rm -f "$KC_NAME" >/dev/null || true
fi

if docker volume ls --format '{{.Name}}' | grep -qx "$KC_VOL"; then
  echo "Removing volume $KC_VOL..."
  docker volume rm -f "$KC_VOL" >/dev/null || true
fi

echo "Creating volume $KC_VOL..."
docker volume create "$KC_VOL" >/dev/null

echo "Starting Keycloak..."
docker run -d \
  --name "$KC_NAME" \
  --restart always \
  -p "${KC_PORT}:8080" \
  -v "$KC_VOL":/opt/keycloak/data:Z \
  -e KC_BOOTSTRAP_ADMIN_USERNAME="$KC_ADMIN" \
  -e KC_BOOTSTRAP_ADMIN_PASSWORD="$KC_PASS" \
  quay.io/keycloak/keycloak:26.3.2 start-dev >/dev/null

# --- wait for KC ---
echo -n "Waiting for Keycloak"
for i in {1..60}; do
  if curl -fs "http://${KC_HOST}:${KC_PORT}/realms/master" >/dev/null; then
    echo; break
  fi
  echo -n .
  sleep 2
done

# --- admin token ---
TOKEN_JSON=$(curl -s --fail \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${KC_ADMIN}" \
  -d "password=${KC_PASS}" \
  "http://${KC_HOST}:${KC_PORT}/realms/master/protocol/openid-connect/token")
ACCESS_TOKEN=$(echo "$TOKEN_JSON" | jq -r '.access_token')
[ -n "$ACCESS_TOKEN" ] || { echo "Failed to get admin token"; exit 1; }
authz() { echo "Authorization: Bearer ${ACCESS_TOKEN}"; }

# --- realm ---
echo "Creating realm '${REALM}'..."
curl -s -o /dev/null -w "%{http_code}" \
  -H "$(authz)" -H "Content-Type: application/json" \
  -d "{\"realm\":\"${REALM}\",\"enabled\":true}" \
  "http://${KC_HOST}:${KC_PORT}/admin/realms" | grep -Eq '^(201|409)$' || { echo "realm create failed"; exit 1; }

# --- client (confidential) ---
echo "Creating/updating client '${CLIENT_ID}'..."
CLIENTS=$(curl -s -H "$(authz)" "http://${KC_HOST}:${KC_PORT}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}")
CLIENT_UUID=$(echo "$CLIENTS" | jq -r '.[0].id // empty')

CREATE_PAYLOAD=$(cat <<JSON
{
  "clientId": "${CLIENT_ID}",
  "protocol": "openid-connect",
  "publicClient": false,
  "standardFlowEnabled": true,
  "redirectUris": [
    "http://${QUAY_HOST}/oauth2/keycloak/callback",
    "http://${QUAY_HOST}/oauth2/keycloak/callback/attach",
    "http://${QUAY_HOST}/oauth2/keycloak/callback/cli"
  ],
  "webOrigins": ["http://${QUAY_HOST}"],
  "attributes": { "pkce.code.challenge.method": "S256" }
}
JSON
)

if [ -z "$CLIENT_UUID" ]; then
  curl -s -o /dev/null -w "%{http_code}" \
    -H "$(authz)" -H "Content-Type: application/json" \
    -d "$CREATE_PAYLOAD" \
    "http://${KC_HOST}:${KC_PORT}/admin/realms/${REALM}/clients" | grep -Eq '^(201)$' || { echo "client create failed"; exit 1; }
  CLIENT_UUID=$(curl -s -H "$(authz)" "http://${KC_HOST}:${KC_PORT}/admin/realms/${REALM}/clients?clientId=${CLIENT_ID}" | jq -r '.[0].id')
else
  curl -s -o /dev/null -w "%{http_code}" \
    -X PUT -H "$(authz)" -H "Content-Type: application/json" \
    -d "$CREATE_PAYLOAD" \
    "http://${KC_HOST}:${KC_PORT}/admin/realms/${REALM}/clients/${CLIENT_UUID}" | grep -Eq '^(204)$' || { echo "client update failed"; exit 1; }
fi

# --- client secret ---
SECRET_JSON=$(curl -s -H "$(authz)" "http://${KC_HOST}:${KC_PORT}/admin/realms/${REALM}/clients/${CLIENT_UUID}/client-secret")
CLIENT_SECRET=$(echo "$SECRET_JSON" | jq -r '.value')
[ -n "$CLIENT_SECRET" ] || { echo "Failed to get client secret"; exit 1; }

cat <<EOF

=== Keycloak OIDC ready ===
Realm:          ${REALM}
Client ID:      ${CLIENT_ID}
Client Secret:  ${CLIENT_SECRET}
Issuer (OIDC):  http://${KC_HOST}:${KC_PORT}/realms/${REALM}/

Quay → Settings → Add OIDC Provider:
  Provider ID:   keycloak
  OIDC Server:   http://${KC_HOST}:${KC_PORT}/realms/${REALM}/
  Client ID:     ${CLIENT_ID}
  Client Secret: ${CLIENT_SECRET}
  Login Scopes:  openid email profile

Redirect URIs configured in Keycloak:
  http://${QUAY_HOST}/oauth2/keycloak/callback
  http://${QUAY_HOST}/oauth2/keycloak/callback/attach
  http://${QUAY_HOST}/oauth2/keycloak/callback/cli
EOF
