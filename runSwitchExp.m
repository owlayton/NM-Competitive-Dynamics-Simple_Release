close all hidden;
exportResults = true;

[swEsts, nswEsts, swLabels, nswLabels, bias_means, bias_stdevs] = simulateSwitchNoSwitch(runParallel=true);

plotFrame = 34;
plotSwitchInitHeadingBias(plotFrame, swLabels, bias_means, bias_stdevs);

if exportResults
  expPath = 'results/switchExp';
  % Labels
  writetable(swLabels, fullfile(expPath, 'labels_sw.csv'));
  % Mean bias
  save(fullfile(expPath, 'bias_sw.mat'), 'bias_means', 'bias_stdevs', '-v7');
end