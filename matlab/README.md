# MATLAB — ROS connection (native Humble)

Use **MATLAB R2024b** — it ships **ROS 2 Humble**, matching Ubuntu 22.04 and the Yahboom robot stack.

```bash
# Launch R2024b (not R2026a)
~/Desktop/project/Rover-Room-SIM/scripts/matlab_r2024b.sh
```

## Shell (robot on)

```bash
cd ~/Desktop/project/Rover-Room-SIM
source ./setup.bash
./scripts/start_agent.sh
./scripts/check_robot.sh   # must show [OK] /odom live
```

Do **not** start the TCP bridge — native DDS is the default now.

## MATLAB

```matlab
cd('/home/dinuk/Desktop/project/Rover-Room-SIM/matlab')

ros_test                  % /odom, /scan, /cmd_vel over DDS

ctx = ros_connect();
odom = ros_receive(ctx, 'odom', 10);
scan = ros_receive(ctx, 'scan', 10);
ros_cmd_vel(ctx, 0.2, 0);
pause(1);
ros_cmd_vel(ctx, 0, 0);

matlab_connect            % full URDF + teleop GUI (native DDS)
```

## Batch test from terminal

```bash
./scripts/matlab_r2024b.sh -batch "cd('/home/dinuk/Desktop/project/Rover-Room-SIM/matlab'); ros_test"
```

## How it works

| Path | Transport |
|------|-----------|
| `/odom`, `/scan` subscribe | ROS Toolbox DDS (`ros_sub_read` → `LatestMessage`) |
| `/cmd_vel` publish | ROS Toolbox DDS |

`setup_ros_humble.m` sets domain 20, FastDDS profile, and aligns with `/opt/ros/humble`.

## Simulink

Step-by-step guide (drag blocks, Stateflow, Unreal):

- [docs/SIMULINK_ROS_BLUEPRINT.md](../docs/SIMULINK_ROS_BLUEPRINT.md)

After creating `simulink/rover_ros_io.slx` in the Simulink GUI:

```matlab
run_simulink_ros
```

## Files

| File | Role |
|------|------|
| `scripts/matlab_r2024b.sh` | Launch MATLAB R2024b |
| `setup_ros_humble.m` | Humble + domain 20 env |
| `ros_connect.m` | Native DDS connect |
| `ros_sub_read.m` | Read helper (polls LatestMessage) |
| `ros_receive.m` | Read odom/scan from ctx |
| `ros_cmd_vel.m` | Publish `/cmd_vel` |
| `robot_ros_subscriber.m` | QoS matched to micro-ROS |
| `ros_test.m` | One-shot check |
| `matlab_connect.m` | Full GUI teleop |
| `matlab_connect_bridge.m` | Legacy TCP bridge GUI (fallback) |
| `run_simulink_ros.m` | Run Simulink model after `setup_ros_humble` |

## R2026a / Jazzy

R2025a–R2026a ship Jazzy, not Humble. Use R2024b for this project, or keep `matlab_connect_bridge.m` + `./scripts/start_matlab_bridge.sh` as fallback.

## Diagnostics

```matlab
ros_loopback_test
ros_receive_sweep
ros_dds_diag
```
