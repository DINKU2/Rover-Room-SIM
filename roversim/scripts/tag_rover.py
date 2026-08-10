"""Add the RoverTwin tag to the Sim3dStaticMeshActor in MyRoom."""
import unreal

unreal.EditorLoadingAndSavingUtils.load_map("/Game/Maps/MyRoom")

found = []
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    cls = actor.get_class().get_name()
    lbl = actor.get_actor_label()
    if cls == "Sim3dStaticMeshActor" or lbl == "RoverTwin":
        current_tags = [str(t) for t in actor.tags]
        unreal.log_warning(f"FOUND|{lbl}|{cls}|tags_before={current_tags}")
        if "RoverTwin" not in current_tags:
            actor.tags.append(unreal.Name("RoverTwin"))
        # verify
        after = [str(t) for t in actor.tags]
        loc = actor.get_actor_location()
        unreal.log_warning(
            f"TAGGED|{lbl}|{cls}|tags_after={after}"
            f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
        )
        found.append(lbl)

if not found:
    unreal.log_warning("NO_ACTOR_FOUND|no Sim3dStaticMeshActor or RoverTwin label")
else:
    if not unreal.EditorLoadingAndSavingUtils.save_current_level():
        raise RuntimeError("Failed to save level")
    unreal.log_warning("LEVEL_SAVED|OK")
