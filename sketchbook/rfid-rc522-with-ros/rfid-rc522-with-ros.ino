#include <SPI.h>
#include <MFRC522.h>

#include <ros.h>
#include <std_msgs/Int16.h>
ros::NodeHandle nh;
std_msgs::Int16 ic_msg;
ros::Publisher ic_pub("/rfid/ic_uid", &ic_msg);

constexpr uint8_t RST_PIN = 9;
constexpr uint8_t SS_PIN = 10;

#define UID "2C AD BA 16" // 取得した識別子を記述
#define UID_card "09 11 E3 B2"

int led_blue = 8;
int led_red = 3;

MFRC522 mfrc522(SS_PIN, RST_PIN);
MFRC522::MIFARE_Key key;

void ic_touch_sound(){
  ic_msg.data = 1;
  ic_pub.publish(&ic_msg);
}

void setup() {
    //Serial.begin(9600);
    pinMode(led_blue, OUTPUT);
    pinMode(led_red, OUTPUT);
    while (!Serial);
    SPI.begin();
    mfrc522.PCD_Init();
    mfrc522.PCD_DumpVersionToSerial();
    //Serial.println(F("Scan PICC to see UID, SAK, type, and data blocks..."));

    dump_byte_array(key.keyByte, MFRC522::MF_KEY_SIZE);
}

void loop() {
    if ( ! mfrc522.PICC_IsNewCardPresent()) {
        return;
    }
    if ( ! mfrc522.PICC_ReadCardSerial()) {
        return;
    }

    String strBuf[mfrc522.uid.size];
    for (byte i = 0; i < mfrc522.uid.size; i++) {
        strBuf[i] =  String(mfrc522.uid.uidByte[i], HEX);
        if(strBuf[i].length() == 1){
          strBuf[i] = "0" + strBuf[i];
        }
    }
    
    String strUID = strBuf[0] + " " + strBuf[1] + " " + strBuf[2] + " " + strBuf[3] ;//+ " " + strBuf[4] + " " + strBuf[5] + " " + strBuf[6];
    if ( strUID.equalsIgnoreCase(UID_card) ){
        //Serial.println("verified!");
        digitalWrite(led_blue, HIGH); // 青いLEDを光らせる
        delay(1000); // 1秒待つ
        digitalWrite(led_blue, LOW); // 青いLEDを消す
        ic_msg.data = 1;
        i
    } else {
        //Serial.println("error!");
        analogWrite(led_red, 180); // 赤いLEDを光らせる
        delay(1000); // 1秒待つ
        analogWrite(led_red, 0); // 赤いLEDを消す
    }
}

void dump_byte_array(byte *buffer, byte bufferSize) {
    for (byte i = 0; i < bufferSize; i++) {
        //Serial.print(buffer[i] < 0x10 ? " 0" : " ");
        //Serial.print(buffer[i], HEX);
    }
}
