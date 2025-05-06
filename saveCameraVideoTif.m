function saveCameraVideoTif()
% function saveCameraVideo()
% Grab N frames from the camera and save them to desk.
%
% Designed assuming the "gentl" hardware interface. (FLIR Blackfly S BFS-U3-16S2C)
% Package install link: https://www.mathworks.com/hardware-support/gentl.html
%
% Some useful links:
% https://www.mathworks.com/help/imaq/get-hardware-metadata-from-genicam-device.html
% https://www.mathworks.com/help/imaq/genicam-gentl-hardware.html
% https://www.mathworks.com/help/imaq/executecommand.html
% https://softwareservices.flir.com/BFS-U3-16S2/latest/Model/public/index.html
%
% use propinfo(), imaqhelp() to get more info on camera device parameters
% 
% 2024-09: Written for ESE 488, by Matthew Lew

clearvars;
close all;

% global status variable. 0 = stopped, 1 = preview, 2 = acquiring data
status = 0;

%% acqusition parameters
% white almost saturated, no gain
% exposureTime = 26000;   % μs
% gain = 0;   % dB (47.9943 max), higher gain = more electronic noise

% high gain
% exposureTime = 180;   % μs
% gain = 40;   % dB (47.9943 max), higher gain = more electronic noise

% medium gain
exposureTime = 4525;   % μs
%gain = 28;   % dB (47.9943 max), higher gain = more electronic noise
gain = 14;   % dB (47.9943 max), higher gain = more electronic noise


framesPerTrigger = 400; % how many frames to collect after sending start() command

% set up ROI parameters
binning = 1; % combine pixels together, e.g. by summing, see https://softwareservices.flir.com/BFS-U3-16S2/latest/Model/public/ImageFormatControl.html
% ROIPosition is specified as a 1-by-4 element vector [XOffset YOffset Width Height].
%ROIposition = [0 0 1440 1080]; 
ROIposition = [(1440-360)/2 (1080-360)/2 360 360]; % smaller FOV to go very fast

outfilePrefix = string(datetime,"yyyy-MM-dd HH.mm");
outFileFPS = 20;    % set frame rate of saved video file (only affects playback)

%% open camera
% formats supported by Blackfly camera:
% 'BGR8'	'BGRa8'	'BayerRG16'	'BayerRG8'	'Mono10Packed'	'Mono12Packed'	'Mono16'	'Mono8'	'RGB8Packed'	'YUV411Packed'	'YUV422Packed'	'YUV444Packed'
% 'BayerRG8' is an 8-bit color format (226 max fps w/ISP off, 76 max fps w/ISP on)
% 'BayerRG16' is a 16-bit color format (81 max fps w/ISP off, 76 max fps w/ISP on)
% See https://softwareservices.flir.com/BFS-U3-16S2/latest/Model/spec.html

vidDevice = videoinput("gentl",1,"BayerRG8","ROIPosition",ROIposition); 
%vidDevice = videoinput("gentl",1,"BayerRG16","ROIPosition",ROIposition);
vidSrc = getselectedsource(vidDevice);

%% acquisition parameters

% ISPENABLE enum 
% Controls whether the image processing core is used for optional pixel format modes (i.e. mono).
% Camera can go to faster frame rates if ISP is off.
vidSrc.IspEnable = 'False';
% vidSrc.IspEnable = 'True';

% Sets the operation mode of the Exposure. Mode for shutter/exposure control.
% Possible choices are: Off, Timed, TriggerWidth, and TriggerControlled
% Off disables the exposure and leaves the shutter open, Timed uses the 
% ExposureTime property and is not compatible with ExposureTimeAuto turned 
% on, and TriggerWidth and TriggerControlled require ExposureActive hardware 
% triggering to be used.
vidSrc.ExposureMode = 'Timed';

% Sets the automatic exposure mode when the ExposureMode is 'Timed'.
% Possible choices are: Off, Once, and Continuous.
%Once is a convergence method, while continuous is a continuous readjustment
%of exposure during acquisition.
vidSrc.ExposureAuto = 'Off';

% EXPOSURETIME double       [12 30000000]     
% Exposure time in microseconds when Exposure Mode is Timed.
% Sets the exposure time in microseconds (us) when ExposureMode is set to Timed.
vidSrc.ExposureTime = exposureTime;

% Specify whether or not to use the automatic gain control (AGC).
% Possible choices are: Off, Once, and Continuous and possibly device specific values.
% Once is a convergence method, while continuous is a continuous readjustment
% of gain during acquisition.
vidSrc.GainAuto = 'Off';

% GAIN double       [0 47.9943]      
% Controls the amplification of the video signal in dB.
vidSrc.Gain = gain;

% GAMMAENABLE enum         
% Enables/disables gamma correction.
% vidSrc.GammaEnable = "True";   
vidSrc.GammaEnable = "False";  

% BALANCEWHITEAUTO enum 
% White Balance compensates for color shifts caused by different lighting
% conditions and can be automatically or manually controlled.
% Specify the mode for the while balancing between the channels or taps.
% Possible choices are:
% Off, Once, and Continuous and possibly device specific values.
% Once is a convergence method, while continuous is a continuous readjustment 
% of white balance during acquisition.
%    See also PROPINFO, the various BalanceRatio, and the various BalanceRatioAbs properties.
vidSrc.BalanceWhiteAuto = "Off";

% BINNINGHORIZONTAL integer       [1 4]     
% Number of horizontal photo-sensitive cells to combine together.
% Sets the horizontal binning.  Changing this property will reset the 
% RegionOfInterest since the maximum image size changes.
%    See also PROPINFO, and BinningVertical.
vidSrc.BinningHorizontal = binning;
vidSrc.BinningVertical = binning;

% FRAMESPERTRIGGER          
% Specify the number of frames to acquire using the selected video source.
% By default, the object acquires 10 frames for each trigger.
% If FramesPerTrigger is set to Inf, the object keeps acquiring frames
% until an error occurs or you issue a STOP command. When FramesPerTrigger
% is set to Inf, the object ignores the value of the TriggerRepeat property.
% The value of FramesPerTrigger cannot be modified while the object is
% running. See also IMAQDEVICE/STOP.
vidDevice.FramesPerTrigger = framesPerTrigger;

%% enable chunk mode and get, set properties
% vidSrc.ChunkModeActive = "True";
% vidSrc.ChunkSelector = "FrameID";
% vidSrc.ChunkEnable = "True";
% vidSrc.ChunkSelector = "ExposureTime";
% vidSrc.ChunkEnable = "True";
% vidSrc.ChunkSelector = "Gain";
% vidSrc.ChunkEnable = "True";
% vidSrc.ChunkSelector = "Height";
% vidSrc.ChunkEnable = "False";
% vidSrc.ChunkSelector = "Width";
% vidSrc.ChunkEnable = "False";
% vidSrc.ChunkSelector = "BlackLevel";
% vidSrc.ChunkEnable = "True";
% vidSrc.ChunkSelector = "PixelFormat";
% vidSrc.ChunkEnable = "True";
% chunkinfo = chunkDataInfo(vidSrc);

%% set up preview window
% get image settings from camera
imWidth = ROIposition(3);
imHeight = ROIposition(4);
nColors = vidDevice.NumberOfBands;

% Create a figure window. This example turns off the default
% toolbar and menubar in the figure.
hFig = figure('Toolbar','none',...
       'Menubar', 'none',...
       'NumberTitle','Off',...
       'Name','Camera Preview and Acquisition', ...
       'Position',[50 50 imWidth imHeight]);

% Set up the push buttons
c = uicontrol('String', 'Save Video',...
    'Units','normalized',...
    'FontSize',11,...
    'Position',[0 0 0.15 .03]);
c.Callback = @saveVideo;
c = uicontrol('String', 'Stop Preview',...
    'Units','normalized',...
    'FontSize',11,...
    'Position',[0.16 0 0.15 .03]);
c.Callback = @togglePreview;
uicontrol('String', 'Close',...
    'Callback', 'close(gcf)',...
    'Units','normalized',...
    'FontSize',11,...
    'Position',[0.32 0 0.15 .03]);

% Create the text label for the timestamp
hTextLabel = uicontrol('style','text','String','Image Info', ...
    'Units','normalized',...
    'FontSize',11,...
    'Position',[0.5 -.04 .5 .08]);

% Create the image object in which you want to
% display the video preview data.
hImage = image( zeros(imHeight, imWidth, nColors) );

% Specify the size of the axes that contains the image object
% so that it displays the image at the right resolution and
% centers it in the figure window.
figSize = get(hFig,'Position');
figWidth = figSize(3);
figHeight = figSize(4);
gca.unit = 'pixels';
gca.position = [ ((figWidth - imWidth)/2)... 
               ((figHeight - imHeight)/2)...
               imWidth imHeight ];

% Set up the update preview window function.
setappdata(hImage,'UpdatePreviewWindowFcn',@updateWindow);
% Make handle to text label available to update function.
setappdata(hImage,'hTextLabel',hTextLabel);

%% start preview
preview(vidDevice, hImage);
status = 1;

%% helper functions
function updateWindow(obj,event,hImageLocal)
% Example update preview window function.

% Get handle to text label uicontrol.
hTextLabelLocal = getappdata(hImageLocal,'hTextLabel');

% Set the value of the text label.
switch status
    case 1
        hTextLabelLocal.String = event.Timestamp + ": " + event.Status + ", Resolution: " + event.Resolution ...
            + ", Frame rate: " + event.FrameRate + " fps";
    case 2
        hTextLabelLocal.String = vidDevice.FramesAvailable + " frames acquired";
end

% Display image data.
hImageLocal.CData = event.Data;
end

%% **********************************************************
function togglePreview(src,event)
switch status 
    case 0
        % start preview
        preview(vidDevice, hImage);
        status = 1;
        src.String = "Stop Preview";
    case 1
        % stop preview
        closepreview(vidDevice);
        status = 0;
        src.String = "Start Preview";
end
end

%% **********************************************************
function saveVideo(src,event)
% stop preview
closepreview(vidDevice);
status = 0;

hTextLabelLocal = getappdata(hImage,'hTextLabel');

% start image capture
start(vidDevice);
status = 2;
% wait for image capture
while vidDevice.FramesAvailable < framesPerTrigger
    hTextLabelLocal.String = vidDevice.FramesAvailable + "/" + framesPerTrigger + " frames acquired";
    drawnow limitrate nocallbacks
end
% grab data from vidDevice object, getdata will block execution
[imageStack, timestamp, metadata] = getdata(vidDevice);
hTextLabelLocal.String = "Saving data " + outfilePrefix + "...";
drawnow limitrate nocallbacks

numFrames = size(imageStack,4);
colorSpace = vidDevice.ReturnedColorSpace;
frameRate = vidSrc.AcquisitionFrameRate;
IspEnable = vidSrc.IspEnable;
ROIposition = vidDevice.ROIPosition;
frameID = [];
exposureTimeData = [];
cameraGain = [];
blackLevel = [];
pixelFormat = [];
for a=1:numFrames
    % frameID = [frameID; metadata(a).ChunkData.FrameID];
    % exposureTimeData = [exposureTimeData; metadata(a).ChunkData.ExposureTime];
    % cameraGain = [cameraGain; metadata(a).ChunkData.Gain];
    % blackLevel = [blackLevel; metadata(a).ChunkData.BlackLevel];
    % pixelFormat = [pixelFormat; metadata(a).ChunkData.PixelFormat];
end

% save all data to matlab file (raw images are too big)
save(outfilePrefix + "_videoMetadata.mat","colorSpace","numFrames","frameRate",...
    "frameID","timestamp","exposureTimeData","cameraGain","blackLevel","pixelFormat",...
    "IspEnable","ROIposition");

% write video to tif for 16-bit output (avoids mj2 bug
% https://www.mathworks.com/support/bugreports/3099984)
t = Tiff(outfilePrefix + "_video.tif","w");
% need to initialize tif metadata before writing image data
tagstruct.Photometric=Tiff.Photometric.RGB;
tagstruct.Compression=Tiff.Compression.AdobeDeflate; % better than LZW?
if contains(class(imageStack),"uint8") % bit depth
    tagstruct.BitsPerSample=8;
else
    tagstruct.BitsPerSample=16;
end
tagstruct.SamplesPerPixel=3; % 3 colors
tagstruct.SampleFormat=Tiff.SampleFormat.UInt;
tagstruct.ImageLength=imHeight;
tagstruct.ImageWidth=imWidth;
tagstruct.PlanarConfiguration=Tiff.PlanarConfiguration.Chunky;
% need to write video frame-by-frame, store each image in new "directory"
% within same tif file
for a=1:numFrames
    if a>1
        % need to prepare to write another image to file
        writeDirectory(t);
    end
    
    % write data to file
    setTag(t,tagstruct);
    write(t,imageStack(:,:,:,a));
end
close(t);

% clean up video hardware object, close gui to signal end of data collection
% delete(vidDevice)
% clear vidDevice
close(gcf);

%% analyze images

% % plot timing interval between frames
% figure;
% plot(diff(timestamp)*1E3,'.'); hold on;   % convert s to ms
% plot([1 numFrames-1],exposureTimeData(1)*1E-3*[1 1],'r');   % convert μs to ms
% plot([1 numFrames-1],1E3/frameRate*[1 1],'r--');   % convert s to ms
% title("Frame rate: " + frameRate + " fps, exposure time: " + num2str(exposureTimeData(1)*1E-3) + " ms");
% xlabel("Frame index");
% ylabel("Interval between exposures (ms)");


end

end