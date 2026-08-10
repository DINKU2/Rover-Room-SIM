"""
RoverSweepComponent — Python ActorComponent that sweeps the owner toward RoverTwin.

Loaded by setup_rover_sweep_complete.py. Each tick:
  ghost = actor tagged RoverTwin
  owner.set_actor_location(ghost_loc, sweep=True)
  owner.set_actor_rotation(ghost_rot)
"""
import unreal


@unreal.uclass()
class RoverSweepComponent(unreal.ActorComponent):
    ghost_tag = unreal.uproperty(unreal.Name, meta={"DefaultValue": "RoverTwin"})

    def _post_init(self):
        self.primary_component_tick.b_can_ever_tick = True
        self.primary_component_tick.set_tick_function_enable(True)

    def receive_tick(self, delta_seconds):
        owner = self.get_owner()
        if owner is None:
            return

        ghost = None
        for actor in unreal.GameplayStatics.get_all_actors_with_tag(owner, self.ghost_tag):
            ghost = actor
            break
        if ghost is None:
            for actor in unreal.EditorLevelLibrary.get_all_level_actors():
                if str(self.ghost_tag) in [str(t) for t in actor.tags]:
                    ghost = actor
                    break
        if ghost is None:
            return

        target_loc = ghost.get_actor_location()
        target_rot = ghost.get_actor_rotation()
        owner.set_actor_location(target_loc, sweep=True, teleport=False)
        owner.set_actor_rotation(target_rot, teleport=False)
