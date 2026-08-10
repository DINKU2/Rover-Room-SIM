import unreal

MAP_PATH = "/Game/Maps/MyRoom"
ROVER_LABEL = "RoverTwin"
ROVER_TAG = "RoverTwin"
FALLBACK_MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined"
SIM3D_CLASS = "/Script/MathWorksSimulation.Sim3dStaticMeshActor"

unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

old_rover = None
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    if actor.get_actor_label() == ROVER_LABEL:
        old_rover = actor
        break

if old_rover is None:
    raise RuntimeError(f"Cannot find actor labelled '{ROVER_LABEL}' in {MAP_PATH}")

loc = old_rover.get_actor_location()
rot = old_rover.get_actor_rotation()
scl = old_rover.get_actor_scale3d()
old_class = old_rover.get_class().get_name()
unreal.log_warning(
    f"FOUND_ROVER|class={old_class}|"
    f"loc=({loc.x:.1f},{loc.y:.1f},{loc.z:.1f})|"
    f"rot=({rot.pitch:.1f},{rot.yaw:.1f},{rot.roll:.1f})|"
    f"scale=({scl.x:.2f},{scl.y:.2f},{scl.z:.2f})"
)

if old_class == "Sim3dStaticMeshActor":
    unreal.log_warning("ALREADY_CONVERTED|RoverTwin is already a Sim3dStaticMeshActor — skipping")
    raise SystemExit(0)

mesh_asset = None
for comp in old_rover.get_components_by_class(unreal.StaticMeshComponent):
    found = comp.get_editor_property("static_mesh")
    if found:
        mesh_asset = found
        unreal.log_warning(f"FOUND_MESH|{mesh_asset.get_path_name()}")
        break

if mesh_asset is None:
    unreal.log_warning(f"NO_MESH_ON_OLD_ACTOR|falling back to {FALLBACK_MESH_PATH}")
    mesh_asset = unreal.load_asset(FALLBACK_MESH_PATH)
    if mesh_asset is None:
        raise RuntimeError(f"Fallback mesh not found at {FALLBACK_MESH_PATH}")

sim3d_cls = unreal.load_class(None, SIM3D_CLASS)
if sim3d_cls is None:
    raise RuntimeError(f"Cannot load class {SIM3D_CLASS}. Is MathWorksSimulation plugin enabled?")

new_actor = unreal.EditorLevelLibrary.spawn_actor_from_class(sim3d_cls, loc, rot)
if new_actor is None:
    raise RuntimeError("spawn_actor_from_class returned None for Sim3dGenericActor")

new_actor.set_actor_scale3d(scl)
new_actor.set_actor_label(ROVER_LABEL)
new_actor.tags = [unreal.Name(ROVER_TAG)]

mesh_comp = new_actor.get_component_by_class(unreal.StaticMeshComponent)
if mesh_comp:
    mesh_comp.set_editor_property("static_mesh", mesh_asset)
    unreal.log_warning(f"MESH_APPLIED|{mesh_asset.get_path_name()}")
else:
    unreal.log_warning("WARNING|Sim3dGenericActor has no StaticMeshComponent — mesh not applied")

unreal.EditorLevelLibrary.destroy_actor(old_rover)
unreal.log_warning("OLD_ACTOR_DELETED")

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save level after conversion")

unreal.log_warning(
    f"ROVER_CONVERTED_TO_SIM3D|label={new_actor.get_actor_label()}|"
    f"class={new_actor.get_class().get_name()}|"
    f"tags={[str(t) for t in new_actor.tags]}|"
    f"loc=({new_actor.get_actor_location().x:.1f},"
    f"{new_actor.get_actor_location().y:.1f},"
    f"{new_actor.get_actor_location().z:.1f})"
)
