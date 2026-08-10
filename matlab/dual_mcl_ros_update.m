function dual_mcl_ros_update()
%DUAL_MCL_ROS_UPDATE  One MCL step from /odom + /scan (verify-style, for dual overlay).

    persistent ctx ros lastScanKey trailMap trailUe scanCount initDone

    tTotal = tic;

    if isempty(initDone)
        setup_rover_paths();
        if isempty(which('monteCarloLocalization'))
            error('dual_mcl_ros_update:NoMCL', ...
                'Navigation Toolbox monteCarloLocalization required.');
        end
        ctx = mcl_context_create();
        ros = simulink_dual_ros_init();
        lastScanKey = NaN;
        trailMap = zeros(0, 3);
        trailUe = zeros(0, 3);
        scanCount = 0;
        initDone = true;
        cal = mcl_lidar_cal('load');
        fprintf('[Dual MCL] map: %s\n', ctx.mapPath);
        fprintf('[Dual MCL] lidar cal: Reflect=%d  Flip=%.0f°\n', ...
            cal.mirror, rad2deg(cal.offset));
        fprintf('[Dual MCL] heading display: +180° on Unreal twin (VERIFY_HEADING_FLIP=0 to disable)\n');
    end

    t0 = tic;
    odom = ros_sub_latest(ros.odomSub);
    stage4_timing('record', 'overlay.ros_odom', toc(t0) * 1000);

    t0 = tic;
    scan = ros_sub_latest(ros.scanSub);
    stage4_timing('record', 'overlay.ros_scan', toc(t0) * 1000);

    mapPose = ctx.lastMclPose;
    fitScore = ctx.lastScanScore;
    if isnan(fitScore)
        fitScore = 0;
    end
    odomPose = [0, 0, 0];
    scanNew = false;

    if isempty(odom)
        stage4_timing('record', 'overlay.total', toc(tTotal) * 1000);
        return;
    end

    odomPose = odom_to_xyth(odom);

    if ~isempty(scan)
        try
            scanKey = double(scan.header.stamp.sec) + ...
                double(scan.header.stamp.nanosec) * 1e-9;
            if scanKey ~= lastScanKey
                lastScanKey = scanKey;
                scanNew = true;
                t0 = tic;
                lsRaw = scan_msg_to_lidarscan(scan);
                stage4_timing('record', 'overlay.scan_to_ls', toc(t0) * 1000);
                t0 = tic;
                [mapPose, fitScore, ctx] = mcl_track_step(ctx, lsRaw, odomPose);
                stage4_timing('record', 'overlay.mcl_track', toc(t0) * 1000);
            elseif ctx.mclReady
                t0 = tic;
                mapPose = mcl_predict_pose(ctx, odomPose, ctx.mclState.lastPose);
                fitScore = ctx.lastScanScore;
                if isnan(fitScore)
                    fitScore = 0;
                end
                stage4_timing('record', 'overlay.mcl_predict', toc(t0) * 1000);
            end
        catch ME
            fprintf('[Dual MCL] scan error: %s\n', ME.message);
        end
    elseif ctx.mclReady
        t0 = tic;
        mapPose = mcl_predict_pose(ctx, odomPose, ctx.mclState.lastPose);
        stage4_timing('record', 'overlay.mcl_predict', toc(t0) * 1000);
    end

    valid = ctx.mclReady && fitScore >= 0.25;

    if scanNew && ctx.mclReady
        scanCount = scanCount + 1;
        if all(isfinite(mapPose))
            trailMap(end + 1, :) = mapPose; %#ok<AGROW>
            if size(trailMap, 1) > 600
                trailMap = trailMap(end - 599:end, :);
            end
            if ~isempty(ctx.align)
                ue = map_pose_to_unreal_ros(mapPose(1), mapPose(2), mapPose(3), ctx.align);
                trailUe(end + 1, :) = [ue.x, ue.y, ue.yaw]; %#ok<AGROW>
                if size(trailUe, 1) > 600
                    trailUe = trailUe(end - 599:end, :);
                end
            end
        end
    end

    liveTrail = struct('trailMap', trailMap, 'trailUe', trailUe, 'scanCount', scanCount);
    t0 = tic;
    mcl_dual_shared_publish(ctx, mapPose, fitScore, odomPose, scanNew, valid, liveTrail);
    stage4_timing('record', 'overlay.publish', toc(t0) * 1000);

    simulink_stage4_debug('mcl', struct( ...
        'odom', odomPose, 'map', mapPose, 'hasLock', ctx.mclReady, ...
        'scanNew', scanNew, 'fit', fitScore, 'valid_out', valid));

    stage4_timing('record', 'overlay.total', toc(tTotal) * 1000);
end
