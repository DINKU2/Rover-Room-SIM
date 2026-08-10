#!/usr/bin/env bash
# Identify Yahboom ESP32-S3 on a serial port: drive board vs WiFi camera module.
# Usage: ./scripts/identify_esp_port.sh [/dev/ttyUSB0]
set -e
REPLICA_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${1:-${ESP_SERIAL_PORT:-/dev/ttyUSB0}}"

if [ ! -e "$PORT" ]; then
  echo "ERROR: $PORT not found" >&2
  exit 2
fi

python3 - "$PORT" << 'PY'
import serial, sys, time, re

port = sys.argv[1]
markers = {
    "drive": [
        "Lidar_Ms200", "lidar", "motor", "MOTOR", "cmd_vel", "odom",
        "pwm_motor", "car_motion", "Uart1_Rx_Task",
    ],
    "camera": [
        "rover_camera", "esp32camera", "Camera probe", "cam_hal", "OV2640",
        "ROVER_CAM", "ROVER_CAMERA_ONLY", "Camera ready", "Camera publisher",
    ],
}

s = serial.Serial(port, 115200, timeout=0.3)
s.setDTR(False)
s.setRTS(False)
time.sleep(0.15)
s.setDTR(True)
s.setRTS(True)
time.sleep(0.1)
s.setDTR(False)

text = ""
end = time.time() + 12
while time.time() < end:
    line = s.readline()
    if line:
        text += line.decode("utf-8", "replace")

# Also sample live runtime log (drive board prints Lidar watchdog while running).
live_end = time.time() + 4
while time.time() < live_end:
    line = s.readline()
    if line:
        text += line.decode("utf-8", "replace")

scores = {k: sum(1 for m in v if m.lower() in text.lower()) for k, v in markers.items()}
flash_m = re.search(r"SPI Flash Size\s*:\s*(\S+)", text)
flash = flash_m.group(1) if flash_m else "unknown"

kind = "UNKNOWN"
if scores["drive"] > 0:
    kind = "DRIVE_BOARD"
elif scores["camera"] > scores["drive"] and scores["camera"] > 0:
    kind = "CAMERA_MODULE"
elif "Lidar_Ms200" in text or "MOTOR:" in text or "PWM_MOTOR" in text:
    kind = "DRIVE_BOARD"
elif scores["drive"] == 0 and scores["camera"] == 0:
    kind = "UNKNOWN"

print(f"PORT={port}")
print(f"BOARD={kind}")
print(f"FLASH={flash}")
print(f"SCORES drive={scores['drive']} camera={scores['camera']}")
sys.exit(0 if kind in ("DRIVE_BOARD", "CAMERA_MODULE") else 1)
PY
