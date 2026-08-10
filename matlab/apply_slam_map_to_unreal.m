function ptsUe = apply_slam_map_to_unreal(xyMap, align)
%APPLY_SLAM_MAP_TO_UNREAL  MAP-frame Nx2 points -> Unreal / manual-align frame.
%
%   ptsUe = apply_slam_map_to_unreal(xyMap, align)
%
%   Applies slam_flip_y (if present) then R2d/t2d from maps/unreal_alignment.mat.
%   Matches manual_align_slam_to_unreal / map_pose_to_unreal_ros point transform.

    if nargin < 2 || isempty(xyMap) || isempty(align) || ~isfield(align, 'R2d')
        ptsUe = zeros(0, 2);
        return;
    end

    pts = double(xyMap(:, 1:2));
    if isfield(align, 'slam_flip_y') && align.slam_flip_y
        pts(:, 2) = -pts(:, 2);
    end
    ptsUe = apply_map_align2d(pts, align.R2d, align.t2d);
end
