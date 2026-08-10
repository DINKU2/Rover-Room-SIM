"""
setup_room_convex_collision.py

Generate Auto Convex Collision on all MyRoom photogrammetry static meshes.
Uses StaticMeshEditorSubsystem.set_convex_decomposition_collisions (same as
Static Mesh Editor → Collision → Auto Convex Collision).

Run with Unreal Editor open on MyRoom:
  bash scripts/run_setup_room_convex_collision.sh
"""
import unreal

MAP_PATH = "/Game/Maps/MyRoom"
MYROOM_CONTENT_PATH = "/Game/MyRoom"

HULL_COUNT = 32
MAX_HULL_VERTS = 32
HULL_PRECISION = 100000

SKIP_LABELS = {
    "RoverProxy",
    "RoverTwin",
    "RoverProxyFeedback",
    "RoverSweepDriver",
    "SpawnDebugOrb",
    "PlayerStart",
}


def _mesh_from_actor(actor):
    if not isinstance(actor, unreal.StaticMeshActor):
        return None
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        mesh = comp.get_editor_property("static_mesh")
        if mesh is not None:
            return mesh
    return None


def collect_room_meshes():
    meshes = {}
    for actor in unreal.EditorLevelLibrary.get_all_level_actors():
        lbl = actor.get_actor_label()
        if lbl in SKIP_LABELS or lbl.startswith("SoftFill"):
            continue
        mesh = _mesh_from_actor(actor)
        if mesh is None:
            continue
        path = mesh.get_path_name().lower()
        if lbl.startswith("MyRoom") or "my_room" in path or "myroom" in path:
            meshes[mesh.get_path_name()] = mesh
    try:
        registry = unreal.AssetRegistryHelpers.get_asset_registry()
        for data in registry.get_assets_by_path(MYROOM_CONTENT_PATH, recursive=True):
            if data.asset_class_path.asset_name != "StaticMesh":
                continue
            name = str(data.asset_name).lower()
            if "my_room" not in name and "myroom" not in name:
                continue
            mesh = unreal.load_asset(str(data.package_name))
            if mesh is not None:
                meshes[mesh.get_path_name()] = mesh
    except Exception as exc:
        unreal.log_warning(f"CONVEX_COLLISION|asset_scan_warn={exc}")
    return list(meshes.values())


def apply_convex_collision(mesh):
    sub = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
    before = sub.get_convex_collision_count(mesh)
    ok = sub.set_convex_decomposition_collisions(
        mesh,
        HULL_COUNT,
        MAX_HULL_VERTS,
        HULL_PRECISION,
    )
    after = sub.get_convex_collision_count(mesh)
    complexity = sub.get_collision_complexity(mesh)
    saved = unreal.EditorAssetLibrary.save_loaded_asset(mesh)
    return before, after, ok, complexity, saved


def ensure_actor_collision():
    fixed = 0
    for actor in unreal.EditorLevelLibrary.get_all_level_actors():
        lbl = actor.get_actor_label()
        if lbl == "GroundPlane":
            for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
                comp.set_collision_profile_name("NoCollision")
                comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
            continue
        if not lbl.startswith("MyRoom"):
            mesh = _mesh_from_actor(actor)
            if mesh is None:
                continue
            path = mesh.get_path_name().lower()
            if "my_room" not in path and "myroom" not in path:
                continue
        else:
            mesh = _mesh_from_actor(actor)
            if mesh is None:
                continue
        for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
            fixed += 1
    unreal.log_warning(f"CONVEX_COLLISION|actors_blockall={fixed}")


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

meshes = collect_room_meshes()
if not meshes:
    raise RuntimeError("No MyRoom static meshes found under /Game/MyRoom or MyRoom_Part_* actors")

unreal.log_warning(
    f"CONVEX_COLLISION|start|meshes={len(meshes)}"
    f"|hulls={HULL_COUNT}|verts={MAX_HULL_VERTS}|precision={HULL_PRECISION}"
)

for mesh in meshes:
    name = mesh.get_name()
    before, after, ok, complexity, saved = apply_convex_collision(mesh)
    unreal.log_warning(
        f"CONVEX_COLLISION|mesh={name}|before={before}|after={after}"
        f"|ok={ok}|complexity={complexity}|saved={saved}"
    )

ensure_actor_collision()

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom level")

unreal.log_warning("CONVEX_COLLISION_DONE|ok")
