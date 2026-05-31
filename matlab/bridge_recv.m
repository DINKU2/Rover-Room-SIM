function msg = bridge_recv(client, timeoutSec)
%BRIDGE_RECV  Read one length-prefixed JSON message from TCP bridge.

    if nargin < 2, timeoutSec = 5; end
    msg = [];
    client.Timeout = timeoutSec;
    try
        hdr = read(client, 4, 'uint8');
        if numel(hdr) < 4, return; end
        len = swapbytes(typecast(uint8(hdr(:)), 'uint32'));
        body = read(client, double(len), 'uint8');
        txt = char(body(:))';
        msg = jsondecode(txt);
    catch
    end
end
