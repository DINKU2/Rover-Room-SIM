function ok = check_robot_preflight(requireScan)
%CHECK_ROBOT_PREFLIGHT  True when robot topics exist AND /odom is live.
%   Runs ./scripts/check_robot.sh in the project tree.
%
%   check_robot_preflight()         % odom required
%   check_robot_preflight(true)     % odom + /scan live (SLAM / verify)

    if nargin < 1
        requireScan = false;
    end

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);

    cmd = sprintf('bash -lc "cd ''%s'' && source ./setup.bash && ./scripts/check_robot.sh"', projectRoot);

    out = '';
    ok = false;
    for attempt = 1:3
        [~, out] = system(cmd);
        fprintf('%s', out);
        topics = parseTopicBlock(out);
        ok = all(ismember({'/odom', '/cmd_vel'}, topics)) ...
            && contains(out, '[OK] /odom live');
        if ok && requireScan
            ok = any(strcmp(topics, '/scan')) && contains(out, '[OK] /scan live');
        end
        if ok
            break;
        end
        if attempt < 3
            fprintf('[preflight] retry %d/3 in 3 s (run ./scripts/reset_robot_ros.sh if this persists)\n', attempt + 1);
            pause(3);
        end
    end

    if ~ok
        fprintf(['Robot not ready. In a terminal:\n' ...
            '  cd %s\n' ...
            '  ./scripts/reset_robot_ros.sh\n'], projectRoot);
    elseif ~requireScan && ~any(strcmp(topics, '/scan'))
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
