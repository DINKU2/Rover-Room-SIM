"""
setup_rover_proxy_level.py — Level setup for swept-collision rover architecture.

Architecture (the correct one):
  RoverTwin  (Sim3dStaticMeshActor, HIDDEN, NoCollision, Movable)
      Simulink Transform Set teleports this ghost every 20 ms.

  BP_RoverProxy  (Blueprint Actor, VISIBLE, BlockAll, NO physics sim)
      Event Tick: SetActorLocation(ghost_pos, sweep=True)
                  SetActorRotation(ghost_rot)
      Sweep=True means Unreal stops the rover at the wall surface.
      Tagged "RoverProxy" so Simulink Transform Get reads its ACTUAL position.

  Room meshes  BlockAll + ComplexAsSimple  (photogrammetry walls are solid)

No PhysicsConstraint spring needed.  Sweep handles collision directly.

Run AFTER create_rover_proxy_bp.py and AFTER the user has added the
Event Tick graph to BP_RoverProxy (see docs/rover-proxy-blueprint.md).
"""
import os
import sys
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rover_spawn_pose import spawn_ue_vector

MAP_PATH = "/Game/Maps/MyRoom"
GHOST_TAG = "RoverTwin"
PROXY_LABEL = "RoverProxy"
PROXY_TAG = "RoverProxy"
BP_PATH = "/Game/Rover/BP_RoverProxy.BP_RoverProxy_C"

REMOVE_LABELS = {"RoverVisible", "RoverConstraint", "RoverActual"}


def actor_tags(actor):
    return [str(t) for t in actor.tags]


def ensure_room_collision():
    """BlockAll + ComplexAsSimple on every room and ground mesh."""
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
    unreal.log_warning(f"ROOM_COLLISION|components_fixed={fixed}")


def configure_ghost(ghost):
    """Hide ghost and remove blocking collision so sweep doesn't hit it."""
    ghost.set_actor_hidden_in_game(True)
    root = ghost.get_editor_property("root_component")
    if root is not None:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_hidden_in_game(True)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_collision_profile_name("NoCollision")
        comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        break
    unreal.log_warning("GHOST|hidden_in_game=True|collision=NoCollision|sim=False")


def destroy_stale_actors():
    """Remove old spring/proxy actors left from previous setup."""
    removed = []
    for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        lbl = a.get_actor_label()
        if lbl in REMOVE_LABELS:
            unreal.EditorLevelLibrary.destroy_actor(a)
            removed.append(lbl)
    if removed:
        unreal.log_warning(f"STALE_REMOVED|{removed}")


def find_existing_proxy():
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        if PROXY_TAG in actor_tags(a) or a.get_actor_label() == PROXY_LABEL:
            return a
    return None


def spawn_proxy(location):
    bp_class = unreal.load_class(None, BP_PATH)
    if bp_class is None:
        raise RuntimeError(
            f"Cannot load {BP_PATH}. "
            "Run create_rover_proxy_bp.py first, then add the Event Tick graph, "
            "then re-run this script."
        )

    proxy = unreal.EditorLevelLibrary.spawn_actor_from_class(
        bp_class, location, unreal.Rotator(0, 0, 0)
    )
    if proxy is None:
        raise RuntimeError("Failed to spawn BP_RoverProxy instance")

    proxy.set_actor_label(PROXY_LABEL)
    proxy.tags = [unreal.Name(PROXY_TAG)]
    proxy.set_actor_hidden_in_game(False)

    root = proxy.get_editor_property("root_component")
    if root is not None:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)

    loc = proxy.get_actor_location()
    unreal.log_warning(
        f"PROXY_SPAWNED|label={PROXY_LABEL}|tag={PROXY_TAG}"
        f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
    )
    return proxy


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

ensure_room_collision()

ghost = None
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if GHOST_TAG in actor_tags(a):
        ghost = a
        break

if ghost is None:
    raise RuntimeError(
        f"Ghost '{GHOST_TAG}' not found. "
        "Run scripts/run_audit_rover_scene.sh first."
    )

ghost_loc = ghost.get_actor_location()
unreal.log_warning(
    f"GHOST_FOUND|label={ghost.get_actor_label()}"
    f"|loc=({ghost_loc.x:.0f},{ghost_loc.y:.0f},{ghost_loc.z:.0f})"
)

configure_ghost(ghost)
destroy_stale_actors()

existing_proxy = find_existing_proxy()
if existing_proxy is not None:
    unreal.log_warning(f"PROXY_EXISTS|label={existing_proxy.get_actor_label()}|re-using")
    proxy = existing_proxy
    proxy.tags = [unreal.Name(PROXY_TAG)]
else:
    proxy = spawn_proxy(ghost_loc)

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom")

unreal.log_warning(
    "PROXY_LEVEL_SETUP_DONE|"
    "Ghost=RoverTwin(hidden,NoCollision) | "
    "Proxy=RoverProxy(visible,BlockAll,sweep) | "
    "Simulink Transform Set->RoverTwin | Transform Get->RoverProxy"
)
