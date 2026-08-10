# Verification checklist

Use this before and after a simulation run to confirm the system matches the intended architecture.

## A. Level state (Unreal Editor, map MyRoom)

Run audit first if anything is uncertain:

```bash
bash scripts/run_audit_rover_scene.sh
```

Check `RoverTwin/Saved/Logs/AuditRoverScene.log`:

- [ ] `AUDIT_ROVER_SCENE_DONE` present
- [ ] `AUDIT_COUNTS|sim3d_static_mesh=1|rover_mesh_actors=1|tagged_RoverTwin=1`
- [ ] `ROVER_READY|...|loc=(125,80,-147)`

### Outliner search (editor, not PIE)

| Search term | Expected |
|-------------|----------|
| `RoverTwin` | **1** actor, class `Sim3dStaticMeshActor` |
| `RoverVisible` | **0** |
| `RoverActual` | **0** |
| `RoverConstraint` | **0** |
| `Rover` | Only `RoverTwin` (+ no extra rover meshes) |

With Unreal MCP connected:

```
editor_get_world_outliner
```

Confirm one `Sim3dStaticMeshActor` at `(125, 80, -147)` approximately.

## B. Simulink model

```matlab
cd("…/MATLAB")
open_rover_control
```

Open block dialogs:

### Move RoverTwin

- [ ] `ActorTag` = `RoverTwin`
- [ ] `ActorControl` = `on`
- [ ] `ControlledActor` = `RoverTwin`
- [ ] `InitialPos` ≈ `[1.25 -0.8 -1.47]`

### Room Scene

- [ ] Scene path `/Game/Maps/MyRoom`
- [ ] UE project under `/tmp/RoverTwinUnrealProject/...`
- [ ] Project format = Unreal Editor
- [ ] `Ts` = 0.02

## C. Spawn pose files agree

- [ ] `MATLAB/rover_spawn_pose.m` → `ue_cm = [125, 80, -147]`
- [ ] `scripts/rover_spawn_pose.py` → `SPAWN_UE_CM = (125.0, 80.0, -147.0)`

## D. During simulation

1. Click **Run** in Simulink  
2. Wait for Unreal PIE (log: `SIMULINK_PIE_STARTED`)  
3. Focus **RoverTwin Keyboard Control** window  

### Keyboard UI

At rest:

- [ ] `command` ≈ X=1.25, Y=−0.80, yaw=0°
- [ ] `actual` matches `command` within small tolerance (once co-sim alive)

Hold **W** for 2 seconds:

- [ ] `command` X or Y changes
- [ ] **`actual` changes too** (if only command changes → duplicate actor bug)
- [ ] Visible rover mesh moves on bedroom floor in PIE viewport

### Logs (`RoverTwin/Saved/Logs/RoverTwin.log`)

- [ ] `An actor with the tag RoverTwin registered with Sim3dInterface`
- [ ] No repeated spawn failures / tag conflicts

## E. Pass / fail summary

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Two rovers in outliner | Old physics/ghost setup | `run_audit_rover_scene.sh` |
| Command moves, actual frozen | Simulink not driving visible actor | Audit + verify ActorTag |
| Rover outside room | Wrong spawn | Edit `rover_spawn_pose`, rebuild, audit |
| Editor closes on Run | `-ExecutePythonScript` in launcher | Use `launch_rovertwin_simulink.sh` as-is |
| Keyboard no effect | Sim not running or window unfocused | Click keyboard window; check sim status |

## Related docs

- [Troubleshooting](troubleshooting.md)
- [Architecture overview](architecture-overview.md)
