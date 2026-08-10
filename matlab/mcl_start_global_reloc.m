function [mcl, state] = mcl_start_global_reloc(mcl, lockCfg)
%MCL_START_GLOBAL_RELOC  Spread particles over the map to re-find pose.

    if ~isempty(mcl) && isobject(mcl)
        release(mcl);
    end

    mcl = mcl_create_from_cfg(lockCfg, struct('GlobalLocalization', true));
    state = mcl_default_state();
    fprintf('[mcl] Global relocalization — drive slowly until pose settles\n');
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
