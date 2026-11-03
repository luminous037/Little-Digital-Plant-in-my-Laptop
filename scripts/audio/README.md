# Original lo-fi replacements

The two replacement recordings are composed procedurally by `generate-lofi.py`:

| Track | Duration | Tempo | Character |
| --- | --- | --- | --- |
| Moonlit Notes | 126.8 seconds | 74 BPM | Soft electric keys, minor seventh chords, relaxed drums |
| Apricot Afternoon | 121.8 seconds | 82 BPM | Brighter keys, warm bass, gently swung percussion |

The generator uses only mathematical oscillators and seeded noise. It does not load or analyze the removed recordings, copy their melodies, or use third-party samples. Generation source is included for provenance and reproducibility; this is not a legal clearance opinion.

To recreate the recordings on macOS with Python 3 and NumPy installed:

```sh
python3 scripts/audio/generate-lofi.py .build/original-lofi
afconvert -f m4af -d aac -b 160000 '.build/original-lofi/Moonlit Notes.wav' 'Sources/LittlePlant/Resources/Music/Moonlit Notes.m4a'
afconvert -f m4af -d aac -b 160000 '.build/original-lofi/Apricot Afternoon.wav' 'Sources/LittlePlant/Resources/Music/Apricot Afternoon.m4a'
```

The lavender and pale-yellow albums keep their existing interactions. The third track, `my cozy room`, is unchanged.
