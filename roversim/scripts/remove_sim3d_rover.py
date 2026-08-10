"""DEPRECATED — do not run. Use audit_rover_scene.py instead.

Remove the pre-placed Sim3dStaticMeshActor tagged RoverTwin.

The Simulink 'Simulation 3D Static Mesh Actor' block will create its own
RoverTwin actor at simulation start. Having a second pre-placed actor with the
same tag causes a tag conflict — the Simulink actor falls back to the world
origin (outside the room). Removing the pre-placed actor eliminates that
conflict so the Simulink block can place the rover at the correct initial
position inside the room.
"""
import sys
raise SystemExit("DEPRECATED: run scripts/run_audit_rover_scene.sh instead")

import unreal

MAP_PATH = "/Game/Maps/MyRoom"
unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

deleted = []
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    cls  = actor.get_class().get_name()
    tags = [str(t) for t in actor.tags]
    lbl  = actor.get_actor_label()
    if cls == "Sim3dStaticMeshActor" or "RoverTwin" in tags:
        loc = actor.get_actor_location()
        unreal.log_warning(
            f"REMOVING|label={lbl}|class={cls}|tags={tags}"
            f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
        )
        unreal.EditorLevelLibrary.destroy_actor(actor)
        deleted.append(lbl)

if not deleted:
    unreal.log_warning("NOTHING_TO_REMOVE|no Sim3dStaticMeshActor or RoverTwin tag found")
else:
    unreal.log_warning(f"REMOVED|count={len(deleted)}|actors={deleted}")
    if not unreal.EditorLoadingAndSavingUtils.save_current_level():
        raise RuntimeError("Failed to save level")
    unreal.log_warning("LEVEL_SAVED|OK")
