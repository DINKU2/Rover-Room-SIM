function state = rover_kinematics(state, cmd, dt)
%ROVER_KINEMATICS One unicycle integration step — same as firmware odom_update().
%
%   state = struct('x', 0, 'y', 0, 'yaw', 0)
%   cmd   = struct('linear_x', 0, 'angular_z', 0)   % geometry_msgs/Twist
%   dt    = sample period [s]
%
% Firmware reference (lidar_publisher/main/main.c):
%   delta_heading = angular_vel_z * vel_dt;
%   delta_x = linear_vel_x * cosf(heading_) * vel_dt;
%   delta_y = linear_vel_x * sinf(heading_) * vel_dt;

arguments
    state (1,1) struct
    cmd (1,1) struct
    dt (1,1) double {mustBePositive}
end

v = cmd.linear_x;
omega = cmd.angular_z;
yaw = state.yaw;

state.yaw = yaw + omega * dt;
state.x = state.x + v * cos(yaw) * dt;
state.y = state.y + v * sin(yaw) * dt;
end
