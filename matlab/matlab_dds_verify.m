function ok = matlab_dds_verify(timeoutSec)
%MATLAB_DDS_VERIFY  Step-by-step DDS receive test (dummy or real robot).
%
%   Shell first:
%     ./scripts/start_agent.sh
%     ./scripts/verify_topic_data.sh        % must pass with robot running
%
%   MATLAB:
%     setup_ros_dds
%     matlab_dds_verify
%
%   ok = matlab_dds_verify(15)

    if nargin < 1, timeoutSec = 15; end

    fprintf('\n=== MATLAB DDS verify (domain 20) ===\n\n');

    setup_ros_dds();
    pause(2);

    fprintf('Step 1 — topic names (discovery only, NOT proof of data)\n');
    topics = list_ros2_topics();
    if isempty(topics)
        fprintf('  [FAIL] No topics visible\n');
        ok = false;
        printNextSteps();
        return;
    end
    fprintf('  Topics: %s\n', strjoin(topics, ', '));
    hasOdom = any(strcmp(topics, '/odom'));
    hasScan = any(strcmp(topics, '/scan'));
    if hasOdom, fprintf('  [OK] /odom name visible\n'); else, fprintf('  [!!] /odom not in list\n'); end
    if hasScan, fprintf('  [OK] /scan name visible\n'); else, fprintf('  [!!] /scan not in list\n'); end

    fprintf('\nStep 2 — live /odom sample (RELIABLE)\n');
    node = ros2node('matlab_dds_verify');
    odomOk = false;
    scanOk = false;
    try
        odomSub = robot_ros_subscriber(node, '/odom', 'nav_msgs/Odometry');
        msg = receive(odomSub, timeoutSec);
        if ~isempty(msg)
            px = msg.pose.pose.position.x;
            py = msg.pose.pose.position.y;
            fprintf('  [OK] /odom  x=%.3f  y=%.3f\n', px, py);
            odomOk = true;
        end
    catch ME
        fprintf('  [FAIL] /odom — %s\n', ME.message);
    end

    fprintf('\nStep 3 — live /scan sample (BEST_EFFORT, 90 pts)\n');
    try
        scanSub = robot_ros_subscriber(node, '/scan', 'sensor_msgs/LaserScan');
        msg = receive(scanSub, timeoutSec);
        if ~isempty(msg)
            n = numel(msg.ranges);
            rmin = min(msg.ranges(isfinite(msg.ranges)));
            rmax = max(msg.ranges(isfinite(msg.ranges)));
            fprintf('  [OK] /scan  %d ranges  min=%.2f  max=%.2f m\n', n, rmin, rmax);
            scanOk = true;
        end
    catch ME
        fprintf('  [FAIL] /scan — %s\n', ME.message);
    end

    fprintf('\n=== Summary ===\n');
    ok = odomOk && scanOk;
    if odomOk && scanOk
        fprintf('[PASS] MATLAB receives live odom + scan.\n');
        fprintf('Next: matlab_connect\n');
    elseif odomOk
        fprintf('[PARTIAL] Odom OK, scan failed — check best-effort QoS.\n');
    else
        fprintf('[FAIL] MATLAB cannot receive data (shell check may still pass).\n');
        printNextSteps();
    end
    fprintf('\n');
end

function printNextSteps()
    fprintf('\nNext steps (native Linux):\n');
    fprintf('  1. source ./setup.bash && ./scripts/start_agent.sh\n');
    fprintf('  2. ./scripts/check_robot.sh\n');
    fprintf('  3. Restart MATLAB, run setup_ros_dds, then matlab_ros_test\n');
    fprintf('  4. Read docs/NATIVE_LINUX_SETUP.md\n');
end
