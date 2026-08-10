"""
setup_disable_collision.py — Single visible RoverTwin, collision off.

Removes proxy/sweep stack (RoverProxy, RoverProxyFeedback, RoverSweepDriver).
Removes MyRoomBoundary_* perimeter walls (no longer needed with collision off).
Ensures one visible Sim3dStaticMeshActor tagged RoverTwin.
Room meshes set to NoCollision (visual only).

Run: bash scripts/run_disable_collision.sh
Or via Unreal MCP editor_run_python with this file path.
"""
import os
import sys
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rover_spawn_pose import sim_m_from_ue_cm, spawn_ue_vector

MAP_PATH = "/Game/Maps/MyRoom"
MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"
ROVER_TAG = "RoverTwin"
ROVER_LABEL = "RoverTwin"
SPAWN_UE = spawn_ue_vector()
ROVER_MESH_NAME = "SM_Rover_Combined"
REMOVE_LABELS = {
    "Rover",
    "RoverVisible",
    "RoverConstraint",
    "RoverActual",
    "RoverProxy",
    "RoverProxyFeedback",
    "RoverSweepDriver",
    "StaticMeshActorRoverTwin",
    "SpawnDebugOrb",
}


def actor_tags(actor):
    return [str(t) for t in actor.tags]


def has_rover_mesh(actor):
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        mesh = comp.get_editor_property("static_mesh")
        if mesh is None:
            continue
        name = mesh.get_name()
        path = mesh.get_path_name()
        if ROVER_MESH_NAME in name or ROVER_MESH_NAME in path:
            return True
    return False


def is_rover_candidate(actor):
    lbl = actor.get_actor_label()
    cls = actor.get_class().get_name()
    tags = actor_tags(actor)
    if lbl in REMOVE_LABELS:
        return True
    if ROVER_TAG in tags and lbl != ROVER_LABEL:
        return True
    if lbl == ROVER_LABEL:
        return True
    if "rover" in lbl.lower() and cls in ("StaticMeshActor", "Sim3dStaticMeshActor"):
        return True
    if has_rover_mesh(actor) and lbl != ROVER_LABEL:
        return True
    if cls == "Sim3dStaticMeshActor" and lbl != ROVER_LABEL:
        return True
    return False


def is_room_mesh_actor(actor):
    lbl = actor.get_actor_label()
    if lbl.startswith("MyRoom") or lbl == "GroundPlane":
        return True
    if not isinstance(actor, unreal.StaticMeshActor):
        return False
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        mesh = comp.get_editor_property("static_mesh")
        if mesh is None:
            continue
        path = mesh.get_path_name().lower()
        if "myroom" in path or "my_room" in path:
            return True
    return False


def set_no_collision(comp):
    comp.set_collision_profile_name("NoCollision")
    comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)


def is_boundary_actor(actor):
    lbl = actor.get_actor_label()
    tags = actor_tags(actor)
    if lbl.startswith("MyRoomBoundary"):
        return True
    if "MyRoomBoundary" in tags:
        return True
    return False


def remove_boundary_actors():
    removed = []
    for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if not is_boundary_actor(a):
            continue
        lbl = a.get_actor_label()
        unreal.EditorLevelLibrary.destroy_actor(a)
        removed.append(lbl)
    unreal.log_warning(f"BOUNDARY_REMOVE|count={len(removed)}")
    return removed


def configure_visible_rover(rover, mesh):
    rover.set_actor_label(ROVER_LABEL)
    rover.tags = [unreal.Name(ROVER_TAG)]
    rover.set_actor_hidden_in_game(False)

    root = rover.get_editor_property("root_component")
    if root is not None:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)

    for comp in rover.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_editor_property("static_mesh", mesh)
        comp.set_visibility(True, True)
        comp.set_hidden_in_game(False)
        set_no_collision(comp)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        break


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

room_count = 0
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if not is_room_mesh_actor(a):
        continue
    room_count += 1
    for comp in a.get_components_by_class(unreal.StaticMeshComponent):
        set_no_collision(comp)

unreal.log_warning(f"ROOM_COLLISION|disabled|room_actors={room_count}")

remove_boundary_actors()

removed = []
for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
    if not is_rover_candidate(a):
        continue
    lbl = a.get_actor_label()
    cls = a.get_class().get_name()
    loc = a.get_actor_location()
    unreal.log_warning(
        f"ROVER_REMOVE|label={lbl}|class={cls}|tags={actor_tags(a)}"
        f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
    )
    unreal.EditorLevelLibrary.destroy_actor(a)
    removed.append(lbl)

unreal.log_warning(f"ROVER_PURGE|removed={len(removed)}|labels={removed}")

mesh = unreal.load_asset(MESH_PATH)
if mesh is None:
    raise RuntimeError(f"Cannot load mesh: {MESH_PATH}")

sim3d_cls = unreal.load_class(None, "/Script/MathWorksSimulation.Sim3dStaticMeshActor")
if sim3d_cls is None:
    raise RuntimeError("Sim3dStaticMeshActor class not found — is MathWorksSimulation enabled?")

rover = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sim3d_cls, SPAWN_UE, unreal.Rotator(0, 0, 0)
)
if rover is None:
    raise RuntimeError("Failed to spawn Sim3dStaticMeshActor")

configure_visible_rover(rover, mesh)

loc = rover.get_actor_location()
sim_m = sim_m_from_ue_cm((loc.x, loc.y, loc.z))
unreal.log_warning(
    f"ROVER_READY|label={ROVER_LABEL}|tag={ROVER_TAG}|class=Sim3dStaticMeshActor"
    f"|visible=True|collision=NoCollision|sim3d=OK"
    f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
    f"|sim_m=({sim_m[0]:.2f},{sim_m[1]:.2f},{sim_m[2]:.2f})"
)

sim3d_count = sum(
    1
    for a in unreal.EditorLevelLibrary.get_all_level_actors()
    if a.get_class().get_name() == "Sim3dStaticMeshActor"
)
rover_mesh_count = sum(
    1
    for a in unreal.EditorLevelLibrary.get_all_level_actors()
    if has_rover_mesh(a)
)
tagged = sum(
    1
    for a in unreal.EditorLevelLibrary.get_all_level_actors()
    if ROVER_TAG in actor_tags(a)
)

unreal.log_warning(
    f"DISABLE_COLLISION_COUNTS|sim3d_static_mesh={sim3d_count}"
    f"|rover_mesh_actors={rover_mesh_count}|tagged_RoverTwin={tagged}"
)

if tagged != 1:
    raise RuntimeError(
        f"Setup failed: expected exactly 1 actor tagged {ROVER_TAG}, got tagged={tagged}"
    )
if rover_mesh_count != 1:
    raise RuntimeError(
        f"Setup failed: expected exactly 1 rover mesh actor, got {rover_mesh_count}"
    )

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom")

unreal.log_warning("DISABLE_COLLISION_DONE|one_visible_RoverTwin|sweep_off|room_NoCollision")
