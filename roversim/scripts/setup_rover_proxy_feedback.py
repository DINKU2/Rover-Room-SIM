"""
setup_rover_proxy_feedback.py — Sim3D pose reporter for Transform Get (tag=RoverProxy).

Transform Get only reads Sim3dStaticMeshActor actors registered with Sim3dInterface.
This invisible actor is tagged RoverProxy and attached to the visible proxy (or the
RoverTwin ghost until BP_RoverProxy exists).

Run in Unreal: Edit -> Execute Python Script -> this file
Or: bash scripts/run_setup_rover_proxy_feedback.sh
"""
import unreal

MAP_PATH = "/Game/Maps/MyRoom"
GHOST_TAG = "RoverTwin"
PROXY_TAG = "RoverProxy"
PROXY_LABEL = "RoverProxyFeedback"
BP_PROXY_LABEL = "RoverProxy"


def actor_tags(a):
    return [str(t) for t in a.tags]


def find_by_tag(tag):
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        if tag in actor_tags(a):
            return a
    return None


def find_by_label(label):
    for a in unreal.EditorLevelLibrary.get_all_level_actors():
        if a.get_actor_label() == label:
            return a
    return None


def destroy_proxy_feedback():
    for a in list(unreal.EditorLevelLibrary.get_all_level_actors()):
        lbl = a.get_actor_label()
        cls = a.get_class().get_name()
        if lbl == PROXY_LABEL:
            unreal.EditorLevelLibrary.destroy_actor(a)
        elif (
            PROXY_TAG in actor_tags(a)
            and cls == "Sim3dStaticMeshActor"
            and GHOST_TAG not in actor_tags(a)
        ):
            unreal.EditorLevelLibrary.destroy_actor(a)


def pick_attach_parent():
    visible = find_by_label(BP_PROXY_LABEL)
    if visible is not None and visible.get_class().get_name() != "Sim3dStaticMeshActor":
        return visible, BP_PROXY_LABEL
    bp = find_by_label("BP_RoverProxy")
    if bp is not None and bp.get_class().get_name() != "Sim3dStaticMeshActor":
        return bp, "BP_RoverProxy"
    ghost = find_by_tag(GHOST_TAG)
    if ghost is not None:
        unreal.log_warning(
            "FEEDBACK_WARN|no visible RoverProxy — attaching to ghost (run run_setup_rover_sweep_complete.sh)"
        )
        return ghost, "RoverTwin"
    return None, "none"


unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

parent, parent_name = pick_attach_parent()
if parent is None:
    raise RuntimeError("RoverTwin ghost not found — run scripts/run_audit_rover_scene.sh first")

destroy_proxy_feedback()

sim3d_cls = unreal.load_class(None, "/Script/MathWorksSimulation.Sim3dStaticMeshActor")
if sim3d_cls is None:
    raise RuntimeError("Sim3dStaticMeshActor class not found — is MathWorksSimulation enabled?")

loc = parent.get_actor_location()
feedback = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sim3d_cls, loc, unreal.Rotator(0, 0, 0)
)
if feedback is None:
    raise RuntimeError("Failed to spawn RoverProxy Sim3dStaticMeshActor")

feedback.set_actor_label(PROXY_LABEL)
feedback.tags = [unreal.Name(PROXY_TAG)]
feedback.set_actor_hidden_in_game(True)

for comp in feedback.get_components_by_class(unreal.StaticMeshComponent):
    comp.set_editor_property("static_mesh", None)
    comp.set_collision_profile_name("NoCollision")
    comp.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
    comp.set_simulate_physics(False)
    comp.set_enable_gravity(False)
    comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    comp.set_visibility(False, True)
    comp.set_hidden_in_game(True)
    break

feedback.attach_to_actor(
    parent,
    "",
    unreal.AttachmentRule.SNAP_TO_TARGET,
    unreal.AttachmentRule.SNAP_TO_TARGET,
    unreal.AttachmentRule.KEEP_RELATIVE,
    False,
)

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save MyRoom")

unreal.log_warning(
    f"ROVER_PROXY_FEEDBACK_DONE|tag={PROXY_TAG}|class=Sim3dStaticMeshActor"
    f"|attached_to={parent_name}|label={PROXY_LABEL}"
)
