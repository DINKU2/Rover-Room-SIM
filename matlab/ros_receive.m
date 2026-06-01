function msg = ros_receive(ctx, topic, timeoutSec)
%ROS_RECEIVE  Read one /odom or /scan message (native DDS via ros_sub_read).
%
%   odom = ros_receive(ctx, 'odom', 10);
%   scan = ros_receive(ctx, 'scan', 5);

    if nargin < 3, timeoutSec = 10; end
    topic = lower(char(topic));

    if ~isstruct(ctx)
        error('ros_receive:BadCtx', 'Call ros_connect() first.');
    end

    if isfield(ctx, 'client')
        msg = ros_receive_bridge(ctx, topic, timeoutSec);
        return;
    end

    if ~isfield(ctx, 'odomSub')
        error('ros_receive:NoSub', 'Call ros_connect() first.');
    end

    switch topic
        case 'odom'
            msg = ros_sub_read(ctx.odomSub, timeoutSec);
        case 'scan'
            msg = ros_sub_read(ctx.scanSub, timeoutSec);
        otherwise
            error('ros_receive:Topic', 'Unknown topic "%s" (use odom or scan).', topic);
    end
end

function msg = ros_receive_bridge(ctx, topic, timeoutSec)
    client = ctx.client;
    t0 = tic;
    msg = [];
    while toc(t0) < timeoutSec
        if client.NumBytesAvailable > 0
            raw = bridge_recv(client, 1);
            if isempty(raw) || ~isstruct(raw), continue; end
            if strcmp(raw.type, topic)
                msg = raw;
                return;
            end
        end
        pause(0.05);
    end
end
