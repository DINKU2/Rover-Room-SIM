function [mapPose, isUpdated, state, mcl] = mcl_update_pose(mcl, relOdom, lidarScan, state, lockCfg)
%MCL_UPDATE_POSE  One predict+correct MCL step; pose in saved-map frame.
%
%   relOdom is [dx, dy, dtheta] in the previous odometry frame (same as lidarSLAM).
%   lockCfg (optional) holds SensorModel/MotionModel for mcl_switch_to_tracking.

    if nargin < 4 || isempty(state)
        state = mcl_default_state();
    end
    if nargin < 5
        lockCfg = [];
    end

    state.odomTravel = state.odomTravel + norm(relOdom(1:2));

    [isUpdated, mapPose, ~] = mcl(relOdom, lidarScan);
    if isUpdated
        state.hasPose = true;
        state.lastPose = mapPose;
        state.poseBuf(end + 1, :) = mapPose; %#ok<AGROW>
        if size(state.poseBuf, 1) > 8
            state.poseBuf = state.poseBuf(end - 7:end, :);
        end
    elseif state.hasPose
        mapPose = state.lastPose;
    end

    if ~state.locked && mcl.GlobalLocalization && isUpdated && ~isempty(lockCfg)
        state.globalLocScans = state.globalLocScans + 1;
        stable = mcl_pose_stable(state.poseBuf, 5, 0.6, deg2rad(25));
        movedEnough = state.odomTravel >= 0.35;
        if movedEnough && state.globalLocScans >= 5 && stable
            mcl = mcl_switch_to_tracking(mcl, mapPose, lockCfg);
            state.locked = true;
            fprintf('[mcl] Locked onto saved map (global localization off)\n');
        end
    end
end

function state = mcl_default_state()
    state = struct( ...
        'globalLocScans', 0, ...
        'locked', false, ...
        'hasPose', false, ...
        'lastPose', [0, 0, 0], ...
        'poseBuf', zeros(0, 3), ...
        'odomTravel', 0);
end

function ok = mcl_pose_stable(buf, minCount, posTol, yawTol)
    ok = false;
    if size(buf, 1) < minCount
        return;
    end
    recent = buf(end - minCount + 1:end, :);
    posSpread = max(vecnorm(recent(:, 1:2) - recent(1, 1:2), 2, 2));
    yawSpread = max(abs(wrap_to_pi(recent(:, 3) - recent(1, 3))));
    ok = posSpread <= posTol && yawSpread <= yawTol;
end

function a = wrap_to_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end
