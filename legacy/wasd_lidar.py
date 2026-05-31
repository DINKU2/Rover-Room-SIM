#!/usr/bin/env python3
"""Deprecated: use ./scripts/run_wasd_lidar.sh for the 3-terminal workflow."""
import subprocess
import sys
from pathlib import Path

REPLICA_ROOT = Path(__file__).resolve().parent.parent
script = REPLICA_ROOT / "scripts" / "run_wasd_lidar.sh"
sys.exit(subprocess.run([str(script), *sys.argv[1:]], check=False).returncode)
