import  qrcode
from PIL import Image

qr = qrcode.QRCode(box_size=10)
qr.add_data('Hello world!')
qr.make()
img_qr = qr.make_image()
img_qr.save('../images/qr_hello_world.png')
