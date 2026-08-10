function verify_map_pose(varargin)
%VERIFY_MAP_POSE  Live SLAM map registered to saved map + Unreal overlay.
%
%   verify_map_pose()
%   verify_map_pose('MapPath', 'maps/rover_room_....mat')
%   verify_map_pose('Localization', 'mcl')   % scan-only particle filter (legacy)
%
%   Default Localization='slam':
%     - Runs real-time lidarSLAM while you drive (builds its own map)
%     - Periodically registers the LIVE map walls to your SAVED Stage-2 map
%     - Transforms pose through saved map -> unreal_alignment.mat -> Unreal
%
%   LEFT  (saved MAP frame):
%       gray  = saved Stage-2 map (reference)
%       blue  = live SLAM map registered onto gray (should overlap as you drive)
%       yellow = robot pose on saved map (after live->saved registration)
%   RIGHT (Unreal / manual-align frame):
%       red   = Unreal room reference
%       green = saved map after manual align
%       blue  = live map in Unreal frame
%       cyan  = robot in Unreal
%
%   Prereqs: ./scripts/start_agent.sh, saved rover_room_*.mat, unreal_alignment.mat
%   Drive:  source ./setup.bash && ./scripts/run_teleop.sh
%   MCL mode keys (click figure first):  W/A/S/D  Q/E  R  F  X

    opts = parse_verify_opts(varargin);
    setup_rover_paths();
    useMcl = strcmpi(opts.Localization, 'mcl');
    useSlam = ~useMcl;
    if useMcl
        check_verify_mcl();
    else
        check_verify_lidar_slam();
    end

    [unrealPts, refMeta] = unreal_room_wall_points('Source', opts.RefSource);
    align = load_align_optional();

    mapDataSaved = load_slam_map(opts.MapPath);
    bgSlamPts = slam_map_wall_points(mapDataSaved.map);
    bgMapPath = mapDataSaved.path;
    if useMcl
        mcl_get_map_cache(mapDataSaved.map);
    end

    locLabel = ternary(useMcl, 'MCL on saved map', 'live SLAM map-to-map');
    fprintf('\n=== Verify MAP pose (live) — %s ===\n', locLabel);
    fprintf('Unreal ref: %s (%d pts)\n', refMeta.source, size(unrealPts, 1));
    if isempty(align)
        fprintf('[WARN] maps/unreal_alignment.mat missing — run run_manual_align_slam first.\n');
    else
        mirrorY = isfield(align, 'slam_flip_y') && align.slam_flip_y;
        fprintf('Alignment loaded (yaw offset %.1f deg, mirrorY=%d)\n', ...
            rad2deg(align.yaw_offset), mirrorY);
    end
    if ~isempty(bgMapPath)
        fprintf('Saved map: %s\n', bgMapPath);
    end
    if useSlam
        fprintf(['Live SLAM: builds a new map as you drive, registers it to the saved map.\n' ...
            '  LEFT:  gray=saved map  blue=live SLAM map aligned onto gray  yellow=pose\n' ...
            '  RIGHT: red=Unreal  green=manual align  blue=live map  cyan=robot\n' ...
            '  Drive around — alignment improves after ~%d scans.\n'], opts.MinScansForAlign);
    elseif useMcl
        cal = mcl_lidar_cal('load');
        fprintf(['MCL mode (legacy): matches individual scans to saved map.\n' ...
            '  Lidar cal: Reflect=%d  Flip=%.0f°  (maps/mcl_lidar_offset.mat)\n' ...
            '  Heading display: +180° on triangle (set VERIFY_HEADING_FLIP=0 to disable)\n' ...
            '  Use Localization=''slam'' (default) for live map-to-map alignment.\n' ...
            '  Keys: Reflect lidar X | Flip 180 F | Re-match R | nudge WASD/QE\n'], ...
            cal.mirror, rad2deg(cal.offset));
    end
    fprintf('Drive the robot. Close figure or Ctrl+C to stop.\n\n');

    ctx = ros_connect('verify_map_pose');
    slam = [];
    mcl = [];
    mclState = [];
    mclLockCfg = [];
    if useSlam
        slam = lidarSLAM(20, 8);
    end

    fig = figure('Name', 'Verify MAP pose — live', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [60 60 1100 620], 'Color', [0.96 0.96 0.96]);

    axMap = subplot(1, 2, 1);
    axUe = subplot(1, 2, 2);
    set(axMap, 'Position', [0.06 0.24 0.42 0.70]);
    set(axUe, 'Position', [0.54 0.24 0.42 0.70]);
    hold(axMap, 'on'); grid(axMap, 'on'); axis(axMap, 'equal');
    hold(axUe, 'on'); grid(axUe, 'on'); axis(axUe, 'equal');
    xlabel(axMap, 'x [m]'); ylabel(axMap, 'y [m]');
    xlabel(axUe, 'x [m]'); ylabel(axUe, 'y [m]');
    title(axMap, sprintf('MAP frame (raw SLAM) — %s', locLabel));
    title(axUe, 'Calibrated frame — red=Unreal  green=your manual align');

    status = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.01 0.96 0.08], 'HorizontalAlignment', 'left', ...
        'Enable', 'inactive', 'BackgroundColor', get(fig, 'Color'), ...
        'FontSize', 10, 'String', 'Waiting for scans...');

    ud = struct();
    ud.axMap = axMap;
    ud.axUe = axUe;
    ud.status = status;
    ud.unrealPts = unrealPts;
    ud.bgSlamPts = bgSlamPts;
    ud.align = align;
    ud.refSource = refMeta.source;
    ud.mapPose = [0, 0, 0];
    ud.liveMapPose = [0, 0, 0];
    ud.savedMapPose = [0, 0, 0];
    ud.odomPose = [0, 0, 0];
    ud.uePose = struct('x', NaN, 'y', NaN, 'yaw', NaN);
    ud.ueSim = struct('x', NaN, 'y', NaN, 'z', NaN, 'yaw', NaN);
    ud.liveSlamPts = zeros(0, 2);
    ud.liveSlamAlignedPts = zeros(0, 2);
    ud.liveSlamUePts = zeros(0, 2);
    ud.liveReg = struct('ready', false, 'R2d', eye(2), 't2d', [0; 0], ...
        'yaw_offset', 0, 'rmse_m', inf);
    ud.useSlam = useSlam;
    ud.mapAlignEvery = opts.MapAlignEvery;
    ud.minScansForAlign = opts.MinScansForAlign;
    ud.slamObj = slam;
    ud.trailMap = zeros(0, 3);
    ud.trailUe = zeros(0, 3);
    ud.scanCount = 0;
    ud.autoAxisMap = true;
    ud.autoAxisUe = true;
    ud.plotWallEvery = opts.PlotWallEvery;
    ud.useMcl = useMcl;
    ud.locLabel = locLabel;
    ud.scanPtsMap = zeros(0, 2);
    ud.scanPtsUe = zeros(0, 2);
    ud.scanOnWall = [];
    ud.mclReady = false;
    if ~isempty(align) && ~isempty(bgSlamPts) && isfield(align, 'R2d')
        ud.alignedSlamPts = apply_slam_map_to_unreal(bgSlamPts, align);
    else
        ud.alignedSlamPts = zeros(0, 2);
    end
    fig.UserData = ud;

    if useMcl
        btnY = 0.11;
        btnH = 0.07;
        gap = 0.012;
        x0 = 0.06;
        bw = 0.14;
        verify_add_btn(fig, [x0, btnY, bw, btnH], 'Reflect lidar', ...
            @(~, ~) verify_mcl_action(fig, 'mirror'));
        verify_add_btn(fig, [x0 + bw + gap, btnY, 0.11, btnH], 'Flip 180°', ...
            @(~, ~) verify_mcl_action(fig, 'flip'));
        verify_add_btn(fig, [x0 + bw + gap + 0.11 + gap, btnY, 0.11, btnH], 'Re-match', ...
            @(~, ~) verify_mcl_action(fig, 'rematch'));
        lidarCal = mcl_lidar_cal('load');
        fig.UserData.mclCtx = struct( ...
            'mcl', mcl, 'mclState', mclState, 'mclLockCfg', mclLockCfg, ...
            'useMcl', true, 'mclReady', false, 'mapData', mapDataSaved, ...
            'align', align, 'mapPath', opts.MapPath, 'manualPose', [], ...
            'lidarAngleOffset', lidarCal.offset, 'lidarMirror', lidarCal.mirror, ...
            'lastLsRaw', [], ...
            'lowScoreCount', 0, 'lowFitSnapCount', 0, 'lastScanScore', NaN, ...
            'odomAnchor', [], 'lastMclPose', []);
        fig.WindowKeyPressFcn = @verify_map_pose_key;
        fig.ButtonDownFcn = @(~,~) figure(fig);
    end

    set(ud.status, 'String', ternary(useSlam, ...
        'Building live SLAM map — drive around...', ...
        'Gray = saved map. Waiting for /scan from robot...'));
    verify_map_pose_redraw(fig);
    drawnow;

    prevOdomPose = [];
    lastScanKey = NaN;
    tStart = tic;

    try
        while isgraphics(fig) && toc(tStart) < opts.MaxDuration
            scan = ros_sub_read(ctx.scanSub, 0);
            if isempty(scan)
                pause(0.04);
                ud = fig.UserData;
                set(ud.status, 'String', 'Waiting for /scan from robot (is teleop/agent running?)...');
                drawnow limitrate;
                continue;
            end

            scanKey = verify_scan_stamp_key(scan);
            if scanKey == lastScanKey && fig.UserData.scanCount > 0
                pause(0.02);
                drawnow limitrate;
                continue;
            end
            lastScanKey = scanKey;

            odom = ros_sub_read(ctx.odomSub, 0);
            if isempty(odom)
                odom = ros_sub_read(ctx.odomSub, 0.15);
            end
            if isempty(odom)
                ud = fig.UserData;
                set(ud.status, 'String', 'Got /scan — waiting for /odom...');
                drawnow limitrate;
                continue;
            end

            try
                ls = scan_msg_to_lidarscan(scan);
            catch ME
                fprintf('[WARN] skip scan: %s\n', ME.message);
                continue;
            end

            odomPose = odom_to_xyth(odom);
            if useMcl
                mclCtx = fig.UserData.mclCtx;
                if isfield(mclCtx, 'resetOdom') && mclCtx.resetOdom
                    prevOdomPose = [];
                    mclCtx.resetOdom = false;
                    fig.UserData.mclCtx = mclCtx;
                end

                if ~mclCtx.mclReady
                    ud = fig.UserData;
                    set(ud.status, 'String', 'Matching scan to map (global search)...');
                    drawnow;
                end

                [mapPose, fitScore, mclCtx] = mcl_track_step(mclCtx, ls, odomPose);
                ls = verify_lidarscan_prepare(ls, mclCtx);

                isAccepted = isfield(mclCtx, 'odomAnchor') && ~isempty(mclCtx.odomAnchor);
                mclState = mclCtx.mclState;
                if ~isfield(mclState, 'hasPose') || isempty(mclState)
                    mclState = mcl_default_state();
                end

                match = mcl_scan_map_match(mclCtx.mapData.map, ls, mapPose);
                mclCtx.lastScanScore = fitScore;
                mclCtx.scanWx = match.wx;
                mclCtx.scanWy = match.wy;
                mclCtx.scanOnWall = match.onWall;
                if fitScore < 0.28
                    mclCtx.lowScoreCount = mclCtx.lowScoreCount + 1;
                else
                    mclCtx.lowScoreCount = 0;
                end
                if mclCtx.lowScoreCount >= 30
                    fprintf('[mcl] Lidar fit only %.0f%% — press R to re-match\n', 100 * fitScore);
                    mclCtx.lowScoreCount = 0;
                end
                fig.UserData.mclCtx = mclCtx;
            else
                if isempty(prevOdomPose)
                    isAccepted = addScan(slam, ls);
                else
                    relPose = odom_relative_xyth(prevOdomPose, odomPose);
                    isAccepted = addScan(slam, ls, relPose);
                end
                prevOdomPose = odomPose;
                if ~isAccepted
                    drawnow limitrate;
                    continue;
                end
                liveMapPose = verify_current_map_pose(slam);
                mapPose = liveMapPose;
            end

            if useMcl && ~mclState.hasPose && ~isAccepted
                drawnow limitrate;
                continue;
            end

            ud = fig.UserData;
            ud.scanCount = ud.scanCount + 1;
            ud.mapPose = mapPose;
            ud.odomPose = odomPose;

            if useSlam
                ud.liveMapPose = liveMapPose;
                ud.slamObj = slam;
                if mod(ud.scanCount, ud.mapAlignEvery) == 0 || ~ud.liveReg.ready
                    [liveWalls, nLiveScans] = verify_build_live_slam_walls(slam, ud.minScansForAlign);
                    ud.liveSlamPts = liveWalls;
                    if size(liveWalls, 1) >= 20
                        ud.liveReg = verify_register_point_maps(liveWalls, ud.bgSlamPts);
                        ud.liveSlamAlignedPts = apply_map_align2d(liveWalls, ...
                            ud.liveReg.R2d, ud.liveReg.t2d);
                        if ud.liveReg.ready
                            fprintf('[slam] Live map registered to saved map (RMSE %.2f m, %d scans)\n', ...
                                ud.liveReg.rmse_m, nLiveScans);
                        end
                    end
                end
                if ud.liveReg.ready
                    ud.savedMapPose = verify_apply_pose_reg(liveMapPose, ud.liveReg);
                    mapPose = ud.savedMapPose;
                    ud.mapPose = mapPose;
                else
                    ud.savedMapPose = liveMapPose;
                end
                if ~isempty(ud.align) && ud.liveReg.ready && ~isempty(ud.liveSlamAlignedPts)
                    ud.liveSlamUePts = apply_slam_map_to_unreal(ud.liveSlamAlignedPts, ud.align);
                else
                    ud.liveSlamUePts = zeros(0, 2);
                end
                ud.regFitPct = verify_reg_fit_pct(ud.liveReg);
            end

            if useMcl
                mclCtx = fig.UserData.mclCtx;
                if isfield(mclCtx, 'scanWx') && ~isempty(mclCtx.scanWx)
                    ud.scanPtsMap = [mclCtx.scanWx(:), mclCtx.scanWy(:)];
                    ud.scanOnWall = mclCtx.scanOnWall(:);
                    ud.scanPtsUe = verify_map_points_to_unreal(ud.scanPtsMap, ud.align);
                end
                ud.mclReady = true;
                ud.scanFitScore = mclCtx.lastScanScore;
            end

            if ~isempty(ud.align)
                poseForUe = ternary(useSlam && ud.liveReg.ready, ud.savedMapPose, ud.mapPose);
                ue = map_pose_to_unreal_ros(poseForUe(1), poseForUe(2), poseForUe(3), ud.align);
                ud.uePose = ue;
                sim = map_pose_to_unreal_sim3d(poseForUe(1), poseForUe(2), poseForUe(3), ud.align);
                ud.ueSim = sim;
            end

            ud.trailMap(end + 1, :) = mapPose; %#ok<AGROW>
            if ~isempty(ud.align) && isfinite(ud.uePose.x)
                ud.trailUe(end + 1, :) = [ud.uePose.x, ud.uePose.y, ud.uePose.yaw]; %#ok<AGROW>
            end
            if size(ud.trailMap, 1) > opts.TrailLength
                ud.trailMap = ud.trailMap(end - opts.TrailLength + 1:end, :);
            end
            if size(ud.trailUe, 1) > opts.TrailLength
                ud.trailUe = ud.trailUe(end - opts.TrailLength + 1:end, :);
            end

            mapTag = ternary(useMcl, 'MCL ', ternary(useSlam, 'SLAM ', 'MAP '));
            holdTag = '';
            if useMcl && ~isAccepted
                holdTag = ' (init)';
            elseif useMcl && isfield(ud, 'scanFitScore') && isfinite(ud.scanFitScore) && ud.scanFitScore < 0.35
                holdTag = ' (drift?)';
            end
            fitTag = '';
            if useMcl && isfield(ud, 'scanFitScore') && isfinite(ud.scanFitScore)
                fitTag = sprintf('  fit=%.0f%%', 100 * ud.scanFitScore);
            elseif useSlam && isfield(ud, 'regFitPct') && isfinite(ud.regFitPct)
                fitTag = sprintf('  map-reg=%.0f%%', ud.regFitPct);
            end
            if useSlam && ud.liveReg.ready
                poseLabel = 'SAVED';
                poseOut = ud.savedMapPose;
            else
                poseLabel = ternary(useSlam, 'LIVE', mapTag);
                poseOut = ternary(useSlam, ud.liveMapPose, ud.mapPose);
            end
            fprintf(['[%4d] %sx=%+.3f y=%+.3f yaw=%+.1f°%s%s  |  ' ...
                'ODOM x=%+.3f y=%+.3f yaw=%+.1f°'], ...
                ud.scanCount, poseLabel, ...
                poseOut(1), poseOut(2), rad2deg(mcl_heading_display_yaw(poseOut(3))), holdTag, fitTag, ...
                ud.odomPose(1), ud.odomPose(2), rad2deg(mcl_heading_display_yaw(ud.odomPose(3))));
            if ~isempty(ud.align) && isfinite(ud.uePose.x)
                fprintf(['  |  UE x=%+.3f y=%+.3f yaw=%+.1f°  Sim3D x=%+.3f y=%+.3f yaw=%+.1f°\n'], ...
                    ud.uePose.x, ud.uePose.y, rad2deg(mcl_heading_display_yaw(ud.uePose.yaw)), ...
                    ud.ueSim.x, ud.ueSim.y, rad2deg(mcl_heading_display_yaw(ud.ueSim.yaw)));
            else
                fprintf('  |  UE: (no alignment file)\n');
            end

            fig.UserData = ud;
            verify_map_pose_redraw(fig);
            drawnow limitrate;
        end
    catch ME
        if ~strcmp(ME.identifier, 'MATLAB:handle_break')
            rethrow(ME);
        end
    end

    if isgraphics(fig)
        ud = fig.UserData;
        fprintf('\nStopped after %d scans.\n', ud.scanCount);
        if ud.scanCount > 0
            fprintf('Final MAP:  x=%.3f y=%.3f yaw=%.1f deg\n', ...
                ud.mapPose(1), ud.mapPose(2), rad2deg(mcl_heading_display_yaw(ud.mapPose(3))));
            if ~isempty(ud.align) && isfinite(ud.uePose.x)
                fprintf('Final UE:   x=%.3f y=%.3f yaw=%.1f deg\n', ...
                    ud.uePose.x, ud.uePose.y, rad2deg(mcl_heading_display_yaw(ud.uePose.yaw)));
                fprintf('Final Sim3D: x=%.3f y=%.3f z=%.3f yaw=%.1f deg\n', ...
                    ud.ueSim.x, ud.ueSim.y, ud.ueSim.z, rad2deg(mcl_heading_display_yaw(ud.ueSim.yaw)));
            end
        end
    end
end

function verify_map_pose_redraw(fig)
    ud = fig.UserData;
    verify_plot_map_panel(ud);
    verify_plot_unreal_panel(ud);
    set(ud.status, 'String', verify_status_text(ud));
end

function verify_plot_map_panel(ud)
    ax = ud.axMap;
    delete(findobj(ax, 'Tag', 'verify_layer'));
    if ~isempty(ud.bgSlamPts)
        scatter(ax, ud.bgSlamPts(:, 1), ud.bgSlamPts(:, 2), 6, ...
            [0.75 0.75 0.75], 'filled', 'Tag', 'verify_layer', ...
            'MarkerFaceAlpha', 0.4, 'HitTest', 'off');
    end
    if isfield(ud, 'useSlam') && ud.useSlam
        if isfield(ud, 'liveSlamAlignedPts') && ~isempty(ud.liveSlamAlignedPts)
            scatter(ax, ud.liveSlamAlignedPts(:, 1), ud.liveSlamAlignedPts(:, 2), 10, ...
                [0.2 0.45 1.0], 'filled', 'Tag', 'verify_layer', ...
                'MarkerFaceAlpha', 0.75, 'HitTest', 'off');
        elseif isfield(ud, 'liveSlamPts') && ~isempty(ud.liveSlamPts)
            scatter(ax, ud.liveSlamPts(:, 1), ud.liveSlamPts(:, 2), 8, ...
                [0.2 0.45 1.0], 'filled', 'Tag', 'verify_layer', ...
                'MarkerFaceAlpha', 0.35, 'HitTest', 'off');
        end
    elseif ~isempty(ud.scanPtsMap)
        if ~isempty(ud.scanOnWall) && numel(ud.scanOnWall) == size(ud.scanPtsMap, 1)
            off = ~ud.scanOnWall;
            on = ud.scanOnWall;
            if any(off)
                scatter(ax, ud.scanPtsMap(off, 1), ud.scanPtsMap(off, 2), 12, ...
                    [0.95 0.25 0.1], 'filled', 'Tag', 'verify_layer', ...
                    'MarkerFaceAlpha', 0.85, 'HitTest', 'off');
            end
            if any(on)
                scatter(ax, ud.scanPtsMap(on, 1), ud.scanPtsMap(on, 2), 12, ...
                    [0.1 0.75 0.25], 'filled', 'Tag', 'verify_layer', ...
                    'MarkerFaceAlpha', 0.9, 'HitTest', 'off');
            end
        else
            scatter(ax, ud.scanPtsMap(:, 1), ud.scanPtsMap(:, 2), 10, ...
                [0.15 0.45 1.0], 'filled', 'Tag', 'verify_layer', ...
                'MarkerFaceAlpha', 0.75, 'HitTest', 'off');
        end
    end
    if size(ud.trailMap, 1) > 1
        plot(ax, ud.trailMap(:, 1), ud.trailMap(:, 2), '-', ...
            'Color', [1 0.85 0.2], 'LineWidth', 1.2, 'Tag', 'verify_layer');
    end
    verify_draw_pose(ax, ud.odomPose(1), ud.odomPose(2), ud.odomPose(3), ...
        [0.55 0.55 0.55], 0.35, 'ODOM');
    poseDraw = ud.mapPose;
    if isfield(ud, 'useSlam') && ud.useSlam && isfield(ud, 'liveMapPose') && ...
            (~isfield(ud, 'liveReg') || ~ud.liveReg.ready)
        poseDraw = ud.liveMapPose;
    end
    verify_draw_pose(ax, poseDraw(1), poseDraw(2), poseDraw(3), ...
        [1 0.85 0], 1.0, 'MAP');
    if ud.useMcl
        fitPct = NaN;
        if isfield(ud, 'scanFitScore') && isfinite(ud.scanFitScore)
            fitPct = 100 * ud.scanFitScore;
        end
        if isfinite(fitPct) && fitPct >= 40
            title(ax, sprintf('MCL scan %d — %.0f%% scan on saved map', ud.scanCount, fitPct), ...
                'Color', [0 0.45 0.1]);
        else
            title(ax, sprintf(['MCL scan %d — %.0f%% on saved map  |  F flip  X mirror  R'], ...
                ud.scanCount, fitPct), 'Color', [0.75 0.15 0.1]);
        end
    elseif isfield(ud, 'useSlam') && ud.useSlam
        regPct = NaN;
        if isfield(ud, 'regFitPct')
            regPct = ud.regFitPct;
        end
        if isfield(ud, 'liveReg') && ud.liveReg.ready
            title(ax, sprintf(['Live SLAM scan %d — blue map on gray (reg %.0f%%, RMSE %.2f m)'], ...
                ud.scanCount, regPct, ud.liveReg.rmse_m), 'Color', [0 0.45 0.1]);
        else
            title(ax, sprintf('Live SLAM scan %d — building map (%d scans min)...', ...
                ud.scanCount, ud.minScansForAlign), 'Color', [0.2 0.2 0.65]);
        end
    else
        title(ax, sprintf('MAP frame — scan %d', ud.scanCount));
    end
    if ud.autoAxisMap
        pts = ud.bgSlamPts;
        if isfield(ud, 'liveSlamAlignedPts') && ~isempty(ud.liveSlamAlignedPts)
            pts = [pts; ud.liveSlamAlignedPts];
        elseif isfield(ud, 'liveSlamPts') && ~isempty(ud.liveSlamPts)
            pts = [pts; ud.liveSlamPts];
        end
        verify_fit_axis(ax, [pts; ud.trailMap(:, 1:2); poseDraw(1:2)]);
        ud.autoAxisMap = false;
        fig = ancestor(ax, 'figure');
        fig.UserData = ud;
    end
end

function verify_plot_unreal_panel(ud)
    ax = ud.axUe;
    delete(findobj(ax, 'Tag', 'verify_layer'));
    scatter(ax, ud.unrealPts(:, 1), ud.unrealPts(:, 2), 14, ...
        [0.9 0.15 0.15], 'filled', 'Tag', 'verify_layer', ...
        'MarkerFaceAlpha', 0.95, 'HitTest', 'off');
    if ~isempty(ud.align) && isfield(ud, 'alignedSlamPts') && ~isempty(ud.alignedSlamPts)
        scatter(ax, ud.alignedSlamPts(:, 1), ud.alignedSlamPts(:, 2), 8, ...
            [0.1 0.75 0.2], 'filled', 'Tag', 'verify_layer', ...
            'MarkerFaceAlpha', 0.55, 'HitTest', 'off');
    end
    if isfield(ud, 'liveSlamUePts') && ~isempty(ud.liveSlamUePts)
        scatter(ax, ud.liveSlamUePts(:, 1), ud.liveSlamUePts(:, 2), 9, ...
            [0.2 0.45 1.0], 'filled', 'Tag', 'verify_layer', ...
            'MarkerFaceAlpha', 0.65, 'HitTest', 'off');
    elseif ~isempty(ud.scanPtsUe)
        if ~isempty(ud.scanOnWall) && numel(ud.scanOnWall) == size(ud.scanPtsUe, 1)
            off = ~ud.scanOnWall;
            on = ud.scanOnWall;
            if any(off)
                scatter(ax, ud.scanPtsUe(off, 1), ud.scanPtsUe(off, 2), 10, ...
                    [0.95 0.45 0.1], 'filled', 'Tag', 'verify_layer', ...
                    'MarkerFaceAlpha', 0.75, 'HitTest', 'off');
            end
            if any(on)
                scatter(ax, ud.scanPtsUe(on, 1), ud.scanPtsUe(on, 2), 10, ...
                    [0.1 0.85 0.35], 'filled', 'Tag', 'verify_layer', ...
                    'MarkerFaceAlpha', 0.85, 'HitTest', 'off');
            end
        else
            scatter(ax, ud.scanPtsUe(:, 1), ud.scanPtsUe(:, 2), 10, ...
                [0.15 0.45 1.0], 'filled', 'Tag', 'verify_layer', ...
                'MarkerFaceAlpha', 0.65, 'HitTest', 'off');
        end
    end
    if ~isempty(ud.align) && isfinite(ud.uePose.x)
        if size(ud.trailUe, 1) > 1
            plot(ax, ud.trailUe(:, 1), ud.trailUe(:, 2), '-', ...
                'Color', [0 0.75 0.85], 'LineWidth', 1.2, 'Tag', 'verify_layer');
        end
        verify_draw_pose(ax, ud.uePose.x, ud.uePose.y, ud.uePose.yaw, ...
            [0 0.85 0.95], 1.0, 'UE');
    end
    if isempty(ud.align)
        title(ax, 'Calibrated frame — run run_manual_align_slam and press 5 to save');
    elseif isfield(ud, 'useSlam') && ud.useSlam
        title(ax, sprintf(['Unreal scan %d — green=saved manual align  blue=live SLAM map  ' ...
            'cyan=robot'], ud.scanCount));
    else
        title(ax, sprintf('Calibrated scan %d — green=manual align  cyan=robot', ud.scanCount));
    end
    if ud.autoAxisUe
        pts = ud.unrealPts;
        if isfield(ud, 'alignedSlamPts') && ~isempty(ud.alignedSlamPts)
            pts = [pts; ud.alignedSlamPts];
        end
        if isfield(ud, 'liveSlamUePts') && ~isempty(ud.liveSlamUePts)
            pts = [pts; ud.liveSlamUePts];
        elseif ~isempty(ud.scanPtsUe)
            pts = [pts; ud.scanPtsUe];
        end
        if ~isempty(ud.trailUe)
            pts = [pts; ud.trailUe(:, 1:2)];
        end
        verify_fit_axis(ax, pts);
        ud.autoAxisUe = false;
        fig = ancestor(ax, 'figure');
        fig.UserData = ud;
    end
end

function verify_draw_pose(ax, x, y, yaw, color, alpha, ~)
    if ~all(isfinite([x, y, yaw]))
        return;
    end
    yaw = mcl_heading_display_yaw(yaw);
    len = 0.38;
    halfW = 0.17;
    % Body frame: tip at +x (forward), flat base behind.
    local = [len, 0; -0.28 * len, halfW; -0.28 * len, -halfW];
    c = cos(yaw);
    s = sin(yaw);
    R = [c, -s; s, c];
    tri = (R * local')' + [x, y];
    patch(ax, tri(:, 1), tri(:, 2), color, ...
        'FaceAlpha', alpha, 'EdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6, ...
        'Tag', 'verify_layer', 'HitTest', 'off');
end

function verify_fit_axis(ax, pts)
    if isempty(pts)
        return;
    end
    pad = 0.75;
    xlim(ax, [min(pts(:, 1)) - pad, max(pts(:, 1)) + pad]);
    ylim(ax, [min(pts(:, 2)) - pad, max(pts(:, 2)) + pad]);
end

function txt = verify_status_text(ud)
    txt = sprintf(['scan %d  |  MAP x=%+.3f y=%+.3f yaw=%+.1f°  |  ' ...
        'ODOM x=%+.3f y=%+.3f yaw=%+.1f°'], ...
        ud.scanCount, ud.mapPose(1), ud.mapPose(2), rad2deg(mcl_heading_display_yaw(ud.mapPose(3))), ...
        ud.odomPose(1), ud.odomPose(2), rad2deg(mcl_heading_display_yaw(ud.odomPose(3))));
    if ud.useMcl && isfield(ud, 'scanFitScore') && isfinite(ud.scanFitScore)
        pct = 100 * ud.scanFitScore;
        if pct >= 40
            txt = sprintf('%s  |  MCL aligned %.0f%%', txt, pct);
        else
            txt = sprintf('%s  |  MCL NOT aligned %.0f%% — press R or nudge WASD', txt, pct);
        end
    elseif isfield(ud, 'useSlam') && ud.useSlam
        if isfield(ud, 'liveReg') && ud.liveReg.ready
            txt = sprintf('%s  |  live map registered (RMSE %.2f m, fit %.0f%%)', ...
                txt, ud.liveReg.rmse_m, ud.regFitPct);
        else
            txt = sprintf('%s  |  building live SLAM map...', txt);
        end
    end
    if ~isempty(ud.align) && isfinite(ud.uePose.x)
        txt = sprintf(['%s  |  UE x=%+.3f y=%+.3f yaw=%+.1f°  |  ' ...
            'Sim3D x=%+.3f y=%+.3f z=%+.3f yaw=%+.1f°  |  ref=%s'], ...
            txt, ud.uePose.x, ud.uePose.y, rad2deg(mcl_heading_display_yaw(ud.uePose.yaw)), ...
            ud.ueSim.x, ud.ueSim.y, ud.ueSim.z, rad2deg(mcl_heading_display_yaw(ud.ueSim.yaw)), ...
            char(ud.refSource));
    end
end

function align = load_align_optional()
    align = [];
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    if isfile(path)
        align = load(path);
    end
end

function ptsUe = verify_map_points_to_unreal(xyMap, align)
    ptsUe = apply_slam_map_to_unreal(xyMap, align);
end

function pct = verify_reg_fit_pct(reg)
    pct = 0;
    if isempty(reg) || ~isfield(reg, 'ready') || ~reg.ready || ~isfinite(reg.rmse_m)
        return;
    end
    pct = max(0, min(100, 100 * (1 - reg.rmse_m / 0.6)));
end

function pose = verify_current_map_pose(slam)
    [~, poses] = scansAndPoses(slam);
    if isempty(poses)
        pose = [0, 0, 0];
    else
        pose = poses(end, :);
    end
end

function key = verify_scan_stamp_key(scan)
    key = double(scan.header.stamp.sec) + double(scan.header.stamp.nanosec) * 1e-9;
end

function check_verify_lidar_slam()
    if isempty(which('lidarSLAM'))
        error('verify_map_pose:NoToolbox', 'Navigation Toolbox lidarSLAM required.');
    end
end

function check_verify_mcl()
    if isempty(which('monteCarloLocalization'))
        error('verify_map_pose:NoToolbox', ...
            'Navigation Toolbox monteCarloLocalization required for MCL mode.');
    end
end

function opts = parse_verify_opts(args)
    opts = struct( ...
        'MapPath', '', ...
        'RefSource', 'auto', ...
        'Localization', 'slam', ...
        'MaxDuration', inf, ...
        'PlotWallEvery', 10, ...
        'MapAlignEvery', 8, ...
        'MinScansForAlign', 8, ...
        'TrailLength', 200, ...
        'ShowSavedMapBg', true);
    if isempty(args)
        return;
    end
    p = inputParser;
    addParameter(p, 'MapPath', '', @ischar);
    addParameter(p, 'RefSource', 'auto', @ischar);
    addParameter(p, 'Localization', 'slam', @(s) any(strcmpi(s, {'mcl', 'slam'})));
    addParameter(p, 'MaxDuration', inf, @isnumeric);
    addParameter(p, 'PlotWallEvery', 10, @isnumeric);
    addParameter(p, 'MapAlignEvery', 8, @isnumeric);
    addParameter(p, 'MinScansForAlign', 8, @isnumeric);
    addParameter(p, 'TrailLength', 200, @isnumeric);
    addParameter(p, 'ShowSavedMapBg', true, @islogical);
    parse(p, args{:});
    opts = p.Results;
    opts.MapAlignEvery = max(1, round(opts.MapAlignEvery));
    opts.MinScansForAlign = max(3, round(opts.MinScansForAlign));
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function verify_add_btn(fig, pos, label, cb)
    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', pos, 'String', label, 'FontSize', 10, ...
        'Callback', @(src, evt) verify_btn_cb(fig, src, cb));
end

function verify_btn_cb(fig, ~, cb)
    if ~isgraphics(fig)
        return;
    end
    figure(fig);
    cb();
end

function verify_mcl_action(fig, action)
    if ~isfield(fig.UserData, 'mclCtx') || ~fig.UserData.mclCtx.useMcl
        return;
    end
    figure(fig);
    ctx = fig.UserData.mclCtx;
    ud = fig.UserData;

    switch lower(action)
        case 'mirror'
            ctx.lidarMirror = ~ctx.lidarMirror;
            mcl_save_lidar_offset(ctx.lidarAngleOffset, ctx.lidarMirror);
            if ctx.lidarMirror
                fprintf('[verify] Reflect live lidar ON (mirror) — saved\n');
            else
                fprintf('[verify] Reflect live lidar OFF — saved\n');
            end
            verify_mcl_refresh_ui(fig, ctx, ud.mapPose);
        case 'flip'
            ctx.lidarAngleOffset = verify_wrap_pi(ctx.lidarAngleOffset + pi);
            mcl_save_lidar_offset(ctx.lidarAngleOffset, ctx.lidarMirror);
            fprintf('[verify] Live lidar flipped 180° (offset %.0f°) — saved\n', ...
                rad2deg(ctx.lidarAngleOffset));
            verify_mcl_refresh_ui(fig, ctx, ud.mapPose);
        case 'rematch'
            if ~isempty(ctx.mcl) && isobject(ctx.mcl)
                release(ctx.mcl);
            end
            ctx.mcl = [];
            ctx.mclReady = false;
            ctx.resetOdom = true;
            ctx.manualPose = [];
            ctx.lowScoreCount = 0;
            ctx.lowFitSnapCount = 0;
            ctx.odomAnchor = [];
            ctx.lastMclPose = [];
            fprintf('[verify] Re-matching lidar to map...\n');
            fig.UserData.mclCtx = ctx;
    end
end

function verify_map_pose_key(fig, evt)
    if ~isfield(fig.UserData, 'mclCtx') || ~fig.UserData.mclCtx.useMcl
        return;
    end
    figure(fig);
    key = lower(evt.Key);

    if strcmp(key, 'r')
        verify_mcl_action(fig, 'rematch');
        return;
    end
    if strcmp(key, 'f')
        verify_mcl_action(fig, 'flip');
        return;
    end
    if strcmp(key, 'x')
        verify_mcl_action(fig, 'mirror');
        return;
    end

    ctx = fig.UserData.mclCtx;
    ud = fig.UserData;
    nudge = verify_mcl_nudge_delta(key, ismember('shift', evt.Modifier));
    if isempty(nudge)
        return;
    end

    pose = verify_mcl_current_pose(ud, ctx) + nudge;
    pose(3) = verify_wrap_pi(pose(3));
    fprintf('[verify] Nudge → MAP x=%.2f y=%.2f yaw=%.1f°\n', ...
        pose(1), pose(2), rad2deg(mcl_heading_display_yaw(pose(3))));
    verify_mcl_refresh_ui(fig, ctx, pose);
end

function pose = verify_mcl_current_pose(ud, ctx)
    if isfield(ctx, 'manualPose') && ~isempty(ctx.manualPose)
        pose = ctx.manualPose;
    elseif ctx.mclReady && isfield(ctx.mclState, 'hasPose') && ctx.mclState.hasPose
        pose = ud.mapPose;
    else
        pose = ud.mapPose;
    end
end

function verify_mcl_refresh_ui(fig, ctx, pose)
    ud = fig.UserData;

    if ctx.mclReady && ~isempty(ctx.mclLockCfg) && ...
            ~isempty(ctx.mcl) && isobject(ctx.mcl)
        ctx.mcl = mcl_set_pose(ctx.mcl, pose, ctx.mclLockCfg);
        ctx.mclState = mcl_default_state();
        ctx.mclState.hasPose = true;
        ctx.mclState.lastPose = pose;
    end
    ctx.manualPose = pose;
    ctx = mcl_sync_pose(ctx, pose, ud.odomPose, 1.0);

    ud.mapPose = pose;
    if isfield(ctx, 'lastLsRaw') && ~isempty(ctx.lastLsRaw) && isfield(ctx, 'mapData')
        ls = verify_lidarscan_prepare(ctx.lastLsRaw, ctx);
        match = mcl_scan_map_match(ctx.mapData.map, ls, pose);
        ud.scanPtsMap = [match.wx(:), match.wy(:)];
        ud.scanOnWall = match.onWall(:);
        ud.scanPtsUe = verify_map_points_to_unreal(ud.scanPtsMap, ud.align);
        ud.scanFitScore = match.score;
        ctx.lastScanScore = match.score;
        ctx.scanWx = match.wx;
        ctx.scanWy = match.wy;
        ctx.scanOnWall = match.onWall;
    end

    fig.UserData = ud;
    fig.UserData.mclCtx = ctx;
    verify_map_pose_redraw(fig);
    drawnow;
end

function a = verify_wrap_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end

function d = verify_mcl_nudge_delta(key, fine)
    step = 0.15;
    rot = deg2rad(5);
    if fine
        step = 0.05;
        rot = deg2rad(2);
    end
    d = [];
    switch key
        case {'w', 'uparrow'}
            d = [0, step, 0];
        case {'s', 'downarrow'}
            d = [0, -step, 0];
        case {'a', 'leftarrow'}
            d = [-step, 0, 0];
        case {'d', 'rightarrow'}
            d = [step, 0, 0];
        case 'q'
            d = [0, 0, rot];
        case 'e'
            d = [0, 0, -rot];
    end
end

function ctx = verify_mcl_init_from_scan(ctx, ls, odomPose)
    ctx = mcl_init_from_scan(ctx, ls, odomPose);
end

function predicted = verify_mcl_predict_pose(ctx, odomPose, fallbackPose)
    predicted = mcl_predict_pose(ctx, odomPose, fallbackPose);
end

function ctx = verify_mcl_sync_pose(ctx, mapPose, odomPose, fitScore)
    ctx = mcl_sync_pose(ctx, mapPose, odomPose, fitScore);
end

function state = mcl_default_state_struct()
    state = mcl_default_state();
end
