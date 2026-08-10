import unreal
unreal.EditorLoadingAndSavingUtils.load_map("/Game/Maps/MyRoom")
actors = unreal.EditorLevelLibrary.get_all_level_actors()
unreal.log_warning(f"TOTAL_ACTORS|{len(actors)}")
for a in actors:
    cls = a.get_class().get_name()
    lbl = a.get_actor_label()
    tags = [str(t) for t in a.tags]
    loc = a.get_actor_location()
    meshes = []
    for c in a.get_components_by_class(unreal.StaticMeshComponent):
        m = c.get_editor_property('static_mesh')
        if m:
            meshes.append(m.get_path_name().split('.')[-1])
    is_rover = (
        'rover' in lbl.lower()
        or any('rover' in str(t).lower() for t in tags)
        or any('rover' in str(m).lower() for m in meshes)
        or cls.lower() in ('sim3dstaticmeshactor', 'sim3dgenericactor', 'sim3dannotation')
    )
    if is_rover or meshes:
        unreal.log_warning(
            f"ACTOR|label={lbl}|class={cls}|tags={tags}|"
            f"meshes={meshes}|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
        )
