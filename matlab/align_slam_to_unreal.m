function align = align_slam_to_unreal(varargin)
%ALIGN_SLAM_TO_UNREAL  Register SLAM map walls to Unreal room (Method A: ICP).
%
%   align = align_slam_to_unreal()
%   align = align_slam_to_unreal('MapPath', '.../rover_room_....mat')
%   align = align_slam_to_unreal('ShowPlot', true)
%
%   Saves maps/unreal_alignment.mat with R2d, t2d, yaw_offset for
%   map_pose_to_unreal_ros().

    p = inputParser;
    addParameter(p, 'MapPath', '', @ischar);
    addParameter(p, 'ShowPlot', true, @islogical);
    addParameter(p, 'AngleStepDeg', 5, @isnumeric);
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, varargin{:});
    opts = p.Results;

    setup_rover_paths();

    mapData = load_slam_map(opts.MapPath);
    slamPts = slam_map_wall_points(mapData.map);

    fprintf('Aligning SLAM map (%s) to Unreal room reference...\n', mapData.path);
    fprintf('  SLAM wall samples: %d\n', size(slamPts, 1));

    sources = {'sim_lidar', 'occ_grid', 'png_edges'};
    bestRmse = inf;
    best = struct();

    for i = 1:numel(sources)
        src = sources{i};
        try
            [result, rmse, ref] = register_to_reference(slamPts, src, opts);
            fprintf('  %s: %d ref pts, RMSE %.3f m\n', src, size(ref.pts, 1), rmse);
            if rmse < bestRmse
                bestRmse = rmse;
                best.result = result;
                best.ref = ref;
                best.source = src;
            end
        catch ME
            fprintf('  %s: skip (%s)\n', src, ME.message);
        end
    end

    if ~isfinite(bestRmse) || isempty(fieldnames(best))
        error('align_slam_to_unreal:ICP', ...
            'No Unreal reference available. Run sim + save_unreal_lidar_reference, or ensure occ grid JSON exists.');
    end

    R2d = best.result.R2d;
    t2d = best.result.t2d;
    yawOffset = best.result.yaw_offset;
    refMode = best.source;
    ueMeta = best.ref.meta;
    unrealPts = best.ref.pts;
    fprintf('  Best reference: %s (RMSE %.3f m)\n', refMode, bestRmse);

    spawn = rover_spawn_pose();
    align = struct();
    align.R2d = R2d;
    align.t2d = t2d;
    align.yaw_offset = yawOffset;
    align.rmse_m = bestRmse;
    align.ref_mode = refMode;
    if isfield(ueMeta, 'json_path')
        align.unreal_ref_json = ueMeta.json_path;
    elseif isfield(ueMeta, 'path')
        align.unreal_ref_json = ueMeta.path;
    else
        align.unreal_ref_json = '';
    end
    align.slam_map_path = mapData.path;
    align.spawn_x = spawn.sim_m(1);
    align.spawn_y = spawn.sim_m(2);
    align.spawn_yaw = deg2rad(spawn.yaw_deg);
    align.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW,DATST>

    if strlength(string(opts.SavePath)) == 0
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        savePath = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    else
        savePath = char(opts.SavePath);
    end
    align.save_path = savePath;
    save(savePath, '-struct', 'align');

    fprintf('\n[OK] Alignment saved (RMSE %.3f m, yaw offset %.1f deg):\n', ...
        bestRmse, rad2deg(yawOffset));
    fprintf('  %s\n\n', savePath);
    fprintf('Use:  pose = map_pose_to_unreal_ros(x, y, yaw);\n');
    fprintf('      load(''%s'');\n\n', savePath);

    if opts.ShowPlot
        show_alignment_plot(slamPts, unrealPts, R2d, t2d, bestRmse, refMode);
    end
end

function [result, bestRmse, ref] = register_to_reference(slamPts, source, opts)
    [unrealPts, meta] = unreal_room_wall_points('Source', source);
    ref.pts = unrealPts;
    ref.meta = meta;

    fixed = pointCloud([unrealPts, zeros(size(unrealPts, 1), 1)]);
    moving = pointCloud([slamPts, zeros(size(slamPts, 1), 1)]);

    cSlam = mean(slamPts, 1);
    cUnreal = mean(unrealPts, 1);

    bestRmse = inf;
    bestTform = rigid3d(eye(3), [0 0 0]);
    angles = 0:opts.AngleStepDeg:359;

    for a = angles
        R3 = eul2rotm([0 0 deg2rad(a)], 'ZYX');
        t3 = [cUnreal, 0] - ([cSlam, 0] * R3);
        init = rigid3d(R3, t3);

        try
            [tform, ~, rmse] = pcregistericp(moving, fixed, ...
                'InitialTransform', init, ...
                'MaxIterations', 100, ...
                'Tolerance', [0.0005, 0.002], ...
                'InlierDistance', 0.35);
            [tform, ~, rmse] = pcregistericp(moving, fixed, ...
                'InitialTransform', tform, ...
                'MaxIterations', 100, ...
                'Tolerance', [0.0001, 0.001], ...
                'InlierDistance', 0.20);
        catch
            continue;
        end

        if rmse < bestRmse
            bestRmse = rmse;
            bestTform = tform;
        end
    end

    R = bestTform.Rotation;
    t = bestTform.Translation;
    result.R2d = R(1:2, 1:2);
    result.t2d = t(1:2);
    result.yaw_offset = atan2(R(2, 1), R(1, 1));
end

function show_alignment_plot(slamPts, unrealPts, R2d, t2d, rmse, refMode)
    slamAligned = apply_map_align2d(slamPts, R2d, t2d);

    figure('Name', 'SLAM ↔ Unreal alignment', 'NumberTitle', 'off');
    hold on; axis equal; grid on;
    plot(unrealPts(:, 1), unrealPts(:, 2), 'r.', 'MarkerSize', 8, 'DisplayName', 'Unreal ref');
    plot(slamPts(:, 1), slamPts(:, 2), 'b.', 'MarkerSize', 4, 'DisplayName', 'SLAM (raw)');
    plot(slamAligned(:, 1), slamAligned(:, 2), 'g.', 'MarkerSize', 4, 'DisplayName', 'SLAM aligned');
    legend('Location', 'best');
    xlabel('x [m]'); ylabel('y [m]');
    title(sprintf('Map registration (RMSE %.2f m, %s)', rmse, refMode));
end
