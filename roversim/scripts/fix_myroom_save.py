"""
fix_myroom_save.py — Remove unsaveable RoverSweepDriver and fix room physics.

Run with Unreal Editor open on MyRoom:
  bash scripts/run_fix_myroom_save.sh
"""
import unreal
import os

MAP_PATH = "/Game/Maps/MyRoom"
SWEEP_LABEL = "RoverSweepDriver"
SCRIPT_DIR = unreal.Paths.project_content_dir() + "../.."
RUNTIME_PATH = unreal.Paths.project_content_dir() + "Python/rover_sweep_runtime.py"


def _is_sweep_actor(actor):
    if actor.get_actor_label() == SWEEP_LABEL:
        return True
    try:
        return "RoverSweepActor" in actor.get_class().get_name()
    except Exception:
        return False


def _is_room_part(actor):
    lbl = actor.get_actor_label()
    return lbl.startswith("MyRoom_Part") or lbl.startswith("MyRoom_Part_")


def remove_sweep_actors():
    removed = 0
    for actor in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if _is_sweep_actor(actor):
            unreal.EditorLevelLibrary.destroy_actor(actor)
            removed += 1
    unreal.log_warning(f"FIX_SAVE|sweep_removed={removed}")
    return removed


def fix_room_physics():
    fixed = 0
    for actor in unreal.EditorLevelLibrary.get_all_level_actors():
        if not _is_room_part(actor):
            continue
        if not isinstance(actor, unreal.StaticMeshActor):
            continue
        for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
            comp.set_simulate_physics(False)
            comp.set_enable_gravity(False)
            comp.set_editor_property("mobility", unreal.ComponentMobility.STATIC)
            fixed += 1
    unreal.log_warning(f"FIX_SAVE|room_parts_fixed={fixed}|simulate_physics=False")
    return fixed


def reload_runtime_cleanup():
    path = RUNTIME_PATH
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as handle:
        code = handle.read()
    g = {"unreal": unreal, "__file__": path}
    exec(compile(code, path, "exec"), g)
    remove_fn = g.get("remove_sweep_actors_from_level")
    if remove_fn is not None:
        remove_fn()


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)
remove_sweep_actors()
fix_room_physics()
reload_runtime_cleanup()

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom after fix")

unreal.log_warning(
    "FIX_MYROOM_SAVE_DONE|RoverSweepDriver removed|room static|save OK — collision uses sphere sweep, not room physics"
)
