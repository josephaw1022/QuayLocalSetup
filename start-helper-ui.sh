#!/usr/bin/env bash

# 1) Create local folders
mkdir -p ./quay/config ./quay/storage

# 2) Run config UI with required password
podman run --rm -itd \
    --name quay-config-ui \
  -e CONFIG_APP_PASSWORD=admin123 \
  -p 8080:8080 \
  -v ./quay/config:/conf/stack:z \
  quay.io/projectquay/quay:latest config
