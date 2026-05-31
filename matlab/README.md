# MATLAB — native Ubuntu 22.04

Control the Yahboom micro-ROS rover from MATLAB via the **TCP bridge** (recommended) or direct DDS (experimental).

## Prerequisites

- **MATLAB** with **ROS Toolbox** and **Robotics System Toolbox**
- Agent + robot + bridge running:

```bash
cd ~/Desktop/project
source ./setup.bash
./scripts/start_agent.sh
./scripts/start_matlab_bridge.sh
./scripts/check_robot.sh    # must show /odom live
```

Do **not** run `./scripts/run_teleop.sh` while MATLAB publishes `/cmd_vel`.

## Quick start (TCP bridge — recommended)

```matlab
cd('/home/dinuk/Desktop/project/Rover-Room-SIM/matlab')
matlab_connect_bridge
```

Focus the figure window, then drive with **i/j/l/,** (hold key to move, release to stop). **q/w** adjust speed, **z** quit.

## Optional: direct DDS

Direct DDS often lists topics but does not receive live data in MATLAB. If you want to try it:

```matlab
setup_ros_dds
matlab_ros_test
matlab_connect
```

Restart MATLAB after the first `setup_ros_dds` in a session.

## Files

| File | Purpose |
|------|---------|
| `matlab_connect_bridge.m` | Live map + teleop via TCP bridge (port 8765) |
| `check_robot_preflight.m` | Runs `./scripts/check_robot.sh` from MATLAB |
| `setup_ros_dds.m` | Domain 20 + native FastDDS profile (direct DDS only) |
| `matlab_ros_test.m` | Preflight before `matlab_connect` |
| `matlab_connect.m` | Live map via direct DDS (may not receive data) |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Bridge connection failed | `./scripts/start_matlab_bridge.sh` |
| Shell check OK, no movement | Ensure bridge is running; power-cycle robot |
| Shell check fails | Robot/agent — see `docs/NATIVE_LINUX_SETUP.md` |
