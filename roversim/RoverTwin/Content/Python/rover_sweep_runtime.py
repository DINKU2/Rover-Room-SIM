"""
rover_sweep_runtime.py — PIE-only sphere sweep for RoverProxy StaticMeshActor.

Set SWEEP_ENABLED = False for single-actor mode (no proxy, no wall blocking).
"""
import unreal

SWEEP_ENABLED = False
LIDAR_ENABLED = True
import math
import socket
import time

try:
    import rover_occupancy_grid as occ_grid
except ImportError:
    occ_grid = None

GHOST_TAG = "RoverTwin"
PROXY_TAG = "VisibleProxy"
FEEDBACK_LABEL = "RoverProxyFeedback"
PROXY_LABEL = "RoverProxy"
ROVER_RADIUS_CM = 22.0
BODY_Z_OFFSETS = (15.0, 25.0, 35.0)
SMOKE_TEST_DISTANCE_CM = 400.0
MAX_STEP_CM = 10.0
LAVA_HIT_NAME = "GrayVoid"
SWEEP_LABEL = "RoverSweepDriver"
LIDAR_UDP_HOST = "127.0.0.1"
LIDAR_UDP_PORT = 55221
LIDAR_RAYS = 180
LIDAR_MAX_RANGE_CM = 800.0
LIDAR_Z_OFFSET_CM = 7.9
LIDAR_SEND_PERIOD_S = 0.10

_pie_smoke_done = False
_lidar_sock = None
_lidar_last_send_s = 0.0
_lidar_frame = 0


def _norm2d_xy(vec, scale):
    length = math.sqrt(vec.x * vec.x + vec.y * vec.y)
    if length < 0.01:
        return unreal.Vector(0.0, 0.0, 0.0)
    s = scale / length
    return unreal.Vector(vec.x * s, vec.y * s, 0.0)


def _dist2d_xy(a, b):
    dx = a.x - b.x
    dy = a.y - b.y
    return math.sqrt(dx * dx + dy * dy)


def _parse_hit(hr):
    if hr is None:
        return False, None, None, None
    t = hr.to_tuple()
    if len(t) < 10:
        return False, None, None, None
    blocked = bool(t[0]) and t[9] is not None
    return blocked, t[5], t[6], t[9]


def _lidar_socket():
    global _lidar_sock
    if _lidar_sock is None:
        _lidar_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    return _lidar_sock


def _collision_profile():
    try:
        return unreal.CollisionProfile.get()
    except Exception:
        pass
    try:
        return unreal.get_default_object(unreal.CollisionProfile)
    except Exception:
        return None


def _world_static_trace_query():
    profile = _collision_profile()
    if profile is None:
        return None
    try:
        return profile.convert_to_trace_type(unreal.CollisionChannel.ECC_WORLD_STATIC)
    except Exception:
        pass
    try:
        return profile.convert_to_trace_type(unreal.CollisionChannel.WORLD_STATIC)
    except Exception:
        return None


def _world_static_object_types():
    types = []
    profile = _collision_profile()
    if profile is not None:
        for channel_name in ("ECC_WORLD_STATIC", "WORLD_STATIC"):
            channel = getattr(unreal.CollisionChannel, channel_name, None)
            if channel is None:
                continue
            try:
                obj_type = profile.convert_to_object_type(channel)
                if obj_type is not None and obj_type not in types:
                    types.append(obj_type)
            except Exception:
                pass
    if not types:
        for name in (
            "OBJECT_TYPE_QUERY1",
            "OBJECT_TYPE_QUERY2",
            "OBJECT_TYPE_QUERY3",
            "OBJECT_TYPE_QUERY4",
        ):
            value = getattr(unreal.ObjectTypeQuery, name, None)
            if value is not None:
                types.append(value)
    return types


def _world_static_trace_queries():
    queries = []
    for name in ("TRACE_TYPE_QUERY1", "TRACE_TYPE_QUERY2", "TRACE_TYPE_QUERY3"):
        value = getattr(unreal.TraceTypeQuery, name, None)
        if value is not None and value not in queries:
            queries.append(value)
    primary = _world_static_trace_query()
    if primary is not None and primary not in queries:
        queries.append(primary)
    return queries


def _sphere_sweep_channel(world, start, end, ignore):
    for trace_query in _world_static_trace_queries():
        try:
            hr = unreal.SystemLibrary.sphere_trace_single(
                world,
                start,
                end,
                ROVER_RADIUS_CM,
                trace_query,
                True,
                ignore,
                unreal.DrawDebugTrace.NONE,
                True,
                unreal.LinearColor(1.0, 0.0, 0.0, 1.0),
                unreal.LinearColor(0.0, 1.0, 0.0, 1.0),
                0.0,
            )
            blocked, _, _, _ = _parse_hit(hr)
            if blocked:
                return hr, f"channel:{trace_query}"
        except Exception as exc:
            unreal.log_warning(f"SWEEP_TRACE|channel_error={trace_query}|{exc}")
    return None, "channel_miss"


def _sphere_sweep_objects(world, start, end, ignore):
    object_types = _world_static_object_types()
    if not object_types:
        return None, "no_object_types"
    try:
        hr = unreal.SystemLibrary.sphere_trace_single_for_objects(
            world,
            start,
            end,
            ROVER_RADIUS_CM,
            object_types,
            True,
            ignore,
            unreal.DrawDebugTrace.NONE,
            True,
        )
        blocked, _, _, _ = _parse_hit(hr)
        if blocked:
            return hr, "objects"
    except Exception as exc:
        return None, f"objects_error={exc}"
    return None, "objects_miss"


def _sphere_sweep(world, start, end, ignore):
    hr, method = _sphere_sweep_channel(world, start, end, ignore)
    if hr is not None:
        return hr, method
    hr, method = _sphere_sweep_objects(world, start, end, ignore)
    if hr is not None:
        return hr, method
    return None, "miss"


def _line_trace(world, start, end, ignore):
    for trace_query in _world_static_trace_queries():
        try:
            hr = unreal.SystemLibrary.line_trace_single(
                world,
                start,
                end,
                trace_query,
                True,
                ignore,
                unreal.DrawDebugTrace.NONE,
                True,
                unreal.LinearColor(0.0, 0.5, 1.0, 1.0),
                unreal.LinearColor(1.0, 0.0, 0.0, 1.0),
                0.0,
            )
            blocked, impact, _, hit_actor = _parse_hit(hr)
            if blocked:
                return impact, hit_actor
        except Exception as exc:
            unreal.log_warning(f"LIDAR_TRACE|channel_error={trace_query}|{exc}")
    object_types = _world_static_object_types()
    if object_types:
        try:
            hr = unreal.SystemLibrary.line_trace_single_for_objects(
                world,
                start,
                end,
                object_types,
                True,
                ignore,
                unreal.DrawDebugTrace.NONE,
                True,
                unreal.LinearColor(0.0, 0.5, 1.0, 1.0),
                unreal.LinearColor(1.0, 0.0, 0.0, 1.0),
                0.0,
            )
            blocked, impact, _, hit_actor = _parse_hit(hr)
            if blocked:
                return impact, hit_actor
        except Exception as exc:
            unreal.log_warning(f"LIDAR_TRACE|objects_error={exc}")
    return None, None


def _send_udp_lidar(world, rover, ignore):
    global _lidar_last_send_s, _lidar_frame

    now = time.time()
    if now - _lidar_last_send_s < LIDAR_SEND_PERIOD_S:
        return
    _lidar_last_send_s = now
    _lidar_frame += 1

    loc = rover.get_actor_location()
    rot = rover.get_actor_rotation()
    yaw_rad = math.radians(rot.yaw)
    origin = unreal.Vector(loc.x, loc.y, loc.z + LIDAR_Z_OFFSET_CM)
    points = []

    for idx in range(LIDAR_RAYS):
        angle = yaw_rad + (2.0 * math.pi * idx / LIDAR_RAYS)
        direction = unreal.Vector(math.cos(angle), math.sin(angle), 0.0)
        end = unreal.Vector(
            origin.x + direction.x * LIDAR_MAX_RANGE_CM,
            origin.y + direction.y * LIDAR_MAX_RANGE_CM,
            origin.z,
        )
        impact, _ = _line_trace(world, origin, end, ignore)
        if impact is None:
            continue
        points.append(f"{impact.x / 100.0:.3f},{impact.y / 100.0:.3f}")

    packet = (
        f"ROVERLIDAR|{_lidar_frame}|{loc.x / 100.0:.3f}|{loc.y / 100.0:.3f}|"
        f"{math.radians(rot.yaw):.6f}|{';'.join(points)}"
    )
    try:
        _lidar_socket().sendto(packet.encode("ascii"), (LIDAR_UDP_HOST, LIDAR_UDP_PORT))
    except Exception as exc:
        if _lidar_frame % 30 == 1:
            unreal.log_warning(f"LIDAR_UDP|send_failed|{exc}")
    if _lidar_frame % 30 == 1:
        unreal.log_warning(
            f"LIDAR_UDP|frame={_lidar_frame}|points={len(points)}"
            f"|pose=({loc.x:.0f},{loc.y:.0f},{rot.yaw:.1f})|port={LIDAR_UDP_PORT}"
        )


def _is_walkable_floor(world, x, y, ignore):
    if occ_grid is None:
        unreal.log_warning("OCCUPANCY_GRID|missing_module")
        return False
    return occ_grid.is_interior(x, y)


def _segment_wall_stop(start_xy, end_xy, base_z, world, ignore):
    best_stop = None
    best_dist = None
    hit_name = None
    hit_method = None
    origin = unreal.Vector(start_xy[0], start_xy[1], base_z)

    for z_off in BODY_Z_OFFSETS:
        z = base_z + z_off
        start = unreal.Vector(start_xy[0], start_xy[1], z)
        end = unreal.Vector(end_xy[0], end_xy[1], z)
        hr, method = _sphere_sweep(world, start, end, ignore)
        blocked, impact, normal, hit_actor = _parse_hit(hr)
        if not blocked:
            continue

        pull = _norm2d_xy(unreal.Vector(normal.x, normal.y, 0.0), ROVER_RADIUS_CM)
        stop = unreal.Vector(impact.x + pull.x, impact.y + pull.y, base_z)
        dist = _dist2d_xy(origin, stop)
        if best_dist is None or dist < best_dist:
            best_dist = dist
            best_stop = stop
            hit_name = hit_actor.get_actor_label() if hit_actor else "unknown"
            hit_method = method

    if best_stop is not None:
        return True, best_stop, hit_name, hit_method
    return False, unreal.Vector(end_xy[0], end_xy[1], base_z), None, None


def _resolve_target(proxy_loc, ghost_loc, world, ignore):
    target = unreal.Vector(ghost_loc.x, ghost_loc.y, proxy_loc.z)
    pos = unreal.Vector(proxy_loc.x, proxy_loc.y, proxy_loc.z)

    dx = target.x - pos.x
    dy = target.y - pos.y
    dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.5:
        if _is_walkable_floor(world, target.x, target.y, ignore):
            return target, False, None, None, dist
        return pos, True, LAVA_HIT_NAME, "lava", dist

    steps = max(1, int(math.ceil(dist / MAX_STEP_CM)))
    final = pos
    blocked_any = False
    hit_name = None
    hit_method = None

    for step in range(1, steps + 1):
        t = step / float(steps)
        waypoint = unreal.Vector(pos.x + dx * t, pos.y + dy * t, proxy_loc.z)

        if not _is_walkable_floor(world, waypoint.x, waypoint.y, ignore):
            blocked_any = True
            hit_name = LAVA_HIT_NAME
            hit_method = "lava"
            break

        blocked, stop, name, method = _segment_wall_stop(
            (final.x, final.y),
            (waypoint.x, waypoint.y),
            proxy_loc.z,
            world,
            ignore,
        )
        if blocked:
            final = stop
            blocked_any = True
            hit_name = name
            hit_method = method
            break
        final = waypoint

    return final, blocked_any, hit_name, hit_method, dist


def _find_ghost(world):
    ghosts = unreal.GameplayStatics.get_all_actors_with_tag(world, unreal.Name(GHOST_TAG))
    if ghosts:
        return ghosts[0]
    for actor in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.Actor):
        if actor.get_actor_label() == GHOST_TAG:
            return actor
    return None


def _find_proxy(world):
    proxies = unreal.GameplayStatics.get_all_actors_with_tag(
        world, unreal.Name(PROXY_TAG)
    )
    for proxy in proxies:
        if proxy.get_actor_label() == PROXY_LABEL and isinstance(proxy, unreal.StaticMeshActor):
            return proxy

    for actor in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.StaticMeshActor):
        if actor.get_actor_label() == PROXY_LABEL:
            return actor
    return None


def _hide_ghost(ghost):
    if ghost is None:
        return
    ghost.set_actor_hidden_in_game(True)
    for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_hidden_in_game(True)
        comp.set_visibility(False, True)
        try:
            comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        except Exception:
            pass


def _hide_feedback(world):
    for actor in unreal.GameplayStatics.get_all_actors_of_class(world, unreal.Actor):
        if actor.get_actor_label() != FEEDBACK_LABEL:
            continue
        actor.set_actor_hidden_in_game(True)
        for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_hidden_in_game(True)
            comp.set_visibility(False, True)


def run_collision_smoke_test(world, origin=None, ignore=None):
    proxy = _find_proxy(world)
    if proxy is None:
        unreal.log_warning("SWEEP_SMOKE|skip=no_proxy")
        return False

    loc = origin if origin is not None else proxy.get_actor_location()
    ignore = ignore if ignore is not None else [proxy]
    z = loc.z + 25.0
    hits = 0
    methods = set()

    for axis, start, end in (
        ("+X", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x + SMOKE_TEST_DISTANCE_CM, loc.y, z)),
        ("-X", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x - SMOKE_TEST_DISTANCE_CM, loc.y, z)),
        ("+Y", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x, loc.y + SMOKE_TEST_DISTANCE_CM, z)),
        ("-Y", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x, loc.y - SMOKE_TEST_DISTANCE_CM, z)),
    ):
        hr, method = _sphere_sweep(world, start, end, ignore)
        blocked, _, _, hit_actor = _parse_hit(hr)
        name = hit_actor.get_actor_label() if blocked and hit_actor else "none"
        cls = hit_actor.get_class().get_name() if blocked and hit_actor else "none"
        unreal.log_warning(
            f"SWEEP_SMOKE|axis={axis}|hit={blocked}|method={method}|actor={name}|class={cls}"
        )
        if blocked:
            hits += 1
            methods.add(method)

    ok = hits >= 2
    unreal.log_warning(
        f"SWEEP_SMOKE|result={'PASS' if ok else 'FAIL'}|hits={hits}/4|methods={sorted(methods)}"
    )
    return ok


def run_lava_smoke_test(world, origin=None, ignore=None):
    proxy = _find_proxy(world)
    if proxy is None:
        unreal.log_warning("LAVA_SMOKE|skip=no_proxy")
        return False

    loc = origin if origin is not None else proxy.get_actor_location()
    ignore = ignore if ignore is not None else [proxy]
    if occ_grid is None:
        unreal.log_warning("LAVA_SMOKE|skip=no_occupancy_module")
        return False

    occ_grid.load_grid(force=True)
    grid = occ_grid.load_grid()
    spawn_ok = occ_grid.is_interior(loc.x, loc.y)
    outside_x = grid["xmin"] - grid["grid_step"] * 2.0
    outside_lava = not occ_grid.is_interior(outside_x, loc.y)
    void_test = not occ_grid.is_interior(loc.x, loc.y + 450.0)
    unreal.log_warning(
        f"LAVA_SMOKE|spawn_walkable={spawn_ok}|outside_is_lava={outside_lava}"
        f"|void450_is_lava={void_test}|method=occupancy_grid"
        f"|outside_xy=({outside_x:.0f},{loc.y:.0f})"
    )
    return spawn_ok and outside_lava


def run_move_segment_probe(world, proxy_loc, ghost_loc, ignore):
    z = proxy_loc.z + 25.0
    start = unreal.Vector(proxy_loc.x, proxy_loc.y, z)
    end = unreal.Vector(ghost_loc.x, ghost_loc.y, z)
    hr, method = _sphere_sweep(world, start, end, ignore)
    blocked, _, _, hit_actor = _parse_hit(hr)
    name = hit_actor.get_actor_label() if blocked and hit_actor else "none"
    seg = _dist2d_xy(proxy_loc, unreal.Vector(ghost_loc.x, ghost_loc.y, proxy_loc.z))
    unreal.log_warning(
        f"SWEEP_PROBE|seg={seg:.0f}|hit={blocked}|method={method}|actor={name}"
    )
    return blocked


def tick_rover_proxy(world):
    ghost = _find_ghost(world)
    proxy = _find_proxy(world)
    if ghost is None or proxy is None:
        return False, ghost is None, proxy is None

    _hide_ghost(ghost)
    _hide_feedback(world)

    ghost_loc = ghost.get_actor_location()
    proxy_loc = proxy.get_actor_location()
    ghost_rot = ghost.get_actor_rotation()

    target_loc, blocked, hit_name, hit_method, seg_len = _resolve_target(
        proxy_loc, ghost_loc, world, [ghost, proxy]
    )

    proxy.set_actor_location(target_loc, False, True)
    proxy.set_actor_rotation(ghost_rot, False)
    _send_udp_lidar(world, ghost, [ghost, proxy])

    tick_n = getattr(tick_rover_proxy, "_tick_n", 0) + 1
    tick_rover_proxy._tick_n = tick_n

    if blocked:
        unreal.log_warning(
            f"SWEEP_TICK_GAME"
            f"|ghost=({ghost_loc.x:.0f},{ghost_loc.y:.0f})"
            f"|proxy=({target_loc.x:.0f},{target_loc.y:.0f})"
            f"|seg={seg_len:.0f}"
            f"|wall=True"
            f"|hit={hit_name}"
            f"|method={hit_method}"
        )
    elif tick_n % 180 == 1:
        unreal.log_warning(
            f"SWEEP_TICK_GAME"
            f"|ghost=({ghost_loc.x:.0f},{ghost_loc.y:.0f})"
            f"|proxy=({target_loc.x:.0f},{target_loc.y:.0f})"
            f"|seg={seg_len:.0f}"
            f"|wall=False|hit=-|method=-"
        )
        if seg_len >= 30.0:
            run_move_segment_probe(world, proxy_loc, ghost_loc, [ghost, proxy])

    return True, False, False


def tick_lidar_only(world):
    rover = _find_ghost(world)
    if rover is None:
        return False
    _send_udp_lidar(world, rover, [rover])
    return True


def _is_sweep_actor(actor):
    if actor is None:
        return False
    if actor.get_actor_label() == SWEEP_LABEL:
        return True
    try:
        return "RoverSweepActor" in actor.get_class().get_name()
    except Exception:
        return False


def remove_sweep_actors_from_level():
    removed = 0
    for actor in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if _is_sweep_actor(actor):
            unreal.EditorLevelLibrary.destroy_actor(actor)
            removed += 1
    if removed:
        unreal.log_warning(f"SWEEP_ACTOR|removed_from_level|count={removed}")
    return removed


def _get_pie_world():
    try:
        pie_worlds = unreal.EditorLevelLibrary.get_pie_worlds(False)
        if pie_worlds:
            return pie_worlds[0]
    except Exception:
        pass

    for actor in unreal.ObjectIterator(unreal.Actor):
        if "UEDPIE" not in actor.get_path_name():
            continue
        world = actor.get_world()
        if world is not None:
            return world
    return None


_diag_count = 0
_pie_active_logged = False
_missing_logged = False
if not hasattr(unreal, "_rover_sweep_handle"):
    unreal._rover_sweep_handle = None


def _diag_tick(delta_seconds):
    global _diag_count, _pie_active_logged, _missing_logged, _pie_smoke_done
    _diag_count += 1

    editor_sub = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
    if not editor_sub.is_in_play_in_editor():
        _pie_active_logged = False
        _missing_logged = False
        _pie_smoke_done = False
        tick_rover_proxy._tick_n = 0
        return

    world = _get_pie_world()
    if world is None:
        return

    if SWEEP_ENABLED:
        if not _pie_active_logged:
            _pie_active_logged = True
            trace_query = _world_static_trace_query()
            object_types = _world_static_object_types()
            proxy = _find_proxy(world)
            ghost = _find_ghost(world)
            proxy_cls = proxy.get_class().get_name() if proxy else "none"
            ghost_cls = ghost.get_class().get_name() if ghost else "none"
            unreal.log_warning(
                "SWEEP_PIE|active|mode=substep_occupancy_grid"
                f"|trace_query={trace_query}"
                f"|object_types={len(object_types)}"
                f"|proxy={proxy_cls}|ghost={ghost_cls}|max_step={MAX_STEP_CM}"
            )
            if occ_grid is not None:
                occ_grid.load_grid(force=True)
                info = occ_grid.grid_info()
                unreal.log_warning(
                    f"OCCUPANCY_GRID|pie|loaded={info['loaded']}"
                    f"|cells={info['inside_count']}|grid={info['nx']}x{info['ny']}"
                )

        if not _pie_smoke_done:
            _pie_smoke_done = True
            run_collision_smoke_test(world)
            run_lava_smoke_test(world)

        ok, no_ghost, no_proxy = tick_rover_proxy(world)
        if not ok and not _missing_logged:
            _missing_logged = True
            unreal.log_warning(
                f"SWEEP_PIE|missing_actors|ghost={no_ghost}|proxy={no_proxy}"
                f"|run=bash scripts/run_setup_rover_scene.sh"
            )
        return

    if not LIDAR_ENABLED:
        return

    if not _pie_active_logged:
        _pie_active_logged = True
        ghost = _find_ghost(world)
        ghost_cls = ghost.get_class().get_name() if ghost else "none"
        unreal.log_warning(f"LIDAR_PIE|active|rover={ghost_cls}|collision_off")

    if not tick_lidar_only(world) and not _missing_logged:
        _missing_logged = True
        unreal.log_warning("LIDAR_PIE|missing_actors|ghost=True|tag=RoverTwin")


def register_diag_tick():
    global _diag_count, _pie_active_logged, _missing_logged, _pie_smoke_done
    _diag_count = 0
    _pie_active_logged = False
    _missing_logged = False
    _pie_smoke_done = False
    if unreal._rover_sweep_handle is not None:
        try:
            unreal.unregister_slate_post_tick_callback(unreal._rover_sweep_handle)
        except Exception:
            pass
    unreal._rover_sweep_handle = unreal.register_slate_post_tick_callback(_diag_tick)
    mode = "sweep" if SWEEP_ENABLED else "lidar_only"
    unreal.log_warning(f"ROVER_PIE_TICK|registered|mode={mode}")


def unregister_diag_tick():
    if unreal._rover_sweep_handle is not None:
        try:
            unreal.unregister_slate_post_tick_callback(unreal._rover_sweep_handle)
        except Exception:
            pass
        unreal._rover_sweep_handle = None


if SWEEP_ENABLED or LIDAR_ENABLED:
    register_diag_tick()
else:
    unregister_diag_tick()
    unreal.log_warning("ROVER_PIE_TICK|disabled")
