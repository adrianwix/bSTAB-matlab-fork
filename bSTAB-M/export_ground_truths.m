function export_ground_truths()
% export_ground_truths - Export bSTAB results to pyBasinWorkspace
%
% This function reads all results.mat files from case_ folders and exports:
% 1. Point coordinates and labels to CSV files in tests/integration/<case>/ground_truths/<study>/
% 2. Basin stability JSON files to tests/integration/<case>/
%
% Usage:
%   export_ground_truths()
%
% (c) 2026

    % Get the directory where this script is located
    script_dir = fileparts(mfilename('fullpath'));
    
    % Path to pyBasinWorkspace tests/integration
    integration_test_base = fullfile(script_dir, '..', '..', 'pyBasinWorkspace', 'tests', 'integration');
    
    % Find all case_ directories
    case_dirs = dir(fullfile(script_dir, 'case_*'));
    case_dirs = case_dirs([case_dirs.isdir]);
    
    % Mapping from bSTAB case names to Python case study names
    case_mapping = containers.Map();
    case_mapping('case_duffing') = 'duffing';
    case_mapping('case_duffing_unsupervised') = 'duffing';
    case_mapping('case_friction') = 'friction';
    case_mapping('case_lorenz') = 'lorenz';
    case_mapping('case_pendulum') = 'pendulum';
    
    % Mapping from bSTAB result dir names to Python test JSON names
    % Format: {bSTAB_result_dir} -> {python_json_name}
    json_mapping = containers.Map();
    % Duffing
    json_mapping('case_duffing/main_duffing_results') = 'duffing/main_duffing_supervised.json';
    json_mapping('case_duffing_unsupervised/main_duffing_unsupervised_results') = 'duffing/main_duffing_unsupervised.json';
    % Friction
    json_mapping('case_friction/main_friction_results') = 'friction/main_friction_case1.json';
    json_mapping('case_friction/main_friction_vStudy_results') = 'friction/main_friction_v_study.json';
    % Lorenz
    json_mapping('case_lorenz/main_lorenz_results') = 'lorenz/main_lorenz.json';
    json_mapping('case_lorenz/main_lorenz_sigmaStudy_results') = 'lorenz/main_lorenz_sigma_study.json';
    json_mapping('case_lorenz/main_lorenz_hyperpTol_results') = 'lorenz/main_lorenz_hyperpTol.json';
    json_mapping('case_lorenz/main_lorenz_hyperpN_results') = 'lorenz/main_lorenz_hyperparameters.json';
    % Pendulum
    json_mapping('case_pendulum/main_pendulum_case1_results') = 'pendulum/main_pendulum_case1.json';
    json_mapping('case_pendulum/main_pendulum_case2_results') = 'pendulum/main_pendulum_case2.json';
    json_mapping('case_pendulum/main_pendulum_hyperparameters_results') = 'pendulum/main_pendulum_hyperparameters.json';
    
    fprintf('Found %d case directories\n', length(case_dirs));
    
    for i = 1:length(case_dirs)
        case_name = case_dirs(i).name;
        case_path = fullfile(script_dir, case_name);
        
        fprintf('\nProcessing: %s\n', case_name);
        
        % Determine Python case study name
        if isKey(case_mapping, case_name)
            python_case_name = case_mapping(case_name);
        else
            % Fallback: remove 'case_' prefix
            python_case_name = strrep(case_name, 'case_', '');
        end
        
        % Create ground_truths directory for this case study
        % e.g., tests/integration/pendulum/ground_truths/
        case_ground_truths_dir = fullfile(integration_test_base, python_case_name, 'ground_truths');
        if ~exist(case_ground_truths_dir, 'dir')
            mkdir(case_ground_truths_dir);
        end
        
        % Find all main_*_results directories
        result_dirs = dir(fullfile(case_path, 'main_*_results'));
        result_dirs = result_dirs([result_dirs.isdir]);
        
        for j = 1:length(result_dirs)
            result_dir_name = result_dirs(j).name;
            result_path = fullfile(case_path, result_dir_name);
            
            fprintf('  Processing results directory: %s\n', result_dir_name);
            
            % Extract study type from result_dir_name
            % e.g., main_pendulum_case1_results -> case1
            % e.g., main_lorenz_sigmaStudy_results -> sigmaStudy
            % e.g., main_duffing_results -> main
            study_type = extract_study_type(result_dir_name, case_name);
            
            % Create subfolder for this study type
            % e.g., tests/integration/pendulum/ground_truths/case1/
            study_output_dir = fullfile(case_ground_truths_dir, study_type);
            if ~exist(study_output_dir, 'dir')
                mkdir(study_output_dir);
            end
            
            % Copy basin_stability_results.json to tests/integration if mapping exists
            json_key = [case_name, '/', result_dir_name];
            json_src = fullfile(result_path, 'basin_stability_results.json');
            if isKey(json_mapping, json_key) && exist(json_src, 'file')
                json_dst = fullfile(integration_test_base, json_mapping(json_key));
                copyfile(json_src, json_dst);
                fprintf('    Copied JSON to: %s\n', json_dst);
            end
            
            % Try to load results.mat
            mat_file = fullfile(result_path, 'results.mat');
            if ~exist(mat_file, 'file')
                fprintf('    No results.mat found, skipping\n');
                continue;
            end
            
            fprintf('    Loading: %s\n', mat_file);
            
            try
                data = load(mat_file);
                
                % Check if this is an adaptive parameter study (res_detail is cell of cells)
                if isfield(data, 'res_detail')
                    res_detail = data.res_detail;
                    
                    if iscell(res_detail) && ~isempty(res_detail)
                        % Check if first element is also a cell (adaptive parameter study)
                        if iscell(res_detail{1}) && size(res_detail{1}, 2) >= 3
                            % Adaptive parameter study: res_detail{i} contains results for parameter i
                            export_adaptive_parameter_results(res_detail, data, study_output_dir, result_dir_name);
                        else
                            % Single parameter set: res_detail is a cell array [N x 5]
                            export_single_results(res_detail, study_output_dir, result_dir_name);
                        end
                    else
                        fprintf('    Unexpected res_detail format, skipping\n');
                    end
                else
                    fprintf('    No res_detail variable found, skipping\n');
                end
                
            catch ME
                fprintf('    Error loading file: %s\n', ME.message);
            end
        end
    end
    
    fprintf('\n=== Export complete ===\n');
    fprintf('All files exported to: %s\n', integration_test_base);
end


function export_single_results(res_detail, output_dir, result_name)
% Export results from a single parameter set
%
% res_detail structure:
%   Column 1: ic_grid(i,:) - initial conditions (point coordinates)
%   Column 2: feature_array(i,:) - features  
%   Column 3: label (string like 'y1', 'y2', 'NaN')
%   Column 4: classification error
%   Column 5: bifurcation amplitudes

    n_samples = size(res_detail, 1);
    
    if n_samples == 0
        fprintf('    Empty res_detail, skipping\n');
        return;
    end
    
    % Determine number of state dimensions from first sample
    first_ic = res_detail{1, 1};
    n_states = length(first_ic);
    
    % Preallocate arrays
    coordinates = zeros(n_samples, n_states);
    labels = cell(n_samples, 1);
    
    % Extract data
    for i = 1:n_samples
        coordinates(i, :) = res_detail{i, 1};
        labels{i} = res_detail{i, 3};
    end
    
    % Create output filename
    output_name = strrep(result_name, '_results', '');
    output_file = fullfile(output_dir, [output_name, '.csv']);
    
    % Create table with proper column names
    col_names = cell(1, n_states + 1);
    for k = 1:n_states
        col_names{k} = sprintf('x%d', k);
    end
    col_names{n_states + 1} = 'label';
    
    % Combine coordinates and labels
    T = array2table(coordinates, 'VariableNames', col_names(1:n_states));
    T.label = labels;
    
    % Write to CSV
    writetable(T, output_file);
    fprintf('    Exported %d samples to: %s\n', n_samples, output_file);
end


function export_adaptive_parameter_results(res_detail, data, output_dir, result_dir_name)
% Export results from an adaptive parameter study
%
% res_detail is a cell array where res_detail{i} contains results for parameter value i
% Each res_detail{i} has the same structure as single results
%
% Also creates a parameter_index.csv file mapping parameter values to CSV files

    n_params = length(res_detail);
    
    % Try to get parameter values and name from props
    param_values = [];
    param_name = 'parameter';
    if isfield(data, 'props') && isfield(data.props, 'ap_study')
        if isfield(data.props.ap_study, 'ap_values')
            param_values = data.props.ap_study.ap_values;
        end
        if isfield(data.props.ap_study, 'ap_name')
            % Clean up LaTeX formatting from param name
            param_name = data.props.ap_study.ap_name;
            param_name = regexprep(param_name, '\$|\\mathrm\{|\}', '');
            param_name = strtrim(param_name);
        end
    end
    
    output_name = strrep(result_dir_name, '_results', '');
    
    % Prepare index data
    index_param_values = [];
    index_filenames = {};
    index_count = 0;
    
    for p = 1:n_params
        res_detail_p = res_detail{p};
        
        if isempty(res_detail_p)
            continue;
        end
        
        n_samples = size(res_detail_p, 1);
        
        % Determine number of state dimensions
        first_ic = res_detail_p{1, 1};
        n_states = length(first_ic);
        
        % Preallocate arrays
        coordinates = zeros(n_samples, n_states);
        labels = cell(n_samples, 1);
        
        % Extract data
        for i = 1:n_samples
            coordinates(i, :) = res_detail_p{i, 1};
            labels{i} = res_detail_p{i, 3};
        end
        
        % Create output filename with parameter value (use index as fallback)
        if ~isempty(param_values) && p <= length(param_values)
            param_val = param_values(p);
            csv_filename = sprintf('param_%03d.csv', p);
        else
            param_val = p;
            csv_filename = sprintf('param_%03d.csv', p);
        end
        
        output_file = fullfile(output_dir, csv_filename);
        
        % Create table with proper column names
        col_names = cell(1, n_states + 1);
        for k = 1:n_states
            col_names{k} = sprintf('x%d', k);
        end
        col_names{n_states + 1} = 'label';
        
        T = array2table(coordinates, 'VariableNames', col_names(1:n_states));
        T.label = labels;
        
        % Write to CSV
        writetable(T, output_file);
        fprintf('    Exported %d samples (param %d = %.6f) to: %s\n', n_samples, p, param_val, output_file);
        
        % Add to index
        index_count = index_count + 1;
        index_param_values(index_count) = param_val;
        index_filenames{index_count} = csv_filename;
    end
    
    % Write parameter index file
    if index_count > 0
        index_file = fullfile(output_dir, 'parameter_index.csv');
        index_table = table(index_param_values', index_filenames', ...
            'VariableNames', {'parameter_value', 'filename'});
        writetable(index_table, index_file);
        fprintf('    Created parameter index: %s\n', index_file);
    end
end


function study_type = extract_study_type(result_dir_name, case_name)
% Extract the study type from the result directory name
%
% Examples:
%   main_pendulum_case1_results, case_pendulum -> case1
%   main_lorenz_sigmaStudy_results, case_lorenz -> sigmaStudy
%   main_duffing_results, case_duffing -> main
%   main_friction_vStudy_results, case_friction -> vStudy

    % Remove 'main_' prefix and '_results' suffix
    name = result_dir_name;
    name = regexprep(name, '^main_', '');
    name = regexprep(name, '_results$', '');
    
    % Remove the case name part (e.g., 'pendulum', 'lorenz', 'duffing', 'friction')
    case_short = strrep(case_name, 'case_', '');
    name = regexprep(name, ['^', case_short, '_?'], '');
    
    % If nothing left, it's the main study
    if isempty(name)
        study_type = 'main';
    else
        study_type = name;
    end
end
