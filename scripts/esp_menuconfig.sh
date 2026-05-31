#!/usr/bin/env bash
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

PROJECT="${REPLICA_FIRMWARE_PROJECT:-lidar_publisher}"
FW_DIR="$REPLICA_ROOT/esp/Samples/microros_samples/$PROJECT"

# shellcheck source=esp_env.sh
source "$(dirname "$0")/lib/esp_env.sh"

cd "$FW_DIR"
exec idf.py menuconfig
