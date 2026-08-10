#!/usr/bin/env bash
# Read and save Yahboom camera module stock flash BEFORE flashing custom firmware.
#
# Connect CH340 (or camera USB) to the CAMERA module only — not the drive board.
# Enter download mode: hold BOOT on the camera board, tap RESET (or replug power),
# release BOOT after 1s. Then run this script.
#
# Usage:
#   ESP_CAMERA_SERIAL=/dev/ttyUSB0 ./scripts/backup_camera_stock.sh
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"
# shellcheck source=esp_env.sh
source "$(dirname "$0")/lib/esp_env.sh"

PORT="${ESP_CAMERA_SERIAL:-${ESP_SERIAL_PORT:-/dev/ttyUSB0}}"
FLASH_SIZE="${CAMERA_FLASH_SIZE:-2MB}"
OUT_DIR="$REPLICA_ROOT/esp/Samples/microros_samples/lidar_publisher/firmware-artifacts/camera/stock"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_BIN="$OUT_DIR/camera-stock-${STAMP}.bin"

if [ ! -e "$PORT" ]; then
  echo "ERROR: $PORT not found. Plug CH340 into the camera module."
  exit 1
fi

if "$REPLICA_SCRIPTS/identify_esp_port.sh" "$PORT" 2>/dev/null | grep -q 'BOARD=DRIVE_BOARD'; then
  echo "ERROR: $PORT is the DRIVE board — unplug and connect to the camera module."
  exit 1
fi

mkdir -p "$OUT_DIR"
PY="${IDF_PYTHON:-python3}"
ESPTOOL="$(find "$IDF_PATH/components/esptool_py" -name esptool.py | head -1)"

echo "=== Backup Yahboom camera stock flash ==="
echo "Port:  $PORT"
echo "Size:  $FLASH_SIZE"
echo "Out:   $OUT_BIN"
echo ""
echo "If esptool cannot connect:"
echo "  1. Hold BOOT on the camera module"
echo "  2. Tap RESET or briefly disconnect/reconnect 3V3"
echo "  3. Release BOOT after 1 second"
echo "  4. Re-run this script immediately"
echo ""

"$PY" "$ESPTOOL" --chip esp32s3 -p "$PORT" -b 115200 \
  --before default_reset --after no_reset \
  flash_id || {
  echo ""
  echo "Could not enter bootloader. Camera may still be running Yahboom serial firmware."
  echo "Use manual BOOT+RESET, then re-run."
  exit 1
}

"$PY" "$ESPTOOL" --chip esp32s3 -p "$PORT" -b 460800 \
  --before no_reset --after hard_reset \
  read_flash 0 0x200000 "$OUT_BIN"

ln -sf "$(basename "$OUT_BIN")" "$OUT_DIR/camera-stock-latest.bin"
echo ""
echo "Saved stock backup: $OUT_BIN"
echo "Symlink:            $OUT_DIR/camera-stock-latest.bin"
echo ""
echo "Restore with:"
echo "  python3 $ESPTOOL --chip esp32s3 -p $PORT write_flash 0x0 $OUT_BIN"
