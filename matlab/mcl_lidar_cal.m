function varargout = mcl_lidar_cal(action, varargin)
%MCL_LIDAR_CAL  Load/save live lidar calibration (mirror + 180° offset).
%
%   cal = mcl_lidar_cal('load')
%     cal.offset  — radians added to each beam angle (Flip 180° → pi)
%     cal.mirror  — logical, Reflect lidar (negate angles)
%
%   mcl_lidar_cal('save', offset, mirror)
%
%   ls = mcl_lidar_cal('prepare', lsRaw)
%   ls = mcl_lidar_cal('prepare', lsRaw, cal)

    if nargin < 1 || isempty(action)
        action = 'load';
    end
    switch lower(action)
        case 'load'
            varargout{1} = load_cal();
        case 'save'
            save_cal(varargin{1}, varargin{2});
        case 'prepare'
            if nargin >= 3 && ~isempty(varargin{2}) && isstruct(varargin{2})
                cal = varargin{2};
            else
                cal = load_cal();
            end
            ctx = struct('lidarMirror', cal.mirror, 'lidarAngleOffset', cal.offset);
            varargout{1} = verify_lidarscan_prepare(varargin{1}, ctx);
        otherwise
            error('mcl_lidar_cal:BadAction', 'Unknown action: %s', action);
    end
end

function cal = load_cal()
    cal = struct('offset', 0, 'mirror', false);
    path = cal_path();
    if isfile(path)
        S = load(path);
        if isfield(S, 'lidar_angle_offset')
            cal.offset = double(S.lidar_angle_offset);
        end
        if isfield(S, 'lidar_mirror')
            cal.mirror = logical(S.lidar_mirror);
        end
        return;
    end
    path2 = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'maps', 'stage2_cal.mat');
    if isfile(path2)
        S = load(path2);
        if isfield(S, 'lidar_angle_offset')
            cal.offset = double(S.lidar_angle_offset);
        end
    end
end

function save_cal(offset, mirror)
    path = cal_path();
    lidar_angle_offset = double(offset); %#ok<NASGU>
    lidar_mirror = logical(mirror); %#ok<NASGU>
    saved_at = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<NASGU>
    save(path, 'lidar_angle_offset', 'lidar_mirror', 'saved_at');
    fprintf('[lidar cal] Saved mirror=%d  offset=%.0f°  →  %s\n', ...
        lidar_mirror, rad2deg(lidar_angle_offset), path);
end

function path = cal_path()
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    path = fullfile(projectRoot, 'maps', 'mcl_lidar_offset.mat');
end
