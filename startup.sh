#! /usr/bin/env bash

# Teardown all services
bash ./start-teardown.sh

# Start Valkey as our redis cache for Quay
bash ./start-cache.sh

# Start Postgres as our Quay and Clair database
bash ./start-db.sh

# Start Clair
bash ./start-clair.sh

# Start Quay
bash ./start-quay.sh