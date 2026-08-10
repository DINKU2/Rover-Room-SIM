import unreal


unreal.EditorLoadingAndSavingUtils.load_map("/Game/Maps/MyRoom")

actors = unreal.EditorLevelLibrary.get_all_level_actors()
for actor in actors:
    label = actor.get_actor_label()
    actor_class = actor.get_class().get_name()
    path = actor.get_path_name()
    if "rover" in label.lower() or "rover" in path.lower():
        parent = actor.get_attach_parent_actor()
        parent_label = parent.get_actor_label() if parent else "<none>"
        tags = ",".join(str(tag) for tag in actor.tags)
        location = actor.get_actor_location()
        rotation = actor.get_actor_rotation()
        unreal.log_warning(
            f"ROVER_ACTOR|{label}|{actor_class}|{path}|"
            f"parent={parent_label}|tags={tags}|"
            f"location={location}|rotation={rotation}"
        )

unreal.log_warning(f"ACTOR_COUNT|{len(actors)}")
for actor in actors:
    unreal.log_warning(
        f"ROOM_ACTOR|{actor.get_actor_label()}|"
        f"{actor.get_class().get_name()}|{actor.get_path_name()}"
    )
