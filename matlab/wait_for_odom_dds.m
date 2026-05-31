function ok = wait_for_odom_dds(node, timeoutSec)
%WAIT_FOR_ODOM_DDS  Block until MATLAB receives /odom (same path as matlab_ros_test).

    if nargin < 2, timeoutSec = 45; end
    t0 = tic;
    while toc(t0) < timeoutSec
        msg = receive_odom(node, 2);
        if ~isempty(msg)
            p = msg.pose.pose.position;
            fprintf('[OK] MATLAB /odom live (x=%.2f y=%.2f)\n', p.x, p.y);
            ok = true;
            return;
        end
        pause(0.2);
    end
    ok = false;
    error('matlab_connect:Timeout', ...
        'No live /odom in MATLAB within %d s.', timeoutSec);
end
