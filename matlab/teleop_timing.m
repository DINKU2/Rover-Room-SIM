function varargout = teleop_timing(action, varargin)
%TELEOP_TIMING  Key → /cmd_vel → odom latency logger (file-based, no spam).
%
%   teleop_timing('reset')
%   teleop_timing('key', 'press'|'release', keyName)
%   teleop_timing('stop', reason)              % focus lost, space, sim stop, ...
%   teleop_timing('publish', vx, wz, ms, src)  % src: key|timer|stop
%   teleop_timing('odom', odomVx, odomWz, cmdVx, cmdWz)
%   teleop_timing('fail', tag, message)
%   teleop_timing('flush')
%   teleop_timing('report')
%
%   Detailed events: maps/teleop_events.log
%   Summary stats:  maps/teleop_timing.log
%   Disable: setenv('TELEOP_TIMING','0')

    if nargin < 1 || isempty(action)
        action = 'get';
    end

    switch lower(action)
        case 'reset'
            stats = struct();
            stats.tStart = tic;
            stats.lastFlush = 0;
            stats.lineCount = 0;
            stats.buckets = containers.Map('KeyType', 'char', 'ValueType', 'any');
            stats.lastMotionSec = -Inf;
            stats.lastMotionKind = "";
            stats.lastMotionKey = "";
            stats.keysHeld = struct('w', false, 'a', false, 's', false, 'd', false, ...
                'uparrow', false, 'downarrow', false, 'leftarrow', false, 'rightarrow', false);
            stats.lastCmd = [0, 0];
            stats.lastOdom = [0, 0];
            stats.lastPublishSec = -Inf;
            teleop_set(stats);
            init_logs();

        case 'key'
            kind = char(varargin{1});
            key = char(varargin{2});
            stats = teleop_get();
            if isfield(stats.keysHeld, key)
                stats.keysHeld.(key) = strcmp(kind, 'press');
            end
            stats.lastMotionSec = session_sec(stats);
            stats.lastMotionKind = kind;
            stats.lastMotionKey = key;
            teleop_set(stats);
            cmd = current_cmd();
            held = keys_held_str(stats.keysHeld);
            log_event(stats, sprintf('key_%s', kind), ...
                sprintf('key=%s cmd=(%+.2f,%+.2f) held=[%s]', key, cmd(1), cmd(2), held));

        case 'stop'
            reason = "manual";
            if nargin >= 2
                reason = string(varargin{1});
            end
            stats = teleop_get();
            stats.lastMotionSec = session_sec(stats);
            stats.lastMotionKind = "stop";
            stats.lastMotionKey = "";
            stats.keysHeld = default_keys_held();
            teleop_set(stats);
            log_event(stats, 'stop', sprintf('reason=%s cmd=(+0.00,+0.00)', reason));
            record_bucket(stats, 'teleop.unexpected_stop', 1);

        case 'publish'
            vx = varargin{1};
            wz = varargin{2};
            ms = varargin{3};
            src = "timer";
            if nargin >= 5
                src = string(varargin{4});
            end
            stats = teleop_get();
            sinceKey = since_last_motion_ms(stats);
            stats.lastCmd = [vx, wz];
            stats.lastPublishSec = session_sec(stats);
            teleop_set(stats);
            log_event(stats, 'cmd_vel_sent', ...
                sprintf('src=%s cmd=(%+.2f,%+.2f) publish_ms=%.1f since_motion_ms=%.1f', ...
                src, vx, wz, ms, sinceKey));
            record_bucket(stats, 'teleop.publish_ms', ms);
            if sinceKey >= 0
                record_bucket(stats, 'teleop.motion_to_publish_ms', sinceKey);
            end

        case 'odom'
            odomVx = varargin{1};
            odomWz = varargin{2};
            cmdVx = varargin{3};
            cmdWz = varargin{4};
            stats = teleop_get();
            sincePub = since_last_publish_ms(stats);
            movingCmd = abs(cmdVx) > 0.02 || abs(cmdWz) > 0.02;
            movingOdom = abs(odomVx) > 0.02 || abs(odomWz) > 0.02;
            keysMoving = keys_currently_moving();
            jitter = keysMoving && movingCmd && ~movingOdom;
            stall = keysMoving && ~movingCmd;
            changed = ~isfield(stats, 'lastOdom') ...
                || abs(odomVx - stats.lastOdom(1)) > 0.02 ...
                || abs(odomWz - stats.lastOdom(2)) > 0.02 ...
                || abs(cmdVx - stats.lastCmd(1)) > 0.02 ...
                || abs(cmdWz - stats.lastCmd(2)) > 0.02;
            stats.lastOdom = [odomVx, odomWz];
            stats.lastCmd = [cmdVx, cmdWz];
            teleop_set(stats);
            if jitter
                log_event(stats, 'jitter_stop', ...
                    sprintf('odom=(%+.2f,%+.2f) cmd=(%+.2f,%+.2f) held=%d since_publish_ms=%.1f', ...
                    odomVx, odomWz, cmdVx, cmdWz, keysMoving, sincePub));
                record_bucket(stats, 'teleop.jitter_stop', 1);
            elseif stall
                log_event(stats, 'cmd_stall', ...
                    sprintf('odom=(%+.2f,%+.2f) cmd=(%+.2f,%+.2f) held=%d', ...
                    odomVx, odomWz, cmdVx, cmdWz, keysMoving));
                record_bucket(stats, 'teleop.cmd_stall', 1);
            elseif changed
                log_event(stats, 'odom_twist', ...
                    sprintf('odom=(%+.2f,%+.2f) cmd=(%+.2f,%+.2f) since_publish_ms=%.1f', ...
                    odomVx, odomWz, cmdVx, cmdWz, sincePub));
            end
            if movingCmd && sincePub >= 0
                record_bucket(stats, 'teleop.publish_to_odom_ms', sincePub);
            end

        case 'fail'
            tag = char(varargin{1});
            msg = char(varargin{2});
            stats = teleop_get();
            log_event(stats, 'fail', sprintf('tag=%s msg=%s', tag, msg));
            record_bucket(stats, ['teleop.fail.' tag], 1);

        case 'flush'
            stats = teleop_get();
            if ~isfield(stats, 'buckets') || stats.buckets.Count == 0
                return;
            end
            tbl = timing_table(stats);
            stats.lastFlush = session_sec(stats);
            stats.lineCount = stats.lineCount + 1;
            teleop_set(stats);
            hdr = sprintf('[Teleop timing flush #%d  t=%.1fs]', stats.lineCount, stats.lastFlush);
            try
                fid = fopen(summary_log_path(), 'a');
                if fid ~= -1
                    fprintf(fid, '\n%s\n', hdr);
                    for r = 1:height(tbl)
                        fprintf(fid, '  %-32s  n=%6d  avg=%7.2f  min=%7.2f  max=%7.2f  sum=%9.1f\n', ...
                            tbl.tag{r}, tbl.n(r), tbl.avg(r), tbl.min(r), tbl.max(r), tbl.sum(r));
                    end
                    fclose(fid);
                end
            catch
            end

        case 'report'
            teleop_timing('flush');
            if nargout >= 1
                varargout{1} = timing_table(teleop_get());
            end

        case 'get'
            varargout{1} = teleop_get();

        otherwise
            error('teleop_timing:BadAction', 'Unknown action: %s', action);
    end
end

function init_logs()
    if strcmp(getenv('TELEOP_TIMING'), '0')
        return;
    end
    try
        fid = fopen(events_log_path(), 'w');
        if fid ~= -1
            fprintf(fid, '=== Teleop events reset %s ===\n', datestr(now));
            fprintf(fid, '# columns: t_sec event details\n');
            fclose(fid);
        end
        fid = fopen(summary_log_path(), 'w');
        if fid ~= -1
            fprintf(fid, '=== Teleop timing reset %s ===\n', datestr(now));
            fclose(fid);
        end
    catch
    end
end

function log_event(stats, eventName, details)
    if strcmp(getenv('TELEOP_TIMING'), '0')
        return;
    end
    try
        fid = fopen(events_log_path(), 'a');
        if fid == -1
            return;
        end
        fprintf(fid, 't=%8.3f  %-14s  %s\n', session_sec(stats), eventName, details);
        fclose(fid);
    catch
    end
    elapsed = session_sec(stats);
    if (elapsed - stats.lastFlush) >= flush_interval_sec()
        teleop_timing('flush');
    end
end

function record_bucket(stats, tag, value)
    if strcmp(getenv('TELEOP_TIMING'), '0') || ~isfinite(value)
        return;
    end
    key = char(tag);
    if stats.buckets.isKey(key)
        b = stats.buckets(key);
    else
        b = struct('n', 0, 'sum', 0, 'min', inf, 'max', 0);
    end
    b.n = b.n + 1;
    b.sum = b.sum + value;
    b.min = min(b.min, value);
    b.max = max(b.max, value);
    stats.buckets(key) = b;
    teleop_set(stats);
end

function stats = teleop_get()
    if evalin('base', 'exist(''teleopTimingStats'', ''var'')')
        stats = evalin('base', 'teleopTimingStats');
    else
        stats = struct('buckets', containers.Map('KeyType', 'char', 'ValueType', 'any'));
    end
end

function teleop_set(stats)
    assignin('base', 'teleopTimingStats', stats);
end

function sec = session_sec(stats)
    if ~isfield(stats, 'tStart')
        sec = 0;
        return;
    end
    sec = toc(stats.tStart);
end

function ms = since_last_motion_ms(stats)
    if ~isfield(stats, 'lastMotionSec') || stats.lastMotionSec < 0
        ms = -1;
        return;
    end
    ms = (session_sec(stats) - stats.lastMotionSec) * 1000;
end

function ms = since_last_publish_ms(stats)
    if ~isfield(stats, 'lastPublishSec') || stats.lastPublishSec < 0
        ms = -1;
        return;
    end
    ms = (session_sec(stats) - stats.lastPublishSec) * 1000;
end

function cmd = current_cmd()
    if exist('simulink_teleop_utils', 'file') == 2
        cmd = simulink_teleop_utils('command');
    else
        cmd = [0, 0];
    end
end

function tf = keys_currently_moving()
    tf = false;
    if exist('simulink_teleop_utils', 'file') ~= 2
        return;
    end
    try
        state = simulink_teleop_utils('get');
        tf = state.moveX ~= 0 || state.moveTh ~= 0;
    catch
    end
end

function tbl = timing_table(stats)
    keys = stats.buckets.keys;
    n = numel(keys);
    tag = cell(n, 1);
    cnt = zeros(n, 1);
    avg = zeros(n, 1);
    minV = zeros(n, 1);
    maxV = zeros(n, 1);
    sumV = zeros(n, 1);
    for k = 1:n
        b = stats.buckets(keys{k});
        tag{k} = keys{k};
        cnt(k) = b.n;
        avg(k) = b.sum / max(b.n, 1);
        minV(k) = b.min;
        maxV(k) = b.max;
        sumV(k) = b.sum;
    end
    tbl = table(tag, cnt, avg, minV, maxV, sumV, ...
        'VariableNames', {'tag', 'n', 'avg', 'min', 'max', 'sum'});
    tbl = sortrows(tbl, 'sum', 'descend');
end

function s = keys_held_str(keysHeld)
    names = {'w', 'a', 's', 'd'};
    out = {};
    for i = 1:numel(names)
        if isfield(keysHeld, names{i}) && keysHeld.(names{i})
            out{end+1} = names{i}; %#ok<AGROW>
        end
    end
    if isempty(out)
        s = '-';
    else
        s = strjoin(out, ',');
    end
end

function keysHeld = default_keys_held()
    keysHeld = struct('w', false, 'a', false, 's', false, 'd', false, ...
        'uparrow', false, 'downarrow', false, 'leftarrow', false, 'rightarrow', false);
end

function sec = flush_interval_sec()
    sec = 3.0;
    raw = getenv('TELEOP_TIMING_FLUSH_SEC');
    if ~isempty(raw)
        v = str2double(raw);
        if isfinite(v) && v > 0
            sec = v;
        end
    end
end

function logPath = events_log_path()
    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    logPath = fullfile(projectRoot, 'maps', 'teleop_events.log');
end

function logPath = summary_log_path()
    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    logPath = fullfile(projectRoot, 'maps', 'teleop_timing.log');
end
