function ok = ros_cyclonedds_test()
%ROS_CYCLONEDDS_TEST  Try receive() with rmw_cyclonedds_cpp (MathWorks fix).
%
%   Shell (same terminal session before MATLAB):
%     export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
%     ros2 topic pub /matlab_dds_test std_msgs/msg/String "{data: ping}" -r 10
%
%   ok = ros_cyclonedds_test()

    addpath(fileparts(mfilename('fullpath')));

    setenv('ROS_DOMAIN_ID', '20');
    setenv('ROS_LOCALHOST_ONLY', '0');
    setenv('ROS_AUTOMATIC_DISCOVERY_RANGE', 'SUBNET');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    unsetenv('CYCLONEDDS_URI');
    setenv('RMW_IMPLEMENTATION', 'rmw_cyclonedds_cpp');

    try
        rmw = ros.internal.ros2.RMWEnvironment();
        rmw.RMWImplementation = 'rmw_cyclonedds_cpp';
        rmw.saveRMWEnvironment();
        fprintf('[OK] MATLAB pref RMW = rmw_cyclonedds_cpp\n');
    catch ME
        fprintf('[WARN] Could not save RMW pref: %s\n', ME.message);
    end

    ok = false;
    try
        n = ros2node('cyc_test', 'RMWImplementation', 'rmw_cyclonedds_cpp');
        pause(3);
        s = ros2subscriber(n, '/matlab_dds_test', 'std_msgs/String', ...
            'Reliability', 'reliable', 'Durability', 'volatile', 'Depth', 10);
        m = receive(s, 15);
        if ~isempty(m)
            fprintf('[OK] CycloneDDS receive: %s\n', m.data);
            ok = true;
        else
            fprintf('[FAIL] empty message\n');
        end
    catch ME
        fprintf('[FAIL] CycloneDDS receive: %s\n', ME.message);
    end
end
