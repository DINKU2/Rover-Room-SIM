function varargout = mcl_dual_shared(action, payload)
%MCL_DUAL_SHARED  Share Stage-4 MCL state (base workspace — Simulink-safe).
%
%   mcl_dual_shared('init', udStatic)
%   mcl_dual_shared('publish', live)
%   ud = mcl_dual_shared('get')
%   mcl_dual_shared('clear')

    if nargin < 1
        action = 'get';
    end

    state = shared_get();

    switch lower(action)
        case 'init'
            if nargin < 2 || isempty(payload)
                state.staticUd = build_static_ud();
            else
                state.staticUd = payload;
            end
            state.liveUd = default_live();
            shared_set(state);
        case 'publish'
            state.liveUd = merge_live(state.liveUd, payload);
            shared_set(state);
        case 'get'
            if isempty(state.staticUd)
                varargout{1} = [];
                return;
            end
            varargout{1} = merge_ud(state.staticUd, state.liveUd);
        case 'clear'
            shared_set(struct('staticUd', [], 'liveUd', []));
        otherwise
            error('mcl_dual_shared:BadAction', 'Unknown action: %s', action);
    end
end

function state = shared_get()
    if evalin('base', 'exist(''dualMclSharedState'', ''var'')')
        state = evalin('base', 'dualMclSharedState');
    else
        state = struct('staticUd', [], 'liveUd', []);
    end
end

function shared_set(state)
    assignin('base', 'dualMclSharedState', state);
end

function live = default_live()
    live = struct( ...
        'mapPose', [0, 0, 0], ...
        'odomPose', [0, 0, 0], ...
        'scanFitScore', NaN, ...
        'mclReady', false, ...
        'valid', false, ...
        'scanCount', 0, ...
        'scanPtsMap', zeros(0, 2), ...
        'scanPtsUe', zeros(0, 2), ...
        'scanOnWall', [], ...
        'uePose', struct('x', NaN, 'y', NaN, 'yaw', NaN), ...
        'ueSim', struct('x', NaN, 'y', NaN, 'z', NaN, 'yaw', NaN), ...
        'trailMap', zeros(0, 3), ...
        'trailUe', zeros(0, 3));
end

function live = merge_live(live, payload)
    if isempty(live)
        live = default_live();
    end
    fields = fieldnames(payload);
    for k = 1:numel(fields)
        live.(fields{k}) = payload.(fields{k});
    end
end

function ud = merge_ud(staticUd, liveUd)
    if isempty(liveUd)
        liveUd = default_live();
    end
    ud = staticUd;
    ud.mapPose = liveUd.mapPose;
    ud.odomPose = liveUd.odomPose;
    ud.scanFitScore = liveUd.scanFitScore;
    ud.mclReady = liveUd.mclReady;
    ud.valid = liveUd.valid;
    ud.scanCount = liveUd.scanCount;
    ud.scanPtsMap = liveUd.scanPtsMap;
    ud.scanPtsUe = liveUd.scanPtsUe;
    ud.scanOnWall = liveUd.scanOnWall;
    ud.uePose = liveUd.uePose;
    ud.ueSim = liveUd.ueSim;
    ud.trailMap = liveUd.trailMap;
    ud.trailUe = liveUd.trailUe;
    ud.useMcl = true;
    ud.useSlam = false;
end

function ud = build_static_ud()
    setup_rover_paths();
    [unrealPts, refMeta] = unreal_room_wall_points('Source', 'auto');
    align = [];
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    alignPath = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    if isfile(alignPath)
        align = load(alignPath);
    end
    mapData = load_slam_map('');
    bgSlamPts = slam_map_wall_points(mapData.map);
    mcl_get_map_cache(mapData.map);

    ud = struct();
    ud.axMap = [];
    ud.axUe = [];
    ud.status = [];
    ud.unrealPts = unrealPts;
    ud.bgSlamPts = bgSlamPts;
    ud.align = align;
    ud.refSource = refMeta.source;
    ud.autoAxisMap = true;
    ud.autoAxisUe = true;
    if ~isempty(align) && ~isempty(bgSlamPts) && isfield(align, 'R2d')
        ud.alignedSlamPts = apply_slam_map_to_unreal(bgSlamPts, align);
    else
        ud.alignedSlamPts = zeros(0, 2);
    end
    if ~isempty(align) && isfield(align, 'spawn_x')
        ud.spawnMapPose = unreal_pose_to_map( ...
            align.spawn_x, align.spawn_y, align.spawn_yaw, align);
    else
        ud.spawnMapPose = [];
    end
end
