"""Import matlab/my_room.fbx into RoverRoomSIM and place it in the level.

Run by scripts/setup_unreal_project.sh via:
  UnrealEditor RoverRoomSIM.uproject -ExecutePythonScript=import_room_mesh.py
"""

import math
import os
from typing import List, Optional

import unreal

FBX_PATH = os.environ.get(
    "ROVER_ROOM_FBX",
    "/home/dinuk/Desktop/project/Rover-Room-SIM/matlab/my_room.fbx",
)
DEST_PATH = "/Game/Room"
MESH_NAME = "SM_MyRoom"
ASSET_PATH = f"{DEST_PATH}/{MESH_NAME}"
LEVEL_PATH = "/Game/Levels/RoomPreview"


def log(msg: str) -> None:
    unreal.log(f"[RoverRoomSIM] {msg}")


def import_static_mesh() -> Optional[unreal.StaticMesh]:
    if not os.path.isfile(FBX_PATH):
        log(f"FBX not found: {FBX_PATH}")
        return None

    if not unreal.EditorAssetLibrary.does_directory_exist(DEST_PATH):
        unreal.EditorAssetLibrary.make_directory(DEST_PATH)

    task = unreal.AssetImportTask()
    task.set_editor_property("filename", FBX_PATH)
    task.set_editor_property("destination_path", DEST_PATH)
    task.set_editor_property("destination_name", MESH_NAME)
    task.set_editor_property("automated", True)
    task.set_editor_property("save", True)
    task.set_editor_property("replace_existing", True)

    options = unreal.FbxImportUI()
    options.set_editor_property("import_mesh", True)
    options.set_editor_property("import_as_skeletal", False)
    options.set_editor_property("import_materials", True)
    options.set_editor_property("import_textures", True)

    static_data = unreal.FbxStaticMeshImportData()
    static_data.set_editor_property("convert_scene", True)
    static_data.set_editor_property("combine_meshes", True)
    static_data.set_editor_property("generate_lightmap_u_vs", True)
    options.set_editor_property("static_mesh_import_data", static_data)
    task.set_editor_property("options", options)

    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    asset_tools.import_asset_tasks([task])

    if task.imported_object_paths:
        log(f"Imported: {task.imported_object_paths}")
    return unreal.load_asset(ASSET_PATH)


def ensure_working_level() -> str:
    level_asset = f"{LEVEL_PATH}.{LEVEL_PATH.split('/')[-1]}"
    levels = unreal.EditorAssetLibrary.list_assets("/Game/Levels", recursive=False)
    log(f"Levels under /Game/Levels: {levels}")

    if unreal.EditorAssetLibrary.does_asset_exist(level_asset):
        if unreal.EditorLoadingAndSavingUtils.load_map(LEVEL_PATH):
            log(f"Loaded existing level {LEVEL_PATH}")
            return LEVEL_PATH
        log(f"Asset exists but load failed: {LEVEL_PATH}")

    log(f"Creating fresh level {LEVEL_PATH}")
    if not unreal.EditorLevelLibrary.new_level(LEVEL_PATH):
        raise RuntimeError(f"Failed to create level {LEVEL_PATH}")
    log(f"Created level {LEVEL_PATH}")
    return LEVEL_PATH


def focus_viewport_on_actor(actor: unreal.Actor) -> None:
    try:
        origin, extent = actor.get_actor_bounds(False, False)
        radius = max(extent.x, extent.y, extent.z, 100.0)
        cam = unreal.Vector(
            origin.x + radius * 2.0,
            origin.y - radius * 2.0,
            origin.z + radius * 1.2,
        )
        look = origin - cam
        yaw = math.degrees(math.atan2(look.y, look.x))
        pitch = math.degrees(math.atan2(look.z, math.hypot(look.x, look.y)))
        unreal.EditorLevelLibrary.set_level_viewport_camera_info(
            cam, unreal.Rotator(-pitch, yaw, 0.0)
        )
        log(f"Focused viewport on MyRoom (center={origin}, radius={radius:.0f})")
    except Exception as exc:
        log(f"Could not focus viewport (non-fatal): {exc}")


def spawn_room_mesh(mesh: unreal.StaticMesh) -> None:
    actor_subsys = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    existing = [
        a
        for a in actor_subsys.get_all_level_actors()
        if a.get_actor_label() == "MyRoom"
    ]
    for actor in existing:
        actor_subsys.destroy_actor(actor)

    actor = actor_subsys.spawn_actor_from_class(
        unreal.StaticMeshActor,
        unreal.Vector(0.0, 0.0, 0.0),
        unreal.Rotator(0.0, 0.0, 0.0),
    )
    actor.set_actor_label("MyRoom")
    actor.static_mesh_component.set_static_mesh(mesh)
    actor.set_folder_path("Room")
    log(f"Spawned MyRoom actor using {mesh.get_name()}")
    focus_viewport_on_actor(actor)


def ensure_basic_lighting() -> None:
    actor_subsys = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
    has_sun = any(
        isinstance(a, unreal.DirectionalLight)
        for a in actor_subsys.get_all_level_actors()
    )
    if not has_sun:
        actor_subsys.spawn_actor_from_class(
            unreal.DirectionalLight,
            unreal.Vector(0.0, 0.0, 500.0),
            unreal.Rotator(-45.0, 0.0, 0.0),
        )
        log("Added directional light")
    has_sky = any(
        isinstance(a, unreal.SkyLight) for a in actor_subsys.get_all_level_actors()
    )
    if not has_sky:
        sky = actor_subsys.spawn_actor_from_class(
            unreal.SkyLight,
            unreal.Vector(0.0, 0.0, 0.0),
            unreal.Rotator(0.0, 0.0, 0.0),
        )
        sky.light_component.set_intensity(1.0)
        log("Added skylight")


def main() -> None:
    log(f"Importing {FBX_PATH}")
    level_path = ensure_working_level()
    mesh = import_static_mesh()
    if mesh is None:
        raise RuntimeError(f"Failed to import mesh from {FBX_PATH}")

    ensure_basic_lighting()
    spawn_room_mesh(mesh)

    world = unreal.EditorLevelLibrary.get_editor_world()
    if world is None:
        raise RuntimeError("No editor world open after level setup")

    if not unreal.EditorLoadingAndSavingUtils.save_map(world, LEVEL_PATH):
        raise RuntimeError(f"Failed to save level {LEVEL_PATH}")

    unreal.EditorLoadingAndSavingUtils.save_dirty_packages(True, True)
    log(f"Saved level + packages (MyRoom in {level_path})")


if __name__ == "__main__":
    main()
