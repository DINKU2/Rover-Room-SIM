function run_manual_align_slam(varargin)
%RUN_MANUAL_ALIGN_SLAM  Keyboard WASD/QE manual SLAM → Unreal alignment.

    setup_rover_paths();
    manual_align_slam_to_unreal(varargin{:});
end
