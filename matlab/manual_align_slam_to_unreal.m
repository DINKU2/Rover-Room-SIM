function align = manual_align_slam_to_unreal(varargin)
%MANUAL_ALIGN_SLAM_TO_UNREAL  Keyboard-align blue SLAM onto red Unreal ref.
%
%   manual_align_slam_to_unreal()
%   manual_align_slam_to_unreal('MapPath', '.../rover_room_....mat')
%
%   Click the alignment figure, then:
%     W / Up     move SLAM +Y
%     S / Down   move SLAM -Y
%     A / Left   move SLAM -X
%     D / Right  move SLAM +X
%     Q          rotate SLAM left  (CCW)
%     E          rotate SLAM right (CW)
%     5          save maps/unreal_alignment.mat
%     R          reset (auto-seed + mirror detect)
%     M          mirror SLAM across Y (fixes UE vs ROS handedness)
%     Shift      fine step (hold while pressing keys)
%
%   Green = aligned SLAM, Red = Unreal reference, Blue = raw SLAM.

    p = inputParser;
    addParameter(p, 'MapPath', '', @ischar);
    addParameter(p, 'RefSource', 'auto', @ischar);
    addParameter(p, 'TransStepM', 0.05, @isnumeric);
    addParameter(p, 'RotStepDeg', 2, @isnumeric);
    addParameter(p, 'UseExistingAlign', true, @islogical);
    parse(p, varargin{:});
    opts = p.Results;

    setup_rover_paths();

    mapData = load_slam_map(opts.MapPath);
    slamPts = slam_map_wall_points(mapData.map);
    [unrealPts, refMeta] = unreal_room_wall_points('Source', opts.RefSource);

    tx = 0;
    ty = 0;
    theta = 0;
    slamFlipY = false;
    if opts.UseExistingAlign
        [tx, ty, theta, slamFlipY] = load_existing_manual_seed();
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        alignPath = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
        if isfile(alignPath)
            a = load(alignPath);
            if ~isfield(a, 'slam_flip_y')
                [~, ~, ~, slamFlipY] = manual_align_best_seed(slamPts, unrealPts);
                fprintf(['[Manual align] Old save had no mirror flag — using mirrorY=%d. ' ...
                    'Press R to re-seed tx/ty/yaw.\n'], slamFlipY);
            end
        end
    end
    if ~opts.UseExistingAlign
        [tx, ty, theta, slamFlipY] = manual_align_best_seed(slamPts, unrealPts);
    end

    ud = struct();
    ud.slamPts = slamPts;
    ud.unrealPts = unrealPts;
    ud.refMeta = refMeta;
    ud.mapPath = mapData.path;
    ud.tx = tx;
    ud.ty = ty;
    ud.theta = theta;
    ud.slamFlipY = slamFlipY;
    ud.transStep = opts.TransStepM;
    ud.rotStep = deg2rad(opts.RotStepDeg);
    ud.fine = false;

    fprintf('[Manual align] SLAM %d pts | Unreal (%s) %d pts\n', ...
        size(slamPts, 1), refMeta.source, size(unrealPts, 1));

    manual_align_close_figures();

    fig = figure('Name', 'Manual SLAM align — click here', ...
        'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
        'Position', [80 80 920 720], 'Color', [0.96 0.96 0.96], ...
        'CloseRequestFcn', @on_manual_close);
    ax = axes(fig, 'Position', [0.08 0.30 0.88 0.64]);
    manual_align_disable_nav(fig, ax);
    ax.ButtonDownFcn = @(~, ~) manual_align_focus(fig);
    ud.ax = ax;
    hold(ax, 'on');
    grid(ax, 'on');
    axis(ax, 'equal');
    xlabel(ax, 'x [m]');
    ylabel(ax, 'y [m]');
    ud.autoAxis = true;
    ud.refSource = refMeta.source;
    ud.status = uicontrol(fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.04 0.02 0.92 0.12], 'HorizontalAlignment', 'left', ...
        'Enable', 'inactive', ...
        'BackgroundColor', get(fig, 'Color'), 'FontSize', 11, ...
        'String', manual_status_text(ud));

    btnY = 0.16;
    btnH = 0.10;
    btnW = 0.07;
    gap = 0.012;
    x0 = 0.08;
    manual_align_btn(fig, [x0, btnY, btnW, btnH], '← X', @(~,~) manual_align_do(fig, 'a'));
    manual_align_btn(fig, [x0 + (btnW + gap), btnY, btnW, btnH], '↑ Y', @(~,~) manual_align_do(fig, 'w'));
    manual_align_btn(fig, [x0 + 2 * (btnW + gap), btnY, btnW, btnH], '→ X', @(~,~) manual_align_do(fig, 'd'));
    manual_align_btn(fig, [x0 + 3 * (btnW + gap), btnY, btnW, btnH], '↓ Y', @(~,~) manual_align_do(fig, 's'));
    manual_align_btn(fig, [x0 + 4.6 * (btnW + gap), btnY, btnW * 1.3, btnH], 'Q ↺', @(~,~) manual_align_do(fig, 'q'));
    manual_align_btn(fig, [x0 + 6.0 * (btnW + gap), btnY, btnW * 1.3, btnH], 'E ↻', @(~,~) manual_align_do(fig, 'e'));
    manual_align_btn(fig, [0.48, btnY, 0.12, btnH], 'Mirror Y (M)', @(~,~) manual_align_do(fig, 'm'));
    manual_align_btn(fig, [0.62, btnY, 0.14, btnH], 'Save (5)', @(~,~) manual_align_do(fig, '5'));
    manual_align_btn(fig, [0.78, btnY, 0.14, btnH], 'Reset (R)', @(~,~) manual_align_do(fig, 'r'));

    fig.UserData = ud;
    fig.WindowKeyPressFcn = @on_manual_key;
    fig.WindowKeyReleaseFcn = @on_manual_key_release;

    manual_align_redraw(fig);
    manual_align_focus(fig);
    print_manual_help();
end

function manual_align_btn(fig, pos, label, cb)
    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', pos, 'String', label, 'FontSize', 10, ...
        'Callback', @(src, evt) manual_align_btn_cb(fig, src, cb));
end

function manual_align_btn_cb(fig, src, cb)
    if ~manual_align_valid_fig(fig)
        return;
    end
    manual_align_focus(fig);
    cb(src, []);
end

function manual_align_focus(fig)
    if ~manual_align_valid_fig(fig)
        return;
    end
    try
        figure(fig);
        drawnow limitrate;
    catch
    end
end

function on_manual_close(fig, ~)
    manual_align_clear_callbacks(fig);
    try
        if manual_align_valid_fig(fig)
            delete(fig);
        end
    catch
    end
end

function manual_align_close_stale()
    manual_align_close_figures();
end

function manual_align_clear_callbacks(fig)
    if ~manual_align_valid_fig(fig)
        return;
    end
    try
        fig.WindowKeyPressFcn = '';
        fig.WindowKeyReleaseFcn = '';
        fig.KeyPressFcn = '';
        fig.CloseRequestFcn = '';
    catch
    end
end

function tf = manual_align_valid_fig(fig)
    tf = false;
    try
        tf = ~isempty(fig) && isscalar(fig) && isgraphics(fig, 'figure');
    catch
    end
end

function manual_align_disable_nav(fig, ax)
    try
        disableDefaultInteractivity(ax);
    catch
        rotate3d(ax, 'off');
    end
    try
        axtoolbar(ax, {});
    catch
    end
    try
        ax.Interactions = matlab.graphics.interaction.interactions.Interaction.empty;
    catch
    end
    zoom(fig, 'off');
    pan(fig, 'off');
    rotate3d(fig, 'off');
end

function on_manual_key(fig, evt)
    if ~manual_align_valid_fig(fig)
        return;
    end
    try
        ud = fig.UserData;
    catch
        return;
    end
    if isfield(evt, 'Modifier') && any(strcmp(evt.Modifier, 'shift'))
        ud.fine = true;
    end
    fig.UserData = ud;

    key = manual_align_normalize_key(evt);
    if isempty(key)
        return;
    end
    manual_align_do(fig, key);
end

function on_manual_key_release(fig, evt)
    if ~manual_align_valid_fig(fig)
        return;
    end
    try
        ud = fig.UserData;
    catch
        return;
    end
    ud.fine = false;
    if isfield(evt, 'Modifier') && any(strcmp(evt.Modifier, 'shift'))
        ud.fine = true;
    end
    fig.UserData = ud;
end

function manual_align_do(fig, key)
    if ~manual_align_valid_fig(fig)
        return;
    end
    try
        ud = fig.UserData;
    catch
        return;
    end
    key = lower(char(string(key)));
    stepT = ud.transStep * (0.2 + 0.8 * ~ud.fine);
    stepR = ud.rotStep * (0.25 + 0.75 * ~ud.fine);

    switch key
        case {'w', 'uparrow'}
            ud.ty = ud.ty + stepT;
        case {'s', 'downarrow'}
            ud.ty = ud.ty - stepT;
        case {'a', 'leftarrow'}
            ud.tx = ud.tx - stepT;
        case {'d', 'rightarrow'}
            ud.tx = ud.tx + stepT;
        case 'q'
            ud.theta = ud.theta + stepR;
        case 'e'
            ud.theta = ud.theta - stepR;
        case 'm'
            ud.slamFlipY = ~ud.slamFlipY;
            if ud.slamFlipY
                fprintf('[Manual align] Mirror SLAM Y: ON\n');
            else
                fprintf('[Manual align] Mirror SLAM Y: OFF\n');
            end
        case '5'
            fig.UserData = ud;
            manual_align_save(fig);
            return;
        case 'r'
            [ud.tx, ud.ty, ud.theta, ud.slamFlipY] = ...
                manual_align_best_seed(ud.slamPts, ud.unrealPts);
            ud.autoAxis = true;
        otherwise
            return;
    end

    fig.UserData = ud;
    manual_align_redraw(fig);
end

function key = manual_align_normalize_key(evt)
    key = '';
    if isfield(evt, 'Key') && ~isempty(evt.Key) && ~strcmp(evt.Key, 'undefined')
        key = evt.Key;
    elseif isfield(evt, 'Character') && ~isempty(evt.Character)
        key = evt.Character;
    end
    if isempty(key)
        return;
    end
    key = lower(char(string(key)));
    if strcmp(key, 'numpad5')
        key = '5';
    end
end

function manual_align_redraw(fig)
    if ~manual_align_valid_fig(fig)
        return;
    end
    try
        ud = fig.UserData;
    catch
        return;
    end
    aligned = manual_apply_transform(ud.slamPts, ud.tx, ud.ty, ud.theta, ud.slamFlipY);
    manual_align_plot_layers(ud.ax, ud.unrealPts, ...
        manual_slam_display_pts(ud.slamPts, ud.slamFlipY), aligned);

    title(ud.ax, sprintf(['Manual align  tx=%+.3f  ty=%+.3f  yaw=%+.1f°  mirrorY=%d  |  ' ...
        'red=Unreal  blue=SLAM  green=aligned'], ...
        ud.tx, ud.ty, rad2deg(ud.theta), ud.slamFlipY));
    set(ud.status, 'String', manual_status_text(ud));

    if ud.autoAxis
        dispSlam = manual_slam_display_pts(ud.slamPts, ud.slamFlipY);
        manual_align_fit_axis(ud.ax, ud.unrealPts, dispSlam, aligned);
        ud.autoAxis = false;
    end

    fig.UserData = ud;
    drawnow limitrate;
end

function manual_align_plot_layers(ax, unrealPts, slamPts, aligned)
    delete(findobj(ax, 'Tag', 'manual_align_layer'));
    try
        legend(ax, 'off');
    catch
    end

    scatter(ax, unrealPts(:, 1), unrealPts(:, 2), 14, ...
        [0.9 0.15 0.15], 'filled', 'Tag', 'manual_align_layer', ...
        'MarkerFaceAlpha', 0.95, 'HitTest', 'off', 'PickableParts', 'none');
    scatter(ax, slamPts(:, 1), slamPts(:, 2), 8, ...
        [0.2 0.45 1.0], 'filled', 'Tag', 'manual_align_layer', ...
        'MarkerFaceAlpha', 0.35, 'HitTest', 'off', 'PickableParts', 'none');
    scatter(ax, aligned(:, 1), aligned(:, 2), 10, ...
        [0.1 0.75 0.2], 'filled', 'Tag', 'manual_align_layer', ...
        'MarkerFaceAlpha', 0.85, 'HitTest', 'off', 'PickableParts', 'none');
end

function manual_align_fit_axis(ax, unrealPts, slamPts, aligned)
    allPts = [unrealPts; slamPts; aligned];
    if isempty(allPts)
        return;
    end
    pad = 0.75;
    xlim(ax, [min(allPts(:, 1)) - pad, max(allPts(:, 1)) + pad]);
    ylim(ax, [min(allPts(:, 2)) - pad, max(allPts(:, 2)) + pad]);
end

function txt = manual_status_text(ud)
    refSrc = 'unknown';
    if isfield(ud, 'refSource') && ~isempty(ud.refSource)
        refSrc = char(ud.refSource);
    end
    mirrorY = false;
    if isfield(ud, 'slamFlipY')
        mirrorY = ud.slamFlipY;
    end
    txt = sprintf(['Keys (click figure first):  W/A/S/D or arrows = move  |  ' ...
        'Q/E = rotate  |  M = mirror Y  |  5 = save  R = auto-seed  |  ' ...
        'Shift = fine step\n' ...
        'tx=%+.3f m  ty=%+.3f m  yaw=%+.1f°  mirrorY=%d  |  Unreal ref: %s  |  map: %s'], ...
        ud.tx, ud.ty, rad2deg(ud.theta), mirrorY, refSrc, ud.mapPath);
end

function pts = manual_slam_display_pts(slamPts, slamFlipY)
    pts = slamPts;
    if slamFlipY
        pts(:, 2) = -pts(:, 2);
    end
end

function aligned = manual_apply_transform(pts, tx, ty, theta, slamFlipY)
    if nargin >= 5 && slamFlipY
        pts(:, 2) = -pts(:, 2);
    end
    c = cos(theta);
    s = sin(theta);
    R = [c, -s; s, c];
    t = [tx; ty];
    aligned = apply_map_align2d(pts, R, t);
end

function align = manual_align_save(fig)
    ud = fig.UserData;
    c = cos(ud.theta);
    s = sin(ud.theta);

    align = struct();
    align.R2d = [c, -s; s, c];
    align.t2d = [ud.tx; ud.ty];
    align.yaw_offset = ud.theta;
    align.slam_flip_y = ud.slamFlipY;
    align.rmse_m = manual_align_rmse( ...
        manual_slam_display_pts(ud.slamPts, ud.slamFlipY), ud.unrealPts, align.R2d, align.t2d);
    align.ref_mode = 'manual_keyboard';
    align.slam_map_path = ud.mapPath;
    if isfield(ud.refMeta, 'json_path')
        align.unreal_ref_json = ud.refMeta.json_path;
    elseif isfield(ud.refMeta, 'path')
        align.unreal_ref_json = ud.refMeta.path;
    else
        align.unreal_ref_json = '';
    end
    spawn = rover_spawn_pose();
    align.spawn_x = spawn.sim_m(1);
    align.spawn_y = spawn.sim_m(2);
    align.spawn_yaw = deg2rad(spawn.yaw_deg);
    align.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW,DATST>

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    savePath = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    align.save_path = savePath;
    save(savePath, '-struct', 'align');

    fprintf('\n[SAVED] manual alignment (RMSE %.3f m, yaw %.1f deg):\n', ...
        align.rmse_m, rad2deg(align.yaw_offset));
    fprintf('  %s\n\n', savePath);
end

function rmse = manual_align_rmse(slamPts, refPts, R2d, t2d)
    aligned = apply_map_align2d(slamPts, R2d, t2d);
    n = min(size(aligned, 1), size(refPts, 1));
    if n == 0
        rmse = inf;
        return;
    end
    idxA = round(linspace(1, size(aligned, 1), min(800, size(aligned, 1))));
    idxR = round(linspace(1, size(refPts, 1), min(800, size(refPts, 1))));
    d = pdist2(aligned(idxA, :), refPts(idxR, :));
    rmse = sqrt(mean(min(d, [], 2).^2));
end

function [tx, ty, theta, slamFlipY] = load_existing_manual_seed()
    tx = 0;
    ty = 0;
    theta = 0;
    slamFlipY = false;
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    if ~isfile(path)
        return;
    end
    a = load(path);
    if isfield(a, 't2d')
        tx = a.t2d(1);
        ty = a.t2d(2);
    end
    if isfield(a, 'yaw_offset')
        theta = a.yaw_offset;
    elseif isfield(a, 'R2d')
        theta = atan2(a.R2d(2, 1), a.R2d(1, 1));
    end
    if isfield(a, 'slam_flip_y')
        slamFlipY = logical(a.slam_flip_y);
    end
end

function [tx, ty, theta] = centroid_seed(slamPts, unrealPts)
    cs = mean(slamPts, 1);
    cu = mean(unrealPts, 1);
    tx = cu(1) - cs(1);
    ty = cu(2) - cs(2);
    theta = 0;
end

function print_manual_help()
    fprintf('\n=== Manual SLAM alignment ===\n');
    fprintf('Click the figure window (not Command Window), then:\n');
    fprintf('  W / Up     +Y     S / Down   -Y\n');
    fprintf('  A / Left   -X     D / Right  +X\n');
    fprintf('  Q          rotate left (CCW)\n');
    fprintf('  E          rotate right (CW)\n');
    fprintf('  M          mirror SLAM across Y (UE vs ROS flip)\n');
    fprintf('  5          save maps/unreal_alignment.mat\n');
    fprintf('  R          auto-seed + mirror detect\n');
    fprintf('  Shift      finer steps while held\n');
    fprintf('  Or use the on-screen arrow / Q / E / Save buttons.\n\n');
end
