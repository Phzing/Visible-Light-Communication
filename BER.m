% Load the binary strings from the two text files
inputFile = 'img_bits.txt';  % Name of the file containing the input binary string
outputFile = 'output.txt'; % Name of the file containing the output binary string

% Read the contents of the files as strings
inputStr = fileread(inputFile);
charStr = convertStringsToChars(inputStr);
disp(length(charStr));
inputStr = charStr(1:length(charStr));
%disp(length(inputStr));
outputStr = fileread(outputFile);
charOut = convertStringsToChars(outputStr);
disp(length(charOut));
outputStr = charOut(1:length(charStr));
%disp(length(outputStr));
outputStr = convertStringsToChars(outputStr);

test = inputStr~=outputStr;
num_errors = sum(test);
BER_correct = num_errors/length(test);



% % Ensure that both strings are of equal length
% if length(inputStr) > length(outputStr)
%     error('The output is shorter than input.');
% else
%     outputStr = outputStr(1,length(inputStr));
% end

% Convert the strings to arrays of numbers (binary values)
inputBin = inputStr - '0';  % Convert '0' and '1' characters to 0 and 1 numeric values
outputBin = outputStr - '0';  % Same for the output string

% Compute the number of bit errors (mismatches)
numErrors = sum(inputBin ~= outputBin);
error_indices = find(inputBin ~= outputBin);

% Compute the Bit Error Rate (BER)
totalBits = length(inputBin);
ber = numErrors / totalBits;

% get locations of errors
bit_error_locations = locate_bit_errors(error_indices, 254, 3);

% Display the results
fprintf('Total bits: %d\n', totalBits);
fprintf('Number of errors: %d\n', num_errors);
fprintf('Bit Error Rate (BER): %.6f\n', BER_correct);

function bit_error_locations = locate_bit_errors(error_indices, num_tx_pixels, bits_per_pixel)
% error_indices: vector of bit indices (linear indices into the full message)
% num_tx_pixels: number of *data* transmit pixels per frame (e.g., 254)
% bits_per_pixel: number of bits per pixel (e.g., 3)

% Grid size
grid_rows = 16;
grid_cols = 16;

% Clock pixel positions (linear indices in 16x16 grid)
clock_pixels = [249, 256];

% Total bits per frame
bits_per_frame = num_tx_pixels * bits_per_pixel;

% Preallocate output struct
bit_error_locations = struct('frame', {}, 'pixel_index', {}, 'row', {}, 'col', {});

for k = 1:length(error_indices)
    idx = error_indices(k);

    % Frame number
    frame = ceil(idx / bits_per_frame);

    % Index of the bit within the frame
    bit_in_frame = mod(idx-1, bits_per_frame) + 1;

    % Pixel index within the frame
    pixel_index = ceil(bit_in_frame / bits_per_pixel);

    % Map to pixel index in 16x16 grid (excluding clock pixels)
    all_pixel_indices = setdiff(1:256, clock_pixels);  % valid pixel positions
    grid_index = all_pixel_indices(pixel_index);       % 1-based index in 16x16

    % Convert to row/col (row-major ordering)
    row = ceil(grid_index / grid_cols);
    col = mod(grid_index - 1, grid_cols) + 1;

    % Store info
    bit_error_locations(k).frame = frame;
    bit_error_locations(k).pixel_index = pixel_index;
    bit_error_locations(k).row = row;
    bit_error_locations(k).col = col;
end

end
