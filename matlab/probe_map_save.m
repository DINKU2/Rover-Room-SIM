slam = lidarSLAM(20, 8);
ranges = 5 * ones(360, 1);
angles = linspace(-pi, pi, 360)';
ls = lidarScan(ranges, angles);
addScan(slam, ls);
addScan(slam, ls, [0.3 0 0.1]);

% Try various map extraction APIs
try
    m = occupancyMap(slam);
    fprintf('occupancyMap(slam) works, size %dx%d\n', m.GridSize(1), m.GridSize(2));
catch ME
    fprintf('occupancyMap(slam): %s\n', ME.message);
end

try
    m = buildMap(slam);
    fprintf('buildMap works\n');
catch ME
    fprintf('buildMap: %s\n', ME.message);
end

try
    m = exportOccupancyMap(slam);
    fprintf('exportOccupancyMap works\n');
catch ME
    fprintf('exportOccupancyMap: %s\n', ME.message);
end

pg = slam.PoseGraph;
fprintf('PoseGraph class: %s\n', class(pg));
