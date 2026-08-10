function sm = mcl_robust_sensor_model(sm)
%MCL_ROBUST_SENSOR_MODEL  Tolerate lidar hits on objects not in the saved map.
%
%   Dynamic obstacles (people, moved furniture) are treated as "random"
%   measurements so wall structure still drives the pose estimate.

    sm.RandomMeasurementWeight = 0.25;
    sm.ExpectedMeasurementWeight = 0.75;
    sm.MeasurementNoise = 0.18;
    sm.MaxLikelihoodDistance = 0.85;
    sm.NumBeams = 90;
end
