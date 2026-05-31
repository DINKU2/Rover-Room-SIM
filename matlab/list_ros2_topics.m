function topics = list_ros2_topics()
%LIST_ROS2_TOPICS  Compatible topic list across MATLAB / ROS Toolbox versions.

    topics = {};

    if exist('ros2topic', 'file') == 2
        try
            topics = normalizeTopicList(ros2topic("list"));
            if ~isempty(topics), return; end
        catch
        end
    end

    if exist('ros2', 'file') == 2
        try
            topics = normalizeTopicList(ros2('topic', 'list'));
            if ~isempty(topics), return; end
        catch
        end
    end

    try
        txt = evalc('ros2 topic list');
        topics = parseTopicListText(txt);
        if ~isempty(topics), return; end
    catch
    end

    topics = probeRobotTopics();
end

function topics = normalizeTopicList(raw)
    topics = {};
    if isempty(raw), return; end
    if ischar(raw), topics = {raw}; return; end
    if isstring(raw), raw = cellstr(raw); end
    if iscell(raw)
        topics = raw(:)';
        return;
    end
    try
        topics = cellstr(raw);
    catch
        topics = {};
    end
end

function topics = parseTopicListText(txt)
    topics = {};
    lines = splitlines(string(txt));
    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if strlength(line) > 0 && startsWith(line, "/")
            topics{end+1} = char(line); %#ok<AGROW>
        end
    end
end

function topics = probeRobotTopics()
% Last resort: try subscribers on known robot topics.
    topics = {};
    node = ros2node('matlab_topic_probe');
    checks = {
        '/scan',     'sensor_msgs/LaserScan'
        '/odom',     'nav_msgs/Odometry'
        '/cmd_vel',  'geometry_msgs/Twist'
        '/rosout',   'rcl_interfaces/msg/Log'
    };
    for i = 1:size(checks, 1)
        name = checks{i, 1};
        typ = checks{i, 2};
        try
            sub = ros2subscriber(node, name, typ);
            if any(strcmp(name, {'/scan', '/odom'}))
                receive(sub, 2);
            end
            topics{end+1} = name; %#ok<AGROW>
            clear sub
        catch
            try
                sub = ros2subscriber(node, name, strrep(typ, '/msg/', '/'));
                topics{end+1} = name; %#ok<AGROW>
                clear sub
            catch
            end
        end
    end
end
