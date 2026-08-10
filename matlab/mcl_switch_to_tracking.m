function mcl = mcl_switch_to_tracking(mcl, pose, lockCfg)
%MCL_SWITCH_TO_TRACKING  Rebuild MCL with GlobalLocalization off (post lock-in).

    parts = getParticles(mcl);
    release(mcl);

    mcl = mcl_create_from_cfg(lockCfg, struct( ...
        'GlobalLocalization', false, ...
        'InitialPose', pose(:)'));
    setParticles(mcl, parts);
end
