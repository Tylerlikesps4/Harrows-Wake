# Harrow's Wake - soundtrack toolchain

"Harrow's Wake (Main Theme)" - D minor, 64 BPM, 47 bars, 3:03 with the reverb tail.
Two versions from one score: **Instrumental** and **Vocal** (same arrangement, sung lullaby on top).

| File | What |
|---|---|
| `compose.py` | The score as note data (sections, melody, chords, lyrics, events). Writes MIDI. Both versions read this. |
| `synth.py` | FluidSynth stems (FluidR3_GM) + numpy layers (hand bell, drone, wind, tape hiss, riser), generated-IR reverb, tape wobble, 22 kHz/12-bit PS1 crush, vocal ducking, two-pass `loudnorm` master to -14 LUFS / -1.5 dBTP, WAV + OGG + MP3. |
| `vocal.py` | Piper TTS speaks each lyric line (with phoneme timing) -> syllables -> WORLD (pyworld) re-times each syllable to its note and replaces F0 with the melody (portamento, delayed 5.4 Hz vibrato, drift) -> lead + 2 detuned doubles + breathy layer -> `build/vocal_stem.wav`. |
| `lyrics.txt` | Lyrics with timestamps. |
| `spectrogram_*.png` | Analytic listen-check renders. |
| `build/` | Intermediates (MIDI, stems, pre-master mixes, `asr.py` intelligibility check). Safe to delete. |

## Rebuild
```
pip install numpy scipy soundfile mido "setuptools<81" pyworld piper-tts onnx   # pyworld needs g++
sudo apt-get install -y fluidsynth fluid-soundfont-gm g++                       # FluidR3_GM lands in /usr/share/sounds/sf2/
# voice (MIT, LJ Speech public-domain data):
B=https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ljspeech/high
curl -L -o /tmp/voices/en_US-ljspeech-high.onnx $B/en_US-ljspeech-high.onnx
curl -L -o /tmp/voices/en_US-ljspeech-high.onnx.json $B/en_US-ljspeech-high.onnx.json
mkdir -p build
python vocal.py                 # ~45 s on 2 CPUs
python synth.py instrumental    # ~45 s
python synth.py vocal           # ~2 min
```
Env overrides: `SF2=` (soundfont path), `PIPER_VOICE=` (onnx path), `VOCAL_GAIN=` (default 1.4).

Game copies (mono 22 kHz Ogg) are made with
`ffmpeg -i HarrowsWake_MainTheme_Instrumental.wav -ac 1 -ar 22050 -c:a libvorbis -q:a 2 title_music.ogg`
and the same for the vocal (`-q:a 3`, `credits_song.ogg`).

## Licenses
- Music and lyrics: original, Copyright (C) 2026 Tylerlikesps4, GPL-3.0-or-later (same as the game code; these scripts are the source form).
- FluidR3_GM soundfont (Frank Wen): MIT. FluidSynth: LGPL-2.1.
- Piper voice `en_US-ljspeech-high`: MIT (rhasspy/piper-voices), trained on LJ Speech (public domain). Piper 1.8 itself is GPL-3.0 (a tool; its license does not cover output audio).
- pyworld MIT / WORLD modified-BSD; NumPy/SciPy BSD; FFmpeg LGPL.

## Known limits
- The singer is speech re-pitched into song, not a trained singing model: pitch is exact (median error 0.06 semitone measured), but consonants are soft and some words blur, especially "Ding and dong" and "stitched-up smile". A speech recognizer understood most verse-1 lines from the solo vocal stem, much less in the full mix.
