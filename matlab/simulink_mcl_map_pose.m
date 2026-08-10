function y = simulink_mcl_map_pose(~)
%SIMULINK_MCL_MAP_POSE  Read shared MCL pose for Unreal twin (Stage 4).

    persistent warned lastWall
    t0 = tic;
    if ~isempty(lastWall)
        stage4_timing('record', 'slx.step_period', toc(lastWall) * 1000);
    end
    lastWall = tic;

    ud = mcl_dual_shared('get');
    if isempty(ud) || ~isfield(ud, 'mclReady') || ~ud.mclReady
        if isempty(warned)
            fprintf('[Stage4] Waiting for dual MCL overlay to lock on map...\n');
            warned = true;
        end
        y = zeros(4, 1);
        stage4_timing('record', 'slx.mcl_map_pose', toc(t0) * 1000);
        return;
    end

    warned = [];
    valid = isfield(ud, 'valid') && ud.valid;
    y = zeros(4, 1);
    if valid && all(isfinite(ud.mapPose(1:3)))
        y(1) = ud.mapPose(1);
        y(2) = ud.mapPose(2);
        y(3) = mcl_heading_display_yaw(ud.mapPose(3));
        y(4) = 1;
    end
    stage4_timing('record', 'slx.mcl_map_pose', toc(t0) * 1000);
end
