"""Harrow's Wake (Main Theme) - the score as note data.

Both versions (instrumental and vocal) are rendered from this one file, so the
arrangement and timing are identical. Units: beats (quarter notes), 4/4, 64 BPM.

Exports:
  BPM, BEAT, BARS, SECTIONS, TOTAL_BEATS
  notes      -> list of Note(track, start, dur, pitch, vel)   (rendered by FluidSynth)
  events     -> list of dicts for the numpy synth (hand bell, drone, wind, hiss automation)
  vocal      -> list of VNote(start, dur, pitch, syl, line)    (sung by vocal.py)
  LYRICS     -> sections -> lines
  write_midi(path, tracks=None)
"""
from dataclasses import dataclass
import random

BPM = 64
BEAT = 60.0 / BPM
BAR = 4

# ------------------------------------------------------------------ structure
SECTIONS = [  # name, bars
    ("intro", 4),      # distant bell tolls, wind, tape hiss
    ("verse1", 8),     # music box lullaby (core motif)
    ("chorus1", 8),    # strings/pad swell
    ("middle", 8),     # the Bellman approaching: pulses, dissonance, inverted bell motif
    ("verse2", 8),     # lullaby returns, fragmented
    ("chorus2", 8),    # last chorus, thinning out
    ("outro", 3),      # one bell, then silence
]
SEC_START = {}
_b = 0
for _n, _bars in SECTIONS:
    SEC_START[_n] = _b * BAR
    _b += _bars
TOTAL_BEATS = _b * BAR
BARS = _b

# GM programs (0-based) and MIDI channels
TRACKS = {
    "mbox":    dict(ch=0, prog=10, name="Music Box"),       # melody
    "celesta": dict(ch=1, prog=8,  name="Celesta"),         # arpeggio accompaniment
    "strings": dict(ch=2, prog=49, name="Slow Strings"),
    "choir":   dict(ch=3, prog=52, name="Choir Aahs"),
    "bass":    dict(ch=4, prog=43, name="Contrabass"),
    "timp":    dict(ch=5, prog=47, name="Timpani"),
    "tbell":   dict(ch=6, prog=14, name="Tubular Bells"),
    "trem":    dict(ch=7, prog=44, name="Tremolo Strings"),
    "pad":     dict(ch=8, prog=91, name="Pad 4 (choir)"),
}


@dataclass
class Note:
    track: str
    start: float
    dur: float
    pitch: int
    vel: int


@dataclass
class VNote:
    start: float
    dur: float
    pitch: int
    syl: str
    line: int


# ------------------------------------------------------------------ the lullaby
# Each line = 2 bars: six quarter notes then a half note (7 syllables, trochaic).
D4, E4, F4, G4, A4, Bb4, C5, Cs5, Cs4, D5 = 62, 64, 65, 67, 69, 70, 72, 73, 61, 74
RHYTHM = [1, 1, 1, 1, 1, 1, 2]

VERSE_MEL = [
    [A4, A4, F4, A4, Bb4, A4, G4],
    [G4, G4, E4, G4, A4, G4, F4],
    [F4, F4, D4, F4, E4, D4, Cs4],
    [D4, E4, F4, G4, E4, Cs4, D4],
]
CHORUS_MEL = [
    [Bb4, Bb4, A4, G4, A4, F4, D4],
    [Bb4, Bb4, A4, G4, A4, Cs5, A4],
    [F4, F4, E4, D4, E4, F4, G4],
    [A4, G4, F4, E4, D4, Cs4, D4],
]
# chords per bar (root-position triads as MIDI pitch sets, low register)
Dm, Gm, C, F, A, Bb = [50, 53, 57], [43, 50, 55], [48, 52, 55], [41, 48, 53], [45, 49, 52], [46, 50, 53]
VERSE_CH = [Dm, Gm, C, F, Dm, A, Bb, A]
CHORUS_CH = [Gm, Dm, Gm, A, Dm, C, Dm, A]

# Lyrics: one syllable per note; hyphens split words across notes.
LYRICS = {
    "verse1": [
        "Hear the bell a-cross the bay,",
        "fog has come to take the day.",
        "Pull the cov-ers, shut your eyes,",
        "he will pass if no one cries.",
    ],
    "chorus": [
        "Ding and dong, the Bell-man's bell,",
        "stitched up smile and chi-na shell.",
        "If you see him, he sees you,",
        "hide and stay the whole night through.",
    ],
    "verse2": [
        "Chil-dren in the cha-pel sing,",
        "round the Stone, a bro-ken ring.",
        "Let-ters rat-tle down the pipe,",
        "ev-ery name is crossed and typed.",
    ],
}


def syllables(line):
    out = []
    for w in line.replace(",", "").replace(".", "").split():
        out += w.split("-")
    return out


for _sec in LYRICS.values():
    for _ln in _sec:
        assert len(syllables(_ln)) == 7, (_ln, syllables(_ln))

notes: list = []
events: list = []
vocal: list = []
rng = random.Random(1998)


def add(track, start, dur, pitch, vel):
    notes.append(Note(track, float(start), float(dur), int(pitch), int(vel)))


def melody_lines(mel):
    """yield (line_idx, beat_offset, dur, pitch) for an 8-bar melody"""
    for li, line in enumerate(mel):
        t = li * 8
        for p, d in zip(line, RHYTHM):
            yield li, t, d, p
            t += d


def lay_melody(sec, mel, track="mbox", vel=78, octave=12, drop=0.0, sing=None):
    s = SEC_START[sec]
    i = 0
    for li, t, d, p in melody_lines(mel):
        if sing is not None:
            vocal.append(VNote(s + t, d, p, syllables(sing[li])[i % 7], len(vocal) // 7))
        i += 1
        if drop and rng.random() < drop:
            continue  # fragmented: the music box "forgets" notes
        add(track, s + t, d * 0.95, p + octave, vel + rng.randint(-6, 6))


def lay_arps(sec, chords, vel=46, every=0.5, track="celesta", skip=0.0):
    s = SEC_START[sec]
    for bar, ch in enumerate(chords):
        pat = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 24, ch[2] + 12, ch[1] + 12, ch[0] + 24, ch[1] + 12]
        for k in range(int(4 / every)):
            if skip and rng.random() < skip:
                continue
            add(track, s + bar * 4 + k * every, every * 1.6, pat[k % len(pat)], vel + rng.randint(-5, 5))


def lay_pad(sec, chords, track="strings", vel=50, swell=False, octave=0):
    s = SEC_START[sec]
    for bar, ch in enumerate(chords):
        v = vel + (int(bar * 3) if swell else 0)
        for p in ch:
            add(track, s + bar * 4, 4.0, p + octave, min(110, v))
        add(track, s + bar * 4, 4.0, ch[0] - 12 + octave, min(110, v - 8))


# ---- intro: distant bell tolls in the fog, wind, hiss (numpy), low D drone
s = SEC_START["intro"]
for k, b in enumerate([0, 4, 8, 12]):
    events.append(dict(kind="handbell", t=s + b + 0.5, pitch=74, gain=0.22 + 0.02 * k, dist=1.0))
add("tbell", s + 6, 6, 50, 40)
events.append(dict(kind="drone", t=0, dur=SEC_START["verse2"] + 32 + 8, pitch=38, gain=0.08))
events.append(dict(kind="wind", t=0, dur=TOTAL_BEATS + 4, gain=0.10))
events.append(dict(kind="hiss", t=0, dur=TOTAL_BEATS + 8, gain=0.010))

# ---- verse 1: music box lullaby alone, sparse celesta
lay_melody("verse1", VERSE_MEL, vel=82, sing=LYRICS["verse1"])
lay_arps("verse1", VERSE_CH, vel=34, every=1.0)
events.append(dict(kind="handbell", t=SEC_START["verse1"] + 30, pitch=74, gain=0.15, dist=1.0))

# ---- chorus 1: strings swell, choir pad, arps in eighths
lay_melody("chorus1", CHORUS_MEL, vel=84, sing=LYRICS["chorus"])
lay_arps("chorus1", CHORUS_CH, vel=40, every=0.5)
lay_pad("chorus1", CHORUS_CH, vel=46, swell=True)
lay_pad("chorus1", CHORUS_CH, track="pad", vel=34, octave=12)
for bar in range(8):
    add("bass", SEC_START["chorus1"] + bar * 4, 4, CHORUS_CH[bar][0] - 12, 60)

# ---- middle: the Bellman approaching
s = SEC_START["middle"]
# heartbeat pulses on low D, getting faster and louder
t = 0.0
k = 0
while t < 32:
    v = 50 + int(t * 1.6)
    add("timp", s + t, 0.5, 38, v)
    add("bass", s + t, 0.4, 38, v - 6)
    add("timp", s + t + 0.35, 0.4, 38, v - 18)
    t += 2.0 if t < 12 else (1.0 if t < 24 else 0.5)
    k += 1
# tremolo cluster: D, Eb, Ab (tritone) creeping up
for bar in range(8):
    for p in [50, 51, 56] + ([57] if bar >= 4 else []):
        add("trem", s + bar * 4, 4, p, 40 + bar * 6)
# the bell motif inverted (lullaby head A A F A -> A A C# A), on tubular bells + hand bell
INV = [69, 69, 73, 69]
for rep, bar in enumerate([1, 3, 5, 6, 7]):
    for j, p in enumerate(INV):
        add("tbell", s + bar * 4 + j, 1.5, p - (12 if rep % 2 else 0), 54 + rep * 8)
# the Bellman's own hand bell: getting closer (dist 1 -> 0)
for j, b in enumerate([2, 6, 10, 14, 17, 20, 22, 24, 26, 27, 28, 29, 30, 31]):
    events.append(dict(kind="handbell", t=s + b, pitch=76, gain=0.12 + j * 0.022, dist=1.0 - j / 13.0))
events.append(dict(kind="riser", t=s + 24, dur=8, gain=0.08))
# stop dead before the lullaby returns
events.append(dict(kind="silence_cut", t=SEC_START["verse2"] - 0.25, dur=0.25))

# ---- verse 2: lullaby returns, fragmented, wobbly
lay_melody("verse2", VERSE_MEL, vel=76, drop=0.35, sing=LYRICS["verse2"])
lay_arps("verse2", VERSE_CH, vel=30, every=1.0, skip=0.4)
lay_pad("verse2", VERSE_CH, track="pad", vel=28, octave=12)
events.append(dict(kind="wobble", t=SEC_START["verse2"], dur=64, depth=1.0))

# ---- chorus 2: last chorus, thinning out, ending on the tonic
lay_melody("chorus2", CHORUS_MEL, vel=80, drop=0.2, sing=LYRICS["chorus"])
lay_pad("chorus2", CHORUS_CH[:6] + [Dm, Dm], vel=52)
lay_pad("chorus2", CHORUS_CH[:6] + [Dm, Dm], track="choir", vel=40, octave=12)
lay_arps("chorus2", CHORUS_CH[:4], vel=34, every=0.5, skip=0.3)
for bar in range(8):
    add("bass", SEC_START["chorus2"] + bar * 4, 4, (CHORUS_CH[:6] + [Dm, Dm])[bar][0] - 12, 54 - bar * 3)

# ---- outro: a single bell, then silence
events.append(dict(kind="handbell", t=SEC_START["outro"] + 1, pitch=74, gain=0.40, dist=0.6))


# ------------------------------------------------------------------ MIDI export
def write_midi(path, tracks=None, exclude=()):
    import mido
    mid = mido.MidiFile(ticks_per_beat=480)
    tr = mido.MidiTrack()
    mid.tracks.append(tr)
    tr.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(BPM), time=0))
    evs = []
    for name, info in TRACKS.items():
        if (tracks and name not in tracks) or name in exclude:
            continue
        evs.append((0, 0, mido.Message("program_change", channel=info["ch"], program=info["prog"])))
        evs.append((0, 0, mido.Message("control_change", channel=info["ch"], control=91, value=20)))
    for n in notes:
        if (tracks and n.track not in tracks) or n.track in exclude:
            continue
        ch = TRACKS[n.track]["ch"]
        on = int(n.start * 480)
        off = int((n.start + n.dur) * 480)
        evs.append((on, 2, mido.Message("note_on", channel=ch, note=n.pitch, velocity=max(1, min(127, n.vel)))))
        evs.append((off, 1, mido.Message("note_off", channel=ch, note=n.pitch, velocity=0)))
    evs.sort(key=lambda e: (e[0], e[1]))
    last = 0
    for tick, _, msg in evs:
        tr.append(msg.copy(time=tick - last))
        last = tick
    tr.append(mido.MetaMessage("end_of_track", time=480 * 8))
    mid.save(path)


if __name__ == "__main__":
    print(f"{BARS} bars, {TOTAL_BEATS} beats, {TOTAL_BEATS * BEAT:.1f} s; {len(notes)} notes, {len(events)} events, {len(vocal)} sung syllables")
    write_midi("build/theme_full.mid")
