function ok = matlab_connect_smoke(timeoutSec)
%MATLAB_CONNECT_SMOKE  Test matlab_connect DDS path without opening GUI.
%
%   ok = matlab_connect_smoke()   % default 45s odom wait

    if nargin < 1, timeoutSec = 45; end

    setup_ros_dds();
    if ~check_robot_preflight()
        ok = false;
        return;
    end

    node = ros2node('matlab_connect_smoke');
    pause(2);
    try
        wait_for_odom_dds(node, timeoutSec);
        scanSub = robot_ros_subscriber(node, '/scan', 'sensor_msgs/LaserScan');
        try
            receive(scanSub, 8);
            fprintf('[OK] /scan sample received\n');
        catch
            fprintf('[WARN] No /scan sample (agent may have crashed on lidar)\n');
        end
        ok = true;
        fprintf('[PASS] matlab_connect_smoke — run matlab_connect for GUI\n');
    catch
        ok = false;
        fprintf('[FAIL] matlab_connect_smoke\n');
    end
end
