function state = mcl_default_state()
%MCL_DEFAULT_STATE  Empty MCL session state struct.

    state = struct( ...
        'globalLocScans', 0, 'locked', false, 'hasPose', false, ...
        'lastPose', [0, 0, 0], 'poseBuf', zeros(0, 3), 'odomTravel', 0);
end
