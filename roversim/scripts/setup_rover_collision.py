"""
setup_rover_collision.py — Unreal physics wall collision for RoverTwin.

Simulink still teleports the invisible RoverTwin ghost (Transform Set tag=RoverTwin).
A visible physics rover (RoverVisible) follows via a spring constraint and stops
at room walls (BlockAll on photogrammetry meshes + rover).

Run after audit_rover_scene.py (which creates the Sim3dStaticMeshActor ghost).
"""
import os
import sys
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rover_spawn_pose import spawn_ue_vector

MAP_PATH = "/Game/Maps/MyRoom"
MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"

GHOST_TAG = "RoverTwin"
VISIBLE_LABEL = "RoverVisible"
CONSTRAINT_LABEL = "RoverConstraint"

SPRING_STIFFNESS = 80000.0
SPRING_DAMPING = 4000.0
SPRING_MAX_FORCE = 300000.0


def actor_tags(actor):
    return [str(t) for t in actor.tags]


def ensure_room_collision():
    fixed = 0
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        lbl = a.get_actor_label()
        if not (lbl.startswith("MyRoom") or lbl == "GroundPlane"):
            continue
        for comp in a.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
            try:
                comp.set_editor_property(
                    "collision_complexity",
                    unreal.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE,
                )
            except Exception:
                pass
            fixed += 1
    unreal.log_warning(f"ROOM_COLLISION|components={fixed}")


def find_ghost():
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        if GHOST_TAG in actor_tags(a):
            return a
    return None


def destroy_labeled(label):
    for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if a.get_actor_label() == label:
            unreal.EditorLevelLibrary.destroy_actor(a)


def configure_ghost(ghost):
    ghost.set_actor_hidden_in_game(True)
    root = ghost.get_editor_property("root_component")
    if root is not None:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_visibility(True, True)
        comp.set_hidden_in_game(True)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_collision_profile_name("OverlapAll")
        comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        break
    unreal.log_warning("GHOST_COLLISION|hidden_in_game=True|collision=OverlapAll|sim=False")


def create_visible_rover(location):
    mesh = unreal.load_asset(MESH_PATH)
    if mesh is None:
        raise RuntimeError(f"Cannot load mesh: {MESH_PATH}")

    sma_cls = unreal.load_class(None, "/Script/Engine.StaticMeshActor")
    visible = unreal.EditorLevelLibrary.spawn_actor_from_class(
        sma_cls, location, unreal.Rotator(0, 0, 0)
    )
    if visible is None:
        raise RuntimeError("Failed to spawn RoverVisible")

    visible.set_actor_label(VISIBLE_LABEL)
    visible.set_actor_hidden_in_game(False)

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
        body.set_editor_property("linear_damping", 25.0)
        body.set_editor_property("angular_damping", 25.0)
        comp.set_editor_property("body_instance", body)
        break

    loc = visible.get_actor_location()
    unreal.log_warning(
        f"ROVER_VISIBLE|label={VISIBLE_LABEL}|collision=BlockAll|sim=True"
        f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
    )
    return visible


def create_constraint(ghost, visible, location):
    pca_cls = unreal.load_class(None, "/Script/Engine.PhysicsConstraintActor")
    constraint = unreal.EditorLevelLibrary.spawn_actor_from_class(
        pca_cls, location, unreal.Rotator(0, 0, 0)
    )
    if constraint is None:
        raise RuntimeError("Failed to spawn RoverConstraint")

    constraint.set_actor_label(CONSTRAINT_LABEL)
    cc = constraint.get_component_by_class(unreal.PhysicsConstraintComponent)
    cc.set_editor_property("constraint_actor1", ghost)
    cc.set_editor_property("constraint_actor2", visible)

    cc.set_linear_x_limit(unreal.LinearConstraintMotion.LCM_FREE, 0.0)
    cc.set_linear_y_limit(unreal.LinearConstraintMotion.LCM_FREE, 0.0)
    cc.set_linear_z_limit(unreal.LinearConstraintMotion.LCM_LOCKED, 0.0)

    cc.set_angular_swing1_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
    cc.set_angular_swing2_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)
    cc.set_angular_twist_limit(unreal.AngularConstraintMotion.ACM_LOCKED, 0.0)

    cc.set_linear_drive_params(SPRING_STIFFNESS, SPRING_DAMPING, SPRING_MAX_FORCE)
    cc.set_linear_position_drive(True, True, False)
    cc.set_linear_position_target(unreal.Vector(0, 0, 0))

    unreal.log_warning(
        f"ROVER_CONSTRAINT|stiffness={SPRING_STIFFNESS}|damping={SPRING_DAMPING}"
        f"|max_force={SPRING_MAX_FORCE}"
    )
    return constraint


def sync_visible_to_ghost(ghost, visible):
    loc = ghost.get_actor_location()
    rot = ghost.get_actor_rotation()
    for comp in visible.get_components_by_class(unreal.StaticMeshComponent):
        was_sim = comp.is_simulating_physics()
        if was_sim:
            comp.set_simulate_physics(False)
        visible.set_actor_location_and_rotation(loc, rot, False, True)
        if was_sim:
            comp.set_simulate_physics(True)
        break


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

ensure_room_collision()

ghost = find_ghost()
if ghost is None:
    raise RuntimeError(
        f"{GHOST_TAG} not found — run scripts/run_audit_rover_scene.sh first"
    )

ghost_loc = ghost.get_actor_location()
unreal.log_warning(
    f"GHOST_FOUND|label={ghost.get_actor_label()}|class={ghost.get_class().get_name()}"
    f"|loc=({ghost_loc.x:.0f},{ghost_loc.y:.0f},{ghost_loc.z:.0f})"
)

configure_ghost(ghost)

destroy_labeled(VISIBLE_LABEL)
destroy_labeled(CONSTRAINT_LABEL)

visible = create_visible_rover(ghost_loc)
sync_visible_to_ghost(ghost, visible)
create_constraint(ghost, visible, ghost_loc)

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom")

unreal.log_warning(
    "COLLISION_SETUP_DONE|Simulink drives hidden RoverTwin ghost; "
    "RoverVisible uses BlockAll physics and stops at walls."
)
