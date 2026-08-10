function msg = ros_sub_read(sub, timeoutSec, varargin)
%ROS_SUB_READ  Read from ros2subscriber (works around receive() pitfalls).
%
%   receive() only returns messages published AFTER the call starts. If you
%   send once then call receive(), it times out even though LatestMessage
%   has data. This helper polls LatestMessage (MathWorks-recommended for
%   periodic reads) and optionally blocks on receive() for a fresh sample.
%
%   msg = ros_sub_read(sub, 10)           % wait up to 10s for any message
%   msg = ros_sub_read(sub, 10, 'fresh')  % block until a NEW message arrives
%
%   See: https://www.mathworks.com/matlabcentral/answers/1721695

    if nargin < 2, timeoutSec = 10; end
    wantFresh = any(strcmpi(varargin, 'fresh'));

    if timeoutSec <= 0 && ~wantFresh
        msg = [];
        try
            if isprop(sub, 'LatestMessage')
                msg = sub.LatestMessage;
            end
        catch
        end
        if isempty(msg)
            msg = [];
        end
        return;
    end

    t0 = tic;
    msg = [];

    if wantFresh
        try
            msg = receive(sub, timeoutSec);
            return;
        catch
            % fall through to LatestMessage poll
        end
    end

    while toc(t0) < timeoutSec
        if isprop(sub, 'LatestMessage')
            m = sub.LatestMessage;
            if ~isempty(m)
                msg = m;
                return;
            end
        end
        pause(0.05);
    end
end
