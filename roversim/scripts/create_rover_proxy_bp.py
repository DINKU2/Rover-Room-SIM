"""
create_rover_proxy_bp.py — Create BP_RoverProxy Blueprint asset.

BP_RoverProxy is a plain Actor Blueprint with a StaticMeshComponent (BlockAll
collision).  Its Event Tick sweeps toward the hidden RoverTwin ghost each frame
so wall collision is resolved by Unreal physics, not Simulink teleport.

After running this script, open the Blueprint in the editor and add the
Event Tick graph (5 nodes — see docs/rover-proxy-blueprint.md).
"""
import unreal

MESH_PATH = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"
BP_PACKAGE = "/Game/Rover"
BP_NAME = "BP_RoverProxy"
BP_FULL_PATH = f"{BP_PACKAGE}/{BP_NAME}"


def create_bp_asset():
    if unreal.EditorAssetLibrary.does_asset_exist(BP_FULL_PATH):
        unreal.log_warning(f"BP_EXISTS|{BP_FULL_PATH}")
        return unreal.load_asset(BP_FULL_PATH)

    factory = unreal.BlueprintFactory()
    factory.set_editor_property("parent_class", unreal.Actor)
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    bp = asset_tools.create_asset(BP_NAME, BP_PACKAGE, unreal.Blueprint, factory)
    if bp is None:
        raise RuntimeError(f"Failed to create Blueprint at {BP_FULL_PATH}")
    unreal.log_warning(f"BP_CREATED|{BP_FULL_PATH}")
    return bp


def add_mesh_component(bp):
    mesh = unreal.load_asset(MESH_PATH)
    if mesh is None:
        raise RuntimeError(f"Cannot load rover mesh: {MESH_PATH}")

    try:
        subsystem = unreal.get_editor_subsystem(unreal.SubobjectDataSubsystem)
        handles = subsystem.k2_gather_subobject_data_for_blueprint(bp)
        if not handles:
            raise RuntimeError("No subobject handles")

        params = unreal.AddNewSubobjectParams()
        params.parent_handle = handles[0]
        params.new_class = unreal.StaticMeshComponent
        params.blueprint_context = bp
        success, new_handle = subsystem.add_new_subobject(params)
        if not success.is_valid():
            raise RuntimeError("add_new_subobject returned invalid handle")
        unreal.log_warning("MESH_COMPONENT_SUBOBJECT|added via SubobjectDataSubsystem")
    except Exception as e:
        unreal.log_warning(f"SUBOBJECT_API_SKIP|{e}|will configure via CDO")

    unreal.BlueprintEditorLibrary.compile_blueprint(bp)

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

    if not configured:
        unreal.log_warning(
            "MESH_COMP_NOT_FOUND_IN_CDO|Open BP_RoverProxy and add StaticMeshComponent "
            "manually with BlockAll collision and rover mesh — see docs/rover-proxy-blueprint.md"
        )
    else:
        unreal.log_warning("MESH_COMPONENT_CONFIGURED|BlockAll|mobility=Movable|sim=False")


bp_asset = create_bp_asset()
add_mesh_component(bp_asset)
unreal.EditorAssetLibrary.save_asset(BP_FULL_PATH)
unreal.log_warning(
    f"BP_PROXY_READY|{BP_FULL_PATH}|"
    "NEXT: open BP in editor and add Event Tick sweep graph "
    "(see docs/rover-proxy-blueprint.md)"
)
