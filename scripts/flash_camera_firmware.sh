#!/usr/bin/env bash
# Build and flash camera-only profile for Yahboom ROS-WiFi camera module.
# Publishes /espRos/esp32camera (sensor_msgs/CompressedImage).
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

FW_DIR="$REPLICA_ROOT/esp/Samples/microros_samples/lidar_publisher"
PORT="${ESP_SERIAL_PORT:-/dev/ttyUSB0}"

# shellcheck source=esp_env.sh
source "$(dirname "$0")/lib/esp_env.sh"
if [ -z "${IDF_PATH:-}" ]; then
  echo "ERROR: ESP-IDF not found in replica/esp/esp-idf"
  exit 1
fi

echo "Project: $FW_DIR (camera-only profile)"
echo "Serial:  $PORT"
echo "Topic:   /espRos/esp32camera"
echo ""
echo "NOTE: Flash this onto the Yahboom WiFi CAMERA module, not the main drive ESP."
echo "      Drive board GPIO conflicts with camera DVP pins."
echo ""

if [ "${SKIP_BOARD_CHECK:-}" != "1" ] && [ -x "$REPLICA_SCRIPTS/identify_esp_port.sh" ]; then
  BOARD_INFO="$("$REPLICA_SCRIPTS/identify_esp_port.sh" "$PORT" 2>/dev/null || true)"
  echo "$BOARD_INFO"
  BOARD_TYPE="$(echo "$BOARD_INFO" | awk -F= '/^BOARD=/{print $2}')"
  if [ "$BOARD_TYPE" = "DRIVE_BOARD" ]; then
    echo ""
    echo "ERROR: $PORT is the DRIVE board — refusing to flash camera firmware."
    echo "  Unplug USB from the drive board and connect it to the WiFi CAMERA module (lens board)."
    echo "  Then re-run: ./scripts/setup_camera_module.sh"
    exit 1
  fi
  if [ "$BOARD_TYPE" = "UNKNOWN" ]; then
    echo ""
    echo "WARN: Cannot confirm camera module on $PORT (identify=UNKNOWN)."
    echo "      Yahboom stock camera on CH340 often shows UNKNOWN — proceeding in 3s."
    echo "      If this is the DRIVE board, Ctrl+C now."
    sleep 3
  fi
fi

CAMERA_ARTIFACT_DIR="$FW_DIR/firmware-artifacts/camera"

build_camera_profile() {
  export ROVER_CAMERA_BUILD=1
  export SDKCONFIG_DEFAULTS="sdkconfig.defaults;sdkconfig.defaults.camera"
  if [ -f app-colcon.meta.camera ]; then
    cp app-colcon.meta app-colcon.meta.drive.bak 2>/dev/null || true
    cp app-colcon.meta.camera app-colcon.meta
  fi
  if [ "${FORCE_REBUILD:-}" = "1" ] || ! grep -q '^CONFIG_ROVER_CAMERA_ONLY=y' sdkconfig 2>/dev/null; then
    echo "Building camera profile (full configure)..."
    rm -f sdkconfig sdkconfig.old
    idf.py set-target esp32s3
    idf.py fullclean
    idf.py build
  else
    echo "Building camera profile (incremental)..."
    idf.py build
  fi
  if [ -f app-colcon.meta.drive.bak ]; then
    mv app-colcon.meta.drive.bak app-colcon.meta
  fi
  unset ROVER_CAMERA_BUILD
  mkdir -p "$CAMERA_ARTIFACT_DIR"
  cp build/main.bin build/bootloader/bootloader.bin build/partition_table/partition-table.bin "$CAMERA_ARTIFACT_DIR/"
  echo "Stashed camera binaries in $CAMERA_ARTIFACT_DIR"
}

echo ""
echo "Bootloader entry (this module has NO boot button):"
echo "  Option A — add 2 wires from CH340 (one-time, then auto-flash forever):"
echo "    CH340 DTR → ESP32 GPIO0    CH340 RTS → ESP EN (reset)"
echo "  Option B — strap GPIO0 to GND with tweezers/jumper during power-on:"
echo "    1. Touch GPIO0 to GND  2. Cycle 5V power  3. Release GPIO0  4. flash runs"
echo "  See: https://docs.espressif.com/projects/esptool/en/latest/esp32s3/esptool/entering-bootloader.html"
echo ""

flash_camera_artifacts() {
  PY="${IDF_PYTHON:-python3}"
  ESPTOOL="$(find "$IDF_PATH/components/esptool_py" -name esptool.py | head -1)"
  if ! "$PY" "$ESPTOOL" --chip esp32s3 -p "$PORT" -b 460800 \
    --before=default_reset --after=hard_reset write_flash \
    --flash_mode dio --flash_size 2MB --flash_freq 80m \
    0x0 "$CAMERA_ARTIFACT_DIR/bootloader.bin" \
    0x8000 "$CAMERA_ARTIFACT_DIR/partition-table.bin" \
    0x10000 "$CAMERA_ARTIFACT_DIR/main.bin"; then
    echo ""
    echo "Flash failed — chip is still running Yahboom app firmware, not bootloader."
    echo "CH340 TX/RX alone cannot enter download mode. Use Option A or B above, then re-run."
    exit 1
  fi
}

cd "$FW_DIR"

if [ -f "$CAMERA_ARTIFACT_DIR/main.bin" ] && [ "${FORCE_REBUILD:-}" != "1" ]; then
  echo "Using stashed camera firmware in $CAMERA_ARTIFACT_DIR"
else
  build_camera_profile
fi
flash_camera_artifacts

echo ""
echo "Done. Start agent, then on PC:"
echo "  source ros/yahboomcar_ws/install/setup.bash"
echo "  ros2 run yahboom_esp32_camera sub_img"
