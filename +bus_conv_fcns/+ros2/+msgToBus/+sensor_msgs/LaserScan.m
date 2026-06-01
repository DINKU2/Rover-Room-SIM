function slBusOut = LaserScan(msgIn, slBusOut, varargin)
%#codegen
%   Copyright 2021-2022 The MathWorks, Inc.
    currentlength = length(slBusOut.header);
    for iter=1:currentlength
        slBusOut.header(iter) = bus_conv_fcns.ros2.msgToBus.std_msgs.Header(msgIn.header(iter),slBusOut(1).header(iter),varargin{:});
    end
    slBusOut.header = bus_conv_fcns.ros2.msgToBus.std_msgs.Header(msgIn.header,slBusOut(1).header,varargin{:});
    slBusOut.angle_min = single(msgIn.angle_min);
    slBusOut.angle_max = single(msgIn.angle_max);
    slBusOut.angle_increment = single(msgIn.angle_increment);
    slBusOut.time_increment = single(msgIn.time_increment);
    slBusOut.scan_time = single(msgIn.scan_time);
    slBusOut.range_min = single(msgIn.range_min);
    slBusOut.range_max = single(msgIn.range_max);
    maxlength = length(slBusOut.ranges);
    recvdlength = length(msgIn.ranges);
    currentlength = min(maxlength, recvdlength);
    if (max(recvdlength) > maxlength) && ...
            isequal(varargin{1}{1},ros.slros.internal.bus.VarLenArrayTruncationAction.EmitWarning)
        diag = MSLDiagnostic([], ...
                             message('ros:slros:busconvert:TruncatedArray', ...
                                     'ranges', msgIn.MessageType, maxlength, max(recvdlength), maxlength, varargin{2}));
        reportAsWarning(diag);
    end
    slBusOut.ranges_SL_Info.ReceivedLength = uint32(recvdlength);
    slBusOut.ranges_SL_Info.CurrentLength = uint32(currentlength);
    slBusOut.ranges = single(msgIn.ranges(1:slBusOut.ranges_SL_Info.CurrentLength));
    if recvdlength < maxlength
    slBusOut.ranges(recvdlength+1:maxlength) = 0;
    end
    maxlength = length(slBusOut.intensities);
    recvdlength = length(msgIn.intensities);
    currentlength = min(maxlength, recvdlength);
    if (max(recvdlength) > maxlength) && ...
            isequal(varargin{1}{1},ros.slros.internal.bus.VarLenArrayTruncationAction.EmitWarning)
        diag = MSLDiagnostic([], ...
                             message('ros:slros:busconvert:TruncatedArray', ...
                                     'intensities', msgIn.MessageType, maxlength, max(recvdlength), maxlength, varargin{2}));
        reportAsWarning(diag);
    end
    slBusOut.intensities_SL_Info.ReceivedLength = uint32(recvdlength);
    slBusOut.intensities_SL_Info.CurrentLength = uint32(currentlength);
    slBusOut.intensities = single(msgIn.intensities(1:slBusOut.intensities_SL_Info.CurrentLength));
    if recvdlength < maxlength
    slBusOut.intensities(recvdlength+1:maxlength) = 0;
    end
end
