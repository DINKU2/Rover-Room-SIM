function simulink_stage4_debug(tag, data)
%SIMULINK_STAGE4_DEBUG  Throttled Stage 4 pose log (Command Window + file).
%
%   simulink_stage4_debug('slam', struct('odom_x', 0, 'map_x', 0, ...))
%
%   Log file: Rover-Room-SIM/maps/stage4_pose_debug.log
%   Enable/disable: setenv('STAGE4_DEBUG','0') to silence.

    persistent lastPrint tStart lineCount

    if isempty(tStart)
        tStart = tic;
        lastPrint = -inf;
        lineCount = 0;
    end

    if strcmp(getenv('STAGE4_DEBUG'), '0')
        return;
    end

    now = toc(tStart);
    if (now - lastPrint) < 0.5
        return;
    end
    lastPrint = now;
    lineCount = lineCount + 1;

    msg = format_debug_line(tag, now, data);
    fprintf('%s\n', msg);

    try
        logPath = debug_log_path();
        fid = fopen(logPath, 'a');
        if fid ~= -1
            fprintf(fid, '%s\n', msg);
            fclose(fid);
        end
    catch
    end

    if lineCount == 1
        fprintf('[Stage4 debug] logging to %s  (setenv STAGE4_DEBUG 0 to mute)\n', ...
            debug_log_path());
    end
end

function msg = format_debug_line(tag, tSec, data)
    parts = {sprintf('[Stage4 %s t=%.1fs]', tag, tSec)};
    fields = fieldnames(data);
    for k = 1:numel(fields)
        key = fields{k};
        val = data.(key);
        if islogical(val)
            val = double(val);
        end
        if isnumeric(val) && isscalar(val)
            parts{end + 1} = sprintf('%s=%.4f', key, val); %#ok<AGROW>
        elseif isnumeric(val) && numel(val) == 3
            parts{end + 1} = sprintf('%s=[%.3f %.3f %.3f]', key, val(1), val(2), val(3)); %#ok<AGROW>
        else
            parts{end + 1} = sprintf('%s=%s', key, string(val)); %#ok<AGROW>
        end
    end
    msg = strjoin(parts, '  ');
end

function logPath = debug_log_path()
    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    logPath = fullfile(projectRoot, 'maps', 'stage4_pose_debug.log');
end
