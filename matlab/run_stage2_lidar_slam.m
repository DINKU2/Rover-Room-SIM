function run_stage2_lidar_slam(varargin)
%RUN_STAGE2_LIDAR_SLAM  Setup ROS and run MATLAB-native lidar SLAM.
%
%   run_stage2_lidar_slam()
%   run_stage2_lidar_slam('PlotMap', false)
%
%   A "Stage 2 — Save map" popup opens — click it, press 5 or Save button.
%   Auto-saves on Ctrl+C. Map plot is optional (PlotMap).
%
%   Shell prereq:
%     ./scripts/start_agent.sh
%     ./scripts/check_robot.sh
%
%   Drive (separate terminal):
%     source ./setup.bash && ./scripts/run_teleop.sh

    setup_rover_paths();
    setup_ros_humble();
    stage2_lidar_slam(varargin{:});
end
