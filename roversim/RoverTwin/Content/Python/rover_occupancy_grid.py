"""
rover_occupancy_grid.py — 2D interior mask for MyRoom scan footprint (gray void = lava).

Built by scripts/setup_room_boundary_shell.py → rover_occupancy_grid.json
Walkable = cell marked interior on this grid only (not raw mesh overlap).
"""
import json
import math
import os
import unreal

GRID_PATH = unreal.Paths.project_content_dir() + "Python/rover_occupancy_grid.json"

_grid_cache = None


def _empty_grid():
    return {
        "xmin": 0.0,
        "ymin": 0.0,
        "grid_step": 50.0,
        "nx": 0,
        "ny": 0,
        "interior": set(),
    }


def load_grid(force=False):
    global _grid_cache
    if _grid_cache is not None and not force:
        return _grid_cache

    if not os.path.isfile(GRID_PATH):
        unreal.log_warning(f"OCCUPANCY_GRID|missing|path={GRID_PATH}")
        _grid_cache = _empty_grid()
        return _grid_cache

    with open(GRID_PATH, "r", encoding="utf-8") as handle:
        data = json.load(handle)

    interior = set()
    for item in data.get("interior_cells", []):
        if isinstance(item, (list, tuple)) and len(item) == 2:
            interior.add((int(item[0]), int(item[1])))

    _grid_cache = {
        "xmin": float(data["xmin"]),
        "ymin": float(data["ymin"]),
        "grid_step": float(data["grid_step"]),
        "nx": int(data["nx"]),
        "ny": int(data["ny"]),
        "interior": interior,
        "inside_count": int(data.get("inside_count", len(interior))),
    }
    unreal.log_warning(
        f"OCCUPANCY_GRID|loaded|cells={_grid_cache['inside_count']}"
        f"|grid={_grid_cache['nx']}x{_grid_cache['ny']}"
        f"|step={_grid_cache['grid_step']}"
    )
    return _grid_cache


def _cell_index(grid, x, y):
    step = grid["grid_step"]
    ix = int(math.floor((x - grid["xmin"]) / step))
    iy = int(math.floor((y - grid["ymin"]) / step))
    return ix, iy


def is_interior(x, y):
    grid = load_grid()
    if grid["nx"] <= 0 or grid["ny"] <= 0:
        return False

    ix, iy = _cell_index(grid, x, y)
    if ix < 0 or iy < 0 or ix >= grid["nx"] or iy >= grid["ny"]:
        return False
    return (ix, iy) in grid["interior"]


def grid_info():
    grid = load_grid()
    return {
        "loaded": grid["nx"] > 0,
        "inside_count": grid.get("inside_count", len(grid["interior"])),
        "nx": grid["nx"],
        "ny": grid["ny"],
        "step": grid["grid_step"],
    }
