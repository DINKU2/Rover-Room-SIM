function yawD = mcl_heading_display_yaw(yaw)
%MCL_HEADING_DISPLAY_YAW  +180° body-frame correction for display / Unreal twin.
%
%   Robot map yaw is 180° from physical facing (fwd↔bwd, left↔right).
%   Does not change lidar mirror/reflect or MCL pose math.
%
%   Disable: setenv('VERIFY_HEADING_FLIP','0')

    if mcl_heading_flip_enabled()
        yawD = wrap_to_pi(yaw + pi);
    else
        yawD = yaw;
    end
end

function on = mcl_heading_flip_enabled()
    v = getenv('VERIFY_HEADING_FLIP');
    on = isempty(v) || strcmpi(v, '1') || strcmpi(v, 'true') || strcmpi(v, 'yes');
end

function a = wrap_to_pi(a)
    a = mod(a + pi, 2 * pi) - pi;
end
