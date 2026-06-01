# Rover-Room-SIM — Implementation Phases

Build order for blind navigation in a scanned room. Each phase has a **goal**, **deliverables**, and **exit criteria**.

See [ARCHITECTURE.md](ARCHITECTURE.md) for system design and toolbox roles.

---

## Overview

```text
Phase 1  Robot link (agent + bridge teleop)     ✓ DONE
Phase 2  MATLAB Toolbox connection (no UI)      ← NEXT
Phase 3  SLAM — build and save 2D map
Phase 4  Localization — pose in map frame
Phase 5  Navigation Toolbox (maps + planning)
Phase 6  Autonomous goals
Phase 7  Unreal room + alignment
Phase 8  Unreal live sync + blind navigation demo
```

| Phase | Primary toolbox / stack | Depends on |
|-------|-------------------------|------------|
| 1 ✓ | Shell + TCP bridge | — |
| 2 | **ROS Toolbox**, **Robotics System Toolbox** | 1 |
| 3 | ROS slam_toolbox | 2 |
| 4 | ROS AMCL + map_server | 3 |
| 5 | Navigation Toolbox | 4 |
| 6 | Nav2 or Navigation Toolbox | 4, 5 |
| 7 | Unreal Editor | 3 or 4 |
| 8 | Simulink 3D Animation or custom UDP | 5, 7 |

---

## Phase 1 — Robot link ✓ DONE

**Goal:** Real robot on the ROS graph; PC can read `/scan`, `/odom` and send `/cmd_vel`.

**Status:** Complete — agent, `check_robot.sh`, TCP bridge, `matlab_connect_bridge` teleop.

| Item | Detail |
|------|--------|
| **Deliverables** | micro-ROS agent; live topics; bridge on port 8765 |
| **Commands** | `./scripts/start_agent.sh`, `./scripts/start_matlab_bridge.sh`, `./scripts/check_robot.sh` |
| **Key files** | `scripts/matlab_bridge.py`, `config/env`, `matlab/matlab_connect_bridge.m` |

**Exit criteria** *(all done)*

- [x] `./scripts/check_robot.sh` shows `/odom`, `/scan`, `/cmd_vel` live
- [x] Robot moves from MATLAB via bridge
- [x] Agent stable on native Linux (`docker.io`, domain 20)

Phase 1 used a **TCP JSON bridge** because MATLAB direct DDS was unreliable. Phase 2 replaces that with **native MATLAB Toolbox** APIs.

---

## Phase 2 — MATLAB Toolbox connection (no visuals) ← NEXT

**Goal:** Talk to the robot using **ROS Toolbox** and **Robotics System Toolbox** only — no figures, no URDF, no Unreal, no map UI.

This phase is **data in / data out**. You should be able to run short scripts that subscribe, print values, and publish velocity without opening any visualization.

| Item | Detail |
|------|--------|
| **Toolboxes** | ROS Toolbox (required), Robotics System Toolbox (transforms + message handling) |
| **Not in scope** | Figures, `importrobot`, RViz, Unreal, Navigation Toolbox, SLAM |
| **Prerequisites** | `./scripts/start_agent.sh` running; robot powered; `setup_ros_dds` or working DDS env |

### What to build

| Component | ROS Toolbox API | Purpose |
|-----------|-----------------|---------|
| Connect | `ros2node`, `setup_ros_dds` | Join ROS 2 graph (domain 20) |
| Read odom | `ros2subscriber(..., 'nav_msgs/Odometry', '/odom')` | `receive()` → position, orientation |
| Read scan | `ros2subscriber(..., 'sensor_msgs/LaserScan', '/scan')` | `receive()` → ranges, angles |
| Write cmd | `ros2publisher(..., 'geometry_msgs/Twist', '/cmd_vel')` | `send()` linear.x, angular.z |
| Transforms | Robotics System Toolbox — `quaternion`, `eul`, `rotm` | Parse odom orientation (no `importrobot`) |

### Suggested repo files

| File | Role |
|------|------|
| `matlab/ros2_robot_node.m` | Create node + subscribers + publisher |
| `matlab/read_odom.m` | One-shot or latest odom struct |
| `matlab/read_scan.m` | One-shot or latest scan struct |
| `matlab/send_cmd_vel.m` | Publish Twist |
| `matlab/ros2_robot_test.m` | Headless test: receive odom + scan, send zero cmd, print OK |

### Tasks

1. Run `setup_ros_dds` (restart MATLAB once if needed).
2. Create `ros2node` and verify `ros2topic list` equivalent shows `/odom`, `/scan`, `/cmd_vel`.
3. `receive()` at least one `/odom` and one `/scan` message — print timestamp, x, y, range count.
4. Publish `/cmd_vel` (start with zeros, then brief test move with robot clear).
5. Confirm **bridge can be stopped** for this test — MATLAB talks to ROS directly, not TCP 8765.

### If direct DDS still fails

Fallback order (still Phase 2 — still toolbox, still no UI):

1. Fix DDS env (`setup_ros_dds`, `ROS_DOMAIN_ID=20`, subnet discovery).
2. If needed, keep bridge running but add thin MATLAB wrappers that call `ros2subscriber` against localhost ROS — **prefer native DDS first**.
3. Document which path works in `matlab/README.md`.

### Exit criteria

- [ ] `ros2_robot_test` passes without `matlab_connect_bridge` or any `figure`
- [ ] Odom x/y updates in a loop for 10 s while robot is moved by hand
- [ ] Scan message received with expected point count (>0 ranges)
- [ ] `send_cmd_vel(0.1, 0)` moves robot briefly; `send_cmd_vel(0, 0)` stops
- [ ] No dependency on TCP port 8765 for Phase 2 scripts

**Done when:** MATLAB Toolboxes are the official robot I/O layer for all later phases.

---

## Phase 3 — SLAM: build and save 2D map

**Goal:** Drive the robot once around the room; save occupancy grid (`.yaml` + `.pgm`).

| Item | Detail |
|------|--------|
| **Stack** | ROS slam_toolbox (not MATLAB yet) |
| **Commands** | `./scripts/run_slam.sh --slam`, teleop, `./scripts/run_slam.sh --save-map` |
| **Key files** | `launch/slam_launch.py`, `config/slam_params.yaml` |

**Exit criteria**

- [ ] Saved map on disk (e.g. `maps/rover_room.yaml`)
- [ ] Walls in map match physical room
- [ ] Phase 2 MATLAB scripts can still read `/scan` while SLAM runs

---

## Phase 4 — Localization: pose in `map` frame

**Goal:** Robot knows room-fixed pose every run (AMCL or slam_toolbox localization).

| Item | Detail |
|------|--------|
| **Stack** | map_server + AMCL |
| **MATLAB** | Phase 2 scripts subscribe to `/amcl_pose` or TF (still no UI required) |

**Exit criteria**

- [ ] TF `map` → `base_footprint` stable in RViz or `tf2_echo`
- [ ] MATLAB can read map-frame pose as numbers (print x, y, yaw)

---

## Phase 5 — Navigation Toolbox

**Goal:** Load saved map into `occupancyMap`; map-based reasoning in MATLAB (still optional UI).

| Item | Detail |
|------|--------|
| **Toolbox** | Navigation Toolbox |
| **Deliverables** | `occupancyMap` from Phase 3 map; optional MCL/planner scripts |

**Exit criteria**

- [ ] `occupancyMap` loads from saved `.yaml`/`.pgm`
- [ ] Map-frame pose from Phase 4 usable inside Navigation Toolbox workflows

---

## Phase 6 — Autonomous goals

**Goal:** Send goal in map frame; robot drives without teleop.

| Option | Stack |
|--------|-------|
| A | Nav2 → `/cmd_vel` |
| B | Navigation Toolbox planner → Phase 2 `send_cmd_vel` |

**Exit criteria**

- [ ] Robot reaches test goals; single `/cmd_vel` publisher during autonomous run

---

## Phase 7 — Unreal room + alignment

**Goal:** Import `matlab/my_room.fbx`; calibrate Unreal origin to ROS `map`.

**Exit criteria**

- [ ] Known map coordinates match Unreal positions
- [ ] Calibration saved (e.g. `config/unreal_map_calibration.yaml`)

---

## Phase 8 — Unreal sync + blind navigation demo

**Goal:** Unreal tracks real robot; operator navigates without line-of-sight.

| Item | Detail |
|------|--------|
| **Toolboxes** | Simulink + Simulink 3D Animation **or** custom UDP from Phase 2 pose stream |

**Exit criteria**

- [ ] Unreal actor follows real robot in aligned room
- [ ] Full demo: goal → autonomous drive → arrive, view in Unreal/MATLAB only

---

## Phase checklist

| Phase | Status | Done when |
|-------|--------|-----------|
| 1 | ✓ Done | Agent + bridge teleop works |
| 2 | **Next** | ROS Toolbox read/write, no UI, no bridge |
| 3 | | Saved SLAM map |
| 4 | | Map-frame pose in MATLAB |
| 5 | | `occupancyMap` loaded |
| 6 | | Autonomous goal reached |
| 7 | | Unreal aligned to map |
| 8 | | Blind navigation demo |

---

## Related docs

| Doc | Content |
|-----|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Toolboxes, topics, frames |
| [NATIVE_LINUX_SETUP.md](NATIVE_LINUX_SETUP.md) | Agent, bridge, daily commands |
| [../matlab/README.md](../matlab/README.md) | MATLAB entry points |
