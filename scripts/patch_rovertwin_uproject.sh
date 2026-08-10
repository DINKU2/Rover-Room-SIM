#!/usr/bin/env bash
# Enable MathWorks co-sim plugins on RoverTwin (Path 3).
set -euo pipefail
UPROJECT="${1:-/home/dinuk/Desktop/project/Rover-Room-SIM/RoverSIMUunreal-Linux/RoverTwin/RoverTwin.uproject}"
python3 << PY
import json

path = "$UPROJECT"
with open(path) as f:
    data = json.load(f)

data["EngineAssociation"] = "5.3"

plugins = {p["Name"]: p for p in data.get("Plugins", [])}

def ensure(name, enabled, **extra):
    if name in plugins:
        plugins[name]["Enabled"] = enabled
        plugins[name].update(extra)
    else:
        entry = {"Name": name, "Enabled": enabled}
        entry.update(extra)
        plugins[name] = entry

ensure("MathWorksSimulation", True)
ensure("MathWorksAutomotiveContent", True)
ensure("MathWorksGeoSpatial", False)

data["Plugins"] = list(plugins.values())
with open(path, "w") as f:
    json.dump(data, f, indent="\t")
    f.write("\n")
print("patched", path)
PY
