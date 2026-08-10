function report = run_stage4_timing_profile(mode, durationSec)
%RUN_STAGE4_TIMING_PROFILE  Measure Stage-4 hot paths with real ROS data.
%
%   run_stage4_timing_profile()              % overlay loop, 30 s
%   run_stage4_timing_profile('overlay', 30)
%   run_stage4_timing_profile('slx_blocks', 10)  % simulink fcn calls @50 Hz
%   run_stage4_timing_profile('both', 30)

    if nargin < 1 || isempty(mode)
        mode = 'overlay';
    end
    if nargin < 2 || isempty(durationSec)
        durationSec = 30;
    end

    setup_rover_paths();
    setup_ros_humble();
    stage4_timing('reset');

    mode = lower(mode);
    switch mode
        case 'overlay'
            profile_overlay_loop(durationSec);
        case 'slx_blocks'
            profile_slx_blocks(durationSec);
        case 'both'
            profile_overlay_loop(durationSec);
            profile_slx_blocks(min(10, durationSec));
        otherwise
            error('run_stage4_timing_profile:BadMode', ...
                'mode must be overlay, slx_blocks, or both');
    end

    report = stage4_timing('report');
    fprintf('\n=== Final timing report (%s, %.0f s) ===\n', mode, durationSec);
    disp(report);

    if height(report) > 0
        top = report.tag{1};
        fprintf('Top consumer: %s  (%.1f ms total, %.2f ms avg)\n', ...
            top, report.sum_ms(1), report.avg_ms(1));
    end
end

function profile_overlay_loop(durationSec)
    dual_mcl_ros_reset();
    fprintf('[timing] overlay loop %.0f s @ 0.08 s period (dual_mcl_ros_update)...\n', durationSec);
    t0 = tic;
    n = 0;
    while toc(t0) < durationSec
        tt = tic;
        dual_mcl_ros_update();
        stage4_timing('record', 'profile.overlay_tick', toc(tt) * 1000);
        pause(0.08);
        n = n + 1;
    end
    fprintf('[timing] overlay iterations: %d\n', n);
end

function profile_slx_blocks(durationSec)
    fprintf('[timing] simulink blocks %.0f s @ 50 Hz (no Unreal cosim)...\n', durationSec);
    mcl_dual_shared('init');
    ud = mcl_dual_shared('get');
    if isempty(ud)
        mcl_dual_shared('init');
    end

    t0 = tic;
    n = 0;
    dt = 0.02;
    uPose = [6.6; -0.18; 0.31; 1];
    uSim = [2.97; 1.56; 0; -3.05; 1];

    while toc(t0) < durationSec
        tt = tic;
        simulink_mcl_map_pose(0);
        stage4_timing('record', 'profile.slx_mcl', toc(tt) * 1000);

        tt = tic;
        simulink_map_pose_to_unreal(uPose);
        stage4_timing('record', 'profile.slx_map2ue', toc(tt) * 1000);

        tt = tic;
        simulink_unreal_pose_gate(uSim);
        stage4_timing('record', 'profile.slx_gate', toc(tt) * 1000);

        tt = tic;
        simulink_teleop_lin(0);
        simulink_teleop_ang(0);
        stage4_timing('record', 'profile.slx_teleop', toc(tt) * 1000);

        n = n + 1;
        pause(dt);
    end
    fprintf('[timing] slx block iterations: %d\n', n);
end
