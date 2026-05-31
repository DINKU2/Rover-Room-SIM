function bridge_send_cmd(client, linear_x, angular_z)
%BRIDGE_SEND_CMD  Send cmd_vel JSON to TCP bridge (length-prefixed, big-endian).

    payload = struct('type', 'cmd_vel', 'linear_x', linear_x, 'angular_z', angular_z);
    body = uint8(jsonencode(payload));
    n = numel(body);
    len = uint8([ ...
        bitshift(n, -24), ...
        bitand(bitshift(n, -16), 255), ...
        bitand(bitshift(n, -8), 255), ...
        bitand(n, 255)]);
    write(client, len);
    write(client, body);
end
