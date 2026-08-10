function mcl = mcl_set_pose(mcl, pose, lockCfg)
%MCL_SET_POSE  Teleport filter to a MAP-frame pose (manual correction / relocalize).

    if ~isempty(mcl) && isobject(mcl)
        release(mcl);
    end

    mcl = mcl_create_from_cfg(lockCfg, struct( ...
        'GlobalLocalization', false, ...
        'InitialPose', pose(:)', ...
        'InitialCovariance', diag([0.15, 0.15, deg2rad(12)].^2)));
end
