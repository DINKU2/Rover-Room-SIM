"""
DEPRECATED — do not run. Use audit_rover_scene.py instead.

This ghost + RoverVisible + constraint setup caused duplicate rovers and
invisible drivers. See scripts/audit_rover_scene.py.

---
fix_rover_all.py (legacy)

One-shot repair for the common runtime issues:
  1. Two visible rovers  → strip mesh from ghost RoverTwin (Sim3d driver only)
  2. No wall collision   → ensure room meshes BlockAll + complex collision
  3. Spawn outside room  → move all rover actors to room centre (0, 0, floor)
  4. Ghost still visible → HiddenInGame + component hidden
"""
import sys
raise SystemExit("DEPRECATED: run scripts/run_audit_rover_scene.sh instead")

import os
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rover_spawn_pose import spawn_ue_vector

MAP_PATH = "/Game/Maps/MyRoom"
SPAWN_UE = spawn_ue_vector()

GHOST_TAG     = "RoverTwin"
VISIBLE_LABEL = "RoverVisible"
ACTUAL_LABEL  = "RoverActual"
CONSTRAINT_LBL = "RoverConstraint"

unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

# ── 1. Room collision ────────────────────────────────────────────────────────
room_fixed = 0
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    lbl = a.get_actor_label()
    if not lbl.startswith("MyRoom"):
        continue
    for comp in a.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_collision_profile_name("BlockAll")
        comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
        # Use mesh geometry for collision (photogrammetry meshes need this)
        try:
            comp.set_editor_property(
                "collision_complexity",
                unreal.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE,
            )
        except Exception:
            pass
        comp.set_editor_property("mobility", unreal.ComponentMobility.STATIC)
        room_fixed += 1

unreal.log_warning(f"ROOM_COLLISION|parts={room_fixed}")

# Ground plane too
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if a.get_actor_label() == "GroundPlane":
        for comp in a.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
        break

# ── 2. Find rover actors ─────────────────────────────────────────────────────
ghost = visible = actual = constraint = None
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    lbl = a.get_actor_label()
    tags = [str(t) for t in a.tags]
    if GHOST_TAG in tags:
        ghost = a
    elif lbl == VISIBLE_LABEL:
        visible = a
    elif lbl == ACTUAL_LABEL:
        actual = a
    elif lbl == CONSTRAINT_LBL:
        constraint = a

if ghost is None:
    raise RuntimeError("RoverTwin not found — run restore_sim3d_rover.py first")

# ── 3. Move everything to room centre ───────────────────────────────────────
def move_actor(actor, loc):
    if actor is None:
        return
    xform = unreal.Transform(loc, unreal.Rotator(0, 0, 0))
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        was_sim = comp.is_simulating_physics()
        if was_sim:
            comp.set_simulate_physics(False)
        comp.set_world_location(loc, False, True)
        if was_sim:
            comp.set_simulate_physics(True)
        actor.set_actor_transform(xform, False, True)
        return
    actor.set_actor_transform(xform, False, True)

# ── 3. Move ghost to room centre ─────────────────────────────────────────────
move_actor(ghost, SPAWN_UE)

unreal.log_warning(
    f"SPAWN_SET|UE=({SPAWN_UE.x:.0f},{SPAWN_UE.y:.0f},{SPAWN_UE.z:.0f})"
    f"|Simulink_m=[{SPAWN_UE.x/100:.2f}, {-SPAWN_UE.y/100:.2f}, {SPAWN_UE.z/100:.2f}]"
)

# ── 4. Ghost RoverTwin — NO visible mesh, no blocking collision ───────────────
ghost.set_actor_hidden_in_game(True)
for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
    comp.set_visibility(False, True)          # invisible in editor AND game
    comp.set_hidden_in_game(True)
    comp.set_editor_property("static_mesh", None)  # remove mesh → nothing to render
    comp.set_collision_profile_name("NoCollision")
    comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    comp.set_simulate_physics(False)
    comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    break

unreal.log_warning("GHOST_FIXED|mesh=None|hidden=True|collision=NoCollision")

# ── 5. RoverVisible — destroy & recreate at spawn (move doesn't persist) ─────
if visible:
    unreal.EditorLevelLibrary.destroy_actor(visible)
    visible = None
if constraint:
    unreal.EditorLevelLibrary.destroy_actor(constraint)
    constraint = None
if actual:
    unreal.EditorLevelLibrary.destroy_actor(actual)
    actual = None

mesh = unreal.load_asset(
    "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"
)
sma_cls = unreal.load_class(None, "/Script/Engine.StaticMeshActor")
visible = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sma_cls, SPAWN_UE, unreal.Rotator(0, 0, 0)
)
visible.set_actor_label(VISIBLE_LABEL)

for comp in visible.get_components_by_class(unreal.StaticMeshComponent):
    comp.set_editor_property("static_mesh", mesh)
    comp.set_visibility(True, True)
    comp.set_hidden_in_game(False)
    comp.set_collision_profile_name("BlockAll")
    comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
    comp.set_simulate_physics(True)
    comp.set_enable_gravity(False)
    comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    body = comp.get_editor_property("body_instance")
    body.set_editor_property("linear_damping", 20.0)
    body.set_editor_property("angular_damping", 20.0)
    comp.set_editor_property("body_instance", body)
    break

unreal.log_warning(
    f"VISIBLE_RECREATED|loc=({SPAWN_UE.x:.0f},{SPAWN_UE.y:.0f},{SPAWN_UE.z:.0f})|BlockAll|sim=True"
)

# ── 6. RoverActual — invisible pose reporter ────────────────────────────────
sim3d_cls = unreal.load_class(None, "/Script/MathWorksSimulation.Sim3dStaticMeshActor")
actual = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sim3d_cls, SPAWN_UE, unreal.Rotator(0, 0, 0)
)
actual.set_actor_label(ACTUAL_LABEL)
actual.tags = [unreal.Name("RoverActual")]
actual.set_actor_hidden_in_game(True)
for comp in actual.get_components_by_class(unreal.StaticMeshComponent):
    comp.set_editor_property("static_mesh", None)
    comp.set_collision_profile_name("NoCollision")
    comp.set_visibility(False, True)
    break
actual.attach_to_actor(
    visible, "",
    unreal.AttachmentRule.SNAP_TO_TARGET,
    unreal.AttachmentRule.SNAP_TO_TARGET,
    unreal.AttachmentRule.KEEP_RELATIVE,
    False,
)
unreal.log_warning("ACTUAL_RECREATED|attached_to=RoverVisible")

# ── 7. Physics constraint spring ──────────────────────────────────────────────
pca_cls = unreal.load_class(None, "/Script/Engine.PhysicsConstraintActor")
constraint = unreal.EditorLevelLibrary.spawn_actor_from_class(
    pca_cls, SPAWN_UE, unreal.Rotator(0, 0, 0)
)
constraint.set_actor_label(CONSTRAINT_LBL)
cc = constraint.get_component_by_class(unreal.PhysicsConstraintComponent)
cc.set_editor_property("constraint_actor1", ghost)
cc.set_editor_property("constraint_actor2", visible)
cc.set_linear_x_limit(unreal.LinearConstraintMotion.LCM_FREE, 0.0)
cc.set_linear_y_limit(unreal.LinearConstraintMotion.LCM_FREE, 0.0)
cc.set_linear_z_limit(unreal.LinearConstraintMotion.LCM_LOCKED, 0.0)
cc.set_angular_swing1_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
cc.set_angular_swing2_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
cc.set_angular_twist_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
cc.set_linear_drive_params(200.0, 40.0, 5000.0)
cc.set_linear_position_drive(True, True, False)
cc.set_linear_position_target(unreal.Vector(0, 0, 0))
unreal.log_warning("CONSTRAINT_RECREATED|stiffness=200|damping=40")

for name, actor in [("ghost", ghost), ("visible", visible), ("actual", actual), ("constraint", constraint)]:
    if actor:
        loc = actor.get_actor_location()
        unreal.log_warning(f"POST_MOVE|{name}|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})")

# ── 8. Delete any stray duplicate rover mesh actors ───────────────────────────
removed = 0
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    lbl = a.get_actor_label()
    if lbl.startswith("RoverPart_"):
        unreal.EditorLevelLibrary.destroy_actor(a)
        removed += 1

if removed:
    unreal.log_warning(f"DUPLICATES_REMOVED|count={removed}")

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save level")

unreal.log_warning("FIX_ALL_DONE|one_visible_rover|room_collision_on|spawn_in_room")
