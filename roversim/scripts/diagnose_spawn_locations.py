import unreal

MAP_PATH = "/Game/Maps/MyRoom"
LABELS = ("RoverTwin", "SpawnDebugOrb")

unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    lbl = actor.get_actor_label()
    if lbl not in LABELS:
        continue
    loc = actor.get_actor_location()
    rot = actor.get_actor_rotation()
    _origin, extent = actor.get_actor_bounds(False)
    unreal.log_warning(
        f"DIAG_ACTOR|label={lbl}|class={actor.get_class().get_name()}"
        f"|loc=({loc.x:.3f},{loc.y:.3f},{loc.z:.3f})"
        f"|rot=({rot.pitch:.1f},{rot.yaw:.1f},{rot.roll:.1f})"
        f"|bounds_extent=({extent.x:.1f},{extent.y:.1f},{extent.z:.1f})"
        f"|tags={[str(t) for t in actor.tags]}"
    )

unreal.log_warning("DIAG_SPAWN_LOCATIONS_DONE")
