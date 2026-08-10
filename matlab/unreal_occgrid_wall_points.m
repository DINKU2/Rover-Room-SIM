function pts = unreal_occgrid_wall_points(varargin)
%UNREAL_OCCGRID_WALL_POINTS  Room boundary from rover_occupancy_grid.json (UE mesh).
%
%   Samples the walkable-floor footprint exported by setup_room_boundary_shell.py
%   — same geometry Unreal sim lidar raycasts against (not a bounding box).
%
%   Unreal Editor uses left-handed Y; SLAM maps use ROS right-handed Y.
%   Output is converted to ROS metres (y_ros = -y_ue) for manual alignment.
%   Sim dual-control lidar plots use raw UE Y — they look mirrored vs this ref.

    p = inputParser;
    addParameter(p, 'SampleStepM', 0.05, @isnumeric);
    addParameter(p, 'MaxPoints', 6000, @isnumeric);
    parse(p, varargin{:});
    opts = p.Results;

    jsonPath = default_occgrid_json_path();
    if ~isfile(jsonPath)
        error('unreal_occgrid_wall_points:Missing', ...
            'Run setup_room_boundary_shell in Unreal, or save sim lidar ref.\n  %s', jsonPath);
    end

    data = jsondecode(fileread(jsonPath));
    interior = build_interior_set(data.interior_cells);
    ptsCm = boundary_edge_samples(data, interior, opts.SampleStepM * 100);

    if isempty(ptsCm)
        error('unreal_occgrid_wall_points:Empty', 'No boundary samples from %s', jsonPath);
    end

    % UE exports left-handed cm; ROS alignment frame uses y_ros = -y_ue.
    pts = [ptsCm(:, 1), -ptsCm(:, 2)] / 100.0;

    if size(pts, 1) > opts.MaxPoints
        idx = randperm(size(pts, 1), opts.MaxPoints);
        pts = pts(idx, :);
    end
end

function jsonPath = default_occgrid_json_path()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    jsonPath = fullfile(projectRoot, 'roversim', 'RoverTwin', 'Content', 'Python', ...
        'rover_occupancy_grid.json');
end

function interior = build_interior_set(cells)
    interior = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    if isnumeric(cells) && size(cells, 2) == 2
        for k = 1:size(cells, 1)
            key = sprintf('%d,%d', cells(k, 1), cells(k, 2));
            interior(key) = true;
        end
        return;
    end
    for k = 1:numel(cells)
        item = cells(k);
        if numel(item) ~= 2
            continue;
        end
        key = sprintf('%d,%d', item(1), item(2));
        interior(key) = true;
    end
end

function tf = is_interior(interior, ix, iy)
    tf = isKey(interior, sprintf('%d,%d', ix, iy));
end

function pts = boundary_edge_samples(data, interior, stepCm)
    step = double(data.grid_step);
    xmin = double(data.xmin);
    ymin = double(data.ymin);
    nx = double(data.nx);
    ny = double(data.ny);

    pts = zeros(0, 2);
    keys = interior.keys;
    for k = 1:numel(keys)
        parts = sscanf(keys{k}, '%d,%d');
        ix = parts(1);
        iy = parts(2);

        x0 = xmin + ix * step;
        x1 = xmin + (ix + 1) * step;
        y0 = ymin + iy * step;
        y1 = ymin + (iy + 1) * step;

        if ~is_interior(interior, ix + 1, iy)
            pts = [pts; sample_segment(x1, y0, x1, y1, stepCm)]; %#ok<AGROW>
        end
        if ~is_interior(interior, ix - 1, iy)
            pts = [pts; sample_segment(x0, y0, x0, y1, stepCm)]; %#ok<AGROW>
        end
        if ~is_interior(interior, ix, iy + 1)
            pts = [pts; sample_segment(x0, y1, x1, y1, stepCm)]; %#ok<AGROW>
        end
        if ~is_interior(interior, ix, iy - 1)
            pts = [pts; sample_segment(x0, y0, x1, y0, stepCm)]; %#ok<AGROW>
        end
    end

    if ~isempty(pts)
        pts = unique(round(pts, 4), 'rows');
    end
end

function seg = sample_segment(xa, ya, xb, yb, stepCm)
    len = hypot(xb - xa, yb - ya);
    n = max(2, ceil(len / max(stepCm, 1)));
    t = linspace(0, 1, n)';
    seg = [xa + t * (xb - xa), ya + t * (yb - ya)];
end
