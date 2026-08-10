#!/usr/bin/env bash
# Configure Yahboom ROS-WiFi camera module over serial (115200 text commands).
# Connect USB-TTL to the camera module, OR use Yahboom's USB on the module directly.
#
# Protocol: https://www.yahboom.net/public/upload/upload-html/1716379216/
# Commands end with ':'
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

PORT="${ESP_CAMERA_SERIAL:-}"
if [ -z "$PORT" ]; then
  for p in /dev/ttyUSB1 /dev/ttyUSB2 /dev/ttyACM0; do
    [ -e "$p" ] && PORT="$p" && break
  done
fi
PORT="${PORT:-/dev/ttyUSB0}"
SSID="${ESP_WIFI_SSID:?config/wifi.env}"
PASS="${ESP_WIFI_PASSWORD:?config/wifi.env}"
AGENT_IP="${MICRO_ROS_AGENT_IP:-10.0.0.29}"

if [ ! -e "$PORT" ]; then
  echo "ERROR: $PORT not found. Plug camera module USB (or USB-TTL to camera TX/RX)."
  exit 1
fi

if "$REPLICA_SCRIPTS/identify_esp_port.sh" "$PORT" 2>/dev/null | grep -q 'BOARD=DRIVE_BOARD'; then
  echo "ERROR: $PORT is the MAIN DRIVE board (lidar/motors)."
  echo "  Unplug USB from the drive board and connect it to the WiFi CAMERA module (lens board)."
  echo "  Then re-run: ./scripts/configure_camera_wifi.sh"
  exit 1
fi

echo "Configuring camera on $PORT"
echo "  WiFi: $SSID"
echo "  ros2_ip: $AGENT_IP (camera agent port 9999 — see start_camera_agent.sh)"
echo ""

python3 - "$PORT" "$SSID" "$PASS" "$AGENT_IP" << 'PY'
import serial, sys, time

port, ssid, passwd, agent_ip = sys.argv[1:5]
cmds = [
    f"wifi_mode:2",
    f"sta_ssid:{ssid}",
    f"sta_pd:{passwd}",
    f"ros2_ip:{agent_ip}",
    "domainid:20",
    "sta_ip",
    "wifi_ver",
]

s = serial.Serial(port, 115200, timeout=0.5)
time.sleep(0.3)
for cmd in cmds:
    line = cmd if cmd.endswith(":") else cmd + ":"
    if ":" in cmd and not cmd.endswith(":"):
        pass  # already has payload after colon
    payload = (cmd + "\r\n").encode("ascii")
    print(f">> {cmd}")
    s.write(payload)
    time.sleep(0.8)
    out = b""
    end = time.time() + 2.0
    while time.time() < end:
        chunk = s.read(512)
        if chunk:
            out += chunk
        elif out:
            break
        time.sleep(0.05)
    text = out.decode("utf-8", "replace").strip()
    if text:
        print(text)
    else:
        print("(no response — wrong port? use camera module serial, not main board)")
s.close()
print("\nDone. Power-cycle robot, start ./scripts/start_camera_agent.sh, then ./scripts/show_camera_feed.sh")
PY
