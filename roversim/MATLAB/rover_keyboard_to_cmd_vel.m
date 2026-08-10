function cmd = rover_keyboard_to_cmd_vel(forward, reverse, left, right, stop, cfg)
%ROVER_KEYBOARD_TO_CMD_VEL Map W/A/S/D keyboard flags to /cmd_vel values.
%
% Matches physical teleop in ~/Desktop/project/Rover-Room-SIM:
%   matlab_connect.m, teleop/teleop_keyboard.py

if nargin < 6
    cfg = rover_cmd_vel_config();
end

moveX = double(forward) - double(reverse);
moveTh = double(left) - double(right);

if stop
    moveX = 0;
end

cmd = struct();
cmd.linear_x = moveX * cfg.linear_speed_mps;
cmd.angular_z = moveTh * cfg.angular_speed_rps;
end
