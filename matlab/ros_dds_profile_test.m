function ros_dds_profile_test()
%ROS_DDS_PROFILE_TEST  Try DDS env profiles; shell must publish /matlab_dds_test.

    addpath(fileparts(mfilename('fullpath')));
    profiles = {'fastdds_xml', 'no_xml_subnet', 'no_xml_localhost', 'localhost_only'};
    for i = 1:numel(profiles)
        p = profiles{i};
        fprintf('\n=== Profile: %s ===\n', p);
        applyProfile(p);
        try
            n = ros2node("diag_" + string(p));
            pause(2);
            s = ros2subscriber(n, '/matlab_dds_test', 'std_msgs/String');
            m = receive(s, 8);
            if ~isempty(m)
                fprintf('[OK] %s data=%s\n', p, m.data);
            else
                fprintf('[FAIL] %s empty\n', p);
            end
            clear n s
        catch ME
            fprintf('[FAIL] %s — %s\n', p, ME.message);
        end
    end
end

function applyProfile(name)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    setenv('ROS_DOMAIN_ID', '20');
    setenv('ROS_DISCOVERY_SERVER', '');
    setenv('ROS_SUPER_CLIENT', '0');
    setenv('RMW_IMPLEMENTATION', '');
    setenv('CYCLONEDDS_URI', '');

    switch name
        case 'fastdds_xml'
            setup_ros_dds();
        case 'no_xml_subnet'
            unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
            setenv('ROS_AUTOMATIC_DISCOVERY_RANGE', 'SUBNET');
            setenv('ROS_LOCALHOST_ONLY', '0');
        case 'no_xml_localhost'
            unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
            setenv('ROS_AUTOMATIC_DISCOVERY_RANGE', 'LOCALHOST');
            setenv('ROS_LOCALHOST_ONLY', '0');
        case 'localhost_only'
            unsetenv('FASTRTPS_DEFAULT_PROFILES_FILE');
            setenv('ROS_LOCALHOST_ONLY', '1');
            setenv('ROS_AUTOMATIC_DISCOVERY_RANGE', '');
    end
end
