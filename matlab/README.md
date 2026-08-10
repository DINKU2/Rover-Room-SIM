# MATLAB

Use **MATLAB R2024b** (`./scripts/matlab_r2024b.sh`) with ROS 2 Humble.

```bash
source ./setup.bash
./scripts/start_agent.sh
./scripts/check_robot.sh
```

```matlab
setup_rover_paths()
ros_test
```

## Stage 2 — build map

```bash
source ./setup.bash && ./scripts/run_teleop.sh
```

```matlab
run_stage2_lidar_slam
```

Save with key **5** or popup. Output: `maps/rover_room_*.{mat,yaml,pgm}`.

## Stage 3 — align to Unreal

```matlab
run_manual_align_slam
```

Writes `maps/unreal_alignment.mat`.

## Stage 4 — co-sim

```matlab
run_rover_dual_control()
```

See [../README.md](../README.md).

## Verify localization

```matlab
verify_map_pose('Localization','mcl')
```
