function decodedBits = final_decoder(receivedData, num_columns, crosstalk)
    % receivedData has dimensions: (num_rows * num_columns) x num_frames x 3
    % receivedData(row * num_columns + col, frame, color channel)
    crosstalk_correction = inv(crosstalk);
    %crosstalk_correction = eye(3);
    num_rows = num_columns;
    numFrames = size(receivedData, 2);  % Number of frames
    
    % Initialize variables
    decodedBits = [];
    fileName = 'output.txt';
    fileID = fopen(fileName, 'w');
   
    % Loop through frames and average over the symbol period
    for frameNum = 1:numFrames
        % After detecting clock, decode the actual data (excluding the clock pixel)
        for cellIdx = 1:num_rows * num_columns-2  %
            % Get the average RGB value for the current grid cell
            col = squeeze(receivedData(cellIdx,frameNum,:));
            cellColor = inv(crosstalk_correction)*col;
            
            % % Decode the color to bits
            % if cellIdx~=num_rows*num_columns % skip clock pixels
            %     fprintf(fileID, '%s', colorToBits(cellColor));
            %     decodedBits = [decodedBits; colorToBits(cellColor)];
            % end
            % if cellIdx==num_rows*num_columns || cellIdx==num_rows*num_columns-num_columns/2+1
            %     continue
            % end
            fprintf(fileID, '%s', colorToBits(cellColor));
            decodedBits = [decodedBits, colorToBits(cellColor)];
        end
    end
    fclose(fileID);
end

% Helper function to convert RGB color to bits (same as in the encoder)
function bits = colorToBits(color)
    intensities = [0, 85, 170, 255];
    intensities = [0, 255];

    gray = ['00', '01', '11', '10'];
    
    bits = '';
    for ch = 1:3
        % Find the closest intensity for each color channel (R, G, B)
        [~, idx] = min(abs(intensities - color(ch)));
        bits = [bits, dec2bin(idx - 1, 1)];  % Convert to 2-bit representation
        %bits = [bits, gray(idx)];
    end
end
