#!/usr/bin/env bash
# Wait for Yahboom WiFi camera module on USB, identify it, flash camera firmware.
# The drive board must NOT be flashed with the camera profile (GPIO conflict).
#
# Usage:
#   1. Unplug USB from the main drive board (robot can stay on battery).
#   2. Plug USB into the small camera board (the one with the lens).
#   3. ./scripts/setup_camera_module.sh
#
# Optional: ESP_SERIAL_PORT=/dev/ttyUSB0 WAIT_SECS=180 ./scripts/setup_camera_module.sh
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

WAIT_SECS="${WAIT_SECS:-180}"
PORT="${ESP_SERIAL_PORT:-}"

identify() {
  local p="$1"
  "$REPLICA_SCRIPTS/identify_esp_port.sh" "$p" 2>/dev/null || true
}

wait_for_port() {
  local deadline=$((SECONDS + WAIT_SECS))
  while [ "$SECONDS" -lt "$deadline" ]; do
    for p in /dev/ttyUSB* /dev/ttyACM*; do
      [ -e "$p" ] || continue
      echo "$p"
      return 0
    done
    sleep 1
  done
  return 1
}

echo "=== Yahboom camera module setup ==="
echo "Unplug USB from the DRIVE board and plug it into the CAMERA module (lens board)."
echo "Waiting up to ${WAIT_SECS}s for a serial port..."
echo ""

if [ -z "$PORT" ]; then
  PORT="$(wait_for_port)" || {
    echo "ERROR: No /dev/ttyUSB* or /dev/ttyACM* found within ${WAIT_SECS}s."
    echo "Plug the camera module micro-USB into this PC and re-run."
    exit 1
  }
fi

echo "Using port: $PORT"
INFO="$(identify "$PORT")"
echo "$INFO"
BOARD="$(echo "$INFO" | awk -F= '/^BOARD=/{print $2}')"

case "$BOARD" in
  DRIVE_BOARD)
    echo ""
    echo "ERROR: $PORT is the MAIN DRIVE board (lidar/motors, 2MB flash)."
    echo "  Unplug it and connect USB to the WiFi CAMERA module instead."
    echo "  Drive board stays on the car; only the camera board needs USB for flashing."
    exit 1
    ;;
  CAMERA_MODULE|UNKNOWN)
    if [ "$BOARD" = "UNKNOWN" ]; then
      echo "WARN: Could not confirm board type from boot log; proceeding with camera flash."
      echo "      If this is the drive board, STOP now (Ctrl+C) and swap USB."
      sleep 3
    fi
    ;;
esac

export ESP_SERIAL_PORT="$PORT"
"$REPLICA_SCRIPTS/flash_camera_firmware.sh"

echo ""
echo "=== Camera firmware flashed ==="
echo "1. Unplug USB from camera module and remount it on the robot."
echo "2. Power the robot (both boards on Wi-Fi)."
echo "3. Run: ./scripts/start_robot_sensors_view.sh"
echo "   Topics: /scan /odom /espRos/esp32camera"
