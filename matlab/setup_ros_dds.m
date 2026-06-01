function cfg = setup_ros_dds(useDiscoveryServer)
%SETUP_ROS_DDS  Configure ROS 2 DDS for MATLAB on native Linux.
%
%   cfg = setup_ros_dds()       % peer discovery (default)
%   cfg = setup_ros_dds(true)   % discovery server on 127.0.0.1:11811
%
%   Uses fastdds_matlab_native.xml (loopback + LAN IP from config/env).

    if nargin < 1, useDiscoveryServer = false; end

    if ~(isunix && ~ismac)
        error('setup_ros_dds:Platform', ...
            'Native Linux only. On other platforms use matlab_connect_bridge with ./scripts/start_matlab_bridge.sh');
    end

    matlabDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(matlabDir);

    setenv('ROS_DOMAIN_ID', '20');
    setenv('ROS_LOCALHOST_ONLY', '0');
    setenv('ROS_AUTOMATIC_DISCOVERY_RANGE', 'SUBNET');
    setenv('ROS_STATIC_PEERS', '');
    setenv('RMW_IMPLEMENTATION', '');
    setenv('CYCLONEDDS_URI', '');

    if useDiscoveryServer
        setenv('ROS_DISCOVERY_SERVER', '127.0.0.1:11811');
    else
        setenv('ROS_DISCOVERY_SERVER', '');
    end
    setenv('ROS_SUPER_CLIENT', '0');

    lanIp = readLanIp(projectRoot);
    xmlPath = fullfile(matlabDir, 'fastdds_matlab_native.xml');
    writeNativeFastDds(projectRoot, lanIp, xmlPath);
    % Bind loopback + LAN IP — required for MATLAB to receive (not just discover).
    setenv('FASTRTPS_DEFAULT_PROFILES_FILE', xmlPath);

    cfg = struct();
    cfg.domainId = '20';
    cfg.profilesFile = xmlPath;
    cfg.projectRoot = projectRoot;
    cfg.lanIp = lanIp;

    fprintf('ROS DDS configured for MATLAB:\n');
    fprintf('  ROS_DOMAIN_ID=%s\n', cfg.domainId);
    fprintf('  ROS_AUTOMATIC_DISCOVERY_RANGE=SUBNET\n');
    fprintf('  FASTRTPS_DEFAULT_PROFILES_FILE=%s\n', xmlPath);
    fprintf('  LAN IP=%s\n', cfg.lanIp);
    if useDiscoveryServer
        fprintf('  ROS_DISCOVERY_SERVER=127.0.0.1:11811\n');
    end
end

function ip = readLanIp(projectRoot)
    ip = '';
    envFile = fullfile(projectRoot, 'config', 'env');
    if isfile(envFile)
        txt = fileread(envFile);
        tok = regexp(txt, 'export\s+MICRO_ROS_AGENT_IP=([0-9.]+)', 'tokens', 'once');
        if ~isempty(tok)
            ip = tok{1};
            return;
        end
    end
    [st, out] = system('bash -lc "hostname -I | awk ''{print $1}''"');
    if st == 0
        ip = strtrim(out);
    end
    if isempty(ip)
        ip = '127.0.0.1';
    end
end

function writeNativeFastDds(projectRoot, lanIp, outPath)
    tpl = fullfile(projectRoot, 'config', 'fastdds_matlab_linux.xml.in');
    if ~isfile(tpl)
        error('setup_ros_dds:MissingTemplate', 'Not found: %s', tpl);
    end
    xml = fileread(tpl);
    xml = strrep(xml, '@LAN_IP@', lanIp);
    fid = fopen(outPath, 'w');
    if fid < 0
        error('setup_ros_dds:WriteFailed', 'Cannot write %s', outPath);
    end
    fwrite(fid, xml);
    fclose(fid);
end
