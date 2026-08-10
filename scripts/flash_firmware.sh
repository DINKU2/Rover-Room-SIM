#!/usr/bin/env bash
# Build and flash lidar_publisher (lidar + odom + cmd_vel) from bundled esp/ tree.
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

PROJECT="${REPLICA_FIRMWARE_PROJECT:-lidar_publisher}"
FW_DIR="$REPLICA_ROOT/esp/Samples/microros_samples/$PROJECT"
PORT="${ESP_SERIAL_PORT:-/dev/ttyUSB0}"

# shellcheck source=esp_env.sh
source "$(dirname "$0")/lib/esp_env.sh"
if [ -z "${IDF_PATH:-}" ]; then
  echo "ERROR: ESP-IDF not found in replica/esp/esp-idf"
  exit 1
fi

if [ ! -d "$FW_DIR" ]; then
  echo "ERROR: firmware project missing: $FW_DIR"
  exit 1
fi

echo "Project: $FW_DIR"
echo "Serial:  $PORT"
echo "Agent IP in sdkconfig should match config/env MICRO_ROS_AGENT_IP"
echo ""

cd "$FW_DIR"
if [ -f build/CMakeCache.txt ] && grep -q 'replica-done/replica/' build/CMakeCache.txt 2>/dev/null; then
  echo "Stale build path detected — running idf.py fullclean"
  idf.py fullclean
fi
DRIVE_SDK="$FW_DIR/sdkconfig.drive.bak"
if [ -f "$DRIVE_SDK" ]; then
  echo "Restoring drive-board sdkconfig from sdkconfig.drive.bak"
  cp "$DRIVE_SDK" sdkconfig
fi
"$REPLICA_ROOT/scripts/sync_firmware_config.sh"
echo "Disabling camera profile in sdkconfig (drive board only)..."
sed -i 's/^CONFIG_ROVER_ENABLE_CAMERA=y$/# CONFIG_ROVER_ENABLE_CAMERA is not set/' sdkconfig 2>/dev/null || true
sed -i 's/^CONFIG_ROVER_CAMERA_ONLY=y$/# CONFIG_ROVER_CAMERA_ONLY is not set/' sdkconfig 2>/dev/null || true
echo "Running idf.py fullclean (sdkconfig timing changed — rebuild micro-ROS + app)..."
idf.py fullclean
idf.py build
idf.py -p "$PORT" flash
echo "Done. Power-cycle robot if needed; start ./scripts/start_agent.sh"
