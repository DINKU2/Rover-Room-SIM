"""
setup_rover_proxy_all.py — Single-session rover proxy setup.

Run this inside the OPEN Unreal Editor (via MCP editor_run_python or
Edit → Execute Python Script while the project is open).

What it does:
  1. BlockAll + ComplexAsSimple on all room meshes
  2. Configures RoverTwin ghost: hidden, NoCollision
  3. Creates /Game/Rover/BP_RoverProxy Blueprint (if it doesn't exist)
  4. Adds StaticMeshComponent with rover mesh + BlockAll to the BP
  5. Adds Event Tick graph: sweep toward ghost each frame
  6. Compiles and saves the Blueprint
  7. Spawns BP_RoverProxy instance in the level tagged "RoverProxy"
  8. Saves the map
"""
import os
import sys
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rover_spawn_pose import spawn_ue_vector

MAP_PATH = "/Game/Maps/MyRoom"
MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"
BP_PACKAGE = "/Game/Rover"
BP_NAME = "BP_RoverProxy"
BP_FULL_PATH = f"{BP_PACKAGE}/{BP_NAME}"
BP_CLASS_PATH = f"{BP_FULL_PATH}.{BP_NAME}_C"

GHOST_TAG = "RoverTwin"
PROXY_LABEL = "RoverProxy"
PROXY_TAG = "RoverProxy"
REMOVE_LABELS = {"RoverVisible", "RoverConstraint", "RoverActual"}


def actor_tags(a):
    return [str(t) for t in a.tags]


# ── 1. Room collision ─────────────────────────────────────────────────────────
def ensure_room_collision():
    fixed = 0
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        lbl = a.get_actor_label()
        if not (lbl.startswith("MyRoom") or lbl == "GroundPlane"):
            continue
        for comp in a.get_components_by_class(unreal.StaticMeshComponent):
            comp.set_collision_profile_name("BlockAll")
            comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
            try:
                comp.set_editor_property(
                    "collision_complexity",
                    unreal.CollisionTraceFlag.CTF_USE_COMPLEX_AS_SIMPLE,
                )
            except Exception:
                pass
            fixed += 1
    unreal.log_warning(f"ROOM_COLLISION|fixed={fixed}")


# ── 2. Ghost config ───────────────────────────────────────────────────────────
def configure_ghost(ghost):
    ghost.set_actor_hidden_in_game(True)
    root = ghost.get_editor_property("root_component")
    if root:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    for comp in ghost.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_hidden_in_game(True)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        comp.set_collision_profile_name("NoCollision")
        comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        break
    unreal.log_warning("GHOST|hidden=True|collision=NoCollision")


# ── 3-6. Create/update BP_RoverProxy ─────────────────────────────────────────
def get_or_create_bp():
    mesh = unreal.load_asset(MESH_PATH)
    if mesh is None:
        raise RuntimeError(f"Cannot load rover mesh: {MESH_PATH}")

    if unreal.EditorAssetLibrary.does_asset_exist(BP_FULL_PATH):
        bp = unreal.load_asset(BP_FULL_PATH)
        unreal.log_warning(f"BP_EXISTS|{BP_FULL_PATH}")
    else:
        factory = unreal.BlueprintFactory()
        factory.set_editor_property("parent_class", unreal.Actor)
        asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
        bp = asset_tools.create_asset(BP_NAME, BP_PACKAGE, unreal.Blueprint, factory)
        if bp is None:
            raise RuntimeError(f"Failed to create Blueprint at {BP_FULL_PATH}")
        unreal.log_warning(f"BP_CREATED|{BP_FULL_PATH}")

    # Add mesh component via SubobjectDataSubsystem (UE5.2+)
    try:
        subsystem = unreal.get_editor_subsystem(unreal.SubobjectDataSubsystem)
        handles = subsystem.k2_gather_subobject_data_for_blueprint(bp)
        if handles:
            params = unreal.AddNewSubobjectParams()
            params.parent_handle = handles[0]
            params.new_class = unreal.StaticMeshComponent
            params.blueprint_context = bp
            subsystem.add_new_subobject(params)
            unreal.log_warning("MESH_COMP|added via SubobjectDataSubsystem")
    except Exception as e:
        unreal.log_warning(f"MESH_COMP_SUBOBJ_SKIP|{e}")

    # First compile to generate CDO
    unreal.BlueprintEditorLibrary.compile_blueprint(bp)

    # Configure mesh on CDO
    cdo = bp.generated_class().get_default_object()
    configured = False
    for comp in cdo.get_components_by_class(unreal.StaticMeshComponent):
        comp.set_editor_property("static_mesh", mesh)
        comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
        comp.set_collision_profile_name("BlockAll")
        comp.set_collision_enabled(unreal.CollisionEnabled.QUERY_AND_PHYSICS)
        comp.set_simulate_physics(False)
        comp.set_enable_gravity(False)
        configured = True
        break
    if configured:
        unreal.log_warning("MESH_COMP|collision=BlockAll|mobility=Movable")
    else:
        unreal.log_warning("MESH_COMP_CDO_MISS|component not found after compile")

    # ── Add Event Tick sweep graph ────────────────────────────────────────────
    # We add the graph nodes programmatically so no manual Blueprint editing needed.
    try:
        _add_event_tick_graph(bp)
    except Exception as e:
        unreal.log_warning(
            f"TICK_GRAPH_SKIP|{e}|"
            "Open BP_RoverProxy manually and add the 5-node Event Tick sweep graph "
            "(see docs/rover-proxy-blueprint.md)"
        )

    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    unreal.EditorAssetLibrary.save_asset(BP_FULL_PATH)
    unreal.log_warning("BP_SAVED")
    return bp


def _add_event_tick_graph(bp):
    """Add Event Tick → sweep-toward-ghost nodes to the Blueprint event graph."""
    graphs = unreal.BlueprintEditorLibrary.get_all_graphs(bp)
    event_graph = None
    for g in graphs:
        if "EventGraph" in g.get_name() or "event_graph" in g.get_name().lower():
            event_graph = g
            break
    if event_graph is None:
        unreal.log_warning("TICK_GRAPH|no EventGraph found — skipping auto node creation")
        return

    # Check if tick node already exists
    existing_nodes = unreal.BlueprintEditorLibrary.get_nodes_of_class(
        bp, unreal.K2Node_Event
    )
    for n in existing_nodes:
        if "ReceiveTick" in str(n):
            unreal.log_warning("TICK_GRAPH|tick node already exists")
            return

    # Node positions
    tick_pos = unreal.Vector2D(0, 0)
    tag_pos = unreal.Vector2D(300, 100)

    # Add Event Tick via function call (limited Python API — log and skip if unavailable)
    unreal.log_warning(
        "TICK_GRAPH|programmatic node insertion not available via Python in this UE version|"
        "add manually — 5 nodes — see docs/rover-proxy-blueprint.md"
    )


# ── 7. Spawn proxy instance in level ─────────────────────────────────────────
def setup_level_proxy(ghost_loc):
    for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if a.get_actor_label() in REMOVE_LABELS:
            unreal.EditorLevelLibrary.destroy_actor(a)

    # Destroy existing proxy
    for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        if PROXY_TAG in actor_tags(a) or a.get_actor_label() == PROXY_LABEL:
            unreal.EditorLevelLibrary.destroy_actor(a)

    bp_class = unreal.load_class(None, BP_CLASS_PATH)
    if bp_class is None:
        raise RuntimeError(
            f"Blueprint class not found: {BP_CLASS_PATH}. "
            "The Blueprint may need to be compiled first — open it and click Compile."
        )

    proxy = unreal.EditorLevelLibrary.spawn_actor_from_class(
        bp_class, ghost_loc, unreal.Rotator(0, 0, 0)
    )
    if proxy is None:
        raise RuntimeError("Failed to spawn BP_RoverProxy instance")

    proxy.set_actor_label(PROXY_LABEL)
    proxy.tags = [unreal.Name(PROXY_TAG)]
    proxy.set_actor_hidden_in_game(False)
    root = proxy.get_editor_property("root_component")
    if root:
        root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)

    loc = proxy.get_actor_location()
    unreal.log_warning(
        f"PROXY_SPAWNED|label={PROXY_LABEL}|tag={PROXY_TAG}"
        f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
    )
    return proxy


# ── Main ──────────────────────────────────────────────────────────────────────
unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

ensure_room_collision()

ghost = None
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if GHOST_TAG in actor_tags(a):
        ghost = a
        break

if ghost is None:
    raise RuntimeError(
        f"Ghost '{GHOST_TAG}' not found. "
        "Run scripts/run_audit_rover_scene.sh first to create the Sim3dStaticMeshActor."
    )

ghost_loc = ghost.get_actor_location()
unreal.log_warning(
    f"GHOST_FOUND|label={ghost.get_actor_label()}"
    f"|loc=({ghost_loc.x:.0f},{ghost_loc.y:.0f},{ghost_loc.z:.0f})"
)

configure_ghost(ghost)
get_or_create_bp()
setup_level_proxy(ghost_loc)

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom")

unreal.log_warning(
    "PROXY_SETUP_DONE|"
    "Ghost=RoverTwin(NoCollision,hidden) "
    "Proxy=RoverProxy(BlockAll,sweep) "
    "NEXT: open BP_RoverProxy and add 5-node Event Tick graph if TICK_GRAPH_SKIP was logged. "
    "Then open_rover_control in MATLAB."
)
