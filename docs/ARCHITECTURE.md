# Architecture (as built)

Digital twin co-simulation: real Yahboom micro-ROS rover + Unreal RoverTwin, aligned on a saved MATLAB map.

```text
Real robot (ESP32)          PC (Ubuntu + MATLAB R2024b)              Unreal
/scan, /odom  ──WiFi──►  micro-ROS agent :8090  ──►  MCL overlay
/cmd_vel      ◄──WiFi──  run_teleop.sh          ◄──  (external teleop)
                              │
                              ▼
                         rover_dual_control.slx
                         MAP pose → Set_RoverTwin
```

## Data flow

| Step | What |
|------|------|
| Map | Stage 2 MATLAB lidarSLAM → `maps/rover_room_*.mat` |
| Align | `run_manual_align_slam` → `maps/unreal_alignment.mat` |
| Localize | `dual_mcl_ros_update` — MCL + scan-to-map on saved map |
| Twin | `simulink_mcl_map_pose` → `map_pose_to_unreal_sim3d` → Unreal actor |
| Drive | `./scripts/run_teleop.sh` → `/cmd_vel` (not Simulink by default) |

## Config

| File | Purpose |
|------|---------|
| `config/env` | `ROS_DOMAIN_ID`, `MICRO_ROS_AGENT_IP`, port 8090 |
| `config/wifi.env` | ESP Wi-Fi SSID/password (gitignored) |

## Related

| Doc | Content |
|-----|---------|
| [../README.md](../README.md) | Run co-sim |
| [../rover-dual/README.md](../rover-dual/README.md) | Stage 4 model |
| [../matlab/README.md](../matlab/README.md) | Map build + align |
| [CAMERA_HARDWARE.md](CAMERA_HARDWARE.md) | Camera module |
| [FIRMWARE.md](FIRMWARE.md) | Flash drive board |

Sim-only RoverTwin (keyboard → unicycle integrator): see `roversim/docs/README.md` — not Stage 4.
