function [amps] = extract_amps_pendulum(T, Y, props)
% [amps] = extract_amps_pendulum(T, Y, props)
%
% Extract steady-state amplitudes for the orbit diagram.
% Uses only the portion of the trajectory after props.ti.tStar
% to avoid transient contamination.

idx_steady = find(T > props.ti.tStar, 1);
amps = max(abs(Y(idx_steady:end, :)), [], 1);

end
