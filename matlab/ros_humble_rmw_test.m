function ok = ros_humble_rmw_test()
%ROS_HUMBLE_RMW_TEST  Point MATLAB at /opt/ros/humble and test receive().
%
%   Shell first (same RMW + domain):
%     source /opt/ros/humble/setup.bash
%     export ROS_DOMAIN_ID=20
%     export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
%     ros2 topic pub /matlab_dds_test std_msgs/msg/String "{data: ping}" -r 10

    addpath(fileparts(mfilename('fullpath')));

    humble = '/opt/ros/humble';
    if ~isfolder(humble)
        fprintf('[FAIL] %s not found\n', humble);
        ok = false;
        return;
    end

    try
        ros.codertarget.internal.DeviceParameters.setROS2InstallFolder(humble);
        fprintf('[OK] ROS2Install pref -> %s\n', humble);
    catch ME
        fprintf('[WARN] setROS2InstallFolder: %s\n', ME.message);
    end

    setenv('ROS_DOMAIN_ID', '20');
    setenv('ROS_LOCALHOST_ONLY', '0');
    setenv('ROS_AUTOMATIC_DISCOVERY_RANGE', 'SUBNET');
    setenv('RMW_IMPLEMENTATION', 'rmw_fastrtps_cpp');
    unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
    unsetenv('CYCLONEDDS_URI');

    try
        rmw = ros.internal.ros2.RMWEnvironment();
        rmw.RMWImplementation = 'rmw_fastrtps_cpp';
        rmw.saveRMWEnvironment();
    catch
    end

    ok = false;
    try
        n = ros2node('humble_test', 'RMWImplementation', 'rmw_fastrtps_cpp');
        pause(3);
        s = ros2subscriber(n, '/matlab_dds_test', 'std_msgs/String');
        m = receive(s, 15);
        if ~isempty(m)
            fprintf('[OK] Humble-aligned receive: %s\n', m.data);
            ok = true;
        end
    catch ME
        fprintf('[FAIL] %s\n', ME.message);
    end
end
