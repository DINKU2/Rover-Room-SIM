# MathWorks references

Official documentation for the patterns used in RoverTwin.

## Co-simulation overview

- [Create 3D Simulations in Unreal Engine Environment](https://www.mathworks.com/help/sl3d/create-3d-simulation-in-unreal-engine-environment.html)  
  How Simulink 3D Animation interfaces with Unreal; actors, sensors, programmatic control.

- [How 3D Simulation in Unreal Engine Environment Works](https://www.mathworks.com/help/sl3d/how-3d-simulation-in-unreal-engine-environment-works.html)  
  Lock-step co-simulation between Simulink and the game engine.

- [Simulate Actor Movement Using Simulink](https://www.mathworks.com/help/sl3d/simulate-actor-movement-using-simulink.html)  
  Controlling actor translation/rotation each timestep via block I/O.

## Actor blocks

- [Simulation 3D Actor](https://www.mathworks.com/help/sl3d/simulation3dactor.html)  
  Operating modes: `Create at setup`, `Reference by name`, `Reference by instance number`.

- [Simulation 3D Actor Transform Set](https://www.mathworks.com/help/vdynblks/ref/simulation3dactortransformset.html)  
  Sends translation/rotation/scale to a tagged actor (`ActorTag` must match Unreal).

- [Simulation 3D Actor Transform Get](https://www.mathworks.com/help/vdynblks/ref/simulation3dactortransformget.html)  
  Reads actor pose back from Unreal (RoverTwin uses Static Mesh Actor outputs instead).

## Custom Unreal projects

- [Animate Custom Actors in the Unreal Editor](https://www.mathworks.com/help/sl3d/animate-custom-actors-in-the-unreal-editor.html)  
  C++ `ASim3dActor` subclasses, place actor in level, **match tag to Simulink**.

- [ASim3dActor](https://www.mathworks.com/help/sl3d/asim3dactor.html)  
  Base class for user-defined co-sim actors (`Sim3dSetup`, `Sim3dStep`, `Sim3dRelease`).

- [Get Started Communicating with the Unreal Engine Visualization Environment](https://www.mathworks.com/help/vdynblks/ug/get-started-communicating-with-the-unreal-engine-visualization-environment.html)  
  Message Get/Set actors and tag naming conventions.

## RoverTwin mapping to MathWorks pattern

| MathWorks concept | RoverTwin implementation |
|-------------------|-------------------------|
| Scene Configuration | `Room Scene` block |
| Custom static mesh actor | Pre-placed `Sim3dStaticMeshActor` in MyRoom |
| Actor tag | `RoverTwin` |
| Transform Set / drive | `Simulation 3D Static Mesh Actor` with `ActorControl=on` |
| Transform Get / feedback | `Move RoverTwin` output ports 1–2 |
| Unreal Editor scene source | Scene Configuration → Project format = Unreal Editor |
| Play required | PIE started manually or via `watch_rovertwin_play.sh` |

## Product pages

- [Simulink 3D Animation](https://www.mathworks.com/products/3d-animation.html)

## Related docs

- [Architecture overview](architecture-overview.md)
- [Simulink controller](simulink-controller.md)
