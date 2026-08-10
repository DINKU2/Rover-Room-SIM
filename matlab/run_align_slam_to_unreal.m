function align = run_align_slam_to_unreal(varargin)
%RUN_ALIGN_SLAM_TO_UNREAL  Auto-register SLAM map to Unreal room footprint.
%
%   run_align_slam_to_unreal()
%   run_align_slam_to_unreal('MapPath', '.../maps/rover_room_....mat')
%
%   Writes maps/unreal_alignment.mat and shows overlay plot.

    setup_rover_paths();
    align = align_slam_to_unreal(varargin{:});
end
