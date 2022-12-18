function expPath = getIOPath(config, ioChar, mode)
  %GETEXPBASEPATH Uses the info in the config file to build the path to the experiment folder where the stimuli are
  %
  % We handle 'simulate' mode as follows:
  % if we have a train subfolder, use that. Otherwise, check for test. Otherwise work in current folder

  arguments
    config struct
    ioChar char {mustBeIO(ioChar)}
    mode char {mustBeText} = 'simulate'
  end
  
  if strcmpi(ioChar, 'i')
    basePathStr = 'stimulusPath';
  else
    basePathStr = 'exportPath';
  end

  basePath = checkPC(config, basePathStr);
  expPath = getFullPath(config, basePath);
  
  % Are we returning train/test subfolders?
  useTrainPath = inStr("train", mode);
  useTestPath = inStr("test", mode);

  % Check to see if the stimulus dir has train/test subfolders
  stimulusPath = checkPC(config, 'stimulusPath');
  stimulusPath = getFullPath(config, stimulusPath);

  if exist(fullfile(stimulusPath, 'train'), 'dir') && useTrainPath
    expPath = fullfile(expPath, 'train');
  elseif exist(fullfile(stimulusPath, 'test'), 'dir') && useTestPath
    expPath = fullfile(expPath, 'test');
  end
end

function mustBeIO(ioChar)
    % Test that proper code for stimulus (i) or export(o)
    if ~(strcmp(ioChar, 'i') || strcmp(ioChar, 'o'))
        eid = 'IOChar';
        msg = 'Indicator char for getting IO folder should be i for stimulus dir or o for export dir';
        throwAsCaller(MException(eid, msg))
    end
end

function basePath = checkPC(config, basePathStr)
  if ispc
    basePath = config.io.(basePathStr).pc;
  else
    basePath = config.io.(basePathStr).mac;
  end
end

function fullPath = getFullPath(config, basePath)
  fullPath = fullfile(basePath, config.io.year, config.io.project, config.io.experiment_name);
end
