classdef roverLidarLivePlot < matlab.System
    %ROVERLIDARLIVEPLOT Live top-down plot for RoverTwin lidar points.

    properties (Nontunable)
        AxisLimit = 8
        PlotEvery = 1
        MaxPoints = 4000
        UdpPort = 55221
        UdpStaleSec = 0.25
    end

    properties (Access = private)
        Figure
        Axes
        Scatter
        RoverMarker
        PreviousPoints
        UdpReceiver
        UdpFrame = 0
        UdpPose = [0 0 0]
        UdpPoints = zeros(0, 2)
        UdpLastPacketTime = -Inf
        FrameCount = 0
    end

    methods (Access = protected)
        function setupImpl(obj)
            obj.createPlot();
            obj.createUdpReceiver();
        end

        function stepImpl(obj, pointCloud, simulationTime, roverX, roverY, roverYaw)
            obj.FrameCount = obj.FrameCount + 1;
            if mod(obj.FrameCount - 1, obj.PlotEvery) ~= 0
                return
            end

            [hasUdp, udpFrame, udpPose, worldXY] = obj.readUdpLidar(simulationTime);
            if hasUdp
                points = [worldXY, zeros(size(worldXY, 1), 1)];
                roverX = udpPose(1);
                roverY = udpPose(2);
                roverYaw = udpPose(3);
            else
                points = reshape(double(pointCloud), [], 3);
                valid = all(isfinite(points), 2) & any(points ~= 0, 2);
                points = points(valid, :);
            end

            if size(points, 1) > obj.MaxPoints
                keep = round(linspace(1, size(points, 1), obj.MaxPoints));
                points = points(keep, :);
            end

            if isempty(obj.Figure) || ~isvalid(obj.Figure)
                obj.createPlot();
            end

            pointDelta = NaN;
            if ~isempty(points) && ~isempty(obj.PreviousPoints) ...
                    && isequal(size(points), size(obj.PreviousPoints))
                pointDelta = max(abs(points - obj.PreviousPoints), [], "all");
            end
            obj.PreviousPoints = points;

            if ~hasUdp
                yaw = double(roverYaw);
                rotation = [cos(yaw), -sin(yaw); sin(yaw), cos(yaw)];
                worldXY = points(:, 1:2) * rotation.' + [double(roverX), double(roverY)];
                udpFrame = NaN;
            end

            sourceLabel = "UDP";
            if ~hasUdp
                sourceLabel = "Simulink";
            end
            set(obj.Scatter, "XData", worldXY(:, 1), "YData", worldXY(:, 2));
            set(obj.RoverMarker, "XData", double(roverX), "YData", double(roverY));
            title(obj.Axes, sprintf( ...
                "RoverTwin lidar (%s) — sim frame %d, udp frame %.0f, t %.2f, pose [%.2f %.2f %.1f°], Δ %.3g, %d points", ...
                sourceLabel, obj.FrameCount, udpFrame, simulationTime, roverX, roverY, rad2deg(roverYaw), pointDelta, size(points, 1)));
            assignin("base", "roverLidarLastFrame", obj.FrameCount);
            assignin("base", "roverLidarLastUdpFrame", udpFrame);
            assignin("base", "roverLidarLastTime", simulationTime);
            assignin("base", "roverLidarLastPoints", points);
            assignin("base", "roverLidarLastWorldPoints", worldXY);
            assignin("base", "roverLidarLastPose", [double(roverX), double(roverY), double(roverYaw)]);
            assignin("base", "roverLidarLastPointDelta", pointDelta);
            drawnow
        end

        function resetImpl(obj)
            obj.FrameCount = 0;
            obj.PreviousPoints = [];
            obj.UdpLastPacketTime = -Inf;
        end

        function releaseImpl(obj)
            obj.FrameCount = 0;
            obj.PreviousPoints = [];
            obj.UdpLastPacketTime = -Inf;
            obj.UdpReceiver = [];
        end
    end

    methods (Access = private)
        function createUdpReceiver(obj)
            try
                obj.UdpReceiver = udpport("datagram", "IPV4", "LocalPort", obj.UdpPort);
            catch
                obj.UdpReceiver = [];
            end
        end

        function [hasPacket, frame, pose, worldXY] = readUdpLidar(obj, simulationTime)
            hasPacket = false;
            frame = obj.UdpFrame;
            pose = obj.UdpPose;
            worldXY = obj.UdpPoints;

            if isempty(obj.UdpReceiver) || ~isvalid(obj.UdpReceiver)
                obj.createUdpReceiver();
            end
            if isempty(obj.UdpReceiver)
                return
            end

            latest = "";
            while obj.UdpReceiver.NumDatagramsAvailable > 0
                datagram = read(obj.UdpReceiver, 1, "string");
                latest = string(datagram.Data);
            end
            if strlength(latest) == 0
                hasPacket = (obj.UdpLastPacketTime >= 0) ...
                    && (simulationTime - obj.UdpLastPacketTime <= obj.UdpStaleSec);
                if hasPacket
                    frame = obj.UdpFrame;
                    pose = obj.UdpPose;
                    worldXY = obj.UdpPoints;
                end
                return
            end

            parts = split(latest, "|");
            if numel(parts) < 6 || parts(1) ~= "ROVERLIDAR"
                return
            end

            parsedFrame = str2double(parts(2));
            parsedPose = [str2double(parts(3)), str2double(parts(4)), str2double(parts(5))];
            pointTokens = split(parts(6), ";");
            parsedPoints = zeros(numel(pointTokens), 2);
            validCount = 0;
            for idx = 1:numel(pointTokens)
                xy = split(pointTokens(idx), ",");
                if numel(xy) ~= 2
                    continue
                end
                x = str2double(xy(1));
                y = str2double(xy(2));
                if ~isfinite(x) || ~isfinite(y)
                    continue
                end
                validCount = validCount + 1;
                parsedPoints(validCount, :) = [x, y];
            end
            parsedPoints = parsedPoints(1:validCount, :);

            obj.UdpFrame = parsedFrame;
            obj.UdpPose = parsedPose;
            obj.UdpPoints = parsedPoints;
            obj.UdpLastPacketTime = simulationTime;
            hasPacket = true;
            frame = parsedFrame;
            pose = parsedPose;
            worldXY = parsedPoints;
        end

        function createPlot(obj)
            obj.Figure = figure( ...
                "Name", "RoverTwin Live Lidar", ...
                "NumberTitle", "off", ...
                "Color", "w");
            obj.Axes = axes(obj.Figure);
            obj.Scatter = scatter(obj.Axes, nan, nan, 12, "filled");
            axis(obj.Axes, "equal");
            grid(obj.Axes, "on");
            xlim(obj.Axes, [-obj.AxisLimit obj.AxisLimit]);
            ylim(obj.Axes, [-obj.AxisLimit obj.AxisLimit]);
            xlabel(obj.Axes, "World X (m)");
            ylabel(obj.Axes, "World Y (m)");
            title(obj.Axes, "RoverTwin live lidar");
            hold(obj.Axes, "on");
            obj.RoverMarker = plot(obj.Axes, 0, 0, "r^", "MarkerFaceColor", "r");
            hold(obj.Axes, "off");
        end
    end
end
