import unreal

MAP_PATH = "/Game/Maps/MyRoom"
unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

to_delete = []
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    lbl = actor.get_actor_label()
    if lbl.startswith("RoverPart_"):
        loc = actor.get_actor_location()
        unreal.log_warning(f"DELETING_ROVER_PART|{lbl}|{actor.get_class().get_name()}|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})")
        to_delete.append(actor)

if not to_delete:
    unreal.log_warning("NO_ROVER_PARTS_FOUND|nothing to delete")
else:
    for actor in to_delete:
        unreal.EditorLevelLibrary.destroy_actor(actor)
    unreal.log_warning(f"DELETED_ROVER_PARTS|count={len(to_delete)}")
    if not unreal.EditorLoadingAndSavingUtils.save_current_level():
        raise RuntimeError("Failed to save level after deletion")
    unreal.log_warning("LEVEL_SAVED|OK")
