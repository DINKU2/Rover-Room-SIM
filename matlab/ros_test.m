function ok = ros_test(timeoutSec)
%ROS_TEST  Verify native Humble DDS (R2024b): /odom, /scan, /cmd_vel.

    if nargin < 1, timeoutSec = 20; end

    fprintf('\n=== ROS connection test (native Humble DDS) ===\n');
    fprintf('MATLAB %s\n\n', version('-release'));

    try
        ctx = ros_connect('ros_test');
    catch ME
        fprintf('[FAIL] ros_connect: %s\n', ME.message);
        ok = false;
        return;
    end

    ok = true;

    fprintf('\n/odom (timeout %ds)...\n', timeoutSec);
    odom = ros_receive(ctx, 'odom', timeoutSec);
    if isempty(odom)
        fprintf('[FAIL] no /odom\n');
        ok = false;
    else
        p = odom.pose.pose.position;
        fprintf('[OK] x=%.3f  y=%.3f\n', p.x, p.y);
    end

    fprintf('\n/scan (timeout %ds)...\n', timeoutSec);
    scan = ros_receive(ctx, 'scan', timeoutSec);
    if isempty(scan)
        fprintf('[WARN] no /scan (lidar may be disabled in firmware)\n');
    else
        r = scan.ranges(isfinite(scan.ranges));
        fprintf('[OK] %d ranges  min=%.2f  max=%.2f m\n', numel(scan.ranges), min(r), max(r));
    end

    fprintf('\n/cmd_vel publish...\n');
    try
        ros_cmd_vel(ctx, 0, 0);
        fprintf('[OK] sent stop command\n');
    catch ME
        fprintf('[FAIL] %s\n', ME.message);
        ok = false;
    end

    if ok
        fprintf('\n[PASS] Native ROS 2 connected.\n');
        fprintf('  odom = ros_receive(ctx, ''odom'', 10);\n');
        fprintf('  ros_cmd_vel(ctx, 0.2, 0);\n');
    end
    fprintf('\n');
end
