# Rover-Room-SIM — Yahboom micro-ROS robot stack

**Everything** for this project in one folder (~**7.2 GB**): PC stack, **ESP-IDF**, toolchains, all Yahboom ESP samples (with builds), and full ROS workspaces.

See **`MANIFEST.md`** for the complete file list.

## What you get

| Component | Location |
|-----------|----------|
| Drive + lidar + SLAM scripts | `scripts/`, `config/`, `launch/` |
| ESP-IDF + compilers | `esp/esp-idf/`, `tooling/espressif/` |
| All micro-ROS / ESP samples | `esp/Samples/` |
| Yahboom Pi ROS packages (built) | `ros/yahboomcar_ws/` |
| Other ROS ws + zip archives | `ros/`, `archives/` |

## Quick start (native Ubuntu 22.04)

```bash
cd ~/Desktop/project/Rover-Room-SIM
cp config/env.example config/env   # edit MICRO_ROS_AGENT_IP if needed
source ./setup.bash
./scripts/start_agent.sh
./scripts/check_robot.sh
./scripts/run_teleop.sh
```

See **`docs/NATIVE_LINUX_SETUP.md`** for one-time install and MATLAB bridge workflow.

## Flash firmware (bundled IDF — no ~/esp needed)

```bash
source ./setup.bash
./scripts/esp_menuconfig.sh
./scripts/flash_firmware.sh
```

## SLAM

```bash
./scripts/run_slam.sh --slam
```

## Layout

```text
project/
├── esp/esp-idf/              # ESP-IDF 5.1
├── esp/Samples/              # microros_samples, extra_components, …
├── tooling/espressif/        # ~/.espressif toolchains
├── ros/yahboomcar_ws/        # full colcon workspace
├── ros/gmapping_ws/ imu_ws/ …
├── archives/*.zip
├── home/config_robot.py …
└── scripts/ config/ docs/ …
```
