function ROItimeSeries = GridROIs2timeSeries_ColorCorrect(varargin)
% GridROIs2timeSeries_ColorCorrect
%
% This script extracts grid-based ROI time-series data from a video file that
% shows an LED grid array (e.g., used for VLC). The user first selects a 
% quadrilateral ROI (four corners) and then scrubs through the video until a 
% calibration frame is found (by pressing 'c'). In the calibration phase, the 
% user clicks several sample points for a set of reference colors (Red, Green, 
% Blue, White, and Black). A least squares solution is used to compute a 3x3 
% color correction matrix M such that M * [measured RGB]' ≈ [target RGB]'. 
%
% The script then displays the color corrected version of the calibration frame,
% and finally it reprocesses the entire video: each frame is cropped, color 
% corrected, and spatially averaged across the grid.
%
% 2025-03/04: Modified for color calibration, correction, and display of the
% calibrated frame.
%

close all;

%% Parameters
debug = true;
num_rows = 32;      % Number of grid rows
num_columns = 32;   % Number of grid columns
numCalibSamples = 3; % Number of calibration samples per reference color

% --- Video Selection ---
if nargin == 1
    [infilepath, infilename, infilext] = fileparts(varargin{1});
else
    [file, location] = uigetfile({...
        '*.tif;*.TIF;*.tiff;*.TIFF', 'TIFF files (*.tif, *.tiff)'; ...
        '*.mp4', 'MP4 files (*.mp4)'; ...
        '*.mj2', 'Motion JPEG 2000 (*.mj2)'; ...
        '*.*','All Files (*.*)'}, 'Open video file for analysis');
    [infilepath, infilename, infilext] = fileparts([location file]);
end

% --- Open video file ---
if contains(lower(infilext), 'tif')
    v = Tiff(fullfile(infilepath, [infilename infilext]), "r");
    imgWidth = getTag(v, 'ImageWidth');
    imgHeight = getTag(v, 'ImageLength');
else
    v = VideoReader(fullfile(infilepath, [infilename infilext]));
    imgWidth = v.Width;
    imgHeight = v.Height;
end

outfilePrefix = infilename + "_GridROItimeSeries_ColorCorrect";

%% ROI Selection: Ask user to click the four corners of the ROI quadrilateral
figure('Position', [50 50 imgWidth imgHeight], 'Color', 'black', ...
       'DefaultAxesFontSize', 20, 'DefaultAxesXColor', 'white', ...
       'DefaultAxesYColor', 'white', 'DefaultAxesColor', 'black');
axVideo = axes('Position', [0 0 1 1]);
hImage = image(zeros(imgHeight, imgWidth, 3), 'Parent', axVideo);
axis(axVideo, 'image', 'off');
hText = text(10, 10, "Click four corners of ROI quadrilateral, then press Return.", ...
              'Color', 'g', 'FontSize', 12, 'VerticalAlignment', 'top');

% Read initial frame
if contains(lower(infilext), 'tif')
    img = read(v);
else
    img = readFrame(v);
end
hImage.CData = img;

% Get the four corners
[xPoints, yPoints] = ginput(4);
xPoints = round(xPoints);
yPoints = round(yPoints);
hold on; 
plot(xPoints, yPoints, 'ro', 'MarkerFaceColor', 'r');

%% Perspective Transform Setup
inputPts = [xPoints, yPoints];
outputPts = [1, 1; imgWidth, 1; imgWidth, imgHeight; 1, imgHeight];
tform = fitgeotrans(inputPts, outputPts, 'projective');

%% Scrub for Calibration Frame
% Create a figure for scrubbing through the transformed video.
scrubFig = figure('Position', [50 50 round(imgWidth/2) round(imgHeight/2)], ...
                  'Name', 'Scrub Through Video');
calib_ax = axes('Parent', scrubFig);
% Get the first transformed frame
calibFrame = imwarp(img, tform, 'OutputView', imref2d([imgHeight, imgWidth]));
hCalibImage = imshow(calibFrame, 'Parent', calib_ax);
title(calib_ax, 'Use right arrow to advance frames. Press "c" to capture this frame for calibration.');

% Set up key press callback for scrubbing.
frameCounter = 1;
set(scrubFig, 'KeyPressFcn', @keyPressCalib);
uiwait(scrubFig);  % Wait until user selects a calibration frame

%% Calibration: Collect calibration samples for known target colors
% Define the reference colors and their target RGB values.
refColors = {'Red','Green','Blue','White','Black'};
refColors = {'Red3', 'Red2', 'Red1', 'Green3','Green2','Green1','Blue3','Blue2','Blue1','White','Black'};
targetVals = [255 0 0; 0 255 0; 0 0 255; 255 255 255; 0 0 0];
targetVals = [255 170 85 0 0 0 0 0 0 255 0;
               0   0   0 255 170 85 0 0 0 255 0;
               0   0   0 0   0   0  255 170 85 255 0];

measuredSamples = [];
targetSamples   = [];

calibFig = figure('Position',[100 100 imgWidth imgHeight], 'Name','Calibration Samples');
imshow(calibFrame);
title('Calibration: Follow prompts to select calibration samples.');
pause(0.5);

for i = 1:length(refColors)
    colorName = refColors{i};
    % For each reference color, collect numCalibSamples samples.
    for s = 1:numCalibSamples
        prompt = sprintf('Click sample %d for %s color', s, colorName);
        hPrompt = text(10, 10, prompt, 'Color','y','FontSize',12, 'BackgroundColor','k');
        [x, y] = ginput(1);
        delete(hPrompt);
        x = round(x); y = round(y);
        % Average a small region (e.g., 5x5 window with radius 2)
        r = 1;
        x1 = max(x-r, 1);
        x2 = min(x+r, size(calibFrame,2));
        y1 = max(y-r, 1);
        y2 = min(y+r, size(calibFrame,1));
        region = calibFrame(y1:y2, x1:x2, :);
        avgColor = squeeze(mean(mean(double(region),1),2));  % use double for calculations
        measuredSamples = [measuredSamples, avgColor];
        % Append target value for this reference color
        targetSamples = [targetSamples, targetVals(:,i)];
        % Mark the click for visual feedback.
        hold on; plot(x, y, 'wo', 'MarkerSize',10, 'LineWidth',2);
    end
end

%% Compute Least Squares Color Correction Matrix
% We want to find a 3x3 matrix M so that for every calibration sample:
% M * (measured RGB)' ≈ (target RGB)'.
% Organize measuredSamples and targetSamples as n x 3 arrays.
%
% The least squares solution is obtained via:
%    M' = pinv(measuredSamples) * targetSamples
disp(size(measuredSamples)); disp(size(targetSamples)); disp(targetSamples);
M_transpose = pinv(measuredSamples') * targetSamples';
M = M_transpose';
disp(M);
% M = [1.47715137910082	-0.225321836527008	-0.0681522444278200;
% -0.623189500027660	1.71232207951406	-0.360895924279945;
% 0.708457616464191	-1.62154220981392	1.91601125138607];
%% Display the Color Corrected Calibration Frame
% Apply the computed color correction to the calibration frame to verify the result.
[h, w, ch] = size(calibFrame);
reshaped_calib = double(reshape(calibFrame, [h*w, ch]));
corrected_pixels = reshaped_calib * M';
corrected_pixels = uint8(min(max(corrected_pixels, 0), 255));
calibFrameCorrected = reshape(corrected_pixels, [h, w, ch]);

figure('Name', 'Color Corrected Calibration Frame');
imshow(calibFrameCorrected);
title('Color Corrected Calibration Frame');

%% Process the Entire Video and Apply Color Correction
% We now re-read the video from the start and process each frame.
% Each frame is warped, color-corrected, and then divided into grid cells.
maxFrames = 2150;  % adjust as necessary for your video length
ROItimeSeries = zeros(num_rows*num_columns, maxFrames, 3, 'uint8');
frameNum = 1;

% Reset video to the beginning.
if contains(lower(infilext), 'tif')
    v.setDirectory(1);
    img = read(v);
else
    v.CurrentTime = 0;
    img = readFrame(v);
end

while true
    % Apply perspective transform to crop to the LED array.
    imgTransformed = imwarp(img, tform, 'OutputView', imref2d([imgHeight, imgWidth]));
    
    % --- Apply color correction ---
    % Reshape the image to a list of pixels and convert to double.
    [h, w, ch] = size(imgTransformed);
    reshaped = double(reshape(imgTransformed, [h*w, ch]));
    % Apply the correction: each pixel becomes M * pixel.
    correctedPixels = reshaped * M';
    % Clip the corrected values to the valid range [0, 255] and convert to uint8.
    correctedPixels = uint8(min(max(correctedPixels, 0), 255));
    imgCorrected = reshape(correctedPixels, [h, w, ch]);
    
    % Divide the corrected frame into grid cells and compute average RGB.
    cellWidth = imgWidth / num_columns;
    cellHeight = imgHeight / num_rows;
    for row = 1:num_rows
        for col = 1:num_columns
            x1 = round((col - 1) * cellWidth) + 1;
            x2 = round(col * cellWidth);
            y1 = round((row - 1) * cellHeight) + 1;
            y2 = round(row * cellHeight);
            
            region = imgCorrected(y1:y2, x1:x2, :);
            idx = (row-1)*num_columns + col;
            ROItimeSeries(idx, frameNum, :) = uint8(mean(mean(double(region), 1), 2));
        end
    end
    
    % Advance to the next frame.
    if contains(lower(infilext), 'tif')
        if ~lastDirectory(v)
            nextDirectory(v);
            img = read(v);
            frameNum = frameNum + 1;
            if frameNum > maxFrames, break; end
        else
            break;
        end
    else
        if hasFrame(v)
            img = readFrame(v);
            frameNum = frameNum + 1;
            if frameNum > maxFrames, break; end
        else
            break;
        end
    end
    
    % Optionally show debugging info
    if debug
        hImage.CData = img;
        hText.String = "Frame " + num2str(frameNum);
        drawnow limitrate nocallbacks;
    end
end

% Trim any unused preallocated frames.
ROItimeSeries = ROItimeSeries(:, 1:frameNum, :);
save(outfilePrefix + ".mat", "ROItimeSeries", "xPoints", "yPoints", "frameNum", ...
     "infilepath", "infilename", "infilext", "M");

%% Nested Callback for Scrubbing
    function keyPressCalib(~, event)
        % This callback allows the user to navigate through transformed frames.
        % Right arrow: advance one frame.
        % 'c': select the current frame as the calibration frame.
        switch event.Key
            case 'rightarrow'
                % Advance frame.
                if contains(lower(infilext), 'tif')
                    if ~lastDirectory(v)
                        nextDirectory(v);
                        img = read(v);
                    else
                        return;
                    end
                else
                    if hasFrame(v)
                        img = readFrame(v);
                    else
                        return;
                    end
                end
                frameCounter = frameCounter + 1;
                calibFrame = imwarp(img, tform, 'OutputView', imref2d([imgHeight, imgWidth]));
                imshow(calibFrame, 'Parent', calib_ax);
                title(calib_ax, "Frame " + num2str(frameCounter) + ". Press 'c' to capture this frame for calibration.");
            case 'c'
                % User confirms selection of the current frame.
                calibFrame = imwarp(img, tform, 'OutputView', imref2d([imgHeight, imgWidth]));
                uiresume(scrubFig);
                close(scrubFig);
        end
    end

end
