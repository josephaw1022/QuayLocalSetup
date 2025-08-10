#! /usr/bin/env bash

# set to true if missing, or flip false->true
if ! grep -q '^SETUP_COMPLETE:' ./quay-config/config.yaml; then
  printf '\nSETUP_COMPLETE: true\n' >> ./quay-config/config.yaml
else
  sed -i 's/^SETUP_COMPLETE:.*/SETUP_COMPLETE: true/' ./quay-config/config.yaml
fi





# generate strong keys
DBKEY=$(openssl rand -hex 32)      # 64 hex chars
APPKEY=$(openssl rand -hex 32)     # 64 hex chars

# set/replace DATABASE_SECRET_KEY
if grep -q '^DATABASE_SECRET_KEY:' ./quay-config/config.yaml; then
  sed -i "s|^DATABASE_SECRET_KEY:.*|DATABASE_SECRET_KEY: \"$DBKEY\"|" ./quay-config/config.yaml
else
  printf '\nDATABASE_SECRET_KEY: "%s"\n' "$DBKEY" >> ./quay-config/config.yaml
fi

# set/replace SECRET_KEY (required for app signing)
if grep -q '^SECRET_KEY:' ./quay-config/config.yaml; then
  sed -i "s|^SECRET_KEY:.*|SECRET_KEY: \"$APPKEY\"|" ./quay-config/config.yaml
else
  printf 'SECRET_KEY: "%s"\n' "$APPKEY" >> ./quay-config/config.yaml
fi

# ensure setup is marked complete
if grep -q '^SETUP_COMPLETE:' ./quay-config/config.yaml; then
  sed -i 's|^SETUP_COMPLETE:.*|SETUP_COMPLETE: true|' ./quay-config/config.yaml
else
  printf 'SETUP_COMPLETE: true\n' >> ./quay-config/config.yaml
fi



