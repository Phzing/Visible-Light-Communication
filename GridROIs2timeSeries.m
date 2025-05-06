function ROItimeSeries = GridROIs2timeSeries(varargin)
%function ROItimeSeries = videoGridROIs2timeSeries 
% Extracts time-series data from a video, based on a grid of ROIs
% defined within a quadrilateral region, and stores average RGB values
% for each grid cell across time.
% 
% 2025-03: Written to extract grid-based ROIs from a video.
% 

%close all;

%% Parameters
debug = false;
num_rows = 64;  % Number of rows in the grid
num_columns = 64;  % Number of columns in the grid

%% Decide on full filename
if nargin == 1
    fullFileName = varargin{1};
    if ~ischar(fullFileName) && ~isstring(fullFileName)
        error("Input must be a character vector or string scalar.");
    end
    if exist(fullFileName,'file')~=2
        error("Could not find file:\n  %s", fullFileName);
    end
else
    [file, path] = uigetfile( ...
        {'*.mp4;*.mj2;*.tif;*.tiff','Video & TIF Files (*.mp4,*.mj2,*.tif,*.tiff)'}, ...
        'Select video or TIF for analysis');
    if isequal(file,0)
        error("No file selected.");
    end
    fullFileName = fullfile(path,file);
end

%% Split it apart once
[infilepath, infilename, infilext] = fileparts(fullFileName);
outfilePrefix = infilename + "_GridROItimeSeries";

%% Open video or TIF
if any(strcmpi(infilext,{'.tif','.tiff'}))
    v = Tiff(fullFileName,"r");
    imgWidth  = getTag(v,'ImageWidth');
    imgHeight = getTag(v,'ImageLength');
else
    v = VideoReader(fullFileName);
    imgWidth  = v.Width;
    imgHeight = v.Height;
end

% if nargin == 1
%     [infilepath, infilename, infilext] = fileparts(varargin{1});
% else
%     [file, location] = uigetfile({'*.mp4';'*.mj2';'*.tif;*.tiff';'*.*'}, 'Open video file for analysis');
%     [infilepath, infilename, infilext] = fileparts([location file]);
% end
% 
% % Open video
% if contains(infilext, 'tif')  % Handle TIFF files
%     v = Tiff([infilepath filesep infilename infilext], "r");
%     imgWidth = getTag(v, 'ImageWidth');
%     imgHeight = getTag(v, 'ImageLength');
% else  % Handle video files
%     v = VideoReader([infilepath filesep infilename infilext]);
%     imgWidth = v.Width;
%     imgHeight = v.Height;
% end
% 
% outfilePrefix = infilename + "_GridROItimeSeries";

%% Open video, ask user for quadrilateral ROIs
figure('Position', [50 50 imgWidth imgHeight], 'Color', 'black', 'DefaultAxesFontSize', 20, 'DefaultAxesXColor', 'white', 'DefaultAxesYColor', 'white', 'DefaultAxesColor', 'black');
axVideo = axes('Position', [0 0 1 1]);
hImage = image(zeros(imgHeight, imgWidth, 3), 'Parent', axVideo);
axis(axVideo, 'image', 'off');
%hText = text(0, 0, "Click four corners of the ROI quadrilateral, then press 'Return'.", ...
%        'color', 'g', 'FontSize', 12, 'VerticalAlignment', 'top', 'parent', axVideo);

% Read initial frame
if contains(infilext, 'tif')
    img = read(v);
else
    img = readFrame(v);
end
hImage.CData = img;

% % Get user-defined quadrilateral points (4 points)
% [xPoints, yPoints] = ginput(4);
% xPoints = round(xPoints);
% yPoints = round(yPoints);
% disp([xPoints, yPoints]);
%%automatic corner id
%Parameters
sensitivity = 0.3;
noiseSizePixels = 500;
corners = findLEDCorners(img, sensitivity, noiseSizePixels);
xPoints = round(corners(:,1));
yPoints = round(corners(:,2));
disp([xPoints, yPoints]);

% Mark ROI locations
hold on;
plot(xPoints, yPoints, 'ro', 'MarkerFaceColor', 'r');

%% Calculate perspective transform matrix
inputPts = [xPoints, yPoints];  % 4 points from the user
outputPts = [1, 1; imgWidth, 1; imgWidth, imgHeight; 1, imgHeight];  % Target rectangle (1,1) to (imgWidth, imgHeight)
tform = fitgeotrans(inputPts, outputPts, 'projective');

%% Read remaining frames
frameNum = 1;
ROItimeSeries = zeros(num_rows*num_columns, 1, 3);  % num_rows x num_columns x frames x 3 colors
frameNum = 1;

while true
    % Apply the perspective transform to the current frame
    imgTransformed = imwarp(img, tform, 'OutputView', imref2d([imgHeight, imgWidth]));

    % Define grid cell size after transformation
    cellWidth = imgWidth / num_columns;
    cellHeight = imgHeight / num_rows;

    % Extract average RGB values for each grid cell
    for row = 1:num_rows
        for col = 1:num_columns
            % Define the grid's bounding box for this cell
            x1 = round((col - 1) * cellWidth) + 1;
            x2 = round(col * cellWidth);
            y1 = round((row - 1) * cellHeight) + 1;
            y2 = round(row * cellHeight);
            
            % Extract the region and compute the average RGB values
            region = imgTransformed(y1:y2, x1:x2, :);
            idx = (row-1)*num_columns + col;
            ROItimeSeries(idx, frameNum, :) = mean(mean(region, 1), 2);  % Averaging over the grid square

        end
    end

    % Read the next frame if available
    if contains(infilext, 'tif')
        if ~lastDirectory(v)
            nextDirectory(v);
            img = read(v);
            frameNum = frameNum + 1;
            if frameNum==2150
                break
            end
        else
            break;
        end
    else
        if v.hasFrame
            img = readFrame(v);
            frameNum = frameNum + 1;
            if frameNum==2150
                break
            end
        else
            break;
        end
    end
    
    % Debug: show video being read
    if debug
        hImage.CData = img;
        hText.String = "Frame " + num2str(frameNum);
        drawnow limitrate nocallbacks;
    end
end

% Write data to a file
save(outfilePrefix + ".mat", "ROItimeSeries", "xPoints", "yPoints", "frameNum", "infilepath", "infilename", "infilext");

%% Plot ROI intensities
% figure;
% for row = 1:num_rows
%     for col = 1:num_columns
%         subplot(num_rows, num_columns, (row - 1) * num_columns + col);
%         plot(squeeze(ROItimeSeries(row, col, :, 1)));
%         title(['Cell (' num2str(row) ',' num2str(col) ')']);
%         xlabel('Frame number');
%         ylabel('R values');
%     end
% end
end
