"""
setup_room_boundary_shell.py

Build a collision perimeter around the scanned floorplan (occupancy-grid style).
Samples a 2D grid at floor height; cells overlapping MyRoom mesh = interior.
Spawns thin BlockAll wall segments on edges between interior and exterior (gray void).

Run with Unreal Editor open on MyRoom:
  bash scripts/run_setup_room_boundary_shell.sh
"""
import unreal
import math
import json
import os

MAP_PATH = "/Game/Maps/MyRoom"
CUBE_MESH = "/Engine/BasicShapes/Cube.Cube"
GRID_EXPORT_PATH = unreal.Paths.project_content_dir() + "Python/rover_occupancy_grid.json"

SPAWN_X = 125.0
SPAWN_Y = 80.0

BOUNDARY_TAG = "MyRoomBoundary"
BOUNDARY_LABEL_PREFIX = "MyRoomBoundary_"

FLOOR_Z = -147.0
FLOOR_Z_TOLERANCE = 35.0
FLOOR_NORMAL_MIN_Z = 0.82
TRACE_TOP_Z = 250.0
TRACE_BOTTOM_Z = -400.0
GRID_STEP = 50.0
WALL_THICKNESS = 14.0
WALL_HEIGHT = 300.0
CUBE_BASE_CM = 100.0

def _is_myroom_part(actor):
    if actor is None:
        return False
    return actor.get_actor_label().startswith("MyRoom_Part")


def _is_myroom_actor(actor):
    if _is_myroom_part(actor):
        return True
    if actor is None:
        return False
    lbl = actor.get_actor_label()
    if lbl.startswith("MyRoom") and "Boundary" not in lbl:
        return True
    return False


def _world_static_trace_queries():
    queries = []
    try:
        profile = unreal.CollisionProfile.get()
    except Exception:
        profile = None
    if profile is not None:
        for channel_name in ("ECC_WORLD_STATIC", "WORLD_STATIC"):
            channel = getattr(unreal.CollisionChannel, channel_name, None)
            if channel is None:
                continue
            try:
                query = profile.convert_to_trace_type(channel)
                if query is not None and query not in queries:
                    queries.append(query)
            except Exception:
                pass
    for name in ("TRACE_TYPE_QUERY1", "TRACE_TYPE_QUERY2", "TRACE_TYPE_QUERY3"):
        value = getattr(unreal.TraceTypeQuery, name, None)
        if value is not None and value not in queries:
            queries.append(value)
    return queries


def _parse_hit(hr):
    if hr is None:
        return False, None, None, None
    t = hr.to_tuple()
    if len(t) < 10:
        return False, None, None, None
    blocked = bool(t[0]) and t[9] is not None
    return blocked, t[5], t[6], t[9]


def _line_trace_floor_hit(world, x, y):
    start = unreal.Vector(x, y, TRACE_TOP_Z)
    end = unreal.Vector(x, y, TRACE_BOTTOM_Z)
    for trace_query in _world_static_trace_queries():
        try:
            hr = unreal.SystemLibrary.line_trace_single(
                world,
                start,
                end,
                trace_query,
                True,
                [],
                unreal.DrawDebugTrace.NONE,
                True,
            )
        except Exception:
            continue
        blocked, impact, normal, hit_actor = _parse_hit(hr)
        if not blocked or hit_actor is None:
            continue
        if not _is_myroom_part(hit_actor):
            continue
        if impact is None or normal is None:
            continue
        if abs(impact.z - FLOOR_Z) > FLOOR_Z_TOLERANCE:
            continue
        if normal.z < FLOOR_NORMAL_MIN_Z:
            continue
        return True
    return False


def _cell_inside(world, x, y):
    return _line_trace_floor_hit(world, x, y)


def _world():
    return unreal.EditorLevelLibrary.get_editor_world()


def _room_xy_bounds():
    xmin = ymin = float("inf")
    xmax = ymax = float("-inf")
    found = False
    for actor in unreal.EditorLevelLibrary.get_all_level_actors():
        if not _is_myroom_part(actor):
            continue
        origin, extent = actor.get_actor_bounds(False)
        xmin = min(xmin, origin.x - extent.x)
        xmax = max(xmax, origin.x + extent.x)
        ymin = min(ymin, origin.y - extent.y)
        ymax = max(ymax, origin.y + extent.y)
        found = True
    if not found:
        raise RuntimeError("No MyRoom_Part_* actors found in level")
    return xmin, ymin, xmax, ymax


def _destroy_existing_boundaries():
    removed = 0
    for actor in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        lbl = actor.get_actor_label()
        tags = [str(t) for t in actor.tags]
        if lbl.startswith(BOUNDARY_LABEL_PREFIX) or BOUNDARY_TAG in tags:
            unreal.EditorLevelLibrary.destroy_actor(actor)
            removed += 1
    unreal.log_warning(f"BOUNDARY_SHELL|removed_old={removed}")


def _build_grid(world, xmin, ymin, xmax, ymax):
    nx = max(1, int(math.ceil((xmax - xmin) / GRID_STEP)))
    ny = max(1, int(math.ceil((ymax - ymin) / GRID_STEP)))

    grid = {}
    inside = 0
    for ix in range(nx):
        for iy in range(ny):
            x = xmin + (ix + 0.5) * GRID_STEP
            y = ymin + (iy + 0.5) * GRID_STEP
            val = _cell_inside(world, x, y)
            grid[(ix, iy)] = val
            if val:
                inside += 1
    unreal.log_warning(
        f"BOUNDARY_SHELL|grid={nx}x{ny}|inside_cells={inside}|step={GRID_STEP}"
    )
    return grid, nx, ny, xmin, ymin, inside


def _cell_index_from_xy(x, y, xmin, ymin):
    ix = int(math.floor((x - xmin) / GRID_STEP))
    iy = int(math.floor((y - ymin) / GRID_STEP))
    return ix, iy


def _find_seed_cell(grid, nx, ny, xmin, ymin, seed_x, seed_y):
    seed_ix, seed_iy = _cell_index_from_xy(seed_x, seed_y, xmin, ymin)
    if grid.get((seed_ix, seed_iy), False):
        return seed_ix, seed_iy

    best = None
    best_dist = None
    for (ix, iy), val in grid.items():
        if not val:
            continue
        cx = xmin + (ix + 0.5) * GRID_STEP
        cy = ymin + (iy + 0.5) * GRID_STEP
        dist = (cx - seed_x) ** 2 + (cy - seed_y) ** 2
        if best_dist is None or dist < best_dist:
            best_dist = dist
            best = (ix, iy)
    return best


def _flood_interior_from_spawn(grid, nx, ny, xmin, ymin):
    seed = _find_seed_cell(grid, nx, ny, xmin, ymin, SPAWN_X, SPAWN_Y)
    if seed is None:
        raise RuntimeError("BOUNDARY_SHELL|no interior cell near rover spawn")

    connected = {}
    queue = [seed]
    visited = {seed}
    while queue:
        ix, iy = queue.pop(0)
        if not grid.get((ix, iy), False):
            continue
        connected[(ix, iy)] = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (ix + dx, iy + dy)
            if n in visited:
                continue
            if n[0] < 0 or n[1] < 0 or n[0] >= nx or n[1] >= ny:
                continue
            visited.add(n)
            queue.append(n)

    raw_inside = sum(1 for val in grid.values() if val)
    connected_count = len(connected)
    removed = raw_inside - connected_count
    unreal.log_warning(
        f"BOUNDARY_SHELL|flood|raw={raw_inside}|connected={connected_count}|removed={removed}"
    )
    return connected, connected_count


def _spawn_wall(cube_mesh, center, yaw_deg, length_cm, index):
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.StaticMeshActor,
        center,
        unreal.Rotator(0.0, yaw_deg, 0.0),
    )
    if actor is None:
        return False
    actor.set_actor_label(f"{BOUNDARY_LABEL_PREFIX}{index:04d}")
    actor.tags = [unreal.Name(BOUNDARY_TAG)]
    actor.set_actor_hidden_in_game(True)

    thickness_scale = WALL_THICKNESS / CUBE_BASE_CM
    length_scale = length_cm / CUBE_BASE_CM
    height_scale = WALL_HEIGHT / CUBE_BASE_CM
    actor.set_actor_scale3d(
        unreal.Vector(thickness_scale, length_scale, height_scale)
    )

    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_static_mesh(cube_mesh)
        comp.set_collision_profile_name("BlockAll")
        comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_editor_property("mobility", unreal.ComponentMobility.STATIC)
        comp.set_hidden_in_game(True)
        comp.set_visibility(False, True)
        break
    return True


def _spawn_boundary_walls(grid, nx, ny, xmin, ymin):
    cube_mesh = unreal.load_asset(CUBE_MESH)
    if cube_mesh is None:
        raise RuntimeError(f"Cannot load cube mesh: {CUBE_MESH}")

    z_center = FLOOR_Z + (WALL_HEIGHT * 0.5)
    count = 0

    def neighbor_inside(ix, iy):
        if ix < 0 or iy < 0 or ix >= nx or iy >= ny:
            return False
        return grid.get((ix, iy), False)

    for ix in range(nx):
        for iy in range(ny):
            if not grid.get((ix, iy), False):
                continue

            y_mid = ymin + (iy + 0.5) * GRID_STEP
            x_mid = xmin + (ix + 0.5) * GRID_STEP

            if not neighbor_inside(ix + 1, iy):
                x_edge = xmin + (ix + 1) * GRID_STEP
                center = unreal.Vector(
                    x_edge + WALL_THICKNESS * 0.5,
                    y_mid,
                    z_center,
                )
                if _spawn_wall(cube_mesh, center, 0.0, GRID_STEP, count):
                    count += 1

            if not neighbor_inside(ix - 1, iy):
                x_edge = xmin + ix * GRID_STEP
                center = unreal.Vector(
                    x_edge - WALL_THICKNESS * 0.5,
                    y_mid,
                    z_center,
                )
                if _spawn_wall(cube_mesh, center, 0.0, GRID_STEP, count):
                    count += 1

            if not neighbor_inside(ix, iy + 1):
                y_edge = ymin + (iy + 1) * GRID_STEP
                center = unreal.Vector(
                    x_mid,
                    y_edge + WALL_THICKNESS * 0.5,
                    z_center,
                )
                if _spawn_wall(cube_mesh, center, 90.0, GRID_STEP, count):
                    count += 1

            if not neighbor_inside(ix, iy - 1):
                y_edge = ymin + iy * GRID_STEP
                center = unreal.Vector(
                    x_mid,
                    y_edge - WALL_THICKNESS * 0.5,
                    z_center,
                )
                if _spawn_wall(cube_mesh, center, 90.0, GRID_STEP, count):
                    count += 1

    unreal.log_warning(f"BOUNDARY_SHELL|walls_spawned={count}")
    return count


def _export_occupancy_grid(grid, nx, ny, xmin, ymin, inside):
    interior_cells = [
        [ix, iy] for (ix, iy), val in grid.items() if val
    ]
    payload = {
        "xmin": xmin,
        "ymin": ymin,
        "grid_step": GRID_STEP,
        "nx": nx,
        "ny": ny,
        "inside_count": inside,
        "floor_z": FLOOR_Z,
        "floor_z_tolerance": FLOOR_Z_TOLERANCE,
        "floor_normal_min_z": FLOOR_NORMAL_MIN_Z,
        "detection": "line_trace_floor_flood_spawn",
        "spawn_xy": [SPAWN_X, SPAWN_Y],
        "interior_cells": interior_cells,
    }
    os.makedirs(os.path.dirname(GRID_EXPORT_PATH), exist_ok=True)
    with open(GRID_EXPORT_PATH, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
    unreal.log_warning(
        f"BOUNDARY_SHELL|grid_exported|path={GRID_EXPORT_PATH}|cells={inside}"
    )


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

world = _world()
_destroy_existing_boundaries()

xmin, ymin, xmax, ymax = _room_xy_bounds()
unreal.log_warning(
    f"BOUNDARY_SHELL|bounds|x=({xmin:.0f},{xmax:.0f})|y=({ymin:.0f},{ymax:.0f})"
)

grid, nx, ny, xmin, ymin, inside = _build_grid(world, xmin, ymin, xmax, ymax)
grid, inside = _flood_interior_from_spawn(grid, nx, ny, xmin, ymin)
if inside < 4:
    raise RuntimeError("BOUNDARY_SHELL|too few interior cells — check MyRoom collision")

_export_occupancy_grid(grid, nx, ny, xmin, ymin, inside)

wall_count = _spawn_boundary_walls(grid, nx, ny, xmin, ymin)
if wall_count < 4:
    raise RuntimeError(f"BOUNDARY_SHELL|only {wall_count} walls spawned — grid may be wrong")

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom after boundary shell")

unreal.log_warning(f"BOUNDARY_SHELL_DONE|walls={wall_count}|tag={BOUNDARY_TAG}")
