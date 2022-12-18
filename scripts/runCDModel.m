function headingEsts = runCDModel(nameValueArgs)
  %RUNCDMODEL Run Competitive Dynamics model through all or select stimuli
  arguments
    nameValueArgs.sampleNums (:, 1) double = -1;  % -1 means all
    nameValueArgs.settings struct = readSettings()
    nameValueArgs.runParallel logical = false
  end
  
  settings = nameValueArgs.settings;
  
  % Get stimulus directory
  inputDirPath = getExpPath(settings);
  % Get stimuli names
  sampleNames = listDirectory(inputDirPath);


  if numel(nameValueArgs.sampleNums) == 1 && nameValueArgs.sampleNums < 0
    sampleNums = 1:numel(sampleNames);
  else
    sampleNums = nameValueArgs.sampleNums;
  end

  % Load first sample to estimate number of frames
  numFrames = getNumFrames(fullfile(inputDirPath, sampleNames{1}, sampleNames{1}));
  if settings.io.nFrames > 0
    numFrames = min(numFrames, settings.io.nFrames);
  else
    
  end

  if settings.verbose.timeit
    tic;
  end
  
  if nameValueArgs.runParallel
    headingEsts = runParallel(settings, numFrames, sampleNums, sampleNames);
  else
    headingEsts = runSerial(settings, numFrames, sampleNums, sampleNames);
  end

  if settings.verbose.timeit
    toc;
  end
end

function headingEsts = runSerial(settings, numFrames, sampleNums, sampleNames)
  headingEsts = zeros(numFrames, numel(sampleNums));
  for s = 1:numel(sampleNums)
    ind = sampleNums(s);
    model = CDModel(config=settings);
    % Simulation returns heading estimates for each frame of video
    headingEsts(:, s) = model.simulate(sampleNames{ind});
  end
end

function headingEsts = runParallel(settings, numFrames, sampleNums, sampleNames)
  headingEsts = zeros(numFrames, numel(sampleNums));
  parfor s = 1:numel(sampleNums)
    ind = sampleNums(s);
    model = CDModel(config=settings);
    % Simulation returns heading estimates for each frame of video
    headingEsts(:, s) = model.simulate(sampleNames{ind});
  end
end

function numFrames = getNumFrames(path2Sample)
  load(path2Sample, 'Env');
  numFrames = numel(fieldnames(Env.x));
end

