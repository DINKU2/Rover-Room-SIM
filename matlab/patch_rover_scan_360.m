function patch_rover_scan_360()
%PATCH_ROVER_SCAN_360  Align Simulink with 360-point reliable /scan firmware.

    matlabDir = fileparts(mfilename('fullpath'));
    addpath(matlabDir);
    projectRoot = fileparts(matlabDir);
    modelName = 'rover_ros_io';
    slxPath = fullfile(projectRoot, 'simulink', [modelName '.slx']);

    if ~isfile(slxPath)
        error('patch_rover_scan_360:NoModel', 'Missing %s', slxPath);
    end

    if bdIsLoaded(modelName)
        close_system(modelName, 0);
    end
    load_system(slxPath);

    scanSub = [modelName '/Subscribe_Scan'];
    set_param(scanSub, 'QOSReliability', 'Reliable');
    try
        ros.slros2.internal.block.SubscribeBlockMask.dispatch('messageTypeEdit', scanSub);
    catch
        warning('patch_rover_scan_360:BusRefresh', ...
            'Double-click Subscribe_Scan and OK to refresh LaserScan bus for 360 ranges.');
    end

    scanToMap = [modelName '/ScanToMap'];
    if blockExists(scanToMap)
        script = sprintf([ ...
            'function [scanX, scanY] = ScanToMap(x, y, yaw, ranges, angle_min, angle_increment, range_min, range_max)\n' ...
            '    N = 360;\n' ...
            '    scanX = nan(N, 1);\n' ...
            '    scanY = nan(N, 1);\n' ...
            '    c = cos(yaw);\n' ...
            '    s = sin(yaw);\n' ...
            '    for i = 1:N\n' ...
            '        if i > numel(ranges)\n' ...
            '            continue;\n' ...
            '        end\n' ...
            '        ri = ranges(i);\n' ...
            '        if ~isfinite(ri) || ri <= 0 || ri < range_min || ri > range_max\n' ...
            '            continue;\n' ...
            '        end\n' ...
            '        ang = angle_min + (i - 1) * angle_increment;\n' ...
            '        lx = ri * cos(ang);\n' ...
            '        ly = ri * sin(ang);\n' ...
            '        scanX(i) = x + c*lx - s*ly;\n' ...
            '        scanY(i) = y + s*lx + c*ly;\n' ...
            '    end\n' ...
            'end\n']);
        setMATLABFunctionScript(scanToMap, script);
    end

    set_param(modelName, 'SimulationCommand', 'update');
    save_system(modelName, slxPath);
    fprintf('Patched %s for 360-point reliable /scan.\n', slxPath);
    fprintf('If ranges bus is still 128-wide, double-click Subscribe_Scan -> OK.\n');
    bdclose(modelName);
end

function ok = blockExists(path)
    try
        get_param(path, 'Handle');
        ok = true;
    catch
        ok = false;
    end
end

function setMATLABFunctionScript(blockPath, script)
    rt = sfroot;
    charts = rt.find('-isa', 'Stateflow.EMChart');
    for k = 1:numel(charts)
        if strcmp(charts(k).Path, blockPath)
            charts(k).Script = script;
            return;
        end
    end
    warning('patch_rover_scan_360:NoChart', ...
        'ScanToMap chart not found; paste simulink_scan_to_map logic manually.');
end
