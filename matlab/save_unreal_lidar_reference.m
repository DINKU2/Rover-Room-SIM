function path = save_unreal_lidar_reference(varargin)
%SAVE_UNREAL_LIDAR_REFERENCE  Save sim lidar wall points for map alignment.
%
%   Prereq: run RoverTwinControl (or dual with lidar), drive around room so
%   roverLidarLivePlot accumulates points in base workspace:
%     roverLidarLastWorldPoints
%
%   path = save_unreal_lidar_reference()
%   path = save_unreal_lidar_reference('Append', true)   % merge with existing

    p = inputParser;
    addParameter(p, 'Append', false, @islogical);
    addParameter(p, 'MinPoints', 200, @isnumeric);
    parse(p, varargin{:});
    opts = p.Results;

    if ~evalin('base', 'exist(''roverLidarLastWorldPoints'',''var'')')
        error('save_unreal_lidar_reference:NoData', ...
            ['No sim lidar in workspace. Run RoverTwinControl, drive the room, ' ...
             'then call this again.\n  open_rover_control  or  rover_dual_control']);
    end

    pts = evalin('base', 'roverLidarLastWorldPoints');
    if size(pts, 2) >= 2
        pts = pts(:, 1:2);
    end
    pts = pts(all(isfinite(pts), 2), :);

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'maps', 'unreal_lidar_reference.mat');

    if opts.Append && isfile(path)
        old = load(path);
        if isfield(old, 'wall_pts')
            pts = unique([old.wall_pts; pts], 'rows');
        end
    end

    if size(pts, 1) < opts.MinPoints
        error('save_unreal_lidar_reference:TooFew', ...
            'Only %d points — drive further in sim (need >= %d).', ...
            size(pts, 1), opts.MinPoints);
    end

    wall_pts = pts;
    saved_at = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW,DATST>
    source = 'roverLidarLastWorldPoints';
    save(path, 'wall_pts', 'saved_at', 'source');

    fprintf('[OK] Saved %d sim lidar reference points:\n  %s\n', size(wall_pts, 1), path);
end
