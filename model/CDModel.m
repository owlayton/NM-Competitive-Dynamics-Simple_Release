classdef CDModel < handle
  %CDMODEL Simplified version of the Competitive Dynamics model, similar to Layton, Mingolla & Browning (2012) JOV

  properties
    config
    temps  % MSTd templates. shape: MT rows, MT cols, FoE x, dx/dy
    numTemplates
    mt_ker_2d  % MT spatial smoothing kernel
    mstd_ker_1d  % MSTd match score smoothing kernel
  end

  methods
    function obj = CDModel(nameValueArgs)
      %CDMODEL Construct an instance of this class
      arguments
        nameValueArgs.config struct = readSettings()
      end
      obj.config = nameValueArgs.config;

      % Generate templates
      [obj.temps, obj.numTemplates] = obj.generateTemplates();

      % Generate MT 2D Gaussian kernel
      mt_sz = 2*obj.config.model.mt.radius+1;
      mt_sig = obj.config.model.mt.sigma;
      obj.mt_ker_2d = fspecial('gaussian', mt_sz, mt_sig);

      % Generate MSTd Gaussian kernel
      mstd_sz = [2*obj.config.model.mstd.radius+1, 1];
      mstd_sig = obj.config.model.mstd.sigma;
      obj.mstd_ker_1d = fspecial('gaussian', mstd_sz, mstd_sig);
    end

    function [temps, numTemplates] = generateTemplates(obj)
      % Radial templates distributed along horizon
      dims = obj.config.model.input.dims;

      rows = 1:dims(2);
      cols = 1:obj.config.model.templates.step:dims(1);
      [C, R] = meshgrid(cols, rows);

      numTemplates = numel(cols);

      % Generate templates with FoE prefs outside the field of view to pad convolution in MSTd.
      foePos = cols;
      leftPad = (-obj.config.model.mstd.radius+1):0;
      rightPad = max(foePos)+1:max(foePos)+obj.config.model.mstd.radius;
      foePos = [leftPad, foePos, rightPad];
      numFoEPos = numel(foePos);

      temps_x = single(C - shiftdim(foePos, -1));
      temps_y = repmat(single(R), 1, 1, numFoEPos);
      temps = cat(4, temps_x, temps_y);

      % Normalize & wt by inverse distance
      temps = temps ./ (eps + temps(:,:,:,1).^2 + temps(:,:,:,2).^2);
    end

    function bo_frames = getBlackoutFrames(obj)
      bo_type = obj.config.model.input.blackout.do;

      if inStr('no', bo_type)
        bo_frames = -1;
      else
        start = obj.config.model.input.blackout.start.(bo_type);
        numFrames = obj.config.model.input.blackout.numFrames;
        bo_frames = start:start+numFrames-1;
      end
    end

    function hEsts = simulate(obj, inputFilename)
      arguments
        obj
        inputFilename char
      end
      [flowStruct, numFrames] = obj.readOpticFlow(inputFilename);
      dims = flowStruct.dims;

      if obj.config.io.nFrames > 0 && obj.config.io.nFrames < numFrames
        numFrames = obj.config.io.nFrames;
      end

      % Handle blackout frames
      bo_frames = obj.getBlackoutFrames();

      % Placeholder for previous frame MSTd activation
      prevMSTdAct = zeros(obj.numTemplates, 1);
      % MSTd heading estimate on each frame
      hEsts = zeros(numFrames, 1);
      for f = 1:numFrames
        % Normal condition: we're not in a blackout frame
        if ~any(f == bo_frames)
          currFlowStruct = getCurrInput(flowStruct, f);
          % Convert current flow from array of indices to two 2D images
          currFlow = obj.flowInds2Image(currFlowStruct, dims);
          mtAct = obj.mt(currFlow);
          mstdAct = obj.mstd(prevMSTdAct, mtAct=mtAct, frame=f);
        else
          % Don't compute pre-MSTd when in a blackout frame
          mstdAct = obj.mstd(prevMSTdAct, mtAct=mtAct, frame=f);
        end

        prevMSTdAct = mstdAct;

        % Save heading estimate  in pixels
        hEsts(f) = px2deg(getHeadingEstimate(mstdAct));
      end
    end

    function mtAct = mt(obj, inputFlow)
      mtAct = zeros(size(inputFlow));

      % Spatial convolution of vector components independelty
      for i = 1:2
        mtAct(:,:,i) = conv2(inputFlow(:,:,i), obj.mt_ker_2d, 'same');
      end
    end

    function [act, est, estDeg] = mstd(obj, prevAct, nameValueArgs)
      arguments
        obj
        prevAct (:, 1) double
        nameValueArgs.mtAct single = 0
        nameValueArgs.frame (1,1) double
      end

      % Do template match: dot product between templates and mt vectors weighted by inverse distance
      mtAct = nameValueArgs.mtAct;
      mstdIn = squeeze(sum(obj.temps .* reshape(mtAct, [size(mtAct, 1:2), 1, size(mtAct, 3)]), [1, 2, 4]));
      % Smooth
      mstdInSmooth = conv(mstdIn, obj.mstd_ker_1d, 'same');
      % Select non-padded values to avoid edge effects
      edge = obj.config.model.mstd.radius;
      mstdInSmooth = mstdInSmooth(edge+1:end-edge);

      % Make sure non-padded result matches
      if obj.numTemplates ~= numel(mstdInSmooth)
        error('Mismatch between number of expected templates (%d) and actual number after removing padding (%d)', ...
          obj.numTemplates, numel(mstdInSmooth));
      end

      % Rectify
      mstdInSmooth = max(mstdInSmooth, 0);

      % Competitive network
      A = obj.config.model.mstd.A;
      B = obj.config.model.mstd.B;
      act = B*mstdInSmooth.^2 ./ (A + sum(mstdInSmooth.^2));

      % Exp moving average
      if nameValueArgs.frame ~= 1
        c = obj.config.model.mstd.c;
        act = c*prevAct + (1-c)*act;
      end

      % Plot activation
      if obj.config.model.plot.mstdAct
        figure(1);
        plot(act)
        % Get the current heading estimate in pixels
        est = getHeadingEstimate(act);
        % Get the current heading estimate in degrees
        estDeg = px2deg(est);
        title(sprintf('Frame %d heading: %.2f pix/%.2f deg\n', nameValueArgs.frame, est, estDeg));

        if nameValueArgs.frame < 28 || nameValueArgs.frame > 34
          pause(0.1);
        else
          pause(0.5);
        end
      elseif obj.config.verbose.heading
        fprintf('Frame %d heading: %.2f pix/%.2f deg\n', nameValueArgs.frame, est, estDeg);
      end
    end

    function [Env, numFrames] = readOpticFlow(obj, inputFilename)
      inputPath = fullfile(getExpPath(obj.config), inputFilename);
      load(fullfile(inputPath, inputFilename), 'Env');

      % Figure out number of frames
      numFrames = numel(fieldnames(Env.x));
    end

    function flow = flowInds2Image(obj, currFlowStruct, dims)
      % Image representation of flow: numRows x numCols
      flow_dx = zeros(dims, "single");
      flow_dy = zeros(dims, "single");
      % Convert subscripts to linear inds
      inds = sub2ind(dims, currFlowStruct.y, currFlowStruct.x);
      % Fill in values
      flow_dx(inds) = currFlowStruct.dx;
      flow_dy(inds) = currFlowStruct.dy;
      % Concatenate flow: : numRows x numCols x xy
      flow = cat(3, flow_dx, flow_dy);
      % Normalize each vector to length 1
      flow = flow ./ sqrt(eps + flow(:,:,1).^2 + flow(:,:,2).^2);

      % Visualize
      if obj.config.model.plot.input
        figure(2);
        quiver(flow(:,:,1), flow(:,:,2));
      end
    end
  end
end

function inputStruct = getCurrInput(flowStruct, frameNum)
  frameLabel = getFrameLabel(frameNum);
  inputStruct.x = flowStruct.x.(frameLabel);
  inputStruct.y = flowStruct.y.(frameLabel);
  inputStruct.dx = flowStruct.dx.(frameLabel);
  inputStruct.dy = flowStruct.dy.(frameLabel);
end

function est = getHeadingEstimate(act)
  arguments
    act (:, 1) double
  end

  % Population vector decoding
  N = numel(act);
  % Center
  x = (1:N)' - (N+1)/2;
  % Compute centroid then uncenter
  est = sum(x .* act) ./ sum(act, "all") + (N+1)/2;
end

function estDeg = px2deg(est, nameValueArgs)
  arguments
    est (:,1) double
    nameValueArgs.fov (1,1) double = 90
    nameValueArgs.pxRes (1,1) double = 128
  end

  halfPxRes = nameValueArgs.pxRes/2;
  estCent = est - halfPxRes;
  estDeg = estCent*(nameValueArgs.fov/nameValueArgs.pxRes);
end
