function run_stage4_pose_debug(durationSec)
%RUN_STAGE4_POSE_DEBUG  Watch /odom+/scan outside Simulink (sanity check).
%
%   run_stage4_pose_debug()       % 30 s
%   run_stage4_pose_debug(60)

    if nargin < 1 || isempty(durationSec)
        durationSec = 30;
    end

    setup_rover_paths();
    setup_ros_humble();
    ctx = simulink_dual_ros_init();

    fprintf('Stage 4 ROS debug for %.0f s — drive the robot now.\n', durationSec);
    fprintf('Log: maps/stage4_pose_debug.log\n\n');

    t0 = tic;
    lastOdom = [];
    while toc(t0) < durationSec
        odom = ros_sub_latest(ctx.odomSub);
        scan = ros_sub_latest(ctx.scanSub);
        if ~isempty(odom)
            p = odom_to_xyth(odom);
            if isempty(lastOdom) || any(abs(p - lastOdom) > 1e-4)
                simulink_stage4_debug('watch', struct( ...
                    'odom', p, 'scan', ~isempty(scan)));
                lastOdom = p;
            end
        else
            simulink_stage4_debug('watch', struct('odom', 'empty', 'scan', ~isempty(scan)));
        end
        pause(0.2);
    end

    fprintf('\nDone. If odom stayed empty here, Simulink cannot move the twin.\n');
end
