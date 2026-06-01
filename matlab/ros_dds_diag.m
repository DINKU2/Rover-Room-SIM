function ok = ros_dds_diag()
%ROS_DDS_DIAG  Test whether MATLAB receives any ROS 2 data (uses /rosout).

    addpath(fileparts(mfilename('fullpath')));
    setup_ros_dds();
    fprintf('Testing /rosout receive (8s)...\n');
    ok = false;
    try
        n = ros2node('dds_diag');
        pause(2);
        s = ros2subscriber(n, '/rosout', 'rcl_interfaces/Log');
        m = receive(s, 8);
        if isempty(m)
            fprintf('[FAIL] empty /rosout\n');
        else
            fprintf('[OK] /rosout received (level=%d)\n', m.level);
            ok = true;
        end
    catch ME
        fprintf('[FAIL] %s\n', ME.message);
    end
end
