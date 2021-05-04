#!/usr/bin/env python
from pyzbar.pyzbar import decode
import cv2

cap = cv2.VideoCapture(0)
font = cv2.FONT_HERSHEY_SIMPLEX
while cap.isOpened():
    ret, frame = cap.read()
    if ret == True:
        d = decode(frame)
        if d:
            for barcode in d:
                x, y, w, h = barcode.rect
                cv2.rectangle(frame,(x,y), (x+w, y+h), (0, 0, 255), 2)
                barcodeData = barcode.data.decode('utf-8')
                frame = cv2.putText(frame, barcodeData, (x, y-10), font, .5, (0, 0, 255), 2, cv2.LINE_AA)
        cv2.imshow('frame', frame)

    if cv2.waitKey(1) & 0xFF ==ord('q'):
        break

cap.release()
