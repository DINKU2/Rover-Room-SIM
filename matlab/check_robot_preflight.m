function ok = check_robot_preflight()
%CHECK_ROBOT_PREFLIGHT  True when robot topics exist AND /odom is live.
%   Runs ./scripts/check_robot.sh in the project tree.

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);

    cmd = sprintf('bash -lc "cd ''%s'' && source ./setup.bash && ./scripts/check_robot.sh"', projectRoot);

    [~, out] = system(cmd);
    fprintf('%s', out);
    topics = parseTopicBlock(out);
    ok = all(ismember({'/odom', '/cmd_vel'}, topics)) ...
        && contains(out, '[OK] /odom live');
    if ok && ~any(strcmp(topics, '/scan'))
        fprintf('[NOTE] /scan not present (lidar disabled in firmware — teleop/odom OK)\n');
    end
end

function topics = parseTopicBlock(out)
    topics = {};
    lines = splitlines(string(out));
    inBlock = false;
    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if contains(line, "Topics on the graph:")
            inBlock = true;
            continue;
        end
        if inBlock && (strlength(line) == 0 || startsWith(line, "Expected"))
            break;
        end
        if inBlock && startsWith(line, "/")
            topics{end+1} = char(line); %#ok<AGROW>
        end
    end
end
