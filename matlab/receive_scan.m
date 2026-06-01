function msg = receive_scan(node, timeoutSec)
%RECEIVE_SCAN  Read one /scan sample (best-effort, then reliable fallback).

    if nargin < 2, timeoutSec = 10; end
    addpath(fileparts(mfilename('fullpath')));

    msg = [];
    try
        sub = robot_ros_subscriber(node, '/scan', 'sensor_msgs/LaserScan');
        msg = ros_sub_read(sub, timeoutSec);
        if ~isempty(msg), return; end
    catch
    end

    try
        sub = ros2subscriber(node, '/scan', 'sensor_msgs/LaserScan', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        msg = ros_sub_read(sub, timeoutSec);
    catch
    end
end
