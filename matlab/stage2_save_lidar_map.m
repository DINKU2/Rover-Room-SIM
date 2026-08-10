function paths = stage2_save_lidar_map(slam)
%STAGE2_SAVE_LIDAR_MAP  Save lidarSLAM map (.mat + ROS .yaml/.pgm).
%
%   paths = stage2_save_lidar_map(slam)
%
%   Writes under Rover-Room-SIM/maps/rover_room_YYYYMMDD_HHMMSS.*

    if isempty(which('buildMap'))
        error('stage2:NoToolbox', 'Navigation Toolbox buildMap not found.');
    end

    [scans, poses] = scansAndPoses(slam);
    if isempty(scans)
        error('stage2:NoMap', 'No scans yet — drive around before saving.');
    end

    mapRes = slam.MapResolution;
    maxRange = slam.MaxLidarRange;
    nScans = numel(scans);
    fprintf('Building occupancy map from %d scans (may take 1–3 min)...\n', nScans);
    map = buildMap(scans, poses, mapRes, maxRange);
    mapPose = poses(end, :);

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    mapDir = fullfile(projectRoot, 'maps');
    if ~isfolder(mapDir)
        mkdir(mapDir);
    end

    stamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW,DATST>
    baseName = ['rover_room_' stamp];
    matPath = fullfile(mapDir, [baseName '.mat']);
    yamlPath = fullfile(mapDir, [baseName '.yaml']);
    pgmPath = fullfile(mapDir, [baseName '.pgm']);

    save(matPath, 'map', 'poses', 'mapPose', 'scans', 'mapRes', 'maxRange');

    writeRosMapYaml(yamlPath, pgmPath, map);
    writeRosMapPgm(pgmPath, map);

    paths = struct('mat', matPath, 'yaml', yamlPath, 'pgm', pgmPath);

    fprintf('\n[SAVED] map (%d scans, pose [%.3f %.3f %.1f deg]):\n', ...
        numel(scans), mapPose(1), mapPose(2), rad2deg(mapPose(3)));
    fprintf('  %s\n  %s\n  %s\n\n', matPath, yamlPath, pgmPath);
end

function writeRosMapYaml(yamlPath, pgmPath, map)
    resolution = 1 / map.Resolution;
    originX = map.XWorldLimits(1);
    originY = map.YWorldLimits(1);
    [~, pgmName, pgmExt] = fileparts(pgmPath);
    pgmFile = [pgmName pgmExt];

    lines = {
        ['image: ' pgmFile]
        'mode: trinary'
        ['resolution: ' num2str(resolution, '%.4f')]
        ['origin: [' num2str(originX, '%.4f') ', ' num2str(originY, '%.4f') ', 0.0]']
        'negate: 0'
        'occupied_thresh: 0.65'
        'free_thresh: 0.25'
        };

    fid = fopen(yamlPath, 'w');
    if fid < 0
        error('stage2:WriteYaml', 'Cannot write %s', yamlPath);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end

function writeRosMapPgm(pgmPath, map)
    prob = occupancyMatrix(map);
    pgm = uint8(205 * ones(size(prob)));
    pgm(prob <= 0.25) = 254;
    pgm(prob >= 0.65) = 0;
    pgm = flipud(pgm);
    imwrite(pgm, pgmPath);
end
