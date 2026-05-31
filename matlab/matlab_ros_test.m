function ok = matlab_ros_test(timeoutSec)
%MATLAB_ROS_TEST  Preflight for MATLAB robot connection.
%
%   ok = matlab_ros_test()       % checks robot + TCP bridge
%   ok = matlab_ros_test(30)

    if nargin < 1, timeoutSec = 15; end

    fprintf('\n--- Robot check ---\n');
    if ~check_robot_preflight()
        fprintf('\nFix stack first:\n');
        fprintf('  source ./setup.bash\n');
        fprintf('  ./scripts/start_agent.sh\n');
        fprintf('  ./scripts/start_matlab_bridge.sh\n');
        fprintf('  power-cycle robot, ./scripts/check_robot.sh\n');
        ok = false;
        return;
    end
    fprintf('Robot OK.\n');

    fprintf('\n--- MATLAB bridge check (127.0.0.1:8765) ---\n');
    ok = testBridge(timeoutSec);
    if ok
        fprintf('\nReady — run matlab_connect_bridge\n');
    else
        fprintf('\nStart bridge: ./scripts/start_matlab_bridge.sh\n');
    end
end

function ok = testBridge(timeoutSec)
    try
        client = tcpclient('127.0.0.1', 8765, 'Timeout', 5);
    catch
        fprintf('[FAIL] Cannot connect to bridge on port 8765\n');
        ok = false;
        return;
    end
    c = onCleanup(@() clearClient(client)); %#ok<NASGU>
    hello = bridge_recv(client, 5);
    if ~isstruct(hello) || ~strcmp(hello.type, 'hello')
        fprintf('[FAIL] Bridge handshake failed\n');
        ok = false;
        return;
    end
    fprintf('[OK] Bridge connected\n');

    t0 = tic;
    while toc(t0) < timeoutSec
        if client.NumBytesAvailable > 0
            msg = bridge_recv(client, 2);
            if isstruct(msg) && strcmp(msg.type, 'odom')
                fprintf('[OK] Live odom (x=%.2f y=%.2f)\n', msg.x, msg.y);
                ok = true;
                return;
            end
        end
        pause(0.1);
    end
    fprintf('[FAIL] Bridge up but no odom yet — robot publishing?\n');
    ok = false;
end

function clearClient(client)
    try
        clear client
    catch
    end
end
