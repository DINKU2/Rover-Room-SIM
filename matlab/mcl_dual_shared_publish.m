function mcl_dual_shared_publish(ctx, mapPose, fitScore, odomPose, scanNew, valid, liveTrail)
%MCL_DUAL_SHARED_PUBLISH  Push Simulink MCL state to verify overlay.

    if nargin < 7
        liveTrail = [];
    end

    payload = struct();
    payload.mapPose = mapPose;
    payload.odomPose = odomPose;
    payload.scanFitScore = fitScore;
    payload.mclReady = ctx.mclReady;
    payload.valid = valid;

    if ctx.mclReady && ~isempty(ctx.align) && all(isfinite(mapPose(1:3)))
        t0 = tic;
        ue = map_pose_to_unreal_ros(mapPose(1), mapPose(2), mapPose(3), ctx.align);
        payload.uePose = ue;
        payload.ueSim = map_pose_to_unreal_sim3d(mapPose(1), mapPose(2), mapPose(3), ctx.align);
        stage4_timing('record', 'overlay.pose_to_ue', toc(t0) * 1000);
    end

    if ~isempty(liveTrail)
        payload.trailMap = liveTrail.trailMap;
        payload.trailUe = liveTrail.trailUe;
        payload.scanCount = liveTrail.scanCount;
    end

    if scanNew && ctx.mclReady
        t0 = tic;
        ls = verify_lidarscan_prepare(ctx.lastLsRaw, ctx);
        match = mcl_scan_map_match(ctx.mapData.map, ls, mapPose);
        payload.scanPtsMap = [match.wx(:), match.wy(:)];
        payload.scanOnWall = match.onWall(:);
        if ~isempty(ctx.align)
            payload.scanPtsUe = apply_slam_map_to_unreal(payload.scanPtsMap, ctx.align);
        else
            payload.scanPtsUe = zeros(0, 2);
        end
        stage4_timing('record', 'overlay.scan_match', toc(t0) * 1000);
    end

    mcl_dual_shared('publish', payload);
end
