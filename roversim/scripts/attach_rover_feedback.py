"""
DEPRECATED — do not run. Keyboard reads Move RoverTwin outputs directly.
---
attach_rover_feedback.py

Creates a lightweight "RoverActual" Sim3dStaticMeshActor that is ATTACHED to
the physics-driven RoverVisible actor.

Why this works:
  - RoverVisible moves via the Unreal physics engine (BlockAll collision).
  - RoverActual is a child of RoverVisible → its world transform equals
    RoverVisible's world transform (zero relative offset).
  - Sim3dInterface registers RoverActual by its tag and publishes its
    WorldTransform each frame.
  - Simulink's "Simulation 3D Actor Transform Get" block (tag="RoverActual")
    reads that transform → actual X, Y, Yaw back in Simulink.

No Blueprint event graph needed.  Pure Python level-edit.
"""
import sys
raise SystemExit("DEPRECATED: run scripts/run_audit_rover_scene.sh instead")

import unreal

MAP_PATH      = "/Game/Maps/MyRoom"
ACTUAL_TAG    = "RoverActual"
ACTUAL_LABEL  = "RoverActual"
VISIBLE_LABEL = "RoverVisible"

unreal.EditorLoadingAndSavingUtils.load_map(MAP_PATH)

# ─────────────────────────────────────────────────────────────────────────────
# 0. Find RoverVisible (physics rover) — must exist first
# ─────────────────────────────────────────────────────────────────────────────
rover_visible = None
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if a.get_actor_label() == VISIBLE_LABEL:
        rover_visible = a
        break

if rover_visible is None:
    raise RuntimeError("RoverVisible not found — run run_rover_physics_setup.sh first")

visible_loc = rover_visible.get_actor_location()
unreal.log_warning(
    f"VISIBLE_FOUND|loc=({visible_loc.x:.0f},{visible_loc.y:.0f},{visible_loc.z:.0f})"
)

# ─────────────────────────────────────────────────────────────────────────────
# 1. Skip if RoverActual already exists
# ─────────────────────────────────────────────────────────────────────────────
for a in unreal.EditorLevelLibrary.get_all_level_actors():
    if a.get_actor_label() == ACTUAL_LABEL:
        unreal.log_warning("ALREADY_EXISTS|RoverActual already in level — verifying attachment")
        parent = a.get_attach_parent_actor()
        if parent and parent.get_actor_label() == VISIBLE_LABEL:
            unreal.log_warning("ATTACHMENT_OK|RoverActual already attached to RoverVisible")
        else:
            unreal.log_warning("REATTACHING|Attaching RoverActual to RoverVisible")
            a.attach_to_actor(
                rover_visible, "",
                unreal.AttachmentRule.SNAP_TO_TARGET,
                unreal.AttachmentRule.SNAP_TO_TARGET,
                unreal.AttachmentRule.KEEP_RELATIVE,
                False
            )
            unreal.log_warning("REATTACH_DONE")
        if not unreal.EditorLoadingAndSavingUtils.save_current_level():
            raise RuntimeError("Save failed")
        unreal.log_warning("LEVEL_SAVED|OK")
        raise SystemExit(0)

# ─────────────────────────────────────────────────────────────────────────────
# 2. Create RoverActual as a Sim3dStaticMeshActor (no visible mesh)
#    Sim3dStaticMeshActor registers with Sim3dInterface → Actor Transform Get
#    can read its world transform.
# ─────────────────────────────────────────────────────────────────────────────
sim3d_cls_path = "/Script/MathWorksSimulation.Sim3dStaticMeshActor"
sim3d_cls = unreal.load_class(None, sim3d_cls_path)
if sim3d_cls is None:
    raise RuntimeError(f"Cannot load class: {sim3d_cls_path}")

rover_actual = unreal.EditorLevelLibrary.spawn_actor_from_class(
    sim3d_cls,
    visible_loc,          # same position as RoverVisible
    unreal.Rotator(0, 0, 0)
)
rover_actual.set_actor_label(ACTUAL_LABEL)
rover_actual.tags = [unreal.Name(ACTUAL_TAG)]

# Hide it — it's only a position reporter, not visual
rover_actual.set_actor_hidden_in_game(True)

# Disable collision so it doesn't interfere with physics
for comp in rover_actual.get_components_by_class(unreal.StaticMeshComponent):
    comp.set_collision_profile_name("NoCollision")
    comp.set_editor_property("mobility", unreal.ComponentMobility.MOVABLE)
    break

# ─────────────────────────────────────────────────────────────────────────────
# 3. Attach RoverActual to RoverVisible (zero relative offset)
#    SNAP_TO_TARGET puts it at RoverVisible's exact location.
#    As physics moves RoverVisible, RoverActual follows automatically.
# ─────────────────────────────────────────────────────────────────────────────
rover_actual.attach_to_actor(
    rover_visible,                          # parent actor
    "",                                     # socket (root)
    unreal.AttachmentRule.SNAP_TO_TARGET,   # location: snap to parent
    unreal.AttachmentRule.SNAP_TO_TARGET,   # rotation: snap to parent
    unreal.AttachmentRule.KEEP_RELATIVE,    # scale: keep
    False                                   # weld simulated bodies
)

loc_after = rover_actual.get_actor_location()
parent_actor = rover_actual.get_attach_parent_actor()
parent_label = parent_actor.get_actor_label() if parent_actor else "None"

unreal.log_warning(
    f"ROVER_ACTUAL_CREATED"
    f"|tag={ACTUAL_TAG}|loc=({loc_after.x:.0f},{loc_after.y:.0f},{loc_after.z:.0f})"
    f"|attached_to={parent_label}"
)

# ─────────────────────────────────────────────────────────────────────────────
# 4. Save
# ─────────────────────────────────────────────────────────────────────────────
if not unreal.EditorLoadingAndSavingUtils.save_current_level():
    raise RuntimeError("Save failed")
unreal.log_warning("LEVEL_SAVED|OK")
unreal.log_warning(
    "FEEDBACK_SETUP_DONE|"
    "RoverActual (Sim3dStaticMeshActor, tag='RoverActual') is attached to "
    "RoverVisible. Its world transform mirrors the physics rover position. "
    "Simulink Actor Transform Get block reads tag='RoverActual'."
)
