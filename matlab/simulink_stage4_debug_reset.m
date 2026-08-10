function simulink_stage4_debug_reset()
%SIMULINK_STAGE4_DEBUG_RESET  Truncate log at sim start.

    try
        logPath = stage4_debug_log_path();
        fid = fopen(logPath, 'w');
        if fid ~= -1
            fprintf(fid, '=== Stage 4 pose debug reset %s ===\n', datestr(now));
            fclose(fid);
        end
    catch
    end
    clear simulink_stage4_debug simulink_unreal_pose_gate simulink_mcl_map_pose dual_mcl_ros_update;
end

function logPath = stage4_debug_log_path()
    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    logPath = fullfile(projectRoot, 'maps', 'stage4_pose_debug.log');
end
