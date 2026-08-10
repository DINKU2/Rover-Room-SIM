import unreal


MAP_PATH = "/Game/Maps/MyRoom"
ROVER_LABEL = "RoverTwin"
ROVER_TAG = unreal.Name("RoverTwin")


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

rover = None
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    if actor.get_actor_label() == ROVER_LABEL:
        rover = actor
        break

if rover is None:
    raise RuntimeError(f"Could not find actor labeled {ROVER_LABEL} in {MAP_PATH}")

tags = list(rover.tags)
if ROVER_TAG not in tags:
    tags.append(ROVER_TAG)
    rover.tags = tags
    rover.modify()

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError(f"Failed to save {MAP_PATH}")

unreal.log_warning(
    f"SIMULINK_ROVER_READY|label={ROVER_LABEL}|tag={ROVER_TAG}|"
    f"path={rover.get_path_name()}"
)
