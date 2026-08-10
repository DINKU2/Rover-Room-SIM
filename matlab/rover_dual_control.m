function rover_dual_control()
%ROVER_DUAL_CONTROL  Stage 4 dual sim + real rover (shortcut entry point).
%
%   rover_dual_control()
%   run_rover_dual_control()   % same, from rover-dual/matlab
%
%   Shell: ./scripts/start_agent.sh && ./scripts/check_robot.sh
%   Needs: maps/unreal_alignment.mat, maps/mcl_lidar_offset.mat

    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'rover-dual', 'matlab'));
    run_rover_dual_control();
end
