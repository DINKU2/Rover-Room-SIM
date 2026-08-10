function [mapPose, fitScore, ctx] = mcl_track_step(ctx, lsRaw, odomPose)
%MCL_TRACK_STEP  One MCL + scan-snap update on the saved Stage-2 map.
%
%   Uses maps/mcl_lidar_offset.mat (Reflect + Flip 180) automatically.

    if nargin < 3
        odomPose = [];
    end

    mapPose = ctx.lastMclPose;
    fitScore = ctx.lastScanScore;
    if isnan(fitScore)
        fitScore = 0;
    end

    if isempty(lsRaw)
        if ctx.mclReady
            mapPose = mcl_predict_pose(ctx, odomPose, ctx.mclState.lastPose);
        end
        return;
    end

    ctx.lastLsRaw = lsRaw;

    if ~ctx.mclReady
        ctx = mcl_init_from_scan(ctx, lsRaw, odomPose);
        mapPose = ctx.lastMclPose;
        fitScore = ctx.lastScanScore;
        return;
    end

    ls = verify_lidarscan_prepare(lsRaw, ctx);
    [mclUpdated, mclPose, ~] = ctx.mcl(odomPose, ls);

    odomSeed = mcl_predict_pose(ctx, odomPose, ctx.mclState.lastPose);
    [snapPose, snapScore] = mcl_snap_pose_to_map( ...
        ctx.mapData.map, ls, odomSeed, 'Mode', 'local');
    seedScore = mcl_scan_map_score(ctx.mapData.map, ls, odomSeed);
    if snapScore >= seedScore
        mapPose = snapPose;
    else
        mapPose = odomSeed;
    end
    fitScore = max(snapScore, seedScore);

    if fitScore >= 0.32
        ctx = mcl_sync_pose(ctx, mapPose, odomPose, fitScore);
    elseif mclUpdated
        mclFit = mcl_scan_map_score(ctx.mapData.map, ls, mclPose);
        if mclFit >= 0.38
            ctx = mcl_sync_pose(ctx, mclPose, odomPose, mclFit);
            mapPose = mclPose;
            fitScore = mclFit;
        end
    end

    globalThresh = mcl_global_reloc_threshold();
    if fitScore < globalThresh
        ctx.lowFitSnapCount = ctx.lowFitSnapCount + 1;
        minGlobalSec = 0.8;
        if ~isfield(ctx, 'lastGlobalRelocT') || isempty(ctx.lastGlobalRelocT)
            ctx.lastGlobalRelocT = tic - minGlobalSec;
        end
        if toc(ctx.lastGlobalRelocT) >= minGlobalSec
            ctx.lastGlobalRelocT = tic;
            prevScore = fitScore;
            [gPose, gScore] = mcl_snap_pose_to_map( ...
                ctx.mapData.map, ls, mapPose, 'Mode', 'global');
            if gScore > fitScore
                mapPose = gPose;
                fitScore = gScore;
                if fitScore >= 0.32
                    ctx = mcl_sync_pose(ctx, mapPose, odomPose, fitScore);
                end
                fprintf(['[mcl] Phase-1 global reloc (fit was %.0f%%, thresh %.0f%%) ' ...
                    '→ %.0f%%  MAP x=%.2f y=%.2f yaw=%.1f°\n'], ...
                    100 * prevScore, 100 * globalThresh, 100 * gScore, ...
                    mapPose(1), mapPose(2), rad2deg(mapPose(3)));
            else
                fprintf('[mcl] Phase-1 global search (fit %.0f%% < %.0f%%) — no better match (%.0f%%)\n', ...
                    100 * prevScore, 100 * globalThresh, 100 * gScore);
            end
        end
    else
        ctx.lowFitSnapCount = 0;
    end

    if ~isfield(ctx, 'mclState') || isempty(ctx.mclState)
        ctx.mclState = mcl_default_state();
    end
    ctx.mclState.hasPose = true;
    ctx.mclState.lastPose = mapPose;
    ctx.lastMclPose = mapPose;
    ctx.lastScanScore = fitScore;
end
