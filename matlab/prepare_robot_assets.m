function cfg = prepare_robot_assets()
%PREPARE_ROBOT_ASSETS  Copy URDF + STL meshes into matlab/ for importrobot.
%
%   cfg = prepare_robot_assets()
%
% Run once (or automatically from matlab_connect). Copies from the bundled
% yahboomcar_description package and rewrites package:// mesh URIs to
% relative meshes/ paths MATLAB can resolve.

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    srcDesc = fullfile(projectRoot, 'ros', 'yahboomcar_ws', 'src', ...
        'yahboomcar_description');
    srcUrdf = fullfile(srcDesc, 'urdf', 'MicroROS.urdf');
    srcMeshes = fullfile(srcDesc, 'meshes');

    robotDir = fullfile(matlabDir, 'robot');
    meshDir = fullfile(matlabDir, 'meshes');
    urdfOut = fullfile(robotDir, 'MicroROS.urdf');

    if ~exist(robotDir, 'dir'), mkdir(robotDir); end
    if ~exist(meshDir, 'dir'), mkdir(meshDir); end

    if ~isfile(srcUrdf)
        error('prepare_robot_assets:MissingUrdf', ...
            'URDF not found: %s', srcUrdf);
    end

    raw = fileread(srcUrdf);
    fixed = strrep(raw, 'package://yahboomcar_description/meshes/', 'meshes/');
    fid = fopen(urdfOut, 'w');
    if fid < 0
        error('prepare_robot_assets:WriteFailed', 'Cannot write %s', urdfOut);
    end
    fwrite(fid, fixed);
    fclose(fid);

    if isfolder(srcMeshes)
        stls = dir(fullfile(srcMeshes, '*.STL'));
        for k = 1:numel(stls)
            copyfile(fullfile(srcMeshes, stls(k).name), ...
                fullfile(meshDir, stls(k).name), 'f');
        end
    end

    nMesh = numel(dir(fullfile(meshDir, '*.STL')));
    if nMesh == 0
        warning('prepare_robot_assets:NoMeshes', ...
            ['No STL meshes found. URDF kinematics will load; 3D visuals may be empty. ', ...
             'Copy *.STL from your Yahboom VM into:\n  %s'], meshDir);
    else
        fprintf('Copied %d mesh file(s) to %s\n', nMesh, meshDir);
    end

    cfg = struct();
    cfg.matlabDir = matlabDir;
    cfg.projectRoot = projectRoot;
    cfg.urdfPath = urdfOut;
    cfg.meshDir = meshDir;
    cfg.meshCount = nMesh;
end
