function run_teleop_timing_report()
%RUN_TELEOP_TIMING_REPORT  Print teleop latency summary from log files.
%
%   After a drive session:
%     teleop_timing('report')
%   or:
%     run_teleop_timing_report()

    setup_rover_paths();
    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    summaryPath = fullfile(projectRoot, 'maps', 'teleop_timing.log');
    eventsPath = fullfile(projectRoot, 'maps', 'teleop_events.log');

    fprintf('\n=== Teleop timing report ===\n');
    if exist('teleop_timing', 'file') == 2
        tbl = teleop_timing('report');
        if ~isempty(tbl)
            disp(tbl);
        end
    end

    if ~isfile(eventsPath)
        fprintf('No event log: %s\n', eventsPath);
        return;
    end

    txt = fileread(eventsPath);
    lines = splitlines(string(txt));
    keys = lines(contains(lines, 'key_press') | contains(lines, 'key_release'));
    stops = lines(contains(lines, ' stop ') | contains(lines, 'jitter_stop') | contains(lines, 'cmd_stall') | contains(lines, ' fail '));
    publishes = lines(contains(lines, 'cmd_vel_sent'));

    fprintf('\nEvent counts:\n');
    fprintf('  key events:     %d\n', numel(keys));
    fprintf('  cmd_vel sends:  %d\n', numel(publishes));
    fprintf('  stop/jitter:    %d\n', numel(stops));

    if ~isempty(stops)
        fprintf('\nRecent stop/jitter/fail events:\n');
        tail = stops(max(1, numel(stops)-14):end);
        for i = 1:numel(tail)
            fprintf('  %s\n', tail(i));
        end
    end

    fprintf('\nLogs:\n  %s\n  %s\n', eventsPath, summaryPath);
end
