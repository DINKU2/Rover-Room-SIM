# Scripts reference

All paths relative to repo root.

## Canonical (use these)

| Script | Purpose |
|--------|---------|
| **`scripts/audit_rover_scene.py`** | Delete duplicate rovers; create one tagged `RoverTwin`; save MyRoom |
| **`scripts/run_audit_rover_scene.sh`** | Run audit headless (closes editor, runs Python, checks log) |
| **`scripts/rover_spawn_pose.py`** | Spawn coordinates shared with MATLAB |
| **`scripts/launch_rovertwin_simulink.sh`** | Called from Simulink InitFcn — start editor + PIE watcher |
| **`scripts/launch_rovertwin_editor.sh`** | Low-level Unreal Editor launch with correct `LD_LIBRARY_PATH` |
| **`scripts/watch_rovertwin_play.sh`** | Auto Alt+P when `.start_rover_pie` trigger exists |

### `run_audit_rover_scene.sh` environment

Sets `LD_LIBRARY_PATH` for:

- Unreal Engine binaries
- ProceduralMeshComponent, SunPosition, ChaosVehiclesPlugin
- MathWorksSimulation plugin
- MATLAB `glnxa64` libs

Required or `MathWorksSimulation` plugin fails to load.

## Wrappers / aliases

| Script | Notes |
|--------|-------|
| `scripts/restore_rover_simple.py` | Wrapper → calls `audit_rover_scene.py` |
| `scripts/run_restore_rover_simple.sh` | Same as `run_audit_rover_scene.sh` (points to audit) |

## Deprecated (do not run)

These exit immediately with `DEPRECATED: run scripts/run_audit_rover_scene.sh instead`:

| Script | Old purpose | Why removed |
|--------|-------------|-------------|
| `fix_rover_all.py` | Ghost + RoverVisible + constraint | Duplicate visible/hidden rovers |
| `setup_rover_physics.py` | Physics spring follower | Same |
| `remove_sim3d_rover.py` | Delete pre-placed actor | Conflicts with ActorControl=on |
| `attach_rover_feedback.py` | RoverActual for Transform Get | Keyboard reads Move RoverTwin outputs now |
| `restore_sim3d_rover.py` | Older single-actor restore | Superseded by audit |

Shell redirects:

- `run_fix_rover_all.sh` → `run_audit_rover_scene.sh`
- `run_rover_physics_setup.sh` → `run_audit_rover_scene.sh`

## Legacy / diagnostic

| Script | Purpose |
|--------|---------|
| `configure_rover_for_simulink.py` | Tag existing actor (use audit instead) |
| `convert_rover_to_sim3d.py` | One-time plain → Sim3dStaticMeshActor conversion |
| `tag_rover.py` | Add RoverTwin tag |
| `get_room_bounds.py` | Log MyRoom bounding boxes |
| `remove_rover_parts.py` | Cleanup stray mesh parts |
| `remove_sim3d_rover.py` | Deprecated |

## Launch / packaging

| Script | Purpose |
|--------|---------|
| `Linux/RoverTwin.sh` | Run packaged Linux game build |
| `RoverTwin/PackageRoverTwin_Linux.sh` | Cook/package project |

## MATLAB scripts (not in `scripts/`)

| File | Role |
|------|------|
| `MATLAB/open_rover_control.m` | User entry point |
| `MATLAB/build_rover_control_model.m` | Generate `RoverTwinControl.slx` |
| `MATLAB/rover_keyboard_control.m` | Teleop UI |
| `MATLAB/rover_prepare_simulation.m` | InitFcn |
| `MATLAB/rover_stop_simulation.m` | StopFcn |
| `MATLAB/rover_spawn_pose.m` | Spawn pose (authoritative for Simulink) |
| `MATLAB/rover_unreal_project_alias.m` | `/tmp` symlink |
| `MATLAB/test_*.m` | Dev tests |

## Trigger file

| Path | Writer | Reader |
|------|--------|--------|
| `MATLAB/.start_rover_pie` | `rover_prepare_simulation.m` | `watch_rovertwin_play.sh` |

Deleted by watcher after PIE starts.

## Related docs

- [Verification checklist](verification-checklist.md)
- [Startup sequence](startup-sequence.md)
