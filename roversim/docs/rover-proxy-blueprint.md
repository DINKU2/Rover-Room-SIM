# BP_RoverProxy — Event Tick Blueprint Graph

This is the one manual step you need to do.  It takes under 5 minutes.
Everything else is automated.

---

## Why this is needed

Simulink uses `Transform Set` to **teleport** the `RoverTwin` ghost actor every
20 ms.  Teleporting (`SetActorLocation` without sweep) ignores collision —
the actor jumps to the target regardless of what is in the way.

`BP_RoverProxy` fixes this by reading the ghost position each tick and moving
toward it with **sweep = true**.  When the rover's bounding box hits a wall,
Unreal stops the movement at the contact surface.  The rover never goes through.

---

## Step-by-step in Unreal Editor

### 1. Open the Blueprint

In the **Content Browser**, navigate to `Content/Rover/` and double-click
`BP_RoverProxy`.  The Blueprint editor opens.

### 2. Open the Event Graph

Click the **Event Graph** tab (bottom of the editor).

### 3. Delete the default nodes

Delete `Event BeginPlay` and `Event ActorBeginOverlap` if they are there.

### 4. Add these nodes

Right-click on the graph canvas to open the node search each time.

| # | Node to add | How to find it |
|---|-------------|----------------|
| 1 | `Event Tick` | Already in graph, or search "Event Tick" |
| 2 | `Get All Actors With Tag` | Search "Get All Actors With Tag" |
| 3 | `Get Actor Location` | Search "Get Actor Location" |
| 4 | `Set Actor Location` | Search "Set Actor Location" |
| 5 | `Get Actor Rotation` | Search "Get Actor Rotation" |
| 6 | `Set Actor Rotation` | Search "Set Actor Rotation" |

### 5. Wire the nodes exactly like this

```
[Event Tick]
     |
     └──────────────────────────────────────────────────────┐
                                                            ▼
[Get All Actors With Tag]                         [Set Actor Location]
  Tag = "RoverTwin"                                 Target = self
  Out Actors → Get (index 0) → Actor ref ──┬──►    New Location = (from node 3)
                                           │        Sweep = ✓  (CHECK THIS BOX)
                               ┌───────────┘        ──── exec ────►
                               ▼
                  [Get Actor Location]               [Set Actor Rotation]
                    Target = Actor ref                 Target = self
                    Return Value ──────────────────►  New Rotation = (from node 5)
                                                       Teleport Physics = false

                  [Get Actor Rotation]
                    Target = Actor ref (same)
                    Return Value ────────────────────────────────────►
```

Written linearly:

```
Event Tick
  → Get All Actors With Tag (Tag = "RoverTwin")
  → [0] (first element of the array)
  → Get Actor Location  → Set Actor Location (self, NewLocation, Sweep = TRUE)
  → Get Actor Rotation  → Set Actor Rotation (self, NewRotation)
```

### Critical: make sure Sweep is checked

On the `Set Actor Location` node you will see a **Sweep** pin or checkbox.
It may be hidden — right-click the node → **Add Pin → Sweep** if it is not
visible.  **This must be checked (true).**  Without it the proxy teleports
just like the ghost.

### 6. Compile and Save

Click **Compile** (top-left of Blueprint editor) — it must show a green
checkmark.  Then **Save**.

---

## What the graph looks like

```
┌─────────────┐
│  Event Tick │
└──────┬──────┘
       │ exec
       ▼
┌──────────────────────────┐      ┌──────────────────────────────────┐
│ Get All Actors With Tag  │      │  Set Actor Location              │
│   Tag: "RoverTwin"       │      │    Target: self                  │
│   Out Actors ────────────┼──┐   │    New Location: ◄── (from Get) │
└──────────────────────────┘  │   │    Sweep: ✓ TRUE                 │
                               │   └──────────────┬───────────────────┘
                               │   ┌──────────────▼───────────────────┐
                               │   │  Set Actor Rotation              │
                               │   │    Target: self                  │
                               │   │    New Rotation: ◄── (from Get) │
                               │   └──────────────────────────────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │  Get (index 0)   │ ← first element of array
                      └──────┬───────────┘
                             │
               ┌─────────────┴────────────┐
               ▼                          ▼
   ┌──────────────────────┐   ┌──────────────────────┐
   │  Get Actor Location  │   │  Get Actor Rotation  │
   │  Target: Actor ref   │   │  Target: Actor ref   │
   └──────────────────────┘   └──────────────────────┘
```

---

## After finishing the Blueprint

Run the level setup to spawn the proxy instance:

```bash
bash scripts/run_rover_proxy_setup.sh
```

Or if you just did the Blueprint step after already running the setup:

```bash
# Re-run only the level part (no audit, no BP create)
bash scripts/run_setup_rover_collision.sh   # deprecated; use:
# Open editor manually and Play — the proxy will be in the level already
```

Then in MATLAB:

```matlab
open_rover_control
```

Transform Set still targets `RoverTwin` (ghost — Simulink commands it).
Transform Get now targets `RoverProxy` (the swept actor — actual position).

---

## How to verify it works

1. Start PIE (Play in Editor).
2. In MATLAB run `open_rover_control`, start the sim.
3. Drive toward a wall (W key). The **visible rover should stop** at the wall
   surface. The keyboard control UI may show the commanded position drifting
   past the wall (ghost still moves), but the **actual X/Y** values should
   freeze at the wall.
4. Drive away (S key) — rover should back away normally.

If the rover still passes through walls, the most likely cause is:
- **Sweep not checked** on `Set Actor Location` in the Blueprint.
- **Room mesh has no collision** — check `MyRoom_Part_*` → Details → Collision
  → Collision Preset must be `BlockAll`, not `NoCollision`.
- The Blueprint instance in the level has **mobility set to Static** — it must
  be **Movable**.
