# Rover dual control

Simulink co-sim: MCL on saved map → Unreal RoverTwin. Real robot driven via `./scripts/run_teleop.sh`.

## Prereqs

- `maps/rover_room_*.mat` (Stage 2 SLAM)
- `maps/unreal_alignment.mat` (`run_manual_align_slam`)
- `roversim/RoverTwin` Unreal project

## Run

Same as root [README.md](../README.md) — four terminals: agent, Simulink, teleop, camera.

```matlab
setup_rover_paths()
run_rover_dual_control()
```

Model: `simulink/rover_dual_control.slx`

Optional MATLAB teleop: `setenv('STAGE4_EXTERNAL_TELEOP','0')` before `run_rover_dual_control()`.
