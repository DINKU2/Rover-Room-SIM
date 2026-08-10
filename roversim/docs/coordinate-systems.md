# Coordinate systems

RoverTwin uses **two coordinate frames** that must stay consistent: Unreal Editor (centimetres) and Simulink Simulation 3D (metres).

## Two handedness conventions (critical)

There are **two** frames with **opposite handedness**:

| Frame | Handedness | Used by |
|-------|------------|---------|
| ROS / firmware (REP-103) | right-handed, Y **left**, yaw CCW | `/cmd_vel`, the unicycle integrators, `rover_kinematics.m` |
| Unreal / Sim3D "Default" | left-handed, Y **right**, yaw left-handed | Transform Set/Get inputs/outputs |

MathWorks documents the exact mapping between them
([Robotics System Toolbox coordinate systems](https://www.mathworks.com/help/robotics/ug/coordinate-systems-for-unreal-engine-simulation-in-robotics-system-toolbox.html)):

```
ROS (x, y, z, yaw)  ↔  Unreal/Sim3D (x, -y, z, -yaw)
```

**Y and yaw must be flipped together.** Flipping only one (or neither) makes the
mesh nose and the travel path disagree → "crab-walk" / impossible motion.

### Where the flip happens

The unicycle runs in the ROS frame (identical to firmware). The conversion is
applied only at the Transform Set boundary in `build_rover_control_model.m`:

| Block | Role |
|-------|------|
| `Set Y Flip` (gain −1) | `Translation.y = -y_ros` |
| `Set Yaw Flip` (gain −1) | `Rotation yaw = -yaw_ros` (cos/sin still use un-flipped ROS yaw) |
| `Y Position` IC = `-sim_m(2)` | spawn Y expressed in ROS frame |

The keyboard feedback (`rover_keyboard_control.m → readActualPose`) converts the
Transform Get readback back to the ROS frame (`y_ros = -y_lh`, `yaw_ros = -yaw_lh`)
so the displayed command and actual agree in one frame.

## Position conversion rules

Used in `rover_spawn_pose.m` and `audit_rover_scene.py` (static spawn placement):

| Axis | Unreal (cm) | Simulink Default/LH (m) |
|------|-------------|-------------------------|
| X | `ue_x` | `sim_x = ue_x / 100` |
| Y | `ue_y` | `sim_y = ue_y / 100` |
| Z | `ue_z` | `sim_z = ue_z / 100` |

These map the LH spawn pose for editor placement. The **running** control loop
additionally applies the RH→LH flip above, so the ROS-frame Y integrator IC is
`-sim_m(2)`.

Yaw in Simulink integrators is **radians**; Transform Set rotation is radians in
the Default coordinate system.

## Canonical spawn pose

Single source of truth:

**MATLAB:** `MATLAB/rover_spawn_pose.m`  
**Python:** `scripts/rover_spawn_pose.py`

| Frame | Position |
|-------|----------|
| Unreal cm | `(125, 80, -147)` |
| Simulink m | `(1.25, 0.80, -1.47)` |
| Yaw | `0` |

### Why not `(0, 0, -147)`?

Photogrammetry room actors sit at the world origin, but the **visible floor** inside the scan is offset. Spawning at UE origin places the rover outside the bedroom floor you see in the viewport.

### Room bounds (integrator saturation)

From `build_rover_control_model.m` comments — outer room mesh bounds in **cm**:

- X ∈ [−542, 393]
- Y ∈ [−406, 544]

Saturation in **metres** (with margin) keeps commanded pose inside walkable area:

- X: −5.00 … 3.50 m
- Y: −5.00 … 3.65 m

## Changing spawn

1. Edit **only** `rover_spawn_pose.m` and `rover_spawn_pose.py` (keep them in sync)
2. Rebuild Simulink: `build_rover_control_model`
3. Repair level: `bash scripts/run_audit_rover_scene.sh`
4. Re-run simulation

## Verifying alignment

After audit, log should show:

```
ROVER_READY|...|loc=(125,80,-147)|sim_m=(1.25,0.80,-1.47)
```

Keyboard UI at start (before driving):

- **command** ≈ `(1.25, 0.80, 0°)`
- **actual** should match once co-sim is running

## Related docs

- [Simulink controller](simulink-controller.md)
- [Unreal scene](unreal-scene.md)
