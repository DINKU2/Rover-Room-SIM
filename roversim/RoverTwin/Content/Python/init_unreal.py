"""
init_unreal.py — Auto-executed by Unreal Engine Python at editor startup.

Loads rover_sweep_runtime.py only when SWEEP_ENABLED is True (collision proxy mode).
"""
import unreal
import os

_SCRIPT_DIR = unreal.Paths.project_content_dir() + "Python"


def _load(filename):
    path = os.path.join(_SCRIPT_DIR, filename)
    if not os.path.isfile(path):
        unreal.log_warning(f"init_unreal|MISSING|{path}")
        return {}
    with open(path, "r", encoding="utf-8") as f:
        code = f.read()
    g = {"unreal": unreal, "__file__": path}
    exec(compile(code, path, "exec"), g)
    unreal.log_warning(f"init_unreal|loaded|{filename}")
    return g


g = _load("rover_sweep_runtime.py")

remove_fn = g.get("remove_sweep_actors_from_level")
if remove_fn is not None:
    try:
        remove_fn()
    except Exception as e:
        unreal.log_warning(f"init_unreal|remove_sweep_actor_warn={e}")

if not g.get("SWEEP_ENABLED", False) and g.get("LIDAR_ENABLED", False):
    unreal.log_warning("init_unreal|sweep_disabled|lidar_only_pie_tick")
elif not g.get("SWEEP_ENABLED", False):
    unreal.log_warning("init_unreal|sweep_disabled|collision_off")
