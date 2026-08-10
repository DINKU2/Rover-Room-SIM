function ctx = mcl_sync_pose(ctx, mapPose, odomPose, fitScore)
%MCL_SYNC_POSE  Tie MAP pose to current /odom for dead-reckoning between scans.

    if nargin >= 4 && isfinite(fitScore) && fitScore < 0.35
        return;
    end
    mapPose = mapPose(:)';
    odomPose = odomPose(:)';
    if numel(mapPose) >= 3 && numel(odomPose) >= 3 && ...
            all(isfinite(mapPose(1:3))) && all(isfinite(odomPose(1:3)))
        ctx.odomAnchor = struct('map', mapPose, 'odom', odomPose);
    end
    if isfield(ctx, 'manualPose')
        ctx.manualPose = [];
    end
end
