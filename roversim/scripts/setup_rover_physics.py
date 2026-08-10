"""
DEPRECATED — do not run. Use audit_rover_scene.py instead.
---
setup_rover_physics.py

Implements physics-based collision for the rover WITHOUT Blueprint event graphs.

Architecture:
  RoverTwin  (Sim3dStaticMeshActor, HIDDEN)  ← Simulink teleports this (ghost)
       |
   [PhysicsConstraintActor – linear spring X/Y, locked Z & rotation]
       |
  RoverVisible (StaticMeshActor, VISIBLE, simulate_physics=true, BlockAll)
       → Unreal physics moves it toward ghost each frame
       → Wall collision stops it naturally

No Simulink model changes needed.  The ghost is still "RoverTwin"; the
Physics constraint adds the visible, collision-respecting rover on top.
"""
import sys
raise SystemExit("DEPRECATED: run scripts/run_audit_rover_scene.sh instead")

import unreal

MAP_PATH  = "/Game/Maps/MyRoom"
MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"

GHOST_TAG  = "RoverTwin"
VISIBLE_LBL = "RoverVisible"
CONSTRAINT_LBL = "RoverConstraint"

# Stiffness / damping for the position spring (tune if rover oscillates)
SPRING_STIFFNESS   = 50000.0   # UE units (cm/s²·kg)
SPRING_DAMPING     = 2000.0
SPRING_MAX_FORCE   = 200000.0

unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

# ──────────────────────────────────────────────
# 1. Find the existing ghost (RoverTwin) actor
# ──────────────────────────────────────────────
ghost = None
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if GHOST_TAG in [str(t) for t in a.tags]:
        ghost = a
        break

if ghost is None:
    raise RuntimeError("RoverTwin actor not found – run restore_sim3d_rover.py first")

ghost_loc = ghost.get_actor_location()
unreal.log_warning(
    f"GHOST_FOUND|label={ghost.get_actor_label()}"
    f"|class={ghost.get_class().get_name()}"
    f"|loc=({ghost_loc.x:.0f},{ghost_loc.y:.0f},{ghost_loc.z:.0f})"
)

# Hide ghost during game via the Actor's bHiddenInGame flag.
# Also change collision to OverlapAll so the ghost can teleport through walls
# without physically pushing the RoverVisible physics actor.
ghost.set_actor_hidden_in_game(True)
for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
    # OverlapAll: keeps a physics body (kinematic) so the PhysicsConstraint can
    # anchor to the ghost, but does NOT physically block RoverVisible.
    comp.set_collision_profile_name("OverlapAll")
    break
unreal.log_warning("GHOST_HIDDEN|bHiddenInGame=True, collision=OverlapAll")

# ──────────────────────────────────────────────
# 2. Skip if RoverVisible already exists
# ──────────────────────────────────────────────
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if a.get_actor_label() == VISIBLE_LBL:
        unreal.log_warning("ALREADY_SETUP|RoverVisible exists – skipping creation")
        raise SystemExit(0)

# ──────────────────────────────────────────────
# 3. Create the visible physics rover
# ──────────────────────────────────────────────
mesh = unreal.load_asset(MESH_PATH)
if mesh is None:
    raise RuntimeError(f"Cannot load mesh: {MESH_PATH}")

sma_cls = unreal.load_class(None, "/Script/Engine.StaticMeshActor")
rover_visible = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sma_cls, ghost_loc, unreal.Rotator(0, 0, 0)
)
rover_visible.set_actor_label(VISIBLE_LBL)

mc = rover_visible.get_component_by_class(unreal.StaticMeshComponent)
mc.set_editor_property("static_mesh", mesh)
mc.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)

# BlockAll → collides with WorldStatic walls/floor
mc.set_collision_profile_name("BlockAll")

# Enable Unreal physics simulation so the constraint can push/pull it
mc.set_simulate_physics(True)           # UPrimitiveComponent::SetSimulatePhysics()

# No gravity: Z axis is locked by the constraint at ghost height
mc.set_enable_gravity(False)            # UPrimitiveComponent::SetEnableGravity()

# High linear/angular damping to prevent oscillation or spinning
body = mc.get_editor_property("body_instance")
body.set_editor_property("linear_damping", 20.0)
body.set_editor_property("angular_damping", 20.0)
mc.set_editor_property("body_instance", body)

unreal.log_warning(
    f"ROVER_VISIBLE_CREATED"
    f"|loc=({ghost_loc.x:.0f},{ghost_loc.y:.0f},{ghost_loc.z:.0f})"
)

# ──────────────────────────────────────────────
# 4. Create the PhysicsConstraintActor spring
# ──────────────────────────────────────────────
pca_cls = unreal.load_class(None, "/Script/Engine.PhysicsConstraintActor")
constraint_actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
    pca_cls, ghost_loc, unreal.Rotator(0, 0, 0)
)
constraint_actor.set_actor_label(CONSTRAINT_LBL)

cc = constraint_actor.get_component_by_class(unreal.PhysicsConstraintComponent)

# Wire actors
cc.set_editor_property("constraint_actor1", ghost)
cc.set_editor_property("constraint_actor2", rover_visible)

# Linear: FREE in X and Y (spring drives rover toward ghost), LOCKED in Z
cc.set_linear_x_limit(unreal.LinearConstraintMotion.LCM_FREE, 0.0)
cc.set_linear_y_limit(unreal.LinearConstraintMotion.LCM_FREE, 0.0)
cc.set_linear_z_limit(unreal.LinearConstraintMotion.LCM_LOCKED, 0.0)

# Angular: LOCKED so rover matches ghost rotation exactly
cc.set_angular_swing1_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
cc.set_angular_swing2_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
cc.set_angular_twist_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)

# Linear position drive: pulls RoverVisible toward ghost each physics tick
cc.set_linear_drive_params(SPRING_STIFFNESS, SPRING_DAMPING, SPRING_MAX_FORCE)
cc.set_linear_position_drive(True, True, False)  # X drive, Y drive, Z drive

# Target (0,0,0) in constraint local frame = match the ghost's position exactly
cc.set_linear_position_target(unreal.Vector(0, 0, 0))

unreal.log_warning(
    f"CONSTRAINT_CREATED"
    f"|stiffness={SPRING_STIFFNESS}|damping={SPRING_DAMPING}"
    f"|max_force={SPRING_MAX_FORCE}"
)

# ──────────────────────────────────────────────
# 5. Save level
# ──────────────────────────────────────────────
if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save level")
unreal.log_warning("LEVEL_SAVED|OK")
unreal.log_warning(
    "SETUP_COMPLETE|"
    "Ghost(RoverTwin) is invisible + teleported by Simulink. "
    "RoverVisible follows via physics spring — stops at walls."
)
