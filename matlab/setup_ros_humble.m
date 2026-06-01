function cfg = setup_ros_humble(useDiscoveryServer)
%SETUP_ROS_HUMBLE  R2024b-native ROS 2 Humble environment (domain 20).
%
%   Call once per session before ros2node. Aligns with /opt/ros/humble on
%   Ubuntu 22.04. Requires MATLAB R2024b (bundled Humble).

    if nargin < 1, useDiscoveryServer = false; end

    v = version('-release');
    year = str2double(v(1:4));
    if year >= 2025
        warning('setup_ros_humble:Release', ...
            ['MATLAB %s ships Jazzy, not Humble. Use scripts/matlab_r2024b.sh ' ...
             'or R2024b for native Humble DDS.'], v);
    end

    humble = '/opt/ros/humble';
    if isfolder(humble)
        try
            ros.codertarget.internal.DeviceParameters.setROS2InstallFolder(humble);
        catch
        end
    end

    cfg = setup_ros_dds(useDiscoveryServer);
    setenv('RMW_IMPLEMENTATION', 'rmw_fastrtps_cpp');

    try
        rmw = ros.internal.ros2.RMWEnvironment();
        rmw.RMWImplementation = 'rmw_fastrtps_cpp';
        rmw.saveRMWEnvironment();
    catch
    end

    fprintf('ROS 2 Humble aligned (MATLAB %s, domain %s)\n', v, cfg.domainId);
end
