import unreal
unreal.EditorLoadingAndSavingUtils.load_map("/Game/Maps/MyRoom")

for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    lbl = actor.get_actor_label()
    if 'room' in lbl.lower() or 'Room' in lbl:
        origin, extent = actor.get_actor_bounds(False)
        loc = actor.get_actor_location()
        unreal.log_warning(
            f"ROOM|{lbl}|origin=({origin.x:.0f},{origin.y:.0f},{origin.z:.0f})"
            f"|extent=({extent.x:.0f},{extent.y:.0f},{extent.z:.0f})"
            f"|actor_loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
        )
        # print rough box corners
        unreal.log_warning(
            f"ROOM_BOX|{lbl}"
            f"|Xmin={origin.x-extent.x:.0f} Xmax={origin.x+extent.x:.0f}"
            f"|Ymin={origin.y-extent.y:.0f} Ymax={origin.y+extent.y:.0f}"
            f"|Zmin={origin.z-extent.z:.0f} Zmax={origin.z+extent.z:.0f}"
        )
