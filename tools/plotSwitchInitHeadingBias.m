function plotSwitchInitHeadingBias(frame, labels, bias_means, bias_stdevs)
  
  swAngles = unique(labels.obs_heading_drift);
  initHeadings = unique(labels.obs_heading_x);
  
  markers = ["^", "s", "o"];
  colors = ["r", "g", "b"];
  
  figure(5);
  for h = 1:numel(initHeadings)
    % Plot current frame error
    errorbar(swAngles, bias_means(h,:,frame), bias_stdevs(h,:,frame), "-"+markers(h)+colors(h));
    if h == 1
      hold on;
    end
  end
  yline(0, '--');
  leg = legend(['6', char(176)], ['0', char(176)], ['-6', char(176)], Location='northoutside');
  title(leg, 'Initial heading')
  hold off;
end