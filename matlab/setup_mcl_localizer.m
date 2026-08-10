function [mcl, mapData, cfg] = setup_mcl_localizer(mapPath, varargin)
%SETUP_MCL_LOCALIZER  Monte Carlo localization on a saved Stage-2 map.
%
%   [mcl, mapData, cfg] = setup_mcl_localizer()
%   [mcl, mapData, cfg] = setup_mcl_localizer('maps/rover_room_....mat')
%
%   Uses likelihoodFieldSensorModel + odometryMotionModel (differential drive).
%   Pose output is in the same MAP frame as the saved occupancyMap (Stage 3 align).

    if nargin < 1
        mapPath = '';
    end

    p = inputParser;
    addParameter(p, 'GlobalLocalization', true, @islogical);
    addParameter(p, 'ParticleLimits', [500, 3000], @(v) isnumeric(v) && numel(v) == 2);
    addParameter(p, 'MotionNoise', [0.12, 0.12, 0.06, 0.06], @(v) isnumeric(v) && numel(v) == 4);
    addParameter(p, 'InitialPose', [], @(v) isempty(v) || (isnumeric(v) && numel(v) == 3));
    addParameter(p, 'InitialCovariance', [], @(v) isempty(v) || isnumeric(v));
    parse(p, varargin{:});
    cfg = p.Results;

    mapData = load_slam_map(mapPath);

    sm = likelihoodFieldSensorModel;
    sm.Map = mapData.map;
    sm = mcl_robust_sensor_model(sm);

    mm = odometryMotionModel;
    mm.Noise = cfg.MotionNoise;

    lockCfg = struct();
    lockCfg.SensorModel = sm;
    lockCfg.MotionModel = mm;
    lockCfg.ParticleLimits = cfg.ParticleLimits;
    lockCfg.UpdateThresholds = [0, 0, 0];

    overrides = struct('GlobalLocalization', cfg.GlobalLocalization);
    if ~isempty(cfg.InitialPose)
        overrides.InitialPose = cfg.InitialPose;
        overrides.GlobalLocalization = false;
        if isempty(cfg.InitialCovariance)
            overrides.InitialCovariance = diag([0.20, 0.20, deg2rad(15)].^2);
        else
            overrides.InitialCovariance = cfg.InitialCovariance;
        end
    end
    mcl = mcl_create_from_cfg(lockCfg, overrides);

    cfg.mapPath = mapData.path;
end
