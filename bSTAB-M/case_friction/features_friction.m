function [features] = features_friction(T, Y, props)
% [features] = extract_features_SDOF(T, Y, props)

% computes descriptive features from the time integration data and returns
% the features as a vector that can be used for classification.

% inputs:
% - T: time vector from the time integration
% - Y: states corresponding to T
% - props: property struct with all the required information

% output:
% - features: vector that contains all the features (column!)

% (c) Merten Stender
% Hamburg University of Technology, Dynamics Group
% www.tuhh.de/dyn
% m.stender@tuhh.de
% -------------------------------------------------------------------------


% 1. detect the steady-state regime (time after props.t_bs)
idx_steady = find(T>props.ti.tStar,1);

% One-hot encoding: FP = [1, 0], LC = [0, 1]
if max(abs(Y(idx_steady:end,2))) > 0.2
    features(1,1) = 0; % LC
    features(2,1) = 1;
else
    features(1,1) = 1; % FP
    features(2,1) = 0;
end

end

