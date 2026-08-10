#!/usr/bin/env bash
# Disable MathWorksGeoSpatial (needs Cesium) and set EngineAssociation for local UE.
set -euo pipefail
UPROJECT="${1:-/home/dinuk/Desktop/project/Rover-Room-SIM/unreal/AutoVrtlEnv/AutoVrtlEnv.uproject}"
python3 << PY
import json
path = "$UPROJECT"
with open(path) as f:
    data = json.load(f)
data["EngineAssociation"] = "5.3"
for p in data.get("Plugins", []):
    if p.get("Name") == "MathWorksGeoSpatial":
        p["Enabled"] = False
    if p.get("Name") == "MathWorksAutomotiveContent":
        p["Enabled"] = True
with open(path, "w") as f:
    json.dump(data, f, indent="\t")
    f.write("\n")
print("patched", path)
PY
