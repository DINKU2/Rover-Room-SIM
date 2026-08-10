function paths = rover_unreal_paths()
%ROVER_UNREAL_PATHS Central paths for Unreal + MATLAB co-simulation.
%
%   paths = rover_unreal_paths()
%
%   Override via environment variables (optional):
%     ROVER_UE_ROOT        Unreal Engine install root
%     ROVER_UE_PROJECT     Path to RoverRoomSIM.uproject
%     ROVER_COSIM_PROJECT  Path to co-sim .uproject (default: RoverTwin MyRoom)

    matlabDir = fileparts(mfilename('fullpath'));
    paths.projectRoot = fileparts(matlabDir);
    paths.matlabDir = matlabDir;
    paths.unrealRoot = fullfile(paths.projectRoot, 'unreal');
    paths.roomProjectDir = fullfile(paths.unrealRoot, 'RoverRoomSIM');
    paths.uproject = fullfile(paths.roomProjectDir, 'RoverRoomSIM.uproject');
    paths.roverTwinDir = fullfile(paths.projectRoot, 'RoverSIMUunreal-Linux', 'RoverTwin');
    paths.roverTwinProject = fullfile(paths.roverTwinDir, 'RoverTwin.uproject');
    paths.roverTwinPackage = fullfile(paths.projectRoot, 'RoverSIMUunreal-Linux', 'Linux', 'RoverTwin.sh');
    paths.roomFbx = fullfile(paths.matlabDir, 'my_room.fbx');
    paths.importScript = fullfile(paths.unrealRoot, 'Scripts', 'import_room_mesh.py');
    paths.setupScript = fullfile(paths.projectRoot, 'scripts', 'setup_unreal_project.sh');
    paths.setupRoverTwinScript = fullfile(paths.projectRoot, 'scripts', 'setup_rovertwin.sh');
    paths.roverTwinImportFlag = fullfile(paths.roverTwinDir, '.rovertwin_imported');
    paths.roverTwinLevelMap = fullfile(paths.roverTwinDir, 'Content', 'Maps', 'MyRoom.umap');
    paths.roverTwinScene = '/Game/Maps/MyRoom';

    paths.ueRoot = getenv('ROVER_UE_ROOT');
    if strlength(paths.ueRoot) == 0
        paths.ueRoot = '/home/dinuk/UnrealEngine_5.3';
    end
    paths.launchScript = fullfile(paths.projectRoot, 'scripts', 'launch_unreal_532.sh');
    paths.startRoverTwinCosimScript = fullfile(paths.projectRoot, 'scripts', 'start_rovertwin_cosim.sh');
    paths.startAutoVrtlCosimScript = fullfile(paths.projectRoot, 'scripts', 'start_unreal_cosim.sh');
    paths.roverTwinCosimLog = '/tmp/rover_rovertwin.log';
    paths.autoVrtlCosimLog = '/tmp/rover_autovrtlenv.log';
    paths.launchRoverTwinExeScript = fullfile(paths.projectRoot, 'scripts', 'launch_rovertwin_exe.sh');
    paths.ueEditor = fullfile(paths.ueRoot, 'Engine', 'Binaries', 'Linux', 'UnrealEditor');
    paths.pluginDest = fullfile(paths.ueRoot, 'Engine', 'Plugins', 'Marketplace', 'Mathworks');

    overrideProject = getenv('ROVER_UE_PROJECT');
    if strlength(overrideProject) > 0
        paths.uproject = char(overrideProject);
        paths.roomProjectDir = fileparts(paths.uproject);
    end

    paths.autoVrtlEnvDir = fullfile(paths.unrealRoot, 'AutoVrtlEnv');
    paths.autoVrtlEnvProject = fullfile(paths.autoVrtlEnvDir, 'AutoVrtlEnv.uproject');
    paths.mathworksSpkgRoot = rover_unreal_support_package_root();
    paths.mathworksReady = isfolder(paths.mathworksSpkgRoot);
    overrideCosim = getenv('ROVER_COSIM_PROJECT');
    if strlength(overrideCosim) > 0
        paths.cosimProject = char(overrideCosim);
    elseif isfile(paths.roverTwinLevelMap) && isfile(paths.roverTwinProject)
        paths.cosimProject = paths.roverTwinProject;
    elseif isfile(paths.autoVrtlEnvProject)
        paths.cosimProject = paths.autoVrtlEnvProject;
    else
        paths.cosimProject = paths.uproject;
    end

    paths.simulinkModel = fullfile(paths.projectRoot, 'simulink', 'rover_unreal_preview.slx');
    paths.simulinkModelName = 'rover_unreal_preview';
    paths.simulinkCosimModel = fullfile(paths.projectRoot, 'simulink', 'rover_unreal_cosim.slx');
    paths.simulinkCosimModelName = 'rover_unreal_cosim';
end
