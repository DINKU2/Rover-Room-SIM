function run_verify_map_pose(varargin)
%RUN_VERIFY_MAP_POSE  Live SLAM map aligned to saved map + Unreal overlay.
%
%   run_verify_map_pose()
%   run_verify_map_pose('MapPath', 'maps/rover_room_....mat')
%   run_verify_map_pose('Localization', 'mcl')   % legacy scan-only mode
%
%   Default: real-time lidarSLAM builds a live map, registers it to your
%   saved Stage-2 map, then shows pose in Unreal via unreal_alignment.mat.
%
%   Shell: ./scripts/start_agent.sh && ./scripts/check_robot.sh
%   Drive: source ./setup.bash && ./scripts/run_teleop.sh

    setup_rover_paths();
    verify_map_pose(varargin{:});
end
