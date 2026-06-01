# Rover-Room-SIM — System Architecture

Architecture reference for blind navigation in a scanned room: real Yahboom micro-ROS robot, ROS 2 on Ubuntu, MATLAB toolboxes, and Unreal Engine visualization.

This document describes **what connects to what** and **which MATLAB toolbox owns which concern**. It is not an implementation schedule.

---

## Goal

Operate the **real robot** in a **known room** without line-of-sight:

- Room geometry comes from a prior scan (Unreal mesh / `my_room.fbx`).
- Robot pose comes from **lidar + map-based localization** (not raw wheel odometry alone).
- Operator drives or sends goals from **MATLAB** and/or **Unreal**, watching a virtual room that tracks the real robot.

---

## High-level stack

```text
┌─────────────────────────────────────────────────────────────────┐
│  Presentation                                                    │
│  Unreal Engine (room mesh)  │  MATLAB figures / Simulink 3D     │
└──────────────┬──────────────────────────────┬───────────────────┘
               │                              │
┌──────────────▼──────────────────────────────▼───────────────────┐
│  Application (MATLAB)                                            │
│  ROS Toolbox │ Robotics System Toolbox │ Navigation Toolbox     │
│  (optional) Simulink + Simulink 3D Animation → Unreal            │
└──────────────┬──────────────────────────────────────────────────┘
               │  TCP bridge (8765)  and/or  ROS 2 DDS
┌──────────────▼──────────────────────────────────────────────────┐
│  Middleware (ROS 2 Humble, domain 20)                            │
│  micro-ROS agent │ slam_toolbox │ map_server │ AMCL │ Nav2       │
│  tf2  (map → odom → base_footprint → laser_frame)                │
└──────────────┬──────────────────────────────────────────────────┘
               │  Wi‑Fi UDP :8090
┌──────────────▼──────────────────────────────────────────────────┐
│  Robot (ESP32 firmware — lidar_publisher)                        │
│  /scan  /odom  /cmd_vel                                          │
└──────────────────────────────────────────────────────────────────┘
```

---

## Two maps (do not merge mentally)

| Map | Format | Purpose | In repo today |
|-----|--------|---------|---------------|
| **Visual map** | 3D mesh (`matlab/my_room.fbx`) | Unreal rendering, human spatial context | Yes |
| **Navigation map** | 2D occupancy grid (`nav_msgs/OccupancyGrid`, `.yaml` + `.pgm`) | Metric pose, planning, “where am I in the room?” | Partial (`slam_toolbox`, saved maps under `ros/.../maps/`) |

These live in different representations. **Alignment** (fixed transform: Unreal origin ↔ ROS `map` origin) is a one-time calibration step, not automatic.

---

## Coordinate frames

```text
map  ──►  odom  ──►  base_footprint  ──►  base_link  ──►  laser_frame
 │           │              │
 │           │              └── robot body (planning, URDF)
 │           └── wheel integration (drifts; SLAM/AMCL corrects via map→odom)
 └── room-fixed metric frame (goals, saved map, Unreal sync target)
```

| Frame | Source | Used by |
|-------|--------|---------|
| `laser_frame` | Static TF (see `launch/slam_launch.py`) | `/scan` points |
| `base_footprint` / `base_link` | `/odom` + TF | Robot model, Nav2 |
| `odom` | ESP firmware | Short-term motion; **current MATLAB bridge plots here** |
| `map` | slam_toolbox or AMCL | Room-fixed localization — **target for Rover-Room-SIM** |

**Architectural rule:** Unreal and Navigation Toolbox consume **`map` → `base_footprint`**, not raw `odom` alone.

---

## ROS 2 topics and services (contract)

| Topic / service | Type | Direction | Owner |
|-----------------|------|-----------|-------|
| `/scan` | `sensor_msgs/LaserScan` | Robot → PC | ESP firmware |
| `/odom` | `nav_msgs/Odometry` | Robot → PC | ESP firmware |
| `/cmd_vel` | `geometry_msgs/Twist` | PC → Robot | MATLAB / Nav2 / teleop |
| `/map` | `nav_msgs/OccupancyGrid` | SLAM / map_server → consumers | slam_toolbox or map_server |
| `/tf`, `/tf_static` | TF | SLAM / AMCL / static publishers | tf2 |
| `/amcl_pose` | `PoseWithCovarianceStamped` | AMCL → consumers | nav2_amcl (when enabled) |
| Nav2 action | `NavigateToPose` | MATLAB/RViz → Nav2 | nav2 (when enabled) |

Existing bridge (`scripts/matlab_bridge.py`) today: **`/scan`, `/odom`, `/cmd_vel` only** — no `/map`, no TF.

---

## MATLAB toolboxes — roles in this project

### ROS Toolbox

**Owns:** Connection between MATLAB and the ROS 2 graph.

| Responsibility | ROS interface | Notes |
|----------------|---------------|-------|
| Subscribe to robot sensors | `/scan`, `/odom` | Direct DDS or via bridge JSON |
| Subscribe to map + pose | `/map`, `/amcl_pose`, TF | Required for room-fixed navigation |
| Publish motion commands | `/cmd_vel` | Competes with teleop — one publisher at a time |
| Inspect graph | `ros2node`, `ros2topic list` | Debugging |

**Existing code:** `matlab/setup_ros_dds.m`, `matlab/matlab_connect.m`, `matlab/check_robot_preflight.m`  
**Working path today:** TCP bridge → `matlab_connect_bridge.m` (bypasses DDS data-plane issues)

**Architecture choice:** ROS Toolbox can talk **directly** to ROS 2 or **indirectly** through the Python bridge. Bridge is simpler for `/scan`/`/odom`/`/cmd_vel`; extend bridge or use native ROS for `/map` + TF.

---

### Robotics System Toolbox

**Owns:** Robot model, geometry, and 2D/3D visualization in MATLAB.

| Responsibility | API / pattern | Notes |
|----------------|---------------|-------|
| Load robot | `importrobot`, URDF + STL meshes | `matlab/prepare_robot_assets.m` |
| Transforms | `rigidtform3d`, frame chaining | map → base → laser for scan projection |
| 2D scene | `plot`, patch, custom | Current map view in `matlab_connect_bridge.m` |
| Scan projection | Polar → Cartesian in robot frame | `bridgeScanToXY` pattern |

**Does not own:** Global localization algorithms (that is Navigation Toolbox or ROS AMCL).

**Existing assets:** `matlab/robot/`, `matlab/meshes/`, `ros/.../yahboomcar_description/`

---

### Navigation Toolbox

**Owns:** Map representation and map-based reasoning **inside MATLAB**.

| Responsibility | API / pattern | Notes |
|----------------|---------------|-------|
| Load saved map | `occupancyMap` from `.yaml`/`.pgm` or `/map` | Same grid ROS uses |
| Localize on known map | `monteCarloLocalization` | Alternative to ROS AMCL |
| Plan paths | `plannerAStar`, `plannerRRT`, etc. | Alternative to Nav2 |
| Track + control | `controllerPurePursuit`, etc. | Outputs velocity → `/cmd_vel` |

**Architecture choice:** Navigation Toolbox can **duplicate** ROS slam_toolbox/AMCL/Nav2, or **consume** ROS outputs (subscribe to `/map` + AMCL pose, plan in MATLAB, publish `/cmd_vel`). Recommended split for this repo:

```text
ROS:     build map (slam_toolbox), serve map (map_server), localize (AMCL), plan (Nav2)
MATLAB:  visualize map-frame pose, send goals, optional local replanning via Navigation Toolbox
```

Use Navigation Toolbox actively when you want map logic, goal UI, or planners **in MATLAB** rather than only in RViz/Nav2.

---

### Simulink + Simulink 3D Animation

**Owns:** Time-synchronized co-simulation with **Unreal Engine** (official MathWorks path).

| Responsibility | Pattern | Notes |
|----------------|---------|-------|
| Unreal scene | Simulink 3D Animation / UE plugin | Room mesh + robot actor |
| Pose sync | Simulink blocks driven by MATLAB/ROS pose stream | `map` frame after alignment |
| Optional closed loop | Simulink model → `/cmd_vel` | Same contract as MATLAB scripts |

**Alternative architecture (already started):** Custom TCP/UDP bridge (like `matlab_bridge.py`) into Unreal Blueprints/C++ — no Simulink required, more manual.

```text
Option A (MathWorks):   ROS → MATLAB → Simulink → Simulink 3D Animation → Unreal
Option B (Custom):      ROS → MATLAB → TCP/UDP → Unreal plugin
```

Both options require **map-frame pose** and **Unreal ↔ map calibration**.

---

## Linux / ROS components (not MATLAB toolboxes)

These run on Ubuntu alongside MATLAB and are part of the architecture:

| Component | Role | Repo entry |
|-----------|------|------------|
| micro-ROS UDP agent | ESP ↔ ROS 2 | `scripts/start_agent.sh` |
| ESP firmware | `/scan`, `/odom`, `/cmd_vel` | `esp/.../lidar_publisher/` |
| slam_toolbox | Build or localize on 2D map | `launch/slam_launch.py`, `config/slam_params.yaml` |
| map_server | Serve saved `.yaml`/`.pgm` | Nav2 / yahboomcar_nav launches |
| AMCL | Particle filter localization | `yahboomcar_multi/launch/robot1_amcl_launch.py` |
| Nav2 | Global/local planning → `/cmd_vel` | `yahboomcar_nav/launch/navigation_dwb_launch.py` |
| MATLAB TCP bridge | ROS ↔ MATLAB JSON | `scripts/matlab_bridge.py`, port **8765** |

---

## Data flow — current vs target

### Current (teleop + odom view)

```text
ESP ──/scan,/odom──► agent ──► matlab_bridge.py ──TCP──► matlab_connect_bridge.m
                                    ▲
MATLAB ──cmd JSON──► ────────────────┘ ──► /cmd_vel ──► agent ──► ESP

Plot frame: odom (room position unknown)
```

### Target (blind navigation in scanned room)

```text
ESP ──/scan,/odom──► agent ──► slam_toolbox / AMCL ──► /map, TF map→base
                              │
                              ├──► Nav2 ──► /cmd_vel ──► ESP
                              │
                              └──► matlab_bridge (extended) ──► MATLAB
                                        │                      ├── ROS Toolbox: map + pose
                                        │                      ├── Robotics: URDF + 2D overlay
                                        │                      ├── Navigation: goals / optional planner
                                        └──► Simulink 3D ──► Unreal (aligned room mesh)
```

---

## Component ownership matrix

| Concern | Primary owner | Secondary / alternative |
|---------|---------------|-------------------------|
| Lidar driver | ESP firmware | — |
| Wheel odometry | ESP firmware | — |
| Map building | ROS slam_toolbox | — |
| Map storage | `.yaml` + `.pgm` on disk | `ros/.../maps/` |
| Localization | ROS AMCL (recommended) | Navigation Toolbox `monteCarloLocalization` |
| Path planning | ROS Nav2 (recommended) | Navigation Toolbox planners |
| Low-level drive | `/cmd_vel` | MATLAB, Nav2, or teleop (one at a time) |
| Robot URDF viz | Robotics System Toolbox | Unreal skeletal mesh |
| Room visualization | Unreal (`my_room.fbx`) | MATLAB 3D (optional) |
| Room ↔ map alignment | Manual calibration (config) | Lidar Toolbox ICP (optional, 3D) |
| Operator UI | MATLAB figures | Unreal HUD |
| ROS ↔ MATLAB transport | TCP bridge | ROS Toolbox direct DDS |

---

## Key assets in repo

| Path | Architecture role |
|------|---------------------|
| `matlab/my_room.fbx` | Visual room (Unreal import) |
| `matlab/matlab_connect_bridge.m` | Live odom + scan + teleop (MATLAB UI) |
| `matlab/prepare_robot_assets.m` | URDF/mesh staging for Robotics System Toolbox |
| `scripts/matlab_bridge.py` | ROS 2 ↔ MATLAB transport layer |
| `launch/slam_launch.py` | SLAM + TF + RViz |
| `config/slam_params.yaml` | Frame names, scan topic, SLAM mode |
| `ros/yahboomcar_ws/.../yahboomcar_nav/` | Nav2 + map launches (Yahboom) |
| `ros/yahboomcar_ws/.../maps/` | Example saved occupancy maps |

---

## Architectural decisions (open)

Document choices here as the project evolves:

| Decision | Options | Notes |
|----------|---------|-------|
| Localization runtime | ROS AMCL vs MATLAB MCL | ROS matches existing launches; MATLAB keeps logic in one language |
| Planning runtime | Nav2 vs Navigation Toolbox | Nav2 is production-ready; MATLAB for custom goal UI |
| Unreal link | Simulink 3D Animation vs custom UDP | Simulink = supported; UDP = flexible, already have bridge pattern |
| MATLAB ↔ ROS transport | Extend TCP bridge vs direct DDS | Bridge proven for scan/odom; extend for `/map` + pose |
| Map source | Live SLAM vs pre-scanned grid | SLAM from driving; pre-scan from room survey — must align to Unreal |
| Single `/cmd_vel` source | MATLAB **or** Nav2 **or** teleop | Mutex required — never two publishers |

---

## Related docs

| Doc | Content |
|-----|---------|
| [NATIVE_LINUX_SETUP.md](NATIVE_LINUX_SETUP.md) | Agent, bridge, daily commands |
| [PHASES.md](PHASES.md) | Implementation phases and exit criteria |
| [ROS_WORKSPACE.md](ROS_WORKSPACE.md) | Bundled ROS workspaces |
| [FIRMWARE.md](FIRMWARE.md) | ESP topics and flash |
| [../matlab/README.md](../matlab/README.md) | MATLAB entry points |
