function reg = verify_register_point_maps(movingPts, fixedPts, angleStepDeg)
%VERIFY_REGISTER_POINT_MAPS  Rigid 2D ICP: moving frame -> fixed frame.
%
%   reg = verify_register_point_maps(liveWallPts, savedWallPts)
%   pFixed = reg.R2d * pMoving + reg.t2d

    if nargin < 3 || isempty(angleStepDeg)
        angleStepDeg = 10;
    end

    reg = struct('R2d', eye(2), 't2d', [0; 0], 'yaw_offset', 0, 'rmse_m', inf, 'ready', false);

    if size(movingPts, 1) < 20 || size(fixedPts, 1) < 20
        return;
    end

    if isempty(which('pcregistericp'))
        reg = verify_register_point_maps_centroid(movingPts, fixedPts, angleStepDeg);
        return;
    end

    fixed = pointCloud([fixedPts, zeros(size(fixedPts, 1), 1)]);
    moving = pointCloud([movingPts, zeros(size(movingPts, 1), 1)]);

    cMove = mean(movingPts, 1);
    cFix = mean(fixedPts, 1);

    bestRmse = inf;
    bestTform = rigid3d(eye(3), [0 0 0]);
    angles = 0:angleStepDeg:359;

    for a = angles
        R3 = eul2rotm([0 0 deg2rad(a)], 'ZYX');
        t3 = [cFix, 0] - ([cMove, 0] * R3);
        init = rigid3d(R3, t3);

        try
            [tform, ~, rmse] = pcregistericp(moving, fixed, ...
                'InitialTransform', init, ...
                'MaxIterations', 80, ...
                'Tolerance', [0.0005, 0.002], ...
                'InlierDistance', 0.35);
            [tform, ~, rmse] = pcregistericp(moving, fixed, ...
                'InitialTransform', tform, ...
                'MaxIterations', 80, ...
                'Tolerance', [0.0001, 0.001], ...
                'InlierDistance', 0.25);
        catch
            continue;
        end

        if rmse < bestRmse
            bestRmse = rmse;
            bestTform = tform;
        end
    end

    if ~isfinite(bestRmse)
        reg = verify_register_point_maps_centroid(movingPts, fixedPts, angleStepDeg);
        return;
    end

    R = bestTform.Rotation;
    reg.R2d = R(1:2, 1:2);
    reg.t2d = bestTform.Translation(1:2)';
    reg.yaw_offset = atan2(R(2, 1), R(1, 1));
    reg.rmse_m = bestRmse;
    reg.ready = true;
end

function reg = verify_register_point_maps_centroid(movingPts, fixedPts, angleStepDeg)
    reg = struct('R2d', eye(2), 't2d', [0; 0], 'yaw_offset', 0, 'rmse_m', inf, 'ready', false);
    cMove = mean(movingPts, 1);
    cFix = mean(fixedPts, 1);
    bestRmse = inf;
    bestR = eye(2);
    angles = 0:angleStepDeg:359;

    for a = angles
        th = deg2rad(a);
        R = [cos(th), -sin(th); sin(th), cos(th)];
        aligned = apply_map_align2d(movingPts, R, [0; 0]);
        t = (cFix - mean(aligned, 1))';
        aligned = apply_map_align2d(movingPts, R, t);
        d = pdist2(aligned, fixedPts);
        rmse = sqrt(mean(min(d, [], 2).^2));
        if rmse < bestRmse
            bestRmse = rmse;
            bestR = R;
            reg.t2d = t;
        end
    end

    reg.R2d = bestR;
    reg.yaw_offset = atan2(bestR(2, 1), bestR(1, 1));
    reg.rmse_m = bestRmse;
    reg.ready = isfinite(bestRmse);
end
