function expPath = getExpPath(config, mode)
  %GETEXPPATH Uses the info in the config file to build the path to the experiment folder where the stimuli are
  %
  % We handle 'simulate' mode as follows:
  % if we have a train subfolder, use that. Otherwise, check for test. Otherwise work in current folder

  arguments
    config struct
    mode char {mustBeText} = 'simulate'
  end
  
  expPath = getIOPath(config, 'i', mode);
end

