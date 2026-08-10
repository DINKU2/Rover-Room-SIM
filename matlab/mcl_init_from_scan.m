function ctx = mcl_init_from_scan(ctx, lsRaw, odomPose)
%MCL_INIT_FROM_SCAN  Global scan match + MCL filter init on saved map.

    if nargin < 3
        odomPose = [];
    end

    cal = mcl_lidar_cal('load');
    ctx.lidarAngleOffset = cal.offset;
    ctx.lidarMirror = cal.mirror;
    ctx.lastLsRaw = lsRaw;
    ls = verify_lidarscan_prepare(lsRaw, ctx);

    guess = mcl_guess_pose_from_scan(ctx.mapData.map, ls, ctx.align, ctx.mapData, odomPose);
    if guess.score < 0.40
        [guess2, off2] = mcl_guess_best_offset( ...
            ctx.mapData.map, lsRaw, ctx.align, ctx.mapData, odomPose);
        if guess2.score > guess.score
            guess = guess2;
            ctx.lidarAngleOffset = off2;
            mcl_save_lidar_offset(off2, ctx.lidarMirror);
            ls = verify_lidarscan_prepare(lsRaw, ctx);
        end
    end

    if guess.useGlobal
        [ctx.mcl, ~, ~] = setup_mcl_localizer(ctx.mapPath, 'GlobalLocalization', true);
        fprintf('[mcl] Scan match weak (%.0f%%) — global localization ON\n', 100 * guess.score);
    else
        [ctx.mcl, ~, ~] = setup_mcl_localizer(ctx.mapPath, 'InitialPose', guess.pose);
        fprintf(['[mcl] Scan-matched start: score=%.0f%%  MAP x=%.2f y=%.2f yaw=%.1f°\n'], ...
            100 * guess.score, guess.pose(1), guess.pose(2), rad2deg(guess.pose(3)));
    end

    ctx.mclLockCfg = struct( ...
        'SensorModel', ctx.mcl.SensorModel, ...
        'MotionModel', ctx.mcl.MotionModel, ...
        'ParticleLimits', ctx.mcl.ParticleLimits, ...
        'UpdateThresholds', ctx.mcl.UpdateThresholds);
    ctx.mclState = mcl_default_state();
    ctx.mclReady = true;
    ctx.lastScanScore = guess.score;
    ctx.lastMclPose = guess.pose;
    ctx.lowFitSnapCount = 0;
    ctx.lastGlobalRelocT = [];
    if ~isempty(odomPose) && all(isfinite(odomPose(1:3)))
        ctx.odomAnchor = struct('map', guess.pose, 'odom', odomPose);
    else
        ctx.odomAnchor = [];
    end
end
