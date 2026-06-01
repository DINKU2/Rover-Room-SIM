function ros_ensure_no_bridge()
%ROS_ENSURE_NO_BRIDGE  Stop TCP bridge so it does not add extra DDS load.

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);
    cmd = sprintf('bash -lc "cd ''%s'' && ./scripts/stop_matlab_bridge.sh 2>/dev/null || true"', projectRoot);
    [st, out] = system(cmd);
    if st == 0 && contains(out, 'stopped')
        fprintf('%s', out);
    end
end
