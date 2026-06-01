# Rover-Room-SIM — Simulink + ROS + Unreal Blueprint

**Goal:** Build the official MathWorks chain:

```text
ROS 2 (robot) → Simulink (timed model) → Simulink 3D Animation → Unreal
```

Optional **Stateflow** chart for behavior-tree-style mission logic.

**Stack:** Ubuntu 22.04, ROS 2 Humble, MATLAB **R2024b**, `ROS_DOMAIN_ID=20`, topics `/odom`, `/scan`, `/cmd_vel`.

---

## Part 0 — Before you open Simulink

### Products to verify

MATLAB → **Home → Add-Ons → Manage Add-Ons**

| Product | Why |
|---------|-----|
| Simulink | Models and blocks |
| ROS Toolbox | ROS Subscribe / Publish blocks |
| Simulink 3D Animation | Unreal link (later) |
| Robotics System Toolbox | URDF / geometry helpers (optional) |

### Every session (terminal)

```bash
cd ~/Desktop/project/Rover-Room-SIM
source ./setup.bash
./scripts/start_agent.sh
./scripts/check_robot.sh    # must show /odom and /scan live
```

### Launch MATLAB (R2024b — Humble)

```bash
./scripts/matlab_r2024b.sh
```

In MATLAB once per session:

```matlab
cd('/home/dinuk/Desktop/project/Rover-Room-SIM/matlab')
setup_ros_humble()
```

### Safety rule

Only **one** publisher on `/cmd_vel` at a time:

- Simulink **or** `matlab_connect` teleop **or** `./scripts/run_teleop.sh` — never two together.

---

## Part 1 — Model 1: ROS I/O only (do this first)

**Purpose:** Prove Simulink receives odom and can publish `cmd_vel`.

### 1.1 Create the model

1. MATLAB Command Window: `simulink`
2. **Blank Model** → Save as `Rover-Room-SIM/simulink/rover_ros_io.slx`

### 1.2 Model configuration (required)

1. **Modeling → Model Settings** (Ctrl+E)
2. **Solver**
   - Type: **Fixed-step**
   - Fixed-step size: `0.1` (10 Hz; matches teleop timer in `matlab_connect.m`)
3. OK

### 1.3 Open ROS block library

1. Simulink → **Library Browser** (Ctrl+Shift+L)
2. Search: **ROS** or **ROS Toolbox**
3. Expected blocks:
   - **Subscribe** (ROS 2)
   - **Publish** (ROS 2)
   - **Blank Message** (optional)
   - **ROS 2 Network Setup** (optional — one per model)

If blocks are missing: install or license ROS Toolbox.

### 1.4 Drag blocks — Subscribe `/odom`

| Step | Action |
|------|--------|
| 1 | Drag **Subscribe** onto canvas |
| 2 | Double-click → **Topic**: `/odom` |
| 3 | **Message type**: `nav_msgs/Odometry` |
| 4 | **Sample time**: `-1` (inherit) or `0.1` |
| 5 | QoS (if shown): **Reliability** = `reliable`, **Durability** = `volatile`, **Depth** = `10` |

### 1.5 Debug odom with scopes

From **Simulink → Commonly Used Blocks** or **Sinks**:

| Block | Wire from odom |
|-------|----------------|
| **Bus Selector** | Full odom message bus |
| **Scope** (×2) | `pose.pose.position.x`, `pose.pose.position.y` |

**Bus Selector:** use **Select Signals** → `pose` → `pose` → `position` → `x` / `y`.

Alternative: **MATLAB Function** block returning `msg.pose.pose.position.x` if bus wiring is awkward on the first try.

### 1.6 Subscribe `/scan` (optional in Model 1)

| Setting | Value |
|---------|--------|
| Topic | `/scan` |
| Type | `sensor_msgs/LaserScan` |
| QoS | **besteffort**, volatile, depth 10 |

Add **Scope** on `ranges` (large vector — or scope `range_min` first to verify connection).

### 1.7 Publish `/cmd_vel` (safe test — zeros only)

| Step | Action |
|------|--------|
| 1 | Drag **Publish** |
| 2 | Topic `/cmd_vel`, type `geometry_msgs/Twist` |
| 3 | QoS: reliable, volatile |
| 4 | **Constant** blocks → `linear.x = 0`, `angular.z = 0` |

Wire constants into Twist fields ( **Bus Assignment** or Publish block field mapping).

Do **not** use nonzero velocity until Model 1 passes with zeros.

### 1.8 ROS network / domain

- Run `setup_ros_humble` before simulation
- If the model has **ROS 2 Network Setup**: domain **20**, RMW **fastrtps** (match `matlab/setup_ros_humble.m`)
- Or: **MATLAB → Preferences → ROS Toolbox** → domain 20

### 1.9 Run Model 1

1. Robot on, agent running
2. Simulink **Run** (▶)
3. Scopes: x/y change when you push the robot
4. Stop simulation — robot should not move (cmd = 0)

**Exit criteria:** Live odom in scopes; publish works; no errors in Diagnostic Viewer.

---

## Part 2 — Model 2: Small motion test from Simulink

**Purpose:** Brief forward command with a guard (switch or Stateflow).

### 2.1 Pulsed or switched cmd

Use **Manual Switch** + **Constant** blocks:

- Default: `linear.x = 0`
- When enabled: `linear.x = 0.1` for a short test

Or **MATLAB Function**:

```matlab
function [vx, wz] = cmd_logic(enable)
vx = 0;
wz = 0;
if enable > 0.5
    vx = 0.1;  % slow forward — clear area first
end
end
```

### 2.2 Run checklist

- Clear area around robot
- Enable → Run ~2 s → disable → zeros
- **Stop:** Simulink Stop; shell `ros2 topic pub /cmd_vel geometry_msgs/msg/Twist "{}"` if needed

---

## Part 3 — Stateflow behavior tree (visual logic)

**Purpose:** Visual mission modes before Unreal.

### 3.1 Add Stateflow

1. Library Browser → **Stateflow** → **Chart**
2. Drag **Chart** → name `MissionBT`

### 3.2 Starter states

```text
                    [Idle]
                      |
          +-----------+-----------+
          |                       |
      [Manual]                  [Auto]
   (vx=0, wz=0;                [Navigate]
    teleop elsewhere)               |
                              [Stuck?] --> [Recover] --> [Navigate]
                                    |
                              [E_Stop] --> [Idle]
```

| State | Outputs |
|-------|---------|
| **Idle** | vx=0, wz=0 |
| **Manual** | vx=0, wz=0 |
| **Auto** | planner or test constants |
| **E_Stop** | vx=0, wz=0 |

### 3.3 Wire chart → Publish

- Chart outputs: `vx`, `wz` (double)
- Map to Publish: `linear.x`, `angular.z`

### 3.4 Inputs from ROS (later)

- Odom → stuck detector (position unchanged for N seconds)
- Scan → `min(ranges)` &lt; threshold → **Recover**

### 3.5 Visualize active state

- **Simulation → Stateflow animation** (highlights active state)
- Optional: **Display** block or debug String on canvas

---

## Part 4 — Model 4: All ROS inputs on one canvas

**Purpose:** One diagram — all sensors in, one cmd out.

### 4.1 Layout (left → right)

```text
[ROS Subscribe /odom]  ──┐
[ROS Subscribe /scan]  ──┼──► [Stateflow MissionBT] ──► [ROS Publish /cmd_vel]
[ROS Subscribe /map]   ──┤         ▲
 (after SLAM)           ──┘    [Scopes / Displays]
[ROS Subscribe /amcl_pose] ──┘   (after AMCL)
```

| Block | Topic | When |
|-------|-------|------|
| Subscribe | `/odom` | Now |
| Subscribe | `/scan` | Now |
| Subscribe | `/map` | After `run_slam.sh --save-map` + map_server |
| Subscribe | `/amcl_pose` | After AMCL |
| Publish | `/cmd_vel` | Now |

### 4.2 QoS (match `matlab/robot_ros_subscriber.m`)

| Topic | Reliability | Durability |
|-------|-------------|------------|
| `/odom` | reliable | volatile |
| `/scan` | **besteffort** | volatile |
| `/cmd_vel` | reliable | volatile |

---

## Part 5 — Simulink 3D Animation → Unreal (official path)

**Prerequisites:** Models 1–3 work; **map-frame pose** for room alignment (not odom-only long term).

### 5.1 MathWorks setup (R2024b — follow current docs)

1. Install **Simulink 3D Animation**
2. Install supported **Unreal Engine** version (see MathWorks compatibility list)
3. Install **Simulink 3D Animation** plugin in your Unreal project
4. Import room mesh (e.g. `my_room.fbx`)
5. Link **Simulation 3D** actor to plugin

### 5.2 Simulink side

1. Add **Simulation 3D** blocks (Simulink 3D Animation library)
2. Inputs each step: **x, y, z, yaw** (from odom or map pose)
3. **Co-simulation:** Simulink ↔ Unreal at same fixed step as Model 1 (`0.1` s)

### 5.3 Calibration (required)

Record alignment between **SLAM map origin** and **Unreal level origin**:

- Offset X, Y, yaw
- Scale (meters per Unreal unit if not 1:1)

Without calibration, the robot will look wrong in UE while ROS is correct.

### 5.4 Data flow

```text
/odom or /amcl_pose → Simulink Subscribe → map/UE transform → 3D Animation → Unreal actor
```

See also [ARCHITECTURE.md](ARCHITECTURE.md) (Option A vs custom UDP).

---

## Part 6 — Relation to existing MATLAB scripts

| Working today | Simulink equivalent |
|---------------|---------------------|
| `ros_test` / `ros_connect` | Subscribe + Publish blocks |
| `ros_sub_read` | Subscribe output each timestep |
| `matlab_connect` teleop | **Manual** mode only — do not run with Simulink publishing |
| `setup_ros_humble` | Run before `sim('rover_ros_io')` |

Helper script:

```matlab
run_simulink_ros   % in matlab/ — setup + optional sim()
```

---

## Part 7 — Troubleshooting

| Problem | Check |
|---------|--------|
| No data in Scope | Agent running? `check_robot.sh`? `setup_ros_humble`? Domain 20? |
| Subscribe fails on `/scan` | QoS = **besteffort** |
| Robot jerks | Only one `/cmd_vel` publisher |
| Model won't start | Fixed-step solver? Valid sample times? |
| Works in `ros_test` but not Simulink | ROS Toolbox Preferences; restart MATLAB |

---

## Part 8 — Repo layout

```text
Rover-Room-SIM/
  simulink/
    rover_ros_io.slx          ← Model 1–2 (you create in GUI)
    rover_mission_bt.slx      ← Model 3–4
    rover_unreal_cosim.slx    ← Model 5
  matlab/
    run_simulink_ros.m        ← setup_ros_humble + sim helper
    setup_ros_humble.m
  docs/
    SIMULINK_ROS_BLUEPRINT.md ← this file
```

---

## Part 9 — Build order checklist

- [ ] Verify Add-Ons: Simulink, ROS Toolbox, Simulink 3D Animation (for Unreal later)
- [ ] Model 1: Subscribe odom → Scope; Publish cmd_vel zeros → Run
- [ ] Model 2: Brief forward test with Manual Switch
- [ ] Model 3: Stateflow Idle / Auto / E_Stop
- [ ] SLAM → add `/map` subscribe
- [ ] AMCL → add pose subscribe; calibrate Unreal
- [ ] Model 5: 3D Animation + Unreal co-simulation

---

## Part 10 — You vs automation

| Task | You (Simulink / UE GUI) | Agent / scripts |
|------|-------------------------|-----------------|
| Drag blocks, wire, run | Yes | — |
| Save `.slx` | Yes | Starter models via build scripts (optional) |
| Stateflow design | Yes | Guidance in this doc |
| Unreal plugin | Yes | Instructions in Part 5 |

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) — system design, Simulink vs UDP to Unreal
- [matlab/README.md](../matlab/README.md) — native Humble DDS connection
- [NATIVE_LINUX_SETUP.md](NATIVE_LINUX_SETUP.md) — agent and daily commands
- MathWorks: [Get Started with ROS 2](https://www.mathworks.com/help/ros/ug/get-started-with-ros-2.html)
- MathWorks: Simulink 3D Animation + Unreal (see help for your release)

---

**Start here:** Complete **Part 1** in one session. When scopes show moving odom, continue to Part 2.
