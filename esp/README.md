# Yahboom ESP32 samples (bundled)

Copied from Yahboom’s `esp/Samples/` tree. Paths match upstream so `CMakeLists.txt` still resolve `../../extra_components`.

## Layout

| Directory | Contents |
|-----------|----------|
| `microros_samples/` | All micro-ROS demos — **`lidar_publisher`** is the merged drive+lidar+odom firmware |
| `extra_components/` | `micro_ros_espidf_component` (prebuilt `libmicroros.a` + sources) |
| `esp32_samples/` | Non-ROS ESP32 examples |
| `custom_components/` | Used by `custom_transport` sample |

## Main firmware project

```text
microros_samples/lidar_publisher/
```

Publishes: `/scan`, `/odom` — subscribes: `/cmd_vel`

Configure Wi-Fi and agent IP:

```bash
cd replica && ./scripts/esp_menuconfig.sh
```

Build/flash:

```bash
./scripts/flash_firmware.sh
```

## Other microros_samples

| Project | Purpose |
|---------|---------|
| `twist_subscriber` | Drive only |
| `odom_publisher` | Odom only (merged into lidar_publisher) |
| `imu_publisher` | IMU |
| `lidar_publisher` | **Production firmware** |
| `publisher` / `subscriber` | Hello world |
| `beep_subscriber` / `servo_subscriber` | Peripherals |

Requires **`IDF_PATH`** — see `docs/ESP_IDF_SETUP.md`.
