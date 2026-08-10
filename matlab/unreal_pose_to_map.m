function pose = unreal_pose_to_map(xUe, yUe, yawUe, align)
%UNREAL_POSE_TO_MAP  Unreal/ROS pose -> saved MAP frame [x, y, yaw].
%
%   pose = unreal_pose_to_map(x, y, yaw)
%   pose = unreal_pose_to_map(x, y, yaw, align)

    if nargin < 4 || isempty(align)
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        path = fullfile(projectRoot, 'maps', 'unreal_alignment.mat');
        if ~isfile(path)
            error('unreal_pose_to_map:NoAlign', 'Missing maps/unreal_alignment.mat');
        end
        align = load(path);
    end

    p = align.R2d \ ([xUe; yUe] - align.t2d(:));
    x = p(1);
    y = p(2);
    yaw = wrap_to_pi(yawUe - align.yaw_offset);
    if isfield(align, 'slam_flip_y') && align.slam_flip_y
        y = -y;
        yaw = -yaw;
    end
    pose = [x, y, yaw];
end

function a = wrap_to_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end
