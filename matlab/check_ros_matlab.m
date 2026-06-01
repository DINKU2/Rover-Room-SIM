function ok = check_ros_matlab()
%CHECK_ROS_MATLAB  Quick check: pyenv, RMW, ros_test (for after Python recreate).

    fprintf('=== pyenv ===\n');
    try
        disp(pyenv);
    catch ME
        fprintf('pyenv: %s\n', ME.message);
    end

    fprintf('\n=== RMW ===\n');
    try
        rmw = ros.internal.ros2.RMWEnvironment();
        fprintf('RMW: %s\n', rmw.RMWImplementation);
    catch ME
        fprintf('RMW: %s\n', ME.message);
    end

    fprintf('\n=== ros_test ===\n');
    ok = ros_test(25);
end
