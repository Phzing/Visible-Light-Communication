function avg_frames = extract_and_average_frames_dualclock(data, num_columns)
    % data: [num_tx_pixels x num_frames x 3]
    % avg_frames: [num_tx_pixels-2 x num_transmit_frames x 3] (excluding both clock pixels)
    
    [num_tx_pixels, num_frames, num_channels] = size(data);
    
    num_rows = num_columns;
    clock_idx = num_columns*(num_rows-1)+num_columns/2+1;
    disp(clock_idx);
    % Extract both clock pixels (assumed to be first and last)
    clock1 = squeeze(data(clock_idx, :, :));     % [num_frames x 3]
    clock2 = squeeze(data(end, :, :));   % [num_frames x 3]
    
    % Convert both to grayscale
    clock1_gray = mean(clock1, 2);
    clock2_gray = mean(clock2, 2);
    
    % Threshold to binarize
    threshold1 = (max(clock1_gray) + min(clock1_gray)) / 2;
    threshold2 = (max(clock2_gray) + min(clock2_gray)) / 2;
    clock1_bin = clock1_gray > threshold1;
    clock2_bin = clock2_gray > threshold2;
    
    % Keep only frames where the two clocks agree (i.e., stable frames)
    stable_mask = (clock1_bin == clock2_bin);
    stable_indices = find(stable_mask);
    
    % Reduce clocks and data to stable frames only
    clock_bin_clean = clock1_bin(stable_mask);  % or clock2_bin, same at this point
    data_clean = data(2:end-1, stable_indices, :);  % Remove both clock pixels
    data_clean = cat(1,data(1:clock_idx-1,stable_indices,:),data(clock_idx+1:end-1,stable_indices,:));

    % Find transitions in the cleaned clock signal
    transitions = find(diff(clock_bin_clean) ~= 0) + 1;
    
    % Ensure edge transitions are handled
    if transitions(1) > 1
        transitions = [1; transitions];
    end
    if transitions(end) < length(clock_bin_clean)
        transitions = [transitions; length(clock_bin_clean)];
    end
    
    % Preallocate output
    num_segments = length(transitions) - 1;
    avg_frames = zeros(num_tx_pixels - 2, num_segments, num_channels);  % minus 2 for the clocks
    
    % Average frames for each stable segment
    for i = 1:num_segments
        idx_start = transitions(i);
        idx_end = transitions(i + 1) - 1;
        segment = data_clean(:, idx_start:idx_end, :);
    
        for c = 1:num_channels
            avg_frames(:, i, c) = mean(segment(:, :, c), 2);
        end
    end

end