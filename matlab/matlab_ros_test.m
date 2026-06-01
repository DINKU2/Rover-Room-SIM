function ok = matlab_ros_test(timeoutSec)
%MATLAB_ROS_TEST  Preflight — ROS Toolbox first, bridge noted on failure.
%
%   ok = matlab_ros_test()       % same as ros_test()
%   ok = matlab_ros_test(30)

    if nargin < 1, timeoutSec = 15; end
    ok = ros_test(timeoutSec);
end
