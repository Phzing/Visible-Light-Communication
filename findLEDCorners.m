function corners = findLEDCorners(img, sensitivity, noiseSizePixels) % noiseSizePixels should be estimated to slightly smaller than size of LED array? 
    gray = rgb2gray(img);
    sigma = 2;
    grayBlur = imgaussfilt(gray, sigma);

    bw = imbinarize(grayBlur, 'adaptive', ...  % Compute threshold locally (good for non-uniform lighting?)
        'ForegroundPolarity', 'bright', ...  % Indicates that target object is darker than surroundings (LED array = Black when off)
        'Sensitivity', sensitivity);       % The lower the sensitivity, the darker an area has to be to be marked as foreground. Parts of LED missing --> increase sens
    %bw = ~bw;                              % Previously targeted black values, so flip
    bw = bwareaopen(bw, noiseSizePixels);  % Remove noise

    % Get largest region
    stats = regionprops(bw, 'Area', 'PixelIdxList');
    [~, idx] = max([stats.Area]);          % Find largest connected black region from bw
    mask = false(size(bw));
    mask(stats(idx).PixelIdxList) = true;  % Translate indices to actual img locations

    % Get boundary
    B = bwboundaries(mask);                % Boundary of the mask (from largest region, hopefully the LED array)
    boundary = B{1};                       % Actual coordinates of the boundary...
    x = boundary(:,2);                     % x-values
    y = boundary(:,1);                     % y-values
    
    % Compute scores for each direction
    sumXY = x + y;
    diffXY = x - y;

    % Identify corners based on geometric extremes. This should work as
    % long as the LED array is approximately rectangular + flat (i.e. ■, and
    % NOT ◆).
    [~, idx1] = min(sumXY);  % top-left
    [~, idx2] = max(diffXY); % top-right
    [~, idx3] = max(sumXY);  % bottom-right
    [~, idx4] = min(diffXY); % bottom-left

    corners = [x(idx1), y(idx1);
               x(idx2), y(idx2);
               x(idx3), y(idx3);
               x(idx4), y(idx4)];
end