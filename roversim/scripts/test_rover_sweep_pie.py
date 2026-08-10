"""
test_rover_sweep_pie.py — start PIE briefly and verify sweep tick runs.
"""
import unreal
import time

MAP_PATH = "/Game/Maps/MyRoom"
RUNTIME = unreal.Paths.project_content_dir() + "Python/rover_sweep_runtime.py"


def load_runtime():
    with open(RUNTIME, "r", encoding="utf-8") as handle:
        code = handle.read()
    g = {"unreal": unreal, "__file__": RUNTIME}
    exec(compile(code, RUNTIME, "exec"), g)
    return g


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)
g = load_runtime()
tick_fn = g["tick_rover_proxy"]
get_world = g["_get_pie_world"]
find_ghost = g["_find_ghost"]
find_proxy = g["_find_proxy"]

level_sub = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
if level_sub.is_in_play_in_editor():
    level_sub.editor_request_end_play()
    time.sleep(1.0)

level_sub.editor_play_simulate()
for _ in range(40):
    time.sleep(0.25)
    if level_sub.is_in_play_in_editor():
        break

pie_worlds = []
try:
    pie_worlds = unreal.EditorLevelLibrary.get_pie_worlds(False)
except Exception as exc:
    unreal.log_warning(f"TEST|get_pie_worlds_error={exc}")

unreal.log_warning(f"TEST|in_pie={level_sub.is_in_play_in_editor()}|pie_worlds={len(pie_worlds)}")

time.sleep(1.0)

world = get_world()

ghost = find_ghost(world) if world else None
proxy = find_proxy(world) if world else None

unreal.log_warning(
    f"TEST|pie_worlds={len(pie_worlds)}|world={world is not None}"
    f"|ghost={ghost is not None}|proxy={proxy is not None}"
)

if world and ghost and proxy:
    g0 = ghost.get_actor_location()
    p0 = proxy.get_actor_location()
    ghost.set_actor_location(
        unreal.Vector(g0.x + 50.0, g0.y, g0.z), False, True
    )
    for _ in range(10):
        tick_fn(world)
    p1 = proxy.get_actor_location()
    unreal.log_warning(
        f"TEST|ghost_moved_to=({g0.x+50:.0f},{g0.y:.0f})"
        f"|proxy_before=({p0.x:.0f},{p0.y:.0f})|proxy_after=({p1.x:.0f},{p1.y:.0f})"
    )
    moved = abs(p1.x - p0.x) > 1.0 or abs(p1.y - p0.y) > 1.0
    unreal.log_warning(f"TEST|proxy_moved={moved}")
else:
    unreal.log_warning("TEST|FAIL|missing_world_or_actors")

level_sub.editor_request_end_play()
unreal.log_warning("TEST_ROVER_SWEEP_PIE_DONE")
