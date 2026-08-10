function pose = map_pose_to_unreal_ros(xMap, yMap, yawMap, align)
%MAP_POSE_TO_UNREAL_ROS  MAP-frame pose -> Unreal/Simulink ROS metres.
%
%   pose = map_pose_to_unreal_ros(x, y, yaw)
%   pose = map_pose_to_unreal_ros(x, y, yaw, align)
%
%   Loads maps/unreal_alignment.mat if align omitted.
%   Output fields: x, y, yaw (ROS RH, metres/radians).

    if nargin < 4 || isempty(align)
        align = load_unreal_alignment();
    end

    x = xMap;
    y = yMap;
    yaw = yawMap;
    if isfield(align, 'slam_flip_y') && align.slam_flip_y
        y = -y;
        yaw = -yaw;
    end

    p = align.R2d * [x; y] + align.t2d(:);
    pose.x = p(1);
    pose.y = p(2);
    pose.yaw = wrap_to_pi(yaw + align.yaw_offset);
end

function align = load_unreal_alignment()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
    if ~isfile(path)
        error('map_pose_to_unreal_ros:NoAlign', ...
            ['No alignment file. Run: run_align_slam_to_unreal\n  %s'], path);
    end
    align = load(path);
end

function a = wrap_to_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end
