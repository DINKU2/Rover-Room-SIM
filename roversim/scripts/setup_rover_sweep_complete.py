"""
setup_rover_sweep_complete.py — Canonical rover scene setup (run in open Unreal Editor).

LONG-TERM ARCHITECTURE (do not switch types):

  Actor              Type                    Role
  -----------------  ----------------------  ------------------------------------------
  RoverTwin          Sim3dStaticMeshActor    Hidden ghost; Simulink Transform Set
  RoverProxy         StaticMeshActor         Visible SM_Rover_Combined; sphere-swept in PIE
  RoverProxyFeedback Sim3dStaticMeshActor    Hidden; tag RoverProxy; Transform Get

  Movement: rover_sweep_runtime.py ticks during PIE only (no RoverSweepDriver in level).
  Room:     MyRoom_* StaticMeshActor, BlockAll, Static, no simulate physics.

Run: bash scripts/run_setup_rover_scene.sh
"""
import unreal

MAP_PATH = "/Game/Maps/MyRoom"
MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"
GHOST_TAG = "RoverTwin"
PROXY_LABEL = "RoverProxy"
PROXY_TAG = "VisibleProxy"
FEEDBACK_LABEL = "RoverProxyFeedback"
FEEDBACK_TAG = "RoverProxy"
REMOVE_LABELS = {"RoverVisible", "RoverConstraint", "RoverActual", "RoverSweepDriver"}
ROVER_RADIUS_CM = 22.0
RUNTIME_PATH = unreal.Paths.project_content_dir() + "Python/rover_sweep_runtime.py"

SKIP_LABELS = {
    "RoverProxy",
    "RoverTwin",
    "RoverProxyFeedback",
    "RoverSweepDriver",
    "SpawnDebugOrb",
    "PlayerStart",
}


def actor_tags(actor):
    return [str(t) for t in actor.tags]


def _is_room_mesh_actor(actor):
    lbl = actor.get_actor_label()
    if lbl in SKIP_LABELS or lbl.startswith("SoftFill"):
        return False
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


def _is_proxy_actor(actor):
    lbl = actor.get_actor_label()
    if lbl in (PROXY_LABEL, FEEDBACK_LABEL):
        return True
    tags = actor_tags(actor)
    if PROXY_TAG in tags or FEEDBACK_TAG in tags:
        return True
    try:
        cls = actor.get_class().get_name()
        if "RoverProxy" in cls and "BP_" in cls:
            return True
    except Exception:
        pass
    return False


def _is_sweep_driver(actor):
    if actor.get_actor_label() == "RoverSweepDriver":
        return True
    try:
        return "RoverSweepActor" in actor.get_class().get_name()
    except Exception:
        return False


def ensure_room_collision():
    walls = 0
    floors = 0
    for actor in unreal.EditorLevelLibrary.get_all_level_actors():
        lbl = actor.get_actor_label()
        if lbl == "GroundPlane":
            for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
                comp.set_collision_profile_name("NoCollision")
                comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
                floors += 1
            continue
        if not _is_room_mesh_actor(actor):
            continue
        for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
            comp.set_simulate_physics(False)
            comp.set_enable_gravity(False)
            comp.set_editor_property("mobility", unreal.ComponentMobility.STATIC)
            walls += 1
    unreal.log_warning(f"ROOM_COLLISION|mesh_colliders={walls}|floor_no_collision={floors}")


def find_ghost():
    for actor in unreal.EditorLevelLibrary.get_all_level_actors():
        if GHOST_TAG in actor_tags(actor):
            return actor
    return None


def configure_ghost(ghost, mesh):
    ghost.set_actor_label(GHOST_TAG)
    ghost.tags = [unreal.Name(GHOST_TAG)]
    ghost.set_actor_hidden_in_game(True)
    try:
        ghost.set_is_temporarily_hidden_in_editor(False)
    except Exception:
        pass
    root = ghost.get_editor_property("root_component")
    if root:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_editor_property("static_mesh", mesh)
        comp.set_hidden_in_game(True)
        comp.set_visibility(False, True)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_collision_profile_name("NoCollision")
        comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        break
    unreal.log_warning("GHOST|type=Sim3dStaticMeshActor|hidden=True|collision=NoCollision")


def destroy_stale():
    for actor in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if actor.get_actor_label() in REMOVE_LABELS:
            unreal.EditorLevelLibrary.destroy_actor(actor)


def destroy_proxy_and_sweep_actors():
    removed = 0
    for actor in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if _is_proxy_actor(actor) or _is_sweep_driver(actor):
            unreal.EditorLevelLibrary.destroy_actor(actor)
            removed += 1
    unreal.log_warning(f"CLEANUP|removed_proxy_or_sweep={removed}")


def spawn_visible_proxy(location, mesh):
    """RoverProxy MUST be StaticMeshActor — saveable, mesh always visible."""
    proxy = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.StaticMeshActor, location, unreal.Rotator(0, 0, 0)
    )
    if proxy is None:
        raise RuntimeError("Failed to spawn RoverProxy StaticMeshActor")

    proxy.set_actor_label(PROXY_LABEL)
    proxy.tags = [unreal.Name(PROXY_TAG)]
    proxy.set_actor_hidden_in_game(False)
    try:
        proxy.set_is_temporarily_hidden_in_editor(False)
    except Exception:
        pass

    mesh_ok = False
    mesh_path = mesh.get_path_name()
    for comp in proxy.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_editor_property("static_mesh", mesh)
        comp.set_visibility(True, True)
        comp.set_hidden_in_game(False)
        try:
            comp.set_editor_property("visible", True)
        except Exception:
            pass
        comp.set_collision_profile_name("NoCollision")
        comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        assigned = comp.get_editor_property("static_mesh")
        mesh_ok = assigned is not None and assigned.get_path_name() == mesh_path
        break

    if not mesh_ok:
        raise RuntimeError("RoverProxy StaticMeshActor has no visible assigned mesh")

    loc = proxy.get_actor_location()
    bounds_origin, bounds_extent = proxy.get_actor_bounds(False)
    unreal.log_warning(
        f"PROXY|type=StaticMeshActor|label={PROXY_LABEL}|tag={PROXY_TAG}"
        f"|mesh={mesh.get_name()}|sweep=r={ROVER_RADIUS_CM}"
        f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
        f"|bounds_extent=({bounds_extent.x:.0f},{bounds_extent.y:.0f},{bounds_extent.z:.0f})"
        f"|editor_visible=True|game_hidden=False"
    )
    return proxy


def spawn_feedback_sim3d(parent, location):
    sim3d_cls = unreal.load_class(None, "/Script/MathWorksSimulation.Sim3dStaticMeshActor")
    if sim3d_cls is None:
        raise RuntimeError("Sim3dStaticMeshActor not found")

    feedback = unreal.EditorLevelLibrary.spawn_actor_from_class(
        sim3d_cls, location, unreal.Rotator(0, 0, 0)
    )
    if feedback is None:
        raise RuntimeError("Failed to spawn RoverProxyFeedback")

    feedback.set_actor_label(FEEDBACK_LABEL)
    feedback.tags = [unreal.Name(FEEDBACK_TAG)]
    feedback.set_actor_hidden_in_game(True)

    for comp in feedback.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_editor_property("static_mesh", None)
        comp.set_collision_profile_name("NoCollision")
        comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        comp.set_simulate_physics(False)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        comp.set_visibility(False, True)
        comp.set_hidden_in_game(True)
        break

    feedback.attach_to_actor(
        parent,
        "",
        unreal.AttachmentRule.SNAP_TO_TARGET,
        unreal.AttachmentRule.SNAP_TO_TARGET,
        unreal.AttachmentRule.KEEP_RELATIVE,
        False,
    )
    unreal.log_warning(
        f"FEEDBACK|type=Sim3dStaticMeshActor|label={FEEDBACK_LABEL}|tag={FEEDBACK_TAG}"
    )
    return feedback


def reload_sweep_runtime():
    with open(RUNTIME_PATH, "r", encoding="utf-8") as handle:
        code = handle.read()
    g = {"unreal": unreal}
    exec(compile(code, RUNTIME_PATH, "exec"), g)
    remove_fn = g.get("remove_sweep_actors_from_level")
    if remove_fn is not None:
        remove_fn()
    unreal.log_warning("SWEEP_RUNTIME|mode=direct_pie_tick|no_level_driver")


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

mesh = unreal.load_asset(MESH_PATH)
if mesh is None:
    raise RuntimeError(f"Cannot load mesh: {MESH_PATH}")

ensure_room_collision()
destroy_stale()

ghost = find_ghost()
if ghost is None:
    raise RuntimeError(f"{GHOST_TAG} not found. Run: bash scripts/run_audit_rover_scene.sh")

ghost_loc = ghost.get_actor_location()
unreal.log_warning(
    f"GHOST_FOUND|loc=({ghost_loc.x:.0f},{ghost_loc.y:.0f},{ghost_loc.z:.0f})"
)

configure_ghost(ghost, mesh)
destroy_proxy_and_sweep_actors()

proxy = spawn_visible_proxy(ghost_loc, mesh)
spawn_feedback_sim3d(proxy, ghost_loc)
reload_sweep_runtime()

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom")

unreal.log_warning(
    "ROVER_SCENE_SETUP_DONE|"
    "RoverTwin=Sim3d ghost | RoverProxy=StaticMeshActor visible | "
    "RoverProxyFeedback=Transform Get | sweep=Python PIE only"
)
