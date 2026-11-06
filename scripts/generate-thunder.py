#!/usr/bin/env python3
"""Generate an original thunder effect using oscillators and filtered noise only."""
import math
import random
import struct
import wave
from pathlib import Path

rate = 32000
duration = 5.8
rng = random.Random(20261106)
body = deep = 0.0
mono = []
for i in range(int(rate*duration)):
    t = i/rate
    noise = rng.uniform(-1,1)
    body = .93*body+.07*noise
    deep = .997*deep+.003*noise
    attack = (1-math.exp(-t*90))*math.exp(-t/0.2)
    rumble = (1-math.exp(-t*12))*math.exp(-t/1.45)
    pulse = 1+.28*math.sin(2*math.pi*1.7*t)+.15*math.sin(2*math.pi*3.4*t)
    low = .045*math.sin(2*math.pi*39*t+.7*math.sin(t*2))+.03*math.sin(2*math.pi*63*t)
    value = .2*noise*attack+(body*3+deep*5+low)*rumble*pulse
    value *= min(1,max(0,(duration-t)/.6))
    mono.append(math.tanh(value))
scale = .76/max(abs(v) for v in mono)
frames = bytearray()
for i,value in enumerate(mono):
    left = value*.9+(mono[i-1700] if i>=1700 else 0)*.1
    right = value*.77+(mono[i-1100] if i>=1100 else 0)*.23
    frames.extend(struct.pack('<hh',int(left*scale*32767),int(right*scale*32767)))
path = Path(__file__).resolve().parents[1]/'Sources/LittlePlant/Resources/Sounds/thunder.wav'
with wave.open(str(path),'wb') as output:
    output.setnchannels(2); output.setsampwidth(2); output.setframerate(rate); output.writeframes(frames)
print(f'Generated {path.name}: {duration}s stereo synthesized thunder, no samples.')
