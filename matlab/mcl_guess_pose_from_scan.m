function result = mcl_guess_pose_from_scan(map, ls, align, mapData, odomPose)
%MCL_GUESS_POSE_FROM_SCAN  Full-map likelihood-field pose search.

    if nargin < 5
        odomPose = [];
    end

    fprintf('[mcl] Matching first scan to saved map...\n');
    t0 = tic;
    cache = mcl_get_map_cache(map);
    seedPose = [0, 0, 0];
    if ~isempty(align) && isfield(align, 'spawn_x')
        seedPose = unreal_pose_to_map(align.spawn_x, align.spawn_y, align.spawn_yaw, align);
    end

    bestScore = -inf;
    bestPose = seedPose;
    bestOffset = 0;

    % Stage 2 built this map from the raw scan angles. Searching an additional
    % lidar offset together with map yaw is unobservable: +180 degrees in one
    % can be cancelled by -180 degrees in the other while reversing the robot.
    [bestPose, bestScore] = mcl_snap_pose_to_map( ...
        cache.map, ls, seedPose, 'Mode', 'global');

    result = struct( ...
        'pose', bestPose, ...
        'score', bestScore, ...
        'angleOffset', bestOffset, ...
        'useGlobal', bestScore < 0.25);

    fprintf('[mcl] Global map search — score=%.0f%%  (%.1fs)\n', 100 * bestScore, toc(t0));
end
