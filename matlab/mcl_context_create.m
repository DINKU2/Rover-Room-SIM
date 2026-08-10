function ctx = mcl_context_create()
%MCL_CONTEXT_CREATE  Fresh MCL-on-saved-map context (verify + Stage 4).

    setup_rover_paths();

    cal = mcl_lidar_cal('load');
    mapData = load_slam_map('');
    align = [];
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    alignPath = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    if isfile(alignPath)
        align = load(alignPath);
    end

    ctx = struct();
    ctx.mclReady = false;
    ctx.mapData = mapData;
    ctx.mapPath = mapData.path;
    ctx.align = align;
    ctx.lidarAngleOffset = cal.offset;
    ctx.lidarMirror = cal.mirror;
    ctx.mcl = [];
    ctx.mclLockCfg = [];
    ctx.mclState = mcl_default_state();
    ctx.odomAnchor = [];
    ctx.lastLsRaw = [];
    ctx.lowFitSnapCount = 0;
    ctx.lastGlobalRelocT = [];
    ctx.lastScanScore = NaN;
    ctx.lastMclPose = [0, 0, 0];
    ctx.manualPose = [];
    ctx.lowScoreCount = 0;
end
