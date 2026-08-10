"""
verify_room_collision.py — Audit/fix MyRoom collision and run sphere-sweep smoke test.
"""
import unreal

MAP_PATH = "/Game/Maps/MyRoom"
ROVER_RADIUS_CM = 22.0
SMOKE_TEST_DISTANCE_CM = 400.0

SKIP_LABELS = {
    "RoverProxy",
    "RoverTwin",
    "RoverProxyFeedback",
    "RoverSweepDriver",
    "SpawnDebugOrb",
    "PlayerStart",
}


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
    return types


def _parse_hit(hr):
    if hr is None:
        return False, None
    t = hr.to_tuple()
    if len(t) < 10:
        return False, None
    blocked = bool(t[0]) and t[9] is not None
    return blocked, t[9]


def _sphere_sweep(world, start, end, ignore):
    trace_query = _world_static_trace_query()
    if trace_query is not None:
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
            blocked, hit_actor = _parse_hit(hr)
            if blocked:
                return True, hit_actor, "channel"
        except Exception as exc:
            unreal.log_warning(f"ROOM_COLLISION_TEST|channel_error={exc}")

    object_types = _world_static_object_types()
    if object_types:
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
            blocked, hit_actor = _parse_hit(hr)
            if blocked:
                return True, hit_actor, "objects"
        except Exception as exc:
            unreal.log_warning(f"ROOM_COLLISION_TEST|objects_error={exc}")

    return False, None, "miss"


def _is_room_mesh_actor(actor):
    lbl = actor.get_actor_label()
    if lbl in SKIP_LABELS or lbl.startswith("SoftFill"):
        return False
    if lbl.startswith("MyRoom") or lbl == "GroundPlane":
        return True
    if not isinstance(actor, unreal.StaticMeshActor):
        return False
    for comp in actor.get_components_by_class(unreal.StaticMeshComponent):
        mesh = comp.get_editor_property("static_mesh")
        if mesh is None:
            continue
        path = mesh.get_path_name().lower()
        if "myroom" in path or "my_room" in path:
            return True
    return False


def ensure_room_collision():
    walls = 0
    floors = 0
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        lbl = a.get_actor_label()
        if lbl == "GroundPlane":
            for comp in a.get_components_by_class(unreal.StaticMeshComponent):
                comp.set_collision_profile_name("NoCollision")
                comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
                floors += 1
            continue
        if not _is_room_mesh_actor(a):
            continue
        for comp in a.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
            comp.set_simulate_physics(False)
            comp.set_enable_gravity(False)
            comp.set_editor_property("mobility", unreal.ComponentMobility.STATIC)
            walls += 1
    unreal.log_warning(f"ROOM_COLLISION|mesh_colliders={walls}|floor_no_collision={floors}")
    return walls, floors


def _find_proxy():
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        if a.get_actor_label() == "RoverProxy":
            return a
    return None


def run_sphere_smoke_test():
    proxy = _find_proxy()
    if proxy is None:
        unreal.log_warning("ROOM_COLLISION_TEST|skip=no RoverProxy")
        return False

    world = unreal.EditorLevelLibrary.get_editor_world()
    loc = proxy.get_actor_location()
    z = loc.z + 25.0
    passed = 0
    for axis, start, end in (
        ("+X", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x + SMOKE_TEST_DISTANCE_CM, loc.y, z)),
        ("-X", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x - SMOKE_TEST_DISTANCE_CM, loc.y, z)),
        ("+Y", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x, loc.y + SMOKE_TEST_DISTANCE_CM, z)),
        ("-Y", unreal.Vector(loc.x, loc.y, z), unreal.Vector(loc.x, loc.y - SMOKE_TEST_DISTANCE_CM, z)),
    ):
        hit, actor, method = _sphere_sweep(world, start, end, [proxy])
        name = actor.get_actor_label() if hit and actor else "none"
        unreal.log_warning(
            f"ROOM_COLLISION_TEST|axis={axis}|sphere_r={ROVER_RADIUS_CM}|hit={hit}|method={method}|actor={name}"
        )
        if hit:
            passed += 1

    ok = passed >= 2
    unreal.log_warning(f"ROOM_COLLISION_TEST|result={'PASS' if ok else 'FAIL'}|hits={passed}/4")
    return ok


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)
ensure_room_collision()
ok = run_sphere_smoke_test()
if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom after collision verify")

if ok:
    unreal.log_warning("ROOM_COLLISION_VERIFY_DONE|PASS")
else:
    unreal.log_warning("ROOM_COLLISION_VERIFY_DONE|FAIL|check MyRoom mesh collision")
