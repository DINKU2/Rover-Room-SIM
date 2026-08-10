function [pts, meta] = unreal_room_wall_points(varargin)
%UNREAL_ROOM_WALL_POINTS  Reference wall samples for SLAM alignment (Nx2, metres).
%
%   Priority:
%     1. maps/unreal_lidar_reference.mat  (sim lidar capture — best)
%     2. rover_occupancy_grid.json boundary (Unreal mesh footprint)
%     3. myroom_ue_topdown.png edges (fallback)

    p = inputParser;
    addParameter(p, 'Source', 'auto', @ischar);
    addParameter(p, 'MaxPoints', 6000, @isnumeric);
    parse(p, varargin{:});
    opts = p.Results;

    meta = struct();
    meta.source = opts.Source;

    switch lower(opts.Source)
        case 'auto'
            [pts, meta] = unreal_room_wall_points('Source', pick_auto_source(), ...
                'MaxPoints', opts.MaxPoints);
            return;
        case 'sim_lidar'
            [pts, meta] = load_sim_lidar_ref(opts.MaxPoints);
        case 'occ_grid'
            pts = unreal_occgrid_wall_points('MaxPoints', opts.MaxPoints);
            meta.json_path = occgrid_json_path();
        case 'png_edges'
            [pts, meta] = load_png_edges(opts.MaxPoints);
        otherwise
            error('unreal_room_wall_points:Source', 'Unknown source: %s', opts.Source);
    end

    meta.source = opts.Source;
end

function name = pick_auto_source()
    if isfile(sim_lidar_ref_path())
        name = 'sim_lidar';
    elseif isfile(occgrid_json_path())
        name = 'occ_grid';
    else
        name = 'png_edges';
    end
end

function [pts, meta] = load_sim_lidar_ref(maxPts)
    path = sim_lidar_ref_path();
    if ~isfile(path)
        error('unreal_room_wall_points:NoSimLidar', ...
            'Missing %s — run sim and save_unreal_lidar_reference', path);
    end
    S = load(path);
    pts = S.wall_pts;
    meta.path = path;
    meta.saved_at = "";
    if isfield(S, 'saved_at')
        meta.saved_at = string(S.saved_at);
    end
    if size(pts, 1) > maxPts
        idx = randperm(size(pts, 1), maxPts);
        pts = pts(idx, :);
    end
end

function [pts, meta] = load_png_edges(maxPts)
    meta = load_unreal_room_meta();
    pts = unreal_png_edge_points(meta, maxPts);
    if isempty(pts)
        error('unreal_room_wall_points:NoPng', 'No PNG edge points in %s', meta.png_path);
    end
end

function path = sim_lidar_ref_path()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'maps', 'unreal_lidar_reference.mat');
end

function path = occgrid_json_path()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'roversim', 'RoverTwin', 'Content', 'Python', ...
        'rover_occupancy_grid.json');
end

function meta = load_unreal_room_meta()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    jsonPath = fullfile(projectRoot, 'maps', 'myroom_ue_topdown.json');
    raw = jsondecode(fileread(jsonPath));
    meta.ros_x_m = raw.ros_x_m(:)';
    meta.ros_y_m = raw.ros_y_m(:)';
    meta.image_size_px = raw.image_size_px(:)';
    meta.png_path = fullfile(projectRoot, 'maps', 'myroom_ue_topdown.png');
    meta.json_path = jsonPath;
end

function pts = unreal_png_edge_points(meta, maxPts)
    pts = zeros(0, 2);
    if ~isfile(meta.png_path)
        return;
    end
    img = imread(meta.png_path);
    if size(img, 3) > 1
        gray = rgb2gray(img);
    else
        gray = img;
    end
    edges = edge(gray, 'Canny', [0.05 0.15]);
    [v, u] = find(edges);
    if numel(u) > maxPts
        idx = randperm(numel(u), maxPts);
        u = u(idx);
        v = v(idx);
    end
    W = meta.image_size_px(1);
    H = meta.image_size_px(2);
    x1 = min(meta.ros_x_m);
    x2 = max(meta.ros_x_m);
    y1 = max(meta.ros_y_m);
    y2 = min(meta.ros_y_m);
    xs = x1 + (u - 1) / max(W - 1, 1) * (x2 - x1);
    ys = y1 + (v - 1) / max(H - 1, 1) * (y2 - y1);
    pts = [xs, ys];
end
