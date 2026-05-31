# ESP32 firmware (bundled in `replica/esp/`)

Firmware lives **inside this repo** — you do not need `~/esp` on the new machine except for **ESP-IDF** itself.

## Production project

```text
replica/esp/Samples/microros_samples/lidar_publisher/
```

| Topic / role | |
|--------------|--|
| `/scan` | Lidar |
| `/odom` | Wheel odometry (`odom` → `base_footprint`) |
| `/cmd_vel` | Subscribe — drive |

Merged from Yahboom `odom_publisher` + `lidar_publisher` + `twist_subscriber`.

## Configure Wi-Fi and agent IP

```bash
cd replica
source ./setup.bash
./scripts/esp_menuconfig.sh
```

Set:

- Wi-Fi SSID / password (same LAN as PC)
- **micro-ROS agent IP** = `MICRO_ROS_AGENT_IP` in `config/env`
- Port **8090**

Or edit `sdkconfig` directly (already copied from your working VM).

## Build and flash

```bash
# ESP-IDF must be installed — docs/ESP_IDF_SETUP.md
source ./setup.bash
export ESP_SERIAL_PORT=/dev/ttyUSB0   # optional
./scripts/flash_firmware.sh
```

## All bundled micro-ROS samples

Under `esp/Samples/microros_samples/`:

- `lidar_publisher` — **use this**
- `twist_subscriber`, `odom_publisher`, `imu_publisher`, …
- `publisher`, `subscriber`, `beep_subscriber`, `servo_subscriber`, …

Shared components: `esp/Samples/extra_components/micro_ros_espidf_component/`

## After PC IP changes

1. `config/env` → `MICRO_ROS_AGENT_IP`
2. `./scripts/esp_menuconfig.sh` or edit `sdkconfig`
3. `./scripts/flash_firmware.sh`
