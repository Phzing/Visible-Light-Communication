function tifVideoPlayer()
    % Open file selection dialog
    [fileName, filePath] = uigetfile('*.tif', 'Select a TIF Video');
    if isequal(fileName, 0)
        disp('No file selected.');
        return;
    end
    tifFile = fullfile(filePath, fileName);
    
    % Read the .tif video
    info = imfinfo(tifFile);
    numFrames = numel(info);
    videoData = cell(1, numFrames);
    for k = 1:numFrames
        videoData{k} = imread(tifFile, k);
    end
    
    % Create GUI components
    fig = figure('Name', 'TIF Video Player', 'NumberTitle', 'off', 'Position', [100, 100, 600, 500]);
    ax = axes('Parent', fig, 'Position', [0.1, 0.3, 0.8, 0.65]);
    imgHandle = imshow(videoData{1}, []);
    
    % Play Button
    playButton = uicontrol('Style', 'pushbutton', 'String', 'Play', 'Position', [250, 50, 100, 40], 'Callback', @playVideo);
    
    % Scroll Bar
    slider = uicontrol('Style', 'slider', 'Min', 1, 'Max', numFrames, 'Value', 1, 'Position', [100, 20, 400, 20], 'Callback', @sliderCallback);
    addlistener(slider, 'ContinuousValueChange', @(src, event) updateFrame(round(get(slider, 'Value'))));
    
    isPlaying = false;
    
    function playVideo(~, ~)
        if isPlaying
            isPlaying = false;
            playButton.String = 'Play';
        else
            isPlaying = true;
            playButton.String = 'Pause';
            for frame = round(get(slider, 'Value')):numFrames
                if ~isPlaying
                    break;
                end
                set(slider, 'Value', frame);
                updateFrame(frame);
                pause(0.05); % Adjust playback speed
            end
            isPlaying = false;
            playButton.String = 'Play';
        end
    end
    
    function sliderCallback(~, ~)
        updateFrame(round(get(slider, 'Value')));
    end
    
    function updateFrame(frameIdx)
        imgHandle.CData = videoData{frameIdx};
    end
end
