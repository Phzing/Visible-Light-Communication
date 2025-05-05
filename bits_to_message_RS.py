from PIL import Image
import numpy as np
from math import ceil

from rs_decoder import rs_correct_msg

def bits_to_msg_RS(grayBinary, output_format="binary"):
    rs_bytes = []
    for i in range(0, len(grayBinary), 8):
        byte = grayBinary[i:i+8]
        rs_bytes.append(int(byte, 2))

    decoded_msg = []
    for i in range(ceil(len(rs_bytes) / 255)):
        start_pos = i*255
        end_pos = min(start_pos + 255, len(rs_bytes))

        decoded_str = ""
        input_bytes = rs_bytes[start_pos:end_pos]
        try:
            corrected_msg_list, parity = rs_correct_msg(input_bytes, 32)
            for val in corrected_msg_list:
                if output_format=="text":
                    decoded_str += chr(val)
                elif output_format=="binary":
                    decoded_str += format(val, '08b')
        except:
            for val in input_bytes[:223]:
                if output_format=="text":
                    decoded_str += chr(val)
                elif output_format=="binary":
                    decoded_str += format(val, '08b')
        decoded_msg.append(decoded_str)
        
    return ''.join(decoded_msg)

def bitstream_to_rgb_image(bitstream, width: int, height: int, save_path):
    """
    Converts bitstream into image. Ok for bitstream to be longer than necessary (this function truncates).
    """
    expected_bits = int(width * height * 3 * 8)
    if len(bitstream) < expected_bits:
        raise ValueError(f"Bitstream too short. Expected {expected_bits}, got {len(bitstream)}")
    
    bitstream = bitstream[:expected_bits]
    byte_array = [int(bitstream[i:i+8], 2) for i in range(0, len(bitstream), 8)]
    img_array = np.array(byte_array, dtype=np.uint8).reshape((height, width, 3))
    img = Image.fromarray(img_array, 'RGB')
    img.save(save_path)

def extract_rs_message_payload(bitstream):
    block_size = 255
    msg_size = 223

    # Convert bitstream to byte list
    rs_bytes = []
    for i in range(0, len(bitstream), 8):
        if i + 8 <= len(bitstream):
            rs_bytes.append(int(bitstream[i:i+8], 2))

    extracted_bits = ""
    for i in range(0, len(rs_bytes), block_size):
        block = rs_bytes[i:i+block_size]

        for val in block[:msg_size]:
            extracted_bits += format(val, '08b')

    return extracted_bits


def bitstream_image_RS_comparison(bitstream, width: int, height: int, save_path):
    """
    Converts bitstream into 2 images: one with RS correction, one without.
    Pads corrected output after decoding to match image bit count.
    """
    expected_bits = width * height * 3 * 8

    # With RS correction
    RS_corrected = bits_to_msg_RS(bitstream, output_format="binary")
    RS_corrected_padded = RS_corrected.ljust(expected_bits, '1')
    bitstream_to_rgb_image(RS_corrected_padded, width, height, "corrected_" + save_path)

    # Without RS correction
    RS_payload = extract_rs_message_payload(bitstream)
    RS_payload_padded = RS_payload.ljust(expected_bits, '1')
    bitstream_to_rgb_image(RS_payload_padded, width, height, save_path)

def binary_to_int(binary_str, num_bits):
    if len(binary_str) != num_bits or not all(c in '01' for c in binary_str):
        raise ValueError(f"Input must be a {num_bits}-bit binary string (only 0s and 1s).")
    return int(binary_str, 2)

def bitstream_text_RS(bitstream, length, save_path):
    """
    Converts bitstream into 2 text files: one with RS correction, one without.
    Pads corrected output after decoding to match image bit count.
    """

    text = bits_to_msg_RS(bitstream, output_format="text")
    if len(text)>length:
        text = text[:length]

    with open(save_path, 'w', encoding='utf-8') as f:
        f.write(text)

def bitstream_to_message_RS(bitstream):

    text_code="000"
    img_code="001"
    code = bitstream[:3]

    if code==text_code:
        length_bits = bitstream[3:27]
        length = binary_to_int(length_bits, 24)

        bitstream_text_RS(bitstream[27:], length, "transmitted_text.txt")
    elif code==img_code:
        height_bits = bitstream[3:15] 
        width_bits = bitstream[15:27]
        height = binary_to_int(height_bits, 12)
        width = binary_to_int(width_bits, 12)

        bitstream_image_RS_comparison(bitstream[27:], width, height, "transmitted_img.png")
    else:
        bitstream = "000" + bitstream[3:]


# Example usage:
# Bitstream from message_to_bits_RS.py:
bitstream = "000000000000000000000010011001111000101010001000101010110000101010000100000010011010100010101010011010100110100000101000111010001010010000001001000010001010101001001000101001111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001101111011110001110100000011011011100001110011010101101100111110111110001101101001011001110000010110110000001001010111010000010110100111100011101111100010011000000000110101110011110101000010001111110001111010110010011000011110011001011100001001100000011011"
bitstream_to_message_RS(bitstream)
