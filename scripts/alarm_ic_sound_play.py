#!/usr/bin/env python
import pygame
import time
import rospy
from std_msgs.msg import Int16

flag = True
def qr_callback(msg):
    rospy.loginfo("done")
    print msg.data
    if msg.data == 1 and flag = True:
        pygame.mixer.music.play(1)
        time.sleep(2)
        pygame.mixer.music.stop()
        flag = not flag
    else:
        flag = True
        pygame.mixer.music.stop()
    
def qr_sub():
    rospy.init_node('ic_connector', anonymous=True)
    rospy.Subscriber('/rfid_state', Int16, qr_callback)
    rospy.spin()

def main():
    pygame.mixer.init()
    pygame.mixer.music.load("../sounds/Ticket_Gate-Alarm01-mp3/Ticket_Gate-Alarm01-1(Timbre1-Flap).mp3")
    qr_sub()

if __name__ == '__main__':
    main()
