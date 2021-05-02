#!/usr/bin/env python
# --coding: utf-8 --
from pyzbar.pyzbar import decode
from PIL import Image

image = '../images/qr_hello_world.png'

# read QR code
data = decode(Image.open(image))
input_data = data[0][0].decode('utf-8', 'ignore')
print(input_data)
