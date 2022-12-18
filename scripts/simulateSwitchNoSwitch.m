function [swEsts, nswEsts, swLabels, nswLabels, bias_means, bias_stdevs] = simulateSwitchNoSwitch(nameValueArgs)
  arguments
    nameValueArgs.settings struct = readSettings();
    nameValueArgs.sampleNums (:, 1) double = -1;  % -1 means all
    nameValueArgs.runParallel logical = true;
    nameValueArgs.plot logical = false;
    nameValueArgs.switchDatasetName char = "Switch";
    nameValueArgs.noSwitchDatasetName char = "NoSwitch";
  end
  settings = nameValueArgs.settings;
  
  % Run model with current settings on all switch stimuli, get the heading estimates on each frame
  [swEsts, swLabels] = simulate_ds(nameValueArgs.switchDatasetName);
  % Run model with current settings on all no-switch stimuli, get the heading estimates on each frame
  [nswEsts, nswLabels] = simulate_ds(nameValueArgs.noSwitchDatasetName);
  
  % Compute heading bias: for each final switch angle, subtract off the mean noSwitch estimate
  [bias_means, bias_stdevs] = computeHeadingBias(nswEsts, swEsts, swLabels, nswLabels);
  
  if nameValueArgs.plot
    plotSwitchInitHeadingBias()
  end
  
  function [ests, labels] = simulate_ds(name)
    % Override the switch/no-switch dataset name
    settings.io.experiment_name = name;
    % Read in the dataset labels
    labels = getLabels(getExpPath(settings));
    
    % Simulate model on dataset
    ests = runCDModel(...
      settings=settings, ...
      sampleNums=nameValueArgs.sampleNums, ...
      runParallel=nameValueArgs.runParallel);
    
    % Prune labels if simulated subset of samples
    if all(nameValueArgs.sampleNums > 0)
      labels = labels(nameValueArgs.sampleNums, :);
    end
  end
end

function labels = getLabels(path2labels)
  % Set path to stimulus labels
  labelFilePath = fullfile(path2labels, 'labels.csv');
  % Load in stimulus labels
  labels = readtable(labelFilePath);
  
  labels = createDerivedLabels(labels);
  
  function labels = createDerivedLabels(labels)
    % Handle no switch case. Final heading = initial heading
    if ~inStr('obs_heading_drift', labels.Properties.VariableNames)
      labels.obs_heading_drift = zeros(numel(labels.obs_heading_x), 1);
    end
    
    % We are interested in final heading to compute heading error.
    labels.obs_final_heading = labels.obs_heading_x + labels.obs_heading_drift;
  end
end

function [bias_means, bias_stdevs] = computeHeadingBias(nswEsts, swEsts, swLabels, nswLabels)
  numFrames = size(swEsts, 1);
  
  init_headings = unique(swLabels.obs_heading_x);
  numInitHeadings = numel(init_headings);
  
  swAngles = unique(swLabels.obs_heading_drift);
  numSw = numel(swAngles);
  
  bias_means = zeros(numInitHeadings, numSw, numFrames);
  bias_stdevs = zeros(numInitHeadings, numSw, numFrames);
  for f = 1:numFrames
    for h = 1:numInitHeadings
      for s = 1:numSw
        currFinalHeading = init_headings(h) + swAngles(s);
        curr_nsw_ests = nswEsts(f, nswLabels.obs_final_heading == currFinalHeading);
        curr_sw_ests = swEsts(f, swLabels.obs_heading_x == init_headings(h) & swLabels.obs_heading_drift == swAngles(s));
        diff_curr_final_h = curr_sw_ests - curr_nsw_ests;
        
        % Average reps: samples with the same initial heading + switch angle
        bias_means(h,s,f) = mean(diff_curr_final_h, 'all');
        bias_stdevs(h,s,f) = std(diff_curr_final_h, [], 'all');
      end
    end
  end
  
  % Enforce convention: + bias means toward init heading. Negate Pos switch angles
  bias_means(:, swAngles > 0, :) = -bias_means(:, swAngles > 0, :);
end