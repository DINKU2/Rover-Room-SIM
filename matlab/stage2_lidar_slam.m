function stage2_lidar_slam(varargin)
%STAGE2_LIDAR_SLAM  MATLAB-native SLAM: print map-frame pose while driving.
%
%   stage2_lidar_slam()
%   stage2_lidar_slam('PlotMap', false)
%
%   Opens a **Save map** popup — click it and press 5 or use the Save button.
%   Map files go to Rover-Room-SIM/maps/ (.mat + .yaml + .pgm).
%   Auto-saves on exit (Ctrl+C) when scans exist.
%
%   Drive from another terminal:
%     source ./setup.bash && ./scripts/run_teleop.sh
%
%   Name-value options:
%     PlotMap         - live map figure (default true)
%     PlotEvery       - refresh map every N scans (default 20)
%     MaxDuration     - stop after N seconds (default Inf)
%     AutoSaveOnExit  - save when SLAM stops (default true)

    opts = parseOpts(varargin);
    checkLidarSlamAvailable();

    fprintf('\n=== Stage 2: MATLAB lidarSLAM ===\n');
    fprintf('Map resolution 0.05 m/cell (20 cells/m), max range 8 m.\n');
    fprintf(['Drive: source ./setup.bash && ./scripts/run_teleop.sh\n' ...
        'Save: use the "Stage 2 — Save map" popup (key 5 or Save button).\n' ...
        'Stop: Ctrl+C in Command Window (auto-saves if enabled).\n\n']);

    ctx = ros_connect('stage2_slam');

    slam = lidarSLAM(20, 8);
    saveFig = stage2_save_window(slam);

    ax = [];
    if opts.PlotMap
        [~, ax] = stage2_map_figure();
    end

    prevOdomPose = [];
    lastScanKey = NaN;
    scanCount = 0;
    tStart = tic;

    try
        while toc(tStart) < opts.MaxDuration
            if ~isgraphics(saveFig)
                fprintf('[Stage 2] Save window closed — stopping.\n');
                break;
            end

            scan = ros_sub_read(ctx.scanSub, 0.5, 'fresh');
            if isempty(scan)
                drawnow limitrate;
                continue;
            end

            scanKey = scanStampKey(scan);
            if scanKey == lastScanKey
                drawnow limitrate;
                continue;
            end
            lastScanKey = scanKey;

            odom = ros_sub_read(ctx.odomSub, 0.2);
            if isempty(odom)
                drawnow limitrate;
                continue;
            end

            try
                ls = scan_msg_to_lidarscan(scan);
            catch ME
                fprintf('[WARN] skip scan: %s\n', ME.message);
                continue;
            end

            odomPose = odom_to_xyth(odom);

            if isempty(prevOdomPose)
                isAccepted = addScan(slam, ls);
            else
                relPose = odom_relative_xyth(prevOdomPose, odomPose);
                isAccepted = addScan(slam, ls, relPose);
            end
            prevOdomPose = odomPose;

            if ~isAccepted
                drawnow limitrate;
                continue;
            end

            scanCount = scanCount + 1;
            mapPose = currentMapPose(slam);

            fprintf(['[%4d] MAP  x=%+.3f  y=%+.3f  yaw=%+.1f deg  |  ' ...
                'ODOM  x=%+.3f  y=%+.3f  yaw=%+.1f deg\n'], ...
                scanCount, mapPose(1), mapPose(2), rad2deg(mapPose(3)), ...
                odomPose(1), odomPose(2), rad2deg(odomPose(3)));

            stage2_save_window_update(saveFig, scanCount, mapPose);

            if opts.PlotMap && ~isempty(ax) && isgraphics(ax) && ...
                    mod(scanCount, opts.PlotEvery) == 0
                cla(ax);
                show(slam, 'Parent', ax);
                title(ax, sprintf('Stage 2 map (%d scans)', scanCount));
                drawnow limitrate;
            end

            drawnow limitrate;
        end
    catch ME
        if ~strcmp(ME.identifier, 'MATLAB:handle_break')
            rethrow(ME);
        end
    end

    fprintf('\nStage 2 stopped after %d accepted scans.\n', scanCount);
    if scanCount > 0
        mapPose = currentMapPose(slam);
        fprintf('Final MAP pose: x=%.3f  y=%.3f  yaw=%.1f deg\n', ...
            mapPose(1), mapPose(2), rad2deg(mapPose(3)));
    end

    if opts.AutoSaveOnExit && scanCount > 0 && isgraphics(saveFig)
        ud = saveFig.UserData;
        if ~ud.saving
            fprintf('\n[Stage 2] Auto-saving map on exit...\n');
            stage2_save_from_window(saveFig);
        end
    end
end

function opts = parseOpts(args)
    opts = struct('PlotMap', true, 'PlotEvery', 20, 'MaxDuration', inf, ...
        'AutoSaveOnExit', true);
    if isempty(args)
        return;
    end
    for k = 1:2:numel(args)
        name = args{k};
        if k + 1 > numel(args)
            break;
        end
        switch lower(string(name))
            case "plotmap"
                opts.PlotMap = logical(args{k + 1});
            case "plotevery"
                opts.PlotEvery = max(1, round(args{k + 1}));
            case "maxduration"
                opts.MaxDuration = args{k + 1};
            case "autosaveonexit"
                opts.AutoSaveOnExit = logical(args{k + 1});
            otherwise
                error('stage2:Option', 'Unknown option: %s', char(name));
        end
    end
end

function checkLidarSlamAvailable()
    if isempty(which('lidarSLAM'))
        error('stage2:NoToolbox', ...
            ['Navigation Toolbox lidarSLAM not found.\n' ...
             'Check: which lidarSLAM']);
    end
end

function key = scanStampKey(scan)
    key = double(scan.header.stamp.sec) + double(scan.header.stamp.nanosec) * 1e-9;
end

function pose = currentMapPose(slam)
    [~, poses] = scansAndPoses(slam);
    if isempty(poses)
        pose = [0, 0, 0];
    else
        pose = poses(end, :);
    end
end
