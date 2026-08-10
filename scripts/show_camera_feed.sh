#!/usr/bin/env bash
# Show live camera: starts agents (8090 drive + 9999 camera), saves frames to /tmp/rover_camera.jpg
set -e
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

OUT="${ROVER_CAMERA_JPEG:-/tmp/rover_camera.jpg}"
WAIT_SECS="${WAIT_SECS:-45}"

"$REPLICA_SCRIPTS/start_agent.sh"
"$REPLICA_SCRIPTS/start_camera_agent.sh"

echo "Waiting up to ${WAIT_SECS}s for /espRos/esp32camera ..."

python3 - "$OUT" "$WAIT_SECS" << 'PY'
import sys, time
import rclpy
from rclpy.node import Node
from rclpy.qos import qos_profile_sensor_data
from sensor_msgs.msg import CompressedImage

out_path = sys.argv[1]
wait_secs = int(sys.argv[2])

class Grab(Node):
    def __init__(self):
        super().__init__("camera_grab")
        self.got = False
        self.sub = self.create_subscription(
            CompressedImage, "/espRos/esp32camera", self.cb, qos_profile_sensor_data)

    def cb(self, msg):
        if self.got:
            return
        with open(out_path, "wb") as f:
            f.write(bytes(msg.data))
        self.got = True
        print(f"Saved frame ({len(msg.data)} bytes) -> {out_path}")

rclpy.init()
node = Grab()
deadline = time.time() + wait_secs
while time.time() < deadline and not node.got:
    rclpy.spin_once(node, timeout_sec=0.5)
node.destroy_node()
rclpy.shutdown()
sys.exit(0 if node.got else 1)
PY

if [ $? -eq 0 ]; then
  echo "Frame saved: $OUT"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$OUT" 2>/dev/null &
  fi
  echo "Starting live viewer (Ctrl+C to stop)..."
  ros2 run yahboom_esp32_camera sub_img
else
  echo ""
  echo "No camera frames received."
  echo "  1. Robot powered, camera on Custom GPIO×2"
  echo "  2. Configure camera WiFi (module serial): ./scripts/configure_camera_wifi.sh"
  echo "  3. Camera agent must be on port 9999 (started above)"
  exit 1
fi
