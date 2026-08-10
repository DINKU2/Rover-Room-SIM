function dual_mcl_verify(action)
%DUAL_MCL_VERIFY  Start/stop verify overlay for Stage-4 dual control.
%
%   dual_mcl_verify('start')
%   dual_mcl_verify('stop')

    if nargin < 1 || isempty(action)
        action = 'start';
    end

    switch lower(action)
        case 'start'
            dual_mcl_verify_impl_start();
        case 'stop'
            dual_mcl_verify_impl_stop();
        otherwise
            error('dual_mcl_verify:BadAction', 'Unknown action: %s', action);
    end
end

function dual_mcl_verify_impl_start()
    dual_mcl_verify_impl_stop();

    mcl_dual_shared('init');
    staticUd = mcl_dual_shared('get');
    if isempty(staticUd)
        return;
    end

    fig = figure('Name', 'Dual control — MCL verify (same pose as Unreal twin)', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [60 60 1100 620], 'Color', [0.96 0.96 0.96], ...
        'CloseRequestFcn', @(~, ~) dual_mcl_verify_impl_stop());

    axMap = subplot(1, 2, 1);
    axUe = subplot(1, 2, 2);
    set(axMap, 'Position', [0.06 0.14 0.42 0.78]);
    set(axUe, 'Position', [0.54 0.14 0.42 0.78]);
    hold(axMap, 'on'); grid(axMap, 'on'); axis(axMap, 'equal');
    hold(axUe, 'on'); grid(axUe, 'on'); axis(axUe, 'equal');
    xlabel(axMap, 'x [m]'); ylabel(axMap, 'y [m]');
    xlabel(axUe, 'x [m]'); ylabel(axUe, 'y [m]');

    status = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.02 0.01 0.96 0.08], 'HorizontalAlignment', 'left', ...
        'Enable', 'inactive', 'BackgroundColor', get(fig, 'Color'), ...
        'FontSize', 10, 'String', 'Waiting for Stage-4 MCL...');

    staticUd.axMap = axMap;
    staticUd.axUe = axUe;
    staticUd.status = status;
    staticUd.autoAxisMap = true;
    staticUd.autoAxisUe = true;
    staticUd.lastDisplay = [];
    fig.UserData = staticUd;
    mcl_dual_shared('init', staticUd);

    t = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
        'TimerFcn', @(~, ~) dual_mcl_verify_tick(fig), ...
        'ErrorFcn', @(~, ~) []);
    start(t);

    setappdata(0, 'dualMclVerifyFig', fig);
    setappdata(0, 'dualMclVerifyTimer', t);

    dual_mcl_verify_tick(fig);
    fprintf('[Dual verify] Overlay open — yellow triangle = MCL pose sent to Unreal\n');
end

function dual_mcl_verify_impl_stop()
    t = getappdata(0, 'dualMclVerifyTimer');
    if ~isempty(t)
        try
            stop(t);
            delete(t);
        catch
        end
        if isappdata(0, 'dualMclVerifyTimer')
            rmappdata(0, 'dualMclVerifyTimer');
        end
    end

    fig = getappdata(0, 'dualMclVerifyFig');
    if ~isempty(fig) && isgraphics(fig)
        delete(fig);
    end
    if isappdata(0, 'dualMclVerifyFig')
        rmappdata(0, 'dualMclVerifyFig');
    end
    mcl_dual_shared('clear');
end

function dual_mcl_verify_tick(fig)
    if isempty(fig) || ~isgraphics(fig)
        dual_mcl_verify_impl_stop();
        return;
    end

    tTick = tic;
    dual_mcl_ros_update();

    ud = mcl_dual_shared('get');
    if isempty(ud)
        return;
    end

    base = fig.UserData;
    ud.axMap = base.axMap;
    ud.axUe = base.axUe;
    ud.status = base.status;
    if ~isfield(ud, 'autoAxisMap')
        ud.autoAxisMap = base.autoAxisMap;
    end
    if ~isfield(ud, 'autoAxisUe')
        ud.autoAxisUe = base.autoAxisUe;
    end

    if dual_mcl_verify_display_changed(ud, base.lastDisplay)
        tRedraw = tic;
        dual_mcl_verify_redraw(fig, ud);
        stage4_timing('record', 'overlay.redraw', toc(tRedraw) * 1000);
        base.lastDisplay = dual_mcl_verify_display_snapshot(ud);
    else
        stage4_timing('record', 'overlay.redraw_skip', 0);
    end
    base.autoAxisMap = ud.autoAxisMap;
    base.autoAxisUe = ud.autoAxisUe;
    fig.UserData = base;
    stage4_timing('record', 'overlay.tick_total', toc(tTick) * 1000);
end

function snap = dual_mcl_verify_display_snapshot(ud)
    snap = struct();
    snap.mapPose = ud.mapPose(:);
    snap.scanFitScore = ud.scanFitScore;
    snap.scanCount = ud.scanCount;
    snap.mclReady = ud.mclReady;
    snap.valid = ud.valid;
    if isfield(ud, 'odomPose')
        snap.odomPose = ud.odomPose(:);
    else
        snap.odomPose = [0, 0, 0];
    end
end

function changed = dual_mcl_verify_display_changed(ud, last)
    if isempty(last)
        changed = true;
        return;
    end
    epsPos = 0.002;
    epsFit = 0.005;
    epsYaw = 0.01;
    if ~isfield(ud, 'mapPose') || numel(ud.mapPose) < 3
        changed = true;
        return;
    end
    dMap = norm(ud.mapPose(1:2) - last.mapPose(1:2));
    dYaw = abs(mod(ud.mapPose(3) - last.mapPose(3) + pi, 2 * pi) - pi);
    fitA = ud.scanFitScore;
    fitB = last.scanFitScore;
    if ~isfinite(fitA)
        fitA = 0;
    end
    if ~isfinite(fitB)
        fitB = 0;
    end
    changed = dMap > epsPos || dYaw > epsYaw || abs(fitA - fitB) > epsFit || ...
        ud.scanCount ~= last.scanCount || ud.mclReady ~= last.mclReady || ...
        ud.valid ~= last.valid;
    if ~changed && isfield(ud, 'odomPose') && isfield(last, 'odomPose')
        dOdom = norm(ud.odomPose(1:2) - last.odomPose(1:2));
        if dOdom > epsPos
            changed = true;
        end
    end
end

function dual_mcl_verify_redraw(fig, ud)
    dual_mcl_verify_plot_map(ud);
    dual_mcl_verify_plot_ue(ud);
    set(ud.status, 'String', dual_mcl_verify_status(ud));
    drawnow limitrate;
end

function dual_mcl_verify_plot_map(ud)
    ax = ud.axMap;
    delete(findobj(ax, 'Tag', 'dual_verify_layer'));
    if ~isempty(ud.bgSlamPts)
        scatter(ax, ud.bgSlamPts(:, 1), ud.bgSlamPts(:, 2), 6, ...
            [0.75 0.75 0.75], 'filled', 'Tag', 'dual_verify_layer', ...
            'MarkerFaceAlpha', 0.4, 'HitTest', 'off');
    end
    if isfield(ud, 'spawnMapPose') && ~isempty(ud.spawnMapPose)
        scatter(ax, ud.spawnMapPose(1), ud.spawnMapPose(2), 70, ...
            [0.85 0.2 0.85], 'filled', 'Tag', 'dual_verify_layer', ...
            'MarkerEdgeColor', 'k', 'HitTest', 'off');
        text(ax, ud.spawnMapPose(1), ud.spawnMapPose(2) + 0.25, 'spawn', ...
            'Tag', 'dual_verify_layer', 'FontSize', 9, 'Color', [0.5 0.1 0.5]);
    end
    if ~isempty(ud.scanPtsMap)
        if ~isempty(ud.scanOnWall) && numel(ud.scanOnWall) == size(ud.scanPtsMap, 1)
            off = ~ud.scanOnWall;
            on = ud.scanOnWall;
            if any(off)
                scatter(ax, ud.scanPtsMap(off, 1), ud.scanPtsMap(off, 2), 12, ...
                    [0.95 0.25 0.1], 'filled', 'Tag', 'dual_verify_layer', ...
                    'MarkerFaceAlpha', 0.85, 'HitTest', 'off');
            end
            if any(on)
                scatter(ax, ud.scanPtsMap(on, 1), ud.scanPtsMap(on, 2), 12, ...
                    [0.1 0.75 0.25], 'filled', 'Tag', 'dual_verify_layer', ...
                    'MarkerFaceAlpha', 0.9, 'HitTest', 'off');
            end
        else
            scatter(ax, ud.scanPtsMap(:, 1), ud.scanPtsMap(:, 2), 10, ...
                [0.15 0.45 1.0], 'filled', 'Tag', 'dual_verify_layer', ...
                'MarkerFaceAlpha', 0.75, 'HitTest', 'off');
        end
    end
    if isfield(ud, 'trailMap') && size(ud.trailMap, 1) > 1
        plot(ax, ud.trailMap(:, 1), ud.trailMap(:, 2), '-', ...
            'Color', [1 0.85 0.2], 'LineWidth', 1.2, 'Tag', 'dual_verify_layer');
    end
    dual_mcl_verify_draw_pose(ax, ud.odomPose(1), ud.odomPose(2), ud.odomPose(3), ...
        [0.55 0.55 0.55], 0.35);
    dual_mcl_verify_draw_pose(ax, ud.mapPose(1), ud.mapPose(2), ud.mapPose(3), ...
        [1 0.85 0], 1.0);

    fitPct = 0;
    if isfield(ud, 'scanFitScore') && isfinite(ud.scanFitScore)
        fitPct = 100 * ud.scanFitScore;
    end
    if ud.mclReady && fitPct >= 40
        title(ax, sprintf('MCL scan %d — %.0f%% on saved map (→ Unreal twin)', ...
            ud.scanCount, fitPct), 'Color', [0 0.45 0.1]);
    else
        title(ax, sprintf('MCL scan %d — %.0f%% (waiting for lock...)', ...
            ud.scanCount, fitPct), 'Color', [0.75 0.15 0.1]);
    end

    if ud.autoAxisMap
        pts = ud.bgSlamPts;
        if ~isempty(ud.scanPtsMap)
            pts = [pts; ud.scanPtsMap];
        end
        if isfield(ud, 'trailMap') && ~isempty(ud.trailMap)
            pts = [pts; ud.trailMap(:, 1:2)];
        end
        dual_mcl_verify_fit_axis(ax, pts);
        ud.autoAxisMap = false;
    end
end

function dual_mcl_verify_plot_ue(ud)
    ax = ud.axUe;
    delete(findobj(ax, 'Tag', 'dual_verify_layer'));
    scatter(ax, ud.unrealPts(:, 1), ud.unrealPts(:, 2), 14, ...
        [0.9 0.15 0.15], 'filled', 'Tag', 'dual_verify_layer', ...
        'MarkerFaceAlpha', 0.95, 'HitTest', 'off');
    if ~isempty(ud.align) && ~isempty(ud.alignedSlamPts)
        scatter(ax, ud.alignedSlamPts(:, 1), ud.alignedSlamPts(:, 2), 8, ...
            [0.1 0.75 0.2], 'filled', 'Tag', 'dual_verify_layer', ...
            'MarkerFaceAlpha', 0.55, 'HitTest', 'off');
    end
    if ~isempty(ud.scanPtsUe)
        scatter(ax, ud.scanPtsUe(:, 1), ud.scanPtsUe(:, 2), 10, ...
            [0.15 0.45 1.0], 'filled', 'Tag', 'dual_verify_layer', ...
            'MarkerFaceAlpha', 0.65, 'HitTest', 'off');
    end
    if ~isempty(ud.align) && isfinite(ud.uePose.x)
        if isfield(ud, 'trailUe') && size(ud.trailUe, 1) > 1
            plot(ax, ud.trailUe(:, 1), ud.trailUe(:, 2), '-', ...
                'Color', [0 0.75 0.85], 'LineWidth', 1.2, 'Tag', 'dual_verify_layer');
        end
        dual_mcl_verify_draw_pose(ax, ud.uePose.x, ud.uePose.y, ud.uePose.yaw, ...
            [0 0.85 0.95], 1.0);
    end
    title(ax, sprintf('Unreal frame — scan %d  (cyan = twin target pose)', ud.scanCount));

    if ud.autoAxisUe
        pts = ud.unrealPts;
        if ~isempty(ud.alignedSlamPts)
            pts = [pts; ud.alignedSlamPts];
        end
        if ~isempty(ud.scanPtsUe)
            pts = [pts; ud.scanPtsUe];
        end
        dual_mcl_verify_fit_axis(ax, pts);
        ud.autoAxisUe = false;
    end
end

function dual_mcl_verify_draw_pose(ax, x, y, yaw, color, alpha)
    if ~all(isfinite([x, y, yaw]))
        return;
    end
    yaw = mcl_heading_display_yaw(yaw);
    len = 0.38;
    halfW = 0.17;
    local = [len, 0; -0.28 * len, halfW; -0.28 * len, -halfW];
    c = cos(yaw);
    s = sin(yaw);
    R = [c, -s; s, c];
    tri = (R * local')' + [x, y];
    patch(ax, tri(:, 1), tri(:, 2), color, ...
        'FaceAlpha', alpha, 'EdgeColor', [0.15 0.15 0.15], 'LineWidth', 0.6, ...
        'Tag', 'dual_verify_layer', 'HitTest', 'off');
end

function dual_mcl_verify_fit_axis(ax, pts)
    if isempty(pts)
        return;
    end
    pad = 0.75;
    xlim(ax, [min(pts(:, 1)) - pad, max(pts(:, 1)) + pad]);
    ylim(ax, [min(pts(:, 2)) - pad, max(pts(:, 2)) + pad]);
end

function txt = dual_mcl_verify_status(ud)
    txt = sprintf(['scan %d  |  MAP x=%+.3f y=%+.3f yaw=%+.1f°  |  ' ...
        'ODOM x=%+.3f y=%+.3f yaw=%+.1f°'], ...
        ud.scanCount, ud.mapPose(1), ud.mapPose(2), rad2deg(mcl_heading_display_yaw(ud.mapPose(3))), ...
        ud.odomPose(1), ud.odomPose(2), rad2deg(mcl_heading_display_yaw(ud.odomPose(3))));
    if isfield(ud, 'scanFitScore') && isfinite(ud.scanFitScore)
        pct = 100 * ud.scanFitScore;
        if pct >= 40
            txt = sprintf('%s  |  MCL aligned %.0f%%  |  twin valid=%d', ...
                txt, pct, ud.valid);
        else
            txt = sprintf('%s  |  MCL NOT aligned %.0f%%  |  twin valid=%d', ...
                txt, pct, ud.valid);
        end
    end
    if ~isempty(ud.align) && isfinite(ud.uePose.x)
        txt = sprintf(['%s  |  UE x=%+.3f y=%+.3f yaw=%+.1f°  |  ' ...
            'Sim3D x=%+.3f y=%+.3f z=%+.3f yaw=%+.1f°'], ...
            txt, ud.uePose.x, ud.uePose.y, rad2deg(mcl_heading_display_yaw(ud.uePose.yaw)), ...
            ud.ueSim.x, ud.ueSim.y, ud.ueSim.z, rad2deg(mcl_heading_display_yaw(ud.ueSim.yaw)));
    end
end
