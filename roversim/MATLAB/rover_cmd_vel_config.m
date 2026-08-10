function cfg = rover_cmd_vel_config()
%ROVER_CMD_VEL_CONFIG Shared command interface with the physical micro-ROS rover.
%
% Matches the real robot stack in ~/Desktop/project/Rover-Room-SIM:
%   - Topic: /cmd_vel (geometry_msgs/Twist)
%   - Fields: linear.x [m/s], angular.z [rad/s]
%   - Teleop defaults: matlab_connect.m, teleop/teleop_keyboard.py
%   - Firmware odom integrator: esp/.../lidar_publisher/main/main.c odom_update()
%
% The simulated rover integrates the SAME equations as firmware wheel odom,
% then sends pose to Unreal via Transform Set (visualization only).

cfg.cmd_vel_topic = "/cmd_vel";
cfg.linear_field = "linear.x";
cfg.angular_field = "angular.z";

% Default teleop speeds (physical robot defaults)
cfg.linear_speed_mps = 0.2;
cfg.angular_speed_rps = 1.0;

% Keyboard Q/E speed adjust (Simulink CmdVel Linear/Angular gain blocks)
cfg.linear_speed_min_mps = 0.05;
cfg.linear_speed_max_mps = 0.8;
cfg.angular_speed_min_rps = 0.25;
cfg.angular_speed_max_rps = 4.0;
cfg.speed_step_factor = 1.25;

% Simulink sample time [s] — must match FixedStep in build_rover_control_model.m
cfg.sample_time_s = 0.02;

% URDF-derived geometry (MicroROS.urdf) — for future wheel-speed drive model
% Front wheel Y positions: ±0.0675 m → track width
cfg.track_width_m = 0.135;
% Front X ~0.0455 m, rear X ~-0.0495 m
cfg.wheelbase_m = 0.095;
% Placeholder radius (Unreal cosim model used 0.05 m)
cfg.wheel_radius_m = 0.05;

% Mesh vs Simulation 3D heading offset [deg]. Set after visual calibration.
cfg.mesh_yaw_offset_deg = 0;

% --- Handedness signs (ROS right-handed -> Unreal/Sim3D left-handed) --------
% These feed the "Set Y Flip" and "Set Yaw Flip" gains in the model.
% Theory (MathWorks (x,-y,z,-yaw) map) says both should be -1. If, with the
% scene running, the rover drives correctly STRAIGHT but its nose diverges
% from its travel direction AFTER turning (divergence grows with turn angle),
% the engine renders Default yaw with the opposite sign -> set mesh_yaw_sign = +1.
% Flip live without rebuilding:
%   set_param('RoverTwinControl/Set Yaw Flip','Gain','1')   % try +1
%   set_param('RoverTwinControl/Set Yaw Flip','Gain','-1')  % back to -1
cfg.y_translation_sign = -1;   % Set Y Flip gain
cfg.mesh_yaw_sign      = -1;   % Set Yaw Flip gain (mesh rotation only)

% Source references (do not modify those projects)
cfg.physical_project = fullfile(getenv("HOME"), "Desktop", "project", "Rover-Room-SIM");
end
