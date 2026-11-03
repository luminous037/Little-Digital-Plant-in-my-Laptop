#!/usr/bin/env python3
"""Original procedural lo-fi: no samples, recordings, or source-track analysis.
Requires Python 3 + NumPy. Produces stereo WAV masters for AAC encoding.
"""
import argparse
import wave
from pathlib import Path
import numpy as np

SR = 32000

def compose(path, duration, bpm, seed, chords, melody, bright=False):
    rng = np.random.default_rng(seed)
    out = np.zeros((int(duration*SR), 2), dtype=np.float64)
    beat = 60/bpm
    def add(signal, at, gain=1, pan=0):
        start = int(at*SR)
        if start < 0: return
        n = min(len(signal),len(out)-start)
        if n <= 0: return
        out[start:start+n,0] += signal[:n]*gain*np.sqrt((1-pan)/2)
        out[start:start+n,1] += signal[:n]*gain*np.sqrt((1+pan)/2)
    def note(midi, seconds, kind):
        t = np.arange(int(seconds*SR))/SR
        f = 440*2**((midi-69)/12)
        wobble = .002*np.sin(2*np.pi*.7*t)+.0008*np.sin(2*np.pi*4.1*t)
        phase = 2*np.pi*f*(t + wobble*.04)
        if kind == 'bass':
            signal = np.sin(phase)+.16*np.sin(2*phase)
            env = (1-np.exp(-t*45))*np.exp(-t*2.5)
        else:
            signal = np.sin(phase)+.24*np.sin(2*phase)*np.exp(-t*4)+.08*np.sin(3*phase)*np.exp(-t*8)
            env = (1-np.exp(-t*(100 if bright else 65)))*np.exp(-t*(2.0 if kind == 'lead' else 1.25))
        env *= np.minimum(1,(seconds-t)/.09)
        return np.tanh(signal*.8)*env
    def drum(kind):
        dur = {'kick':.28,'snare':.19,'hat':.065}[kind]
        t = np.arange(int(dur*SR))/SR
        noise = rng.normal(0,1,len(t))
        if kind == 'kick':
            phase = 2*np.pi*(48*t + 55*.025*(1-np.exp(-t/.025)))
            return np.sin(phase)*np.exp(-t*19)
        if kind == 'snare':
            noise = np.convolve(noise,np.ones(5)/5,mode='same')
            return (.65*noise+.2*np.sin(2*np.pi*175*t))*np.exp(-t*28)
        noise = noise-np.convolve(noise,np.ones(9)/9,mode='same')
        return np.tanh(noise*.35)*np.exp(-t*85)
    drums = {k:drum(k) for k in ['kick','snare','hat']}
    bars = int(np.ceil(duration/(beat*4)))
    for bar in range(bars):
        base = bar*beat*4
        chord = chords[(bar//2)%len(chords)]
        # Gentle 8-bar arrangement: intro, beat, quieter breakdown, return.
        block = (bar//8)%4
        chord_gain = .19 if block != 2 else .14
        for j,midi in enumerate(chord):
            add(note(midi,beat*3.8,'keys'),base+j*.026,chord_gain,pan=(j-1.5)*.18)
        if bar%2:
            for j,midi in enumerate(chord[1:]):
                add(note(midi+12,beat*1.4,'keys'),base+beat*2.65+j*.035,.055,pan=.3)
        add(note(chord[0]-24,beat*1.7,'bass'),base,.32)
        add(note(chord[0]-24+(7 if bar%4==3 else 0),beat*1.2,'bass'),base+beat*2.5,.23)
        if bar >= 2 and block != 2:
            for b in [0,1.75,2.5] if bar%2 else [0,2.5]:
                add(drums['kick'],base+beat*b,.34)
            for b in [1,3]:
                add(drums['snare'],base+beat*b+.018,.22,pan=-.06)
            for k in range(8):
                swing = .07*beat if k%2 else 0
                add(drums['hat'],base+k*beat/2+swing+rng.uniform(-.009,.009),rng.uniform(.065,.105),pan=.25)
        if bar >= 4 and bar%4 in [0,1,3]:
            phrase = melody[bar%len(melody)]
            for step,offset in enumerate(phrase):
                if offset is None: continue
                when = base+beat*(step*.75+.35)
                lead = note(chord[0]+12+offset,beat*1.1,'lead')
                add(lead,when,.12,pan=-.22)
                add(lead,when+beat*.75,.035,pan=.4)
    # Short diffuse stereo echoes, soft saturation, quiet generated texture.
    dry = out.copy()
    for delay,gain in [(.071,.12),(.113,.09),(.181,.05)]:
        d = int(delay*SR); out[d:] += dry[:-d,::-1]*gain
    noise = rng.normal(0,1,len(out))
    noise = np.convolve(noise,np.ones(18)/18,mode='same')
    out += noise[:,None]*.002
    out = np.tanh(out*1.3)
    out *= .82/max(.82,float(np.max(np.abs(out))))
    t = np.arange(len(out))/SR
    fade = np.minimum(1,t/2)*np.minimum(1,(duration-t)/4)
    out *= fade[:,None]
    with wave.open(str(path),'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((out*32767).astype('<i2').tobytes())
    rms = np.sqrt(np.mean(out**2))
    print(f'{path.name}: {duration:.2f}s, {bpm} BPM, peak {np.max(np.abs(out)):.3f}, RMS {rms:.3f}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('output',type=Path)
    args = parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    compose(args.output/'Moonlit Notes.wav',126.8,74,2037,
            [[57,60,64,67],[53,57,60,64],[55,59,62,65],[52,55,59,62]],
            [[7,10,None,12],[3,None,7,5],[0,3,7,None],[10,7,3,0]])
    compose(args.output/'Apricot Afternoon.wav',121.8,82,9041,
            [[60,64,67,71],[57,60,64,67],[62,65,69,72],[55,59,62,65]],
            [[4,7,11,None],[7,4,None,2],[0,4,7,9],[11,None,7,4]],bright=True)
