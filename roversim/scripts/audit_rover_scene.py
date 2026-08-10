"""
audit_rover_scene.py — canonical RoverTwin level repair (collision off, one visible actor).

Delegates to setup_disable_collision.py. Run:
  bash scripts/run_disable_collision.sh
"""
import os
import runpy

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "setup_disable_collision.py")
runpy.run_path(_SCRIPT, run_name="__main__")
