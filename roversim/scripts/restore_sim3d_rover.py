"""Re-create the Sim3dStaticMeshActor that Simulink uses to drive the rover.

The Simulink 'Simulation 3D Static Mesh Actor' block (with ActorControl=on /
ControlledActor=RoverTwin) drives a PRE-PLACED ASim3dStaticMeshActor in the
level – it does NOT create actors itself. This script restores that actor at
the original room-interior location with the rover mesh.
"""
import os
import sys
import unreal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rover_spawn_pose import spawn_ue_vector

MAP_PATH   = "/Game/Maps/MyRoom"
MESH_PATH  = "/Game/Rover/Meshes/SM_Rover_Combined.SM_Rover_Combined"
ACTOR_TAG  = "RoverTwin"
ACTOR_LABEL = "RoverTwin"
LOCATION   = spawn_ue_vector()
ROTATION   = unreal.Rotator(0.0, 0.0, 0.0)   # pitch, yaw, roll
SCALE      = unreal.Vector(1.0, 1.0, 1.0)

SIM3D_CLASS = "/Script/MathWorksSimulation.Sim3dStaticMeshActor"

unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

# Guard: don't create a duplicate
for actor in unreal.EditorLevelLibrary.get_all_level_actors():
    if ACTOR_TAG in [str(t) for t in actor.tags]:
        loc = actor.get_actor_location()
        unreal.log_warning(
            f"ALREADY_EXISTS|label={actor.get_actor_label()}"
            f"|class={actor.get_class().get_name()}"
            f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
        )
        raise SystemExit(0)

# Load the class and mesh
sim3d_cls = unreal.load_class(None, SIM3D_CLASS)
if sim3d_cls is None:
    raise RuntimeError(f"Could not load class {SIM3D_CLASS}")

mesh = unreal.load_asset(MESH_PATH)
if mesh is None:
    raise RuntimeError(f"Could not load mesh {MESH_PATH}")

# Spawn the actor
new_actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sim3d_cls, LOCATION, ROTATION
)
if new_actor is None:
    raise RuntimeError("spawn_actor_from_class returned None")

# Set label, tag, scale, mesh
new_actor.set_actor_label(ACTOR_LABEL)
new_actor.tags = [unreal.Name(ACTOR_TAG)]
new_actor.set_actor_scale3d(SCALE)

for comp in new_actor.get_components_by_class(unreal.StaticMeshComponent):
    comp.set_editor_property("static_mesh", mesh)
    comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    break

root = new_actor.get_editor_property("root_component")
if root:
    root.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)

loc = new_actor.get_actor_location()
unreal.log_warning(
    f"ROVER_RESTORED"
    f"|label={new_actor.get_actor_label()}"
    f"|class={new_actor.get_class().get_name()}"
    f"|tags={[str(t) for t in new_actor.tags]}"
    f"|mesh={mesh.get_name()}"
    f"|loc=({loc.x:.0f},{loc.y:.0f},{loc.z:.0f})"
)

if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Failed to save level")
unreal.log_warning("LEVEL_SAVED|OK")
