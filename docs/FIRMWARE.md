# ESP32 firmware

Production project: `esp/Samples/microros_samples/lidar_publisher/`

| Topic | Role |
|-------|------|
| `/scan` | Lidar |
| `/odom` | Wheel odometry |
| `/cmd_vel` | Drive |

Camera module (separate ESP): `/espRos/esp32camera` — see [CAMERA_HARDWARE.md](CAMERA_HARDWARE.md). Do **not** flash camera firmware to the drive board (`/dev/ttyUSB0`).

## Flash drive board

```bash
# Wi-Fi: config/wifi.env
# Agent IP: config/env
source ./setup.bash
./scripts/flash_firmware.sh
```

Wi-Fi and agent IP are synced from `config/wifi.env` + `config/env` via `./scripts/sync_firmware_config.sh` (called by flash script).

## Camera module (one-time)

```bash
source ./setup.bash
./scripts/setup_camera_module.sh
```

## After PC IP changes

1. Edit `config/env` → `MICRO_ROS_AGENT_IP`
2. `./scripts/flash_firmware.sh`
