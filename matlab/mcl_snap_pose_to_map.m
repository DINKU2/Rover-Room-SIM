function [pose, score] = mcl_snap_pose_to_map(map, ls, seedPose, varargin)
%MCL_SNAP_POSE_TO_MAP  Scan-to-wall pose search on the saved map.
%
%   [pose, score] = mcl_snap_pose_to_map(map, ls, seedPose)
%   [pose, score] = mcl_snap_pose_to_map(map, ls, seedPose, 'Mode', 'local')
%   [pose, score] = mcl_snap_pose_to_map(map, ls, seedPose, 'Mode', 'global')
%   [pose, score] = mcl_snap_pose_to_map(map, ls, seedPose, 'Mode', 'auto')
%
%   Modes:
%     local  — fast window around seedPose (MAP frame, ~400 evals)
%     global — coarse search over the whole map (~2k evals)
%     auto   — local if seed scores >= 0.50, else global
%
%   Map walls stay fixed; only the robot pose (scan projection) moves.
%   seedPose must be in the saved MAP frame (not wheel odometry).

    if nargin < 3 || isempty(seedPose)
        seedPose = [0, 0, 0];
    end
    seed = seedPose(:)';

    p = inputParser;
    addParameter(p, 'Mode', 'auto', @(s) any(strcmpi(s, {'local', 'global', 'auto'})));
    parse(p, varargin{:});
    mode = lower(p.Results.Mode);

    cache = mcl_get_map_cache(map);
    seedScore = mcl_scan_map_score_cached(cache, ls, seed);

    if strcmp(mode, 'auto')
        if seedScore >= 0.50
            mode = 'local';
        else
            mode = 'global';
        end
    end

    switch mode
        case 'local'
            [pose, score] = local_search(cache, ls, seed);
        case 'global'
            [pose, score] = global_search(cache, ls, seed);
        otherwise
            [pose, score] = local_search(cache, ls, seed);
    end

    if score < seedScore
        pose = seed;
        score = seedScore;
    end
end

function [pose, score] = local_search(cache, ls, seed)
    xs = seed(1) + (-0.5:0.25:0.5);
    ys = seed(2) + (-0.5:0.25:0.5);
    yaws = seed(3) + deg2rad(-30:5:30);
    yaws = arrayfun(@wrap_to_pi, yaws);
    [pose, score] = grid_search(cache, ls, xs, ys, yaws, seed, seed);
end

function [pose, score] = global_search(cache, ls, seed)
    margin = 0.4;
    xs = (cache.xMin + margin):0.60:(cache.xMax - margin);
    ys = (cache.yMin + margin):0.60:(cache.yMax - margin);
    yaws = deg2rad(-180:15:165);
    [coarsePose, ~] = grid_search(cache, ls, xs, ys, yaws, seed, []);

    xs = coarsePose(1) + (-0.60:0.15:0.60);
    ys = coarsePose(2) + (-0.60:0.15:0.60);
    yaws = coarsePose(3) + deg2rad(-15:3:15);
    yaws = arrayfun(@wrap_to_pi, yaws);
    [pose, score] = grid_search(cache, ls, xs, ys, yaws, coarsePose, []);
end

function [bestPose, bestScore] = grid_search(cache, ls, xs, ys, yaws, fallback, prior)
    bestAdj = -inf;
    bestPose = fallback;
    for x = xs
        for y = ys
            for yaw = yaws
                sc = mcl_scan_map_score_cached(cache, ls, [x, y, yaw]);
                adj = sc;
                if ~isempty(prior)
                    adj = sc - 0.03 * norm([x, y] - prior(1:2)) ...
                        - 0.02 * abs(wrap_to_pi(yaw - prior(3)));
                end
                if adj > bestAdj
                    bestAdj = adj;
                    bestPose = [x, y, yaw];
                end
            end
        end
    end
    bestScore = mcl_scan_map_score_cached(cache, ls, bestPose);
end

function a = wrap_to_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end
