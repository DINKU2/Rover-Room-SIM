"""
DEPRECATED — Blueprint proxy approach abandoned.

Use setup_rover_sweep_complete.py (StaticMeshActor + Python PIE sweep).
Run: bash scripts/run_setup_rover_scene.sh
"""
import os
import unreal

_CANONICAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "setup_rover_sweep_complete.py")
unreal.log_warning("DEPRECATED|setup_rover_proxy_option_a|redirecting to setup_rover_sweep_complete")
with open(_CANONICAL, "r", encoding="utf-8") as handle:
    exec(compile(handle.read(), _CANONICAL, "exec"), {"unreal": unreal, "__file__": _CANONICAL})
