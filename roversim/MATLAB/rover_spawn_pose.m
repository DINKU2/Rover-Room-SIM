function pose = rover_spawn_pose()
%ROVER_SPAWN_POSE Canonical RoverTwin spawn pose inside MyRoom.
%
% The photogrammetry room mesh is offset from the Unreal world origin.
% Spawning at (0, 0) places the rover outside the visible floor; this pose
% matches the room-interior location used by restore_sim3d_rover.py.
%
% Transform Set/Get (Simulation 3D Actor) uses metres with the same axis
% handedness as Unreal world coordinates (centimetres / 100):
%   sim_x = ue_x / 100
%   sim_y = ue_y / 100
%   sim_z = ue_z / 100
%
% Edit pose.ue_cm only when moving spawn; sim_m is derived below.

% Room floor centre inside the photogrammetry scan (not UE world origin).
pose.ue_cm = [125.0, 80.0, -147.0];
pose.sim_m = pose.ue_cm / 100;
pose.yaw_deg = 0;
end
