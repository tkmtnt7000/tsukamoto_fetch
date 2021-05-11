#!/usr/bin/env python
from pydub import AudioSegment
from pydub.playback import play

#sound = AudioSegment.from_file("$HOME/Desktop/tsukamoto_ws/fetch_oneweek/sounds/Paypay_2.wav", format="wav")
sound = AudioSegment.from_file("../sounds/Paypay_2.wav", format="wav")
play(sound)
