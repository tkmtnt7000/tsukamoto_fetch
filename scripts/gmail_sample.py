#!/usr/bin/env python
# -*- coding: utf-8 -*-

import rospy
from std_msgs.msg import Int16
import datetime

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication


def send_room_access_email():
    # SMTPサーバーを指定                                                 
    smtp_server = "smtp.gmail.com"
    #ポート番号を指定
    port_number = 465
    
    #SMTPサーバーを指定しSSL暗号化通信を開始
    server = smtplib.SMTP_SSL(smtp_server, port_number)
    
    #SMTPサーバからのレスポンス確認(省略可)
    response = server.noop()
    print(response)
    
    # Gmailアカウントへログイン                                                
    account = "tsukamoto@jsk.imi.i.u-tokyo.ac.jp"
    password = "jclebwlazixkjgjj"
    
    login_response = server.login(account, password)
    print(login_response)
    
    #メールの件名、送信者、受信者を設定
    msg = MIMEMultipart()
    #件名
    msg["Subject"] = "入退室報告"
    #自分のアドレス
    msg["From"] = "tsukamoto@jsk.imi.i.u-tokyo.ac.jp"
    #受信者のアドレス
    msg["To"] ="naototukka0413@gmail.com"
    #メール送信履歴を残すためにBCCに自分のアドレスを指定
    msg["BCC"] = "tsukamoto@jsk.imi.i.u-tokyo.ac.jp"
    
    #本文作成
    dt_now = datetime.datetime.now()
    str_dt = dt_now.strftime('%Y年%m月%d日 %H:%M\n')
    body = MIMEText("〇〇です.入退室しました.\n\n日時: "+str_dt+'場所: 73B2\n用事: 作業等\n')
    msg.attach(body)
    
    '''
    #添付用のPDFファイルデータの読み込み
    pdf = open("test.pdf", mode="rb")
    pdf_data = pdf.read()
    pdf.close()
    
    #ファイルを添付
    attach_file = MIMEApplication(pdf_data)
    attach_file.add_header("Content-Disposition", "attachment", filename="test.pdf")
    msg.attach(attach_file)
    '''
    
    #メールの送信
    server.send_message(msg)
    
    #SMTPサーバーとの接続を終了
    server.quit()

def room_access_cb(msg):
    if msg.data == 1:
        send_room_access_email()

def sub():
    rospy.init_node('room_access_email', anonymous=True)
    rospy.Subscriber("/rfid/sound", Int16, room_access_cb)
    rospy.spin()
    
if __name__ == '__main__':
    sub()
    
