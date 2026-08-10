"""Backward-compatible wrapper — use audit_rover_scene.py instead."""
import os
import sys
import runpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
runpy.run_path(os.path.join(os.path.dirname(__file__), "audit_rover_scene.py"))
