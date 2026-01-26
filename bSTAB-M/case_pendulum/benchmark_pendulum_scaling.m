% Benchmark MATLAB basin stability computation for different N values
% This script runs the pendulum case study with varying sample sizes
% to analyze scaling behavior for comparison with Python implementation.
%
% Results are saved to CSV for comparison with Python pytest-benchmark results.
%
% (c) Adrian Wix
% 25.01.2026
% -------------------------------------------------------------------------

% ensure a clean start
clear; close all; clc;

% Shutdown any existing parallel pool to ensure clean warmup timing
poolobj = gcp('nocreate');
if ~isempty(poolobj)
    delete(poolobj);
    fprintf('Shut down existing parallel pool.\n');
end

N_values = [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000];

% Number of rounds to run (matching Python pytest-benchmark)
num_rounds = 5;

% Create benchmark results subfolder
benchmark_folder = 'case_pendulum/benchmark_results';
if ~exist(benchmark_folder, 'dir')
    mkdir(benchmark_folder);
end

% Load existing results if available
output_json = fullfile(benchmark_folder, 'matlab_benchmark_results.json');
existing_results = struct('N', {}, 'round_times', {}, 'mean_time', {}, ...
                          'std_time', {}, 'min_time', {}, 'max_time', {});
completed_N = [];
if exist(output_json, 'file')
    fprintf('Found existing results file, loading...\n');
    json_text = fileread(output_json);
    existing_data = jsondecode(json_text);
    if isfield(existing_data, 'benchmarks')
        benchmarks = existing_data.benchmarks;
        for j = 1:length(benchmarks)
            if length(benchmarks(j).round_times) >= num_rounds
                completed_N = [completed_N, benchmarks(j).N];
                existing_results(end+1) = benchmarks(j);
            end
        end
    end
    fprintf('Already completed N values: %s\n', mat2str(completed_N));
end

% Filter out already completed N values
N_to_run = setdiff(N_values, completed_N, 'stable');
if isempty(N_to_run)
    fprintf('All N values already benchmarked. Nothing to do.\n');
    results = existing_results;
else
    fprintf('N values to benchmark: %s\n', mat2str(N_to_run));
    confirm = input('Start benchmark? (Y/n): ', 's');
    if ~strcmpi(confirm, 'Y') && ~isempty(confirm)
        fprintf('Benchmark cancelled.\n');
        return;
    end
    fprintf('\n');

    % Warmup run to initialize parallel pool
    fprintf('Performing warmup run to initialize parallel pool...\n');
    warmup_case = 'case_pendulum/benchmark_warmup';
    [props_warmup] = init_bSTAB(warmup_case);
    [props_warmup] = setup_pendulum(props_warmup);
    props_warmup.roi.N = 100;
    props_warmup.progessBar = false;
    props_warmup.flagShowFigures = false;
    tic;
    [~, ~, ~] = compute_bs(props_warmup);
    warmup_time = toc;
    if exist(props_warmup.subCasePath, 'dir')
        rmdir(props_warmup.subCasePath, 's');
    end
    fprintf('Warmup complete in %.2f seconds.\n\n', warmup_time);

    % Pre-allocate results structure for new runs
    num_new_runs = length(N_to_run);
    new_results = struct('N', cell(1, num_new_runs), ...
                     'round_times', cell(1, num_new_runs), ...
                     'mean_time', cell(1, num_new_runs), ...
                     'std_time', cell(1, num_new_runs), ...
                     'min_time', cell(1, num_new_runs), ...
                     'max_time', cell(1, num_new_runs));

    % Loop through each N value that needs to be run
    for i = 1:num_new_runs
        N = N_to_run(i);
        fprintf('Running benchmark for N = %d (%d/%d) with %d rounds...\n', ...
                N, i, num_new_runs, num_rounds);
        
        % Store times for all rounds
        round_times = zeros(1, num_rounds);
        
        % Run multiple rounds
        for round = 1:num_rounds
            fprintf('  Round %d/%d... ', round, num_rounds);
            
            % Define a name for the current analysis
            currentCase = sprintf('case_pendulum/benchmark_results_N%d_round%d', N, round);
            
            % Set up paths, initialize bSTAB, create properties struct
            [props] = init_bSTAB(currentCase);
            
            % Set up the pendulum case
            [props] = setup_pendulum(props);
            
            % Override N with current benchmark value
            props.roi.N = N;
            
            % Disable progress bar and figures for cleaner benchmark
            props.progessBar = false;
            props.flagShowFigures = false;
            
            % Time the basin stability computation
            tic;
            [res_tab, res_detail, props] = compute_bs(props);
            elapsed = toc;
            
            round_times(round) = elapsed;
            
            fprintf('%.2f seconds\n', elapsed);
            
            % Clean up temporary results directory
            if exist(props.subCasePath, 'dir')
                rmdir(props.subCasePath, 's');
            end
        end
        
        % Compute statistics
        new_results(i).N = N;
        new_results(i).round_times = round_times;
        new_results(i).mean_time = mean(round_times);
        new_results(i).std_time = std(round_times);
        new_results(i).min_time = min(round_times);
        new_results(i).max_time = max(round_times);
        
        fprintf('  Summary: mean=%.2f±%.2f s, min=%.2f s, max=%.2f s\n\n', ...
                new_results(i).mean_time, new_results(i).std_time, ...
                new_results(i).min_time, new_results(i).max_time);
    end

    % Merge existing and new results
    all_results = [existing_results, new_results];
    
    % Sort by N value
    [~, sort_idx] = sort([all_results.N]);
    results = all_results(sort_idx);
end

% Save results to JSON
json_str = jsonencode(struct('num_rounds', num_rounds, 'benchmarks', results), 'PrettyPrint', true);
fid = fopen(output_json, 'w');
fprintf(fid, '%s', json_str);
fclose(fid);
fprintf('Results saved to: %s\n', output_json);

% Display summary
disp('=== Benchmark Summary ===');
for i = 1:length(results)
    fprintf('N=%d: mean=%.2f±%.2f s, rounds=%s\n', ...
            results(i).N, results(i).mean_time, results(i).std_time, ...
            mat2str(results(i).round_times, 2));
end

% Create a simple timing plot
figure('Name', 'MATLAB Benchmark Results');
N_vals = [results.N];
mean_times = [results.mean_time];
std_times = [results.std_time];

b = bar(1:length(N_vals), mean_times);
hold on;
errorbar(1:length(N_vals), mean_times, std_times, 'k.', 'LineWidth', 1.5);
hold off;

set(gca, 'XTick', 1:length(N_vals));
set(gca, 'XTickLabel', arrayfun(@num2str, N_vals, 'UniformOutput', false));
grid on;
xlabel('Number of Samples (N)');
ylabel('Mean Elapsed Time (seconds)');
title('MATLAB Basin Stability Computation Scaling');

% Save plot
saveas(gcf, fullfile(benchmark_folder, 'matlab_benchmark_plot.png'));
savefig(gcf, fullfile(benchmark_folder, 'matlab_benchmark_plot.fig'));

fprintf('\nBenchmark completed successfully!\n');
