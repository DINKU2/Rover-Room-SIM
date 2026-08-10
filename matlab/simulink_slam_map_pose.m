function y = simulink_slam_map_pose(u)
%SIMULINK_SLAM_MAP_POSE  Deprecated — forwards to MCL shared pose (no lidarSLAM).
%
%   Stage 4 uses dual_mcl_ros_update (overlay) + simulink_mcl_map_pose.
%   If you still see this block, rebuild: build_rover_dual_control_model()

    persistent warned
    if isempty(warned)
        fprintf(['[Stage4] Slam_Map_Pose is deprecated — reading MCL pose only.\n' ...
            '  Rebuild model: build_rover_dual_control_model()\n']);
        warned = true;
    end
    if nargin < 1
        u = 0;
    end
    y = simulink_mcl_map_pose(u);
end
