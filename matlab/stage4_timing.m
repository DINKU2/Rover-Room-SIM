function varargout = stage4_timing(action, tag, valueMs)
%STAGE4_TIMING  Aggregate Stage-4 timing (base workspace — Simulink-safe).
%
%   stage4_timing('reset')
%   stage4_timing('record', 'tag', ms)
%   stage4_timing('flush')          % write summary to log + Command Window
%   stats = stage4_timing('get')
%   stage4_timing('report')         % flush + return sorted table
%
%   Log: maps/stage4_timing.log
%   Disable: setenv('STAGE4_TIMING','0')

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
            timing_set(stats);
            try
                fid = fopen(timing_log_path(), 'w');
                if fid ~= -1
                    fprintf(fid, '=== Stage 4 timing reset %s ===\n', datestr(now));
                    fclose(fid);
                end
            catch
            end

        case 'record'
            if nargin < 3 || ~isfinite(valueMs)
                return;
            end
            if strcmp(getenv('STAGE4_TIMING'), '0')
                return;
            end
            stats = timing_get();
            if ~isfield(stats, 'buckets') || isempty(stats.buckets)
                stage4_timing('reset');
                stats = timing_get();
            end
            key = char(tag);
            if stats.buckets.isKey(key)
                b = stats.buckets(key);
            else
                b = struct('n', 0, 'sum', 0, 'min', inf, 'max', 0, 'last', 0);
            end
            b.n = b.n + 1;
            b.sum = b.sum + valueMs;
            b.min = min(b.min, valueMs);
            b.max = max(b.max, valueMs);
            b.last = valueMs;
            stats.buckets(key) = b;
            timing_set(stats);

            elapsed = toc(stats.tStart);
            if (elapsed - stats.lastFlush) >= flush_interval_sec()
                stage4_timing('flush');
            end

        case 'flush'
            stats = timing_get();
            if ~isfield(stats, 'buckets') || stats.buckets.Count == 0
                return;
            end
            tbl = timing_table(stats);
            stats.lastFlush = toc(stats.tStart);
            stats.lineCount = stats.lineCount + 1;
            timing_set(stats);

            hdr = sprintf('[Stage4 timing flush #%d  t=%.1fs]', ...
                stats.lineCount, stats.lastFlush);
            fprintf('\n%s\n', hdr);
            disp(tbl);

            try
                fid = fopen(timing_log_path(), 'a');
                if fid ~= -1
                    fprintf(fid, '\n%s\n', hdr);
                    for r = 1:height(tbl)
                        fprintf(fid, '  %-28s  n=%6d  avg=%7.2f  min=%7.2f  max=%7.2f  sum=%9.1f ms\n', ...
                            tbl.tag{r}, tbl.n(r), tbl.avg_ms(r), tbl.min_ms(r), ...
                            tbl.max_ms(r), tbl.sum_ms(r));
                    end
                    fclose(fid);
                end
            catch
            end

        case 'get'
            varargout{1} = timing_get();

        case 'report'
            stage4_timing('flush');
            varargout{1} = timing_table(timing_get());

        otherwise
            error('stage4_timing:BadAction', 'Unknown action: %s', action);
    end
end

function stats = timing_get()
    if evalin('base', 'exist(''stage4TimingStats'', ''var'')')
        stats = evalin('base', 'stage4TimingStats');
    else
        stats = struct('buckets', containers.Map('KeyType', 'char', 'ValueType', 'any'));
    end
end

function timing_set(stats)
    assignin('base', 'stage4TimingStats', stats);
end

function tbl = timing_table(stats)
    keys = stats.buckets.keys;
    n = numel(keys);
    tag = cell(n, 1);
    cnt = zeros(n, 1);
    avgMs = zeros(n, 1);
    minMs = zeros(n, 1);
    maxMs = zeros(n, 1);
    sumMs = zeros(n, 1);
    for k = 1:n
        b = stats.buckets(keys{k});
        tag{k} = keys{k};
        cnt(k) = b.n;
        avgMs(k) = b.sum / max(b.n, 1);
        minMs(k) = b.min;
        maxMs(k) = b.max;
        sumMs(k) = b.sum;
    end
    tbl = table(tag, cnt, avgMs, minMs, maxMs, sumMs, ...
        'VariableNames', {'tag', 'n', 'avg_ms', 'min_ms', 'max_ms', 'sum_ms'});
    tbl = sortrows(tbl, 'sum_ms', 'descend');
end

function sec = flush_interval_sec()
    sec = 3.0;
    raw = getenv('STAGE4_TIMING_FLUSH_SEC');
    if ~isempty(raw)
        v = str2double(raw);
        if isfinite(v) && v > 0
            sec = v;
        end
    end
end

function logPath = timing_log_path()
    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    logPath = fullfile(projectRoot, 'maps', 'stage4_timing.log');
end
