# Bundle manifest — full offline copy

**~7.2 GB** — copy the entire `project/` directory to another Ubuntu machine. No dependency on `~/esp` or `~/yahboomcar_ws` on the source VM.

## PC stack (repo root)

| Path | Description |
|------|-------------|
| `scripts/`, `config/`, `launch/`, `teleop/`, `viz/`, `bin/` | micro-ROS agent, teleop, SLAM, flash |
| `docs/` | Native Linux setup, firmware, ROS, ESP-IDF |

## ESP32 — complete (`esp/` — 3.3 GB)

| Path | Description |
|------|-------------|
| `esp/esp-idf/` | Full ESP-IDF tree |
| `esp/Samples/microros_samples/` | All demos + **build/** for each project |
| `esp/Samples/extra_components/` | micro-ROS component + prebuild |
| `esp/Samples/esp32_samples/` | ESP32 examples + builds |
| `esp/Samples/custom_components/` | Custom transport |

**Production firmware:** `esp/Samples/microros_samples/lidar_publisher/` (lidar + `/odom` + `/cmd_vel`)

## Toolchains (`tooling/` — 2.5 GB)

| Path | Description |
|------|-------------|
| `tooling/espressif/` | Copy of `~/.espressif` (xtensa gcc, python env, dist) |

## ROS 2 workspaces (`ros/` — 1.3 GB)

| Path | Description |
|------|-------------|
| `ros/yahboomcar_ws/` | **Full** workspace: `src/`, `build/`, `install/`, `log/` |
| `ros/gmapping_ws/` | slam_gmapping workspace |
| `ros/imu_ws/` | IMU packages |
| `ros/uros_ws/` | micro-ROS related |
| `ros/yahboomcar_ros2_ws/` | Additional Yahboom ROS2 tree |

## Archives (`archives/` — 289 MB)

Zip backups: `yahboomcar_ws.zip`, `gmapping_ws.zip`, `imu_ws.zip`

## Home scripts (`home/`)

| File | |
|------|--|
| `config_robot.py` | Yahboom robot config utility |
| `SET_Camera.py` | Camera setup |

## Still install per machine

| Item | Notes |
|------|--------|
| **ROS 2 Humble** | `/opt/ros` — `./scripts/install_deps_ubuntu22.sh` |
| **Docker** | micro-ROS UDP agent image |

## Migrate

```bash
tar -czf yahboom-full-project.tgz -C ~/Desktop project
# tar -xzf yahboom-full-project.tgz -C ~/Desktop
```
