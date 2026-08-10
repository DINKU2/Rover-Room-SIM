# Rover architecture (canonical — do not change actor types)

## Actors in MyRoom

| Label | Type | Visible | Collision | Saved in level |
|-------|------|---------|-----------|----------------|
| **RoverTwin** | `Sim3dStaticMeshActor` | Hidden in game | NoCollision | Yes |
| **RoverProxy** | `StaticMeshActor` | Yes (`SM_Rover_Combined`) | NoCollision on mesh; sphere sweep in code | Yes |
| **RoverProxyFeedback** | `Sim3dStaticMeshActor` | Hidden | NoCollision | Yes |
| **MyRoom_Part_*** | `StaticMeshActor` | Yes | BlockAll, Static | Yes |

**Do not use** `BP_RoverProxy` or `RoverSweepDriver` in the level. Blueprint was abandoned (empty mesh). Python `RoverSweepActor` is transient and breaks World Partition save.

## Data flow

```
Simulink keyboard
  → integrators
  → Transform Set → RoverTwin (ghost, teleports through walls)
  → rover_sweep_runtime.py (PIE only, 60 Hz sphere sweep)
  → RoverProxy StaticMeshActor (visible, stops at walls)
  → RoverProxyFeedback (tag RoverProxy)
  → Transform Get → MATLAB display
```

## Setup (one command)

Editor open on MyRoom, Remote Execution enabled:

```bash
bash scripts/run_setup_rover_scene.sh
```

Or full collision + rover:

```bash
bash scripts/run_all_collision_setup.sh
```

## Save rules

- Ctrl+S is safe — no Python actors in the level.
- Room meshes: **Static**, **BlockAll**, **Simulate Physics OFF**.
