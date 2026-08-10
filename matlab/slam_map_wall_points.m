function pts = slam_map_wall_points(map, varargin)
%SLAM_MAP_WALL_POINTS  Occupied cell centres from occupancyMap (Nx2).

    p = inputParser;
    addParameter(p, 'OccupiedThreshold', 0.65, @isnumeric);
    addParameter(p, 'MaxPoints', 4000, @isnumeric);
    parse(p, varargin{:});
    opts = p.Results;

    prob = occupancyMatrix(map);
    [rows, cols] = find(prob >= opts.OccupiedThreshold);
    if isempty(rows)
        error('slam_map_wall_points:Empty', 'No occupied cells in SLAM map.');
    end

    pts = map_grid_indices_to_world(map, rows, cols);

    if size(pts, 1) > opts.MaxPoints
        idx = randperm(size(pts, 1), opts.MaxPoints);
        pts = pts(idx, :);
    end
end
