from PIL import Image
import numpy as np
from rs_encoder import rs_encode_msg, init_tables

RS_N = 255
RS_K = 223
RS_ECC = RS_N - RS_K

init_tables()  # Initialize Galois field tables

def int_to_desired_length_binary(n, num_bits):
    if not (0 <= n < 2**num_bits):
        raise ValueError(f"Input must be in the range [0, {2**num_bits - 1}] for {num_bits}-bit representation.")
    return format(n, f'0{num_bits}b')

def image_to_rs_bitstream(image_path, message_type_code="001"):
    """
    Converts an RGB image into a Reed-Solomon encoded bitstream.
    Each 223-byte message chunk becomes a 255-byte RS codeword.

    METADATA:
    - 3 bits for message_type_code        ("001" => Image)
    - 12 bits alotted for HEIGHT x WIDTH  (i.e. up to 4095x4095)
    """

    # Load image and convert to flat RGB byte array
    img = Image.open(image_path).convert('RGB')
    img_array = np.array(img)
    flat_rgb = img_array.flatten()
    
    height, width, depth = img_array.shape

    bitstream = ""
    bitstream += message_type_code + int_to_desired_length_binary(height, 12) + int_to_desired_length_binary(width, 12)

    # Process in chunks of RS_K = 223
    for i in range(0, len(flat_rgb), RS_K):
        chunk = flat_rgb[i:i+RS_K].tolist()
        encoded_chunk = rs_encode_msg(chunk, RS_ECC)
        for byte in encoded_chunk:
            bitstream += f'{byte:08b}'

    return bitstream

def text_to_rs_bitstream(message, message_type_code="000"):
    """
    Converts a text message into a Reed-Solomon encoded bitstream.
    Each 223-byte message chunk becomes a 255-byte RS codeword.

    METADATA:
    - 3 bits for message_type_code        ("000" => Text)
    - 24 bits for message length          (up to 16.7GB)
    """

    # Convert string message to list of byte values
    byte_data = list(message.encode('utf-8'))

    bitstream = ""
    bitstream += message_type_code + int_to_desired_length_binary(len(byte_data), 24)

    # Process in chunks of RS_K = 223
    for i in range(0, len(byte_data), RS_K):
        chunk = byte_data[i:i+RS_K]
        # Pad the chunk to 223 bytes if necessary
        if len(chunk) < RS_K:
            chunk += [0] * (RS_K - len(chunk))
        encoded_chunk = rs_encode_msg(chunk, RS_ECC)
        for byte in encoded_chunk:
            bitstream += f'{byte:08b}'

    return bitstream


# Example usage:
# bitstream = image_to_rs_bitstream("<IMAGE_NAME.png>")
bitstream = text_to_rs_bitstream("<TEXT MESSAGE HERE>")

print("Bitstream length (RS-encoded):", len(bitstream))

# Save to file for use in Arduino sketch
with open("bits.txt", "w") as file:
    file.write(bitstream)
