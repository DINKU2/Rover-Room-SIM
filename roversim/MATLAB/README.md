# RoverTwin Simulink Control

Interactive Simulink teleoperation for one rover in `/Game/Maps/MyRoom`.

**Full architecture documentation:** [`../docs/README.md`](../docs/README.md)

## Architecture (do not deviate)

```
Keyboard → Simulink integrators → Move RoverTwin block (ActorTag=RoverTwin)
                                         ↓ co-simulation
                         ONE Sim3dStaticMeshActor in Unreal, tagged RoverTwin
```

- **One** visible rover actor in the level, tagged `RoverTwin`
- **No** `RoverVisible`, `RoverActual`, `RoverConstraint`, or extra rover meshes
- Spawn pose: edit only `rover_spawn_pose.m` (and `.py`)
- Level repair: `scripts/run_audit_rover_scene.sh` (canonical — run when anything looks wrong)

MathWorks references:
- [Simulate Actor Movement Using Simulink](https://www.mathworks.com/help/sl3d/simulate-actor-movement-using-simulink.html)
- [Animate Custom Actors in the Unreal Editor](https://www.mathworks.com/help/sl3d/animate-custom-actors-in-the-unreal-editor.html)
- [Simulation 3D Actor Transform Set](https://www.mathworks.com/help/vdynblks/ref/simulation3dactortransformset.html)

## Requirements

- MATLAB / Simulink R2024b
- Automated Driving Toolbox or Aerospace Blockset (Simulation 3D blocks)
- Unreal Engine 5.3.2 + MathWorks Simulation plugin

## Run

```matlab
cd("/home/dinuk/Desktop/RoverSIMUunreal-Linux (copy)main/MATLAB")
open_rover_control
```

1. Click **Run** in Simulink (Unreal Editor opens on MyRoom; PIE starts automatically)
2. Click the **RoverTwin Keyboard Control** window for focus
3. **W/S** forward/reverse, **A/D** turn, **Space** stop, **Esc** end simulation

The keyboard UI shows **actual** pose from `Move RoverTwin` Sim3D feedback and **command** pose from integrators. If actual stays frozen while command moves, you still have a duplicate-actor problem — run the audit script.

## One-time / repair

```bash
bash scripts/run_audit_rover_scene.sh
```

Rebuild Simulink after editing `build_rover_control_model.m`:

```matlab
build_rover_control_model
```

## Deprecated scripts (do not run)

- `fix_rover_all.py`, `setup_rover_physics.py`, `remove_sim3d_rover.py`, `attach_rover_feedback.py`
- `run_fix_rover_all.sh`, `run_rover_physics_setup.sh` — redirect to audit

## Troubleshooting

**Keyboard shows movement but rover is frozen in Unreal**

Run `run_audit_rover_scene.sh`. In Outliner search `Rover` — you should see exactly one `RoverTwin` `Sim3dStaticMeshActor`.

**Rover spawns outside the room**

Edit spawn in `MATLAB/rover_spawn_pose.m`, then rebuild model and re-run audit.

**Unreal Editor closes immediately on Simulink Run**

Do not pass `-ExecutePythonScript` in `launch_rovertwin_simulink.sh` (that quits the editor after the script).
