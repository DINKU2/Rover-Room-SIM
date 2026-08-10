function [tx, ty, theta, slamFlipY] = manual_align_best_seed(slamPts, unrealPts)
%MANUAL_ALIGN_BEST_SEED  Auto-seed tx/ty/yaw (+ optional Y mirror) for manual align.
%
%   [tx, ty, theta, slamFlipY] = manual_align_best_seed(slamPts, unrealPts)
%
%   Tries both SLAM Y mirrors and a coarse yaw sweep with centroid translation,
%   then optionally refines with ICP when Computer Vision Toolbox is available.

    slamPts = double(slamPts(:, 1:2));
    unrealPts = double(unrealPts(:, 1:2));

    if isempty(slamPts) || isempty(unrealPts)
        tx = 0;
        ty = 0;
        theta = 0;
        slamFlipY = false;
        return;
    end

    angleStepDeg = 5;
    angles = deg2rad(0:angleStepDeg:359);
    bestRmse = inf;
    tx = 0;
    ty = 0;
    theta = 0;
    slamFlipY = false;

    for flipY = [false, true]
        pts = slamPts;
        if flipY
            pts(:, 2) = -pts(:, 2);
        end

        for thetaTry = angles
            c = cos(thetaTry);
            s = sin(thetaTry);
            R = [c, -s; s, c];
            cs = mean(pts, 1)';
            cu = mean(unrealPts, 1)';
            t = cu - R * cs;
            aligned = apply_map_align2d(pts, R, t);
            rmse = seed_rmse(aligned, unrealPts);

            if rmse < bestRmse
                bestRmse = rmse;
                tx = t(1);
                ty = t(2);
                theta = thetaTry;
                slamFlipY = flipY;
            end
        end
    end

    if ~isempty(which('pcregistericp'))
        [tx, ty, theta, slamFlipY, icpRmse] = refine_with_icp( ...
            slamPts, unrealPts, tx, ty, theta, slamFlipY);
        if isfinite(icpRmse)
            bestRmse = icpRmse;
        end
    end

    fprintf('[Manual align] Auto-seed: tx=%+.3f ty=%+.3f yaw=%+.1f° mirrorY=%d (RMSE %.3f m)\n', ...
        tx, ty, rad2deg(theta), slamFlipY, bestRmse);
end

function [tx, ty, theta, slamFlipY, rmse] = refine_with_icp( ...
        slamPts, unrealPts, tx, ty, theta, slamFlipY)
    rmse = inf;
    try
        pts = slamPts;
        if slamFlipY
            pts(:, 2) = -pts(:, 2);
        end
        c = cos(theta);
        s = sin(theta);
        R2d = [c, -s; s, c];
        t2d = [tx; ty];

        fixed = pointCloud([unrealPts, zeros(size(unrealPts, 1), 1)]);
        aligned = apply_map_align2d(pts, R2d, t2d);
        moving = pointCloud([aligned, zeros(size(aligned, 1), 1)]);

        [tform, ~, rmse] = pcregistericp(moving, fixed, ...
            'MaxIterations', 100, ...
            'Tolerance', [0.0005, 0.002], ...
            'InlierDistance', 0.35);
        [tform, ~, rmse] = pcregistericp(moving, fixed, ...
            'InitialTransform', tform, ...
            'MaxIterations', 100, ...
            'Tolerance', [0.0001, 0.001], ...
            'InlierDistance', 0.20);

        R = tform.Rotation(1:2, 1:2);
        t = tform.Translation(1:2)';
        combinedR = R * R2d;
        combinedT = R * t2d + t;

        tx = combinedT(1);
        ty = combinedT(2);
        theta = atan2(combinedR(2, 1), combinedR(1, 1));
    catch
        rmse = inf;
    end
end

function rmse = seed_rmse(aligned, refPts)
    nA = size(aligned, 1);
    nR = size(refPts, 1);
    if nA == 0 || nR == 0
        rmse = inf;
        return;
    end
    idxA = round(linspace(1, nA, min(800, nA)));
    idxR = round(linspace(1, nR, min(800, nR)));
    d = pdist2(aligned(idxA, :), refPts(idxR, :));
    rmse = sqrt(mean(min(d, [], 2).^2));
end
