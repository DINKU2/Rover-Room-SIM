function offset = mcl_load_lidar_offset()
%MCL_LOAD_LIDAR_OFFSET  Load saved lidar angle offset (radians), or 0.

    cal = mcl_lidar_cal('load');
    offset = cal.offset;
end
