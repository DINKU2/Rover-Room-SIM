# Unreal scene

## Project

- **File:** `RoverTwin/RoverTwin.uproject`
- **Engine:** 5.3
- **Default map:** `/Game/Maps/MyRoom` (`Content/Maps/MyRoom.umap`)

## MyRoom level contents

| Actor type | Label pattern | Role |
|------------|---------------|------|
| Static mesh actors | `MyRoom_Part_*` | Photogrammetry room geometry — **BlockAll** collision |
| Static mesh actor | `GroundPlane` | Floor plane under scene |
| **Sim3dStaticMeshActor** | **`RoverTwin`** | Hidden ghost — Simulink **Transform Set** teleports this |
| **StaticMeshActor** | **`RoverVisible`** | Visible rover mesh — **physics + BlockAll** (stops at walls) |
| **PhysicsConstraintActor** | **`RoverConstraint`** | Spring links ghost → visible |
| Lighting / sky | `SunSky`, point lights, etc. | Visualization |

Room meshes are placed at world origin `(0,0,0)` with large scale; **walkable floor is offset** from origin. That is why spawn is at `(125, 80, -147)` cm, not `(0, 0, -147)`.

## Rover actors (required state)

After `run_audit_rover_scene.sh` (audit + collision setup):

### RoverTwin (Simulink driver — ghost)

| Property | Value |
|----------|-------|
| Class | `Sim3dStaticMeshActor` |
| Label / Tag | `RoverTwin` |
| Mesh | `/Game/Rover/Meshes/SM_Rover_Combined` |
| Visibility | **Hidden in game** (editor only) |
| Collision | `OverlapAll` — passes through walls; anchor for constraint |
| Physics | Off (teleported by Simulink each step) |

### RoverVisible (what you see — wall collision)

| Property | Value |
|----------|-------|
| Class | `StaticMeshActor` |
| Label | `RoverVisible` |
| Mesh | Same `SM_Rover_Combined` |
| Collision | `BlockAll` + simulate physics |
| Behavior | Pulled toward ghost by `RoverConstraint` spring; **stops at walls** |

### RoverConstraint

| Property | Value |
|----------|-------|
| Class | `PhysicsConstraintActor` |
| Links | `RoverTwin` → `RoverVisible` |
| Drive | Linear spring X/Y (stiffness 80000), Z locked, rotation locked to ghost |

Simulink still uses **ActorTag = `RoverTwin`** on Transform Set/Get. The integrators command the ghost; Unreal physics on `RoverVisible` enforces collision.

### Counts that must pass audit

```
sim3d_static_mesh = 1
rover_mesh_actors = 1
tagged_RoverTwin  = 1
```

## Engine / Sim3D configuration

From `RoverTwin/Config/DefaultEngine.ini`:

```ini
GameInstanceClass=/Script/MathWorksSimulation.Sim3dGameInstance
GlobalDefaultGameMode=/MathWorksSimulation/Blueprints/Sim3dGameMode.Sim3dGameMode_C
LevelScriptActorClassName=/Script/MathWorksSimulation.Sim3dLevelScriptActor
```

`Sim3dLevelScriptActor` handles messages from Simulink:

- Creates/registers Sim3D camera and static mesh actors at simulation start
- Bridges transform data each co-simulation step

## Simulink ↔ Unreal actor naming

During PIE you may see log names like `StaticMeshActorRoverTwin`. That is the **Simulink registration name** for the static mesh actor block. It is not a second level-placed rover.

**In the editor outliner:** `RoverTwin` (ghost), `RoverVisible`, `RoverConstraint`, plus `SpawnDebugOrb`.

**During Play:** you see **RoverVisible** move and collide; the ghost is invisible.

## Level repair

**Canonical script only:**

```bash
bash scripts/run_audit_rover_scene.sh
```

This runs audit (single `RoverTwin` ghost) then `setup_rover_collision.py` (physics rover + walls).

Collision-only (if ghost already exists):

```bash
bash scripts/run_setup_rover_collision.sh
```

Logs:
- `RoverTwin/Saved/Logs/AuditRoverScene.log` — `AUDIT_ROVER_SCENE_DONE`
- `RoverTwin/Saved/Logs/RoverCollisionSetup.log` — `COLLISION_SETUP_DONE`

What audit does:

1. Enable complex collision on room meshes
2. Delete stray rover actors
3. Spawn fresh `RoverTwin` ghost at `rover_spawn_pose`

What collision setup adds:

4. Hide ghost (`OverlapAll`, no wall blocking)
5. Spawn `RoverVisible` with `BlockAll` + simulate physics
6. Spawn `RoverConstraint` spring (ghost → visible)
7. Verify counts and save map

## Unreal MCP (Cursor)

`.cursor/mcp.json` runs `tools/unreal-mcp` for editor integration when Unreal is open with remote Python execution enabled (`PythonScriptPluginSettings` → `bRemoteExecution=True`).

Useful MCP tools:

| Tool | Use |
|------|-----|
| `editor_get_world_outliner` | List actors — verify single rover |
| `editor_run_python` | Run audit logic live in open editor |
| `editor_take_screenshot` | Visual confirmation |

MCP requires the editor to be running and the MCP server connected (`No command channel open` means editor/MCP is offline).

## Packaged build (optional)

`Linux/RoverTwin.sh` launches a cooked build with `Sim3dGameMode` — separate from the Simulink **Unreal Editor** workflow used for development.

## Related docs

- [Coordinate systems](coordinate-systems.md)
- [Verification checklist](verification-checklist.md)
