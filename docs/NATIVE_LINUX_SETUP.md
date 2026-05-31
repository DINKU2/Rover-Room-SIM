# Native Ubuntu 22.04 setup

This machine runs **everything natively** — no WSL, no Windows IP forwarding.

## Your machine

| Item | Value |
|------|--------|
| OS | Ubuntu 22.04 |
| LAN IP | `10.0.0.29` (robot UDP target) |
| ROS 2 | Humble (`/opt/ros/humble`) |
| Docker | native `docker.io` (`--net=host` for UDP 8090) |
| MATLAB | `/home/dinuk/MATLAB/R2026a/bin/matlab` |
| Project | `/home/dinuk/Desktop/project/Rover-Room-SIM` |

## One-time setup

```bash
sudo ./scripts/install_deps_ubuntu22.sh   # ROS 2 + tools
./scripts/setup_native_linux.sh           # bashrc alias, config/env IP
```

**Docker:** use native engine (`sudo apt install docker.io`). Docker Desktop often fails to bind UDP 8090 on the LAN IP.

**Firmware:** agent IP must match `MICRO_ROS_AGENT_IP` in `config/env`. Reflash after IP changes:

```bash
source ./setup.bash
./scripts/flash_firmware.sh
```

## Daily workflow

```bash
cd ~/Desktop/project/Rover-Room-SIM    # or: project
source ./setup.bash
```

**Tab 1 — micro-ROS agent**

```bash
./scripts/start_agent.sh
```

**Tab 2 — verify robot**

```bash
./scripts/check_robot.sh    # expect /scan /odom /cmd_vel live
```

**Tab 3 — teleop or SLAM**

```bash
./scripts/run_teleop.sh
# or
./scripts/run_slam.sh --slam
```

## MATLAB (TCP bridge)

ROS and MATLAB share the same machine, but **direct DDS often does not receive live data in MATLAB**. Use the TCP bridge:

```bash
./scripts/start_matlab_bridge.sh
```

```matlab
cd('/home/dinuk/Desktop/project/Rover-Room-SIM/matlab')
matlab_connect_bridge
```

Do **not** run `./scripts/run_teleop.sh` while MATLAB publishes `/cmd_vel`.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `docker: connect: no such file` | `sudo systemctl start docker`; add user to `docker` group |
| No topics | Agent not running; wrong firmware IP; power-cycle robot |
| Stale `/home/yahboom` warnings | `./scripts/fix_stale_paths.sh` |
| Flash fails | `ls /dev/ttyUSB*`; `sudo usermod -aG dialout $USER` |
| MATLAB no movement | Bridge running? `./scripts/start_matlab_bridge.sh` |

## Config file

Edit `config/env` if your LAN IP changes:

```bash
export ROS_DOMAIN_ID=20
export MICRO_ROS_AGENT_IP=10.0.0.29
export MICRO_ROS_AGENT_PORT=8090
```
