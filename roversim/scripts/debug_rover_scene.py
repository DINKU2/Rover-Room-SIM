"""
debug_rover_scene.py — dump every rover-related actor in MyRoom (editor mode).

Run while Unreal Editor is open (NOT during PIE). Prints label, class, tags,
location, mesh, mobility for anything that looks like a rover.

Usage: scripts/run_debug_rover_scene.sh
"""
import os
import sys
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

MAP_PATH = "/Game/Maps/MyRoom"
ROVER_MESH = "SM_Rover_Combined"


def actor_tags(actor):
    return [str(t) for t in actor.tags]


def mesh_names(actor):
    names = []
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        mesh = comp.get_editor_property("static_mesh")
        if mesh is None:
            names.append("(none)")
        else:
            names.append(mesh.get_name())
        try:
            mob = comp.get_editor_property("mobility")
            names[-1] += f" mob={mob}"
        except Exception:
            pass
    return names


def is_interesting(actor):
    lbl = actor.get_actor_label().lower()
    tags = [t.lower() for t in actor_tags(actor)]
    cls = actor.get_class().get_name().lower()
    if "rover" in lbl or "rovertwin" in tags or "staticmeshactorrovertwin" in tags:
        return True
    if "sim3d" in cls and "static" in cls:
        return True
    for mn in mesh_names(actor):
        if ROVER_MESH in mn:
            return True
    return False


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

actors = unreal.EditorLevelLibrary.get_all_level_actors()
interesting = [a for a in actors if is_interesting(a)]

unreal.log_warning(f"DEBUG_SCENE|total_actors={len(actors)}|rover_related={len(interesting)}")

for a in interesting:
    loc = a.get_actor_location()
    rot = a.get_actor_rotation()
    unreal.log_warning(
        "DEBUG_ACTOR"
        f"|label={a.get_actor_label()}"
        f"|class={a.get_class().get_name()}"
        f"|tags={actor_tags(a)}"
        f"|loc=({loc.x:.1f},{loc.y:.1f},{loc.z:.1f})"
        f"|rot=({rot.pitch:.1f},{rot.yaw:.1f},{rot.roll:.1f})"
        f"|meshes={mesh_names(a)}"
        f"|hidden={a.get_actor_hidden_in_game()}"
    )

tagged = [a for a in actors if "RoverTwin" in actor_tags(a)]
sim3d = [a for a in actors if a.get_class().get_name() == "Sim3dStaticMeshActor"]

unreal.log_warning(
    f"DEBUG_SUMMARY|tagged_RoverTwin={len(tagged)}"
    f"|Sim3dStaticMeshActor={len(sim3d)}"
    f"|interesting={len(interesting)}"
)

if len(tagged) != 1:
    unreal.log_error(
        f"EXPECTED exactly 1 actor tagged RoverTwin, found {len(tagged)}. "
        "Run scripts/run_audit_rover_scene.sh"
    )
if len(sim3d) != 1:
    unreal.log_error(
        f"EXPECTED exactly 1 Sim3dStaticMeshActor, found {len(sim3d)}. "
        "Run scripts/run_audit_rover_scene.sh"
    )

unreal.log_warning("DEBUG_ROVER_SCENE_DONE")
