function mapData = load_slam_map(mapPath)
%LOAD_SLAM_MAP  Load occupancyMap from Stage 2 .mat or ROS .yaml/.pgm.

    if nargin < 1 || strlength(string(mapPath)) == 0
        mapPath = latest_slam_map_path();
    end
    mapPath = char(mapPath);

    if endsWith(mapPath, '.mat')
        S = load(mapPath);
        if isfield(S, 'map')
            mapData.map = S.map;
        else
            error('load_slam_map:NoMap', 'No ''map'' variable in %s', mapPath);
        end
        mapData.path = mapPath;
        mapData.source = 'mat';
        return;
    end

    if endsWith(mapPath, '.yaml') || endsWith(mapPath, '.yml')
        mapData = load_ros_yaml_map(mapPath);
        return;
    end

    error('load_slam_map:Format', 'Expected .mat or .yaml path: %s', mapPath);
end

function mapPath = latest_slam_map_path()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    mapDir = fullfile(projectRoot, 'maps');
    d = dir(fullfile(mapDir, 'rover_room_*.mat'));
    if isempty(d)
        error('load_slam_map:NotFound', 'No rover_room_*.mat under %s', mapDir);
    end
    [~, idx] = max([d.datenum]);
    mapPath = fullfile(d(idx).folder, d(idx).name);
end

function mapData = load_ros_yaml_map(yamlPath)
    txt = fileread(yamlPath);
    res = parse_yaml_scalar(txt, 'resolution');
    origin = parse_yaml_origin(txt);
    imageName = parse_yaml_scalar(txt, 'image');
    pgmPath = fullfile(fileparts(yamlPath), imageName);

    if ~isfile(pgmPath)
        error('load_slam_map:NoPgm', 'PGM not found: %s', pgmPath);
    end

    img = imread(pgmPath);
    if size(img, 3) > 1
        img = rgb2gray(img);
    end
    img = flipud(img);
    prob = zeros(size(img));
    prob(img <= 25) = 1.0;
    prob(img >= 65) = 0.0;
    prob(img > 25 & img < 65) = 0.5;

    resCells = 1 / res;
    map = occupancyMap(prob, resCells);
    map.XWorldLimits = [origin(1), origin(1) + size(prob, 2) / resCells];
    map.YWorldLimits = [origin(2), origin(2) + size(prob, 1) / resCells];

    mapData.map = map;
    mapData.path = yamlPath;
    mapData.source = 'yaml';
end

function val = parse_yaml_scalar(txt, key)
    tok = regexp(txt, [key '\s*:\s*([\d\.eE\+\-]+)'], 'tokens', 'once');
    if isempty(tok)
        error('load_slam_map:Yaml', 'Missing %s in yaml', key);
    end
    val = str2double(tok{1});
end

function origin = parse_yaml_origin(txt)
    tok = regexp(txt, 'origin:\s*\[([\d\.\eE\+\-]+),\s*([\d\.\eE\+\-]+)', 'tokens', 'once');
    if isempty(tok)
        error('load_slam_map:Yaml', 'Missing origin in yaml');
    end
    origin = [str2double(tok{1}), str2double(tok{2})];
end
