function [result, bestOffset] = mcl_guess_best_offset(map, lsRaw, align, mapData, odomPose)
%MCL_GUESS_BEST_OFFSET  Try common lidar angle offsets; pick best map match.

    if nargin < 5
        odomPose = [];
    end

    saved = mcl_load_lidar_offset();
    offsets = unique([saved, 0, pi, -pi, pi/2, -pi/2], 'stable');

    bestScore = -inf;
    bestOffset = saved;
    result = struct('pose', [0, 0, 0], 'score', 0, 'angleOffset', bestOffset, 'useGlobal', true);

    for k = 1:numel(offsets)
        off = offsets(k);
        ls = lidarscan_apply_offset(lsRaw, off);
        guess = mcl_guess_pose_from_scan(map, ls, align, mapData, odomPose);
        if guess.score > bestScore
            bestScore = guess.score;
            bestOffset = off;
            result = guess;
            result.angleOffset = off;
        end
    end

    if abs(bestOffset) > 1e-9
        fprintf('[mcl] Lidar angle offset %.0f° (score=%.0f%%)\n', ...
            rad2deg(bestOffset), 100 * bestScore);
    end
end
