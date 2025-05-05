# Visible-Light-Communication
Repository for VLC System using Adafruit 64x64 LED Matrix as transmitter + Blackfly S Camera as receiver

-- HARDWARE -- 
LED Matrix (Tx): https://www.adafruit.com/product/4732
Matrix Driver (Tx): https://www.adafruit.com/product/4745
Driver Controller (Tx): ESP32? 
Camera (Rx): https://www.edmundoptics.com/p/bfs-u3-16s2c-cs-usb3-blackflyreg-s-color-camera/40164/?srsltid=AfmBOopQ6-Ipp0Qdrfb-Wus5ME8P0FQBN5wq0GbkBQJ2rmLrpfJKh9S9




TRANSMISSION:
1. message_to_bits_RS.py (Generates bitstream into > bits.txt)
2. transmit.ino          

RECEPTION (files in order of how they're called):
1. message
2. recomp
3. pipeline
4. files
