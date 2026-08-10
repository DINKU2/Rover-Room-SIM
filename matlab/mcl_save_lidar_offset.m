function mcl_save_lidar_offset(offset, mirror)
%MCL_SAVE_LIDAR_OFFSET  Persist lidar calibration for next session.
%
%   mcl_save_lidar_offset(offset)
%   mcl_save_lidar_offset(offset, mirror)

    if nargin < 2 || isempty(mirror)
        cal = mcl_lidar_cal('load');
        mirror = cal.mirror;
    end
    mcl_lidar_cal('save', offset, mirror);
end
