"""Sung vocal for Harrow's Wake: Piper TTS (spoken lines) -> WORLD vocoder re-pitch/re-time -> choir.

For every lyric line:
 1. Piper renders the line as natural speech and reports per-phoneme sample counts.
 2. Phonemes are grouped into the 7 syllables of the line (words split on spaces,
    multi-syllable words split between vowel nuclei).
 3. WORLD (pyworld) analyses the speech (f0, spectral envelope, aperiodicity).
 4. Frames are re-timed: each syllable's onset consonants are kept at natural speed
    and placed just before the beat, the vowel is stretched to fill the note,
    the coda consonants sit at the end of the note.
 5. F0 is replaced by the melody (portamento + delayed vibrato + slight drift).
 6. Resynthesised 3x (lead + 2 detuned/offset doubles) + a breathy whisper layer,
    panned, and written to build/vocal_stem.wav on the song's timeline.

usage: python vocal.py
"""
import os
import sys
import warnings

import numpy as np
import soundfile as sf
from scipy import signal

warnings.filterwarnings("ignore")
import pyworld as pw  # noqa: E402
from piper import PiperVoice  # noqa: E402

import compose as C  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
VOICE = os.environ.get("PIPER_VOICE", "/tmp/voices/en_US-ljspeech-high.onnx")
VSR = 22050          # Piper voice sample rate
OSR = 44100          # song sample rate
FP = 5.0             # WORLD frame period, ms
CONS_BOOST = 10 ** (6 / 10)
VOWELS = set("aeiouyɑɐɒæɛɪɔʊʌəɜɚɝɘɵɤøœɶʏɨʉ")
rng = np.random.default_rng(7)


def phonemize_line(voice, text):
    """-> audio (float), list of (phoneme, n_samples)"""
    from piper.voice import SynthesisConfig
    cfg = SynthesisConfig(length_scale=1.15, noise_scale=0.5, noise_w_scale=0.6, normalize_audio=True)
    sents = voice.phonemize(text)
    phs = [p for s in sents for p in s + [" "]][:-1]
    ids = voice.phonemes_to_ids(phs)
    audio, samples = voice.phoneme_ids_to_audio(ids, cfg, include_alignments=True)
    audio = audio / max(1e-6, np.max(np.abs(audio)))
    # ids = BOS PAD (ph PAD)* EOS ; give each phoneme its own id + following pad
    pid_map = voice.config.phoneme_id_map
    out = []
    i = 0
    bos = len(pid_map["^"]) + len(pid_map["_"])
    lead = int(np.sum(samples[:bos]))
    i = bos
    for p in phs:
        k = len(pid_map.get(p, [])) + len(pid_map["_"])
        out.append((p, int(np.sum(samples[i:i + k]))))
        i += k
    tail = int(np.sum(samples[i:]))
    return audio, out, lead, tail


def syllabify(phon, n_expected, words=None):
    """Group (phoneme, samples) of a whole line into syllables around vowel nuclei.
    Returns list of dict(start, v0, v1, end) in samples (relative to the first phoneme)."""
    pl = []
    pos = 0
    for p, n in phon:
        pl.append((p, pos, pos + n))
        pos += n
    nuclei = []
    j = 0
    while j < len(pl):
        if pl[j][0] in VOWELS:
            k = j
            while k + 1 < len(pl) and (pl[k + 1][0] in VOWELS or pl[k + 1][0] in "ːˈˌ"):
                k += 1
            nuclei.append([j, k])
            j = k + 1
        else:
            j += 1
    dur = lambda r: pl[r[1]][2] - pl[r[0]][1]  # noqa: E731
    while len(nuclei) > n_expected:   # merge the pair with the shortest gap (e.g. "no one" -> one note)
        gaps = [pl[b[0]][1] - pl[a[1]][2] + 0.5 * (dur(a) + dur(b)) for a, b in zip(nuclei[:-1], nuclei[1:])]
        i = int(np.argmin(gaps))
        nuclei[i:i + 2] = [[nuclei[i][0], nuclei[i + 1][1]]]
    split_mid = {}
    while len(nuclei) < n_expected:   # split the longest nucleus in time
        i = max(range(len(nuclei)), key=lambda q: dur(nuclei[q]))
        r = nuclei[i]
        nuclei[i:i + 1] = [r + ["a"], r + ["b"]]
    # boundaries (phoneme index where the next syllable starts)
    bounds = [0]
    for a, b in zip(nuclei[:-1], nuclei[1:]):
        if len(a) == 3:
            bounds.append(None)
            continue
        gap = list(range(a[1] + 1, b[0]))
        sp = [g for g in gap if pl[g][0] == " "]
        if sp:
            bounds.append(sp[-1] + 1)
        else:
            cons = [g for g in gap if pl[g][0] not in "ˈˌ"]
            bounds.append(cons[-1] if cons else b[0])
    bounds.append(len(pl))
    sylls = []
    for si, nuc in enumerate(nuclei):
        if len(nuc) == 3:
            s0, s1 = pl[nuc[0]][1], pl[nuc[1]][2]
            mid = (s0 + s1) // 2
            if nuc[2] == "a":
                sylls.append(dict(start=pl[bounds[si]][1], v0=s0, v1=mid, end=mid))
            else:
                sylls.append(dict(start=mid, v0=mid, v1=s1, end=pl[bounds[si + 1] - 1][2]))
            continue
        j0, j1 = bounds[si], bounds[si + 1]
        sylls.append(dict(start=pl[j0][1], v0=pl[nuc[0]][1], v1=pl[nuc[1]][2], end=pl[j1 - 1][2]))
    return sylls


def word_sylls(line):
    return [len(w.split("-")) for w in line.replace(",", "").replace(".", "").split()]


def retime_and_pitch(f0, sp, ap, sylls, vnotes, lead, offset_frames):
    """Build new (f0, sp, ap) frame arrays on the song timeline for one line.
    returns arrays and the absolute start time (s) of the first frame."""
    fs = 1000.0 / FP
    s2f = lambda s: int(round((s + lead) / VSR * fs))   # noqa: E731
    beat_f = C.BEAT * fs
    segs_f0, segs_sp, segs_ap, tgt = [], [], [], []
    # onset of syllable 0 precedes its note
    # line-initial consonant: reach 40 ms back into Piper's lead-in (alignment often clips it)
    sylls[0] = dict(sylls[0], start=max(-lead, sylls[0]["start"] - int(0.04 * VSR)))
    first_onset = s2f(sylls[0]["v0"]) - s2f(sylls[0]["start"])
    first_onset = min(first_onset, int(0.16 * fs))
    t0 = vnotes[0].start * beat_f - first_onset
    cursor = t0
    for i, (sy, vn) in enumerate(zip(sylls, vnotes)):
        a, v0, v1, e = s2f(sy["start"]), s2f(sy["v0"]), s2f(sy["v1"]), s2f(sy["end"])
        onset = list(range(a, v0))
        coda = list(range(v1, e))
        if i == 0:
            onset = onset[-first_onset:] if first_onset else []
        # next syllable's onset is sung before next beat -> cut into this note
        note_end = (vn.start + vn.dur) * beat_f
        if i + 1 < len(sylls):
            nxt = sylls[i + 1]
            nxt_on = min(s2f(nxt["v0"]) - s2f(nxt["start"]), int(0.12 * fs))
        else:
            nxt_on = 0
            note_end -= 0.08 * fs   # release a little before the end of the line's last note
        onset = onset[:int(0.14 * fs)] if len(onset) > 0.14 * fs else onset
        coda = coda[:int(0.12 * fs)]
        vow_len = int(round(note_end - nxt_on - cursor - len(onset) - len(coda)))
        vow_len = max(vow_len, 4)
        vsrc = np.arange(v0, max(v1, v0 + 1))
        # stretch: linear map with slight "breathing" so long vowels are not a frozen frame
        idx = np.linspace(0, len(vsrc) - 1, vow_len)
        idx = idx + 0.15 * len(vsrc) * np.sin(np.linspace(0, np.pi * 2, vow_len)) * (len(vsrc) > 6)
        idx = np.clip(idx, 0, len(vsrc) - 1).astype(int)
        frames = onset + list(vsrc[idx]) + coda
        kinds = ["c"] * len(onset) + ["v"] * vow_len + ["c"] * len(coda)
        frames = [min(max(0, f), len(f0) - 1) for f in frames]
        for f, kd in zip(frames, kinds):
            segs_sp.append(sp[f])
            segs_ap.append(ap[f])
            voiced = f0[f] > 0 or kd == "v"
            tgt.append((vn.pitch if voiced else 0, kd, i))
        cursor += len(frames)
    sp_n = np.array(segs_sp)
    ap_n = np.array(segs_ap)
    # target f0 with portamento + delayed vibrato + drift
    n = len(tgt)
    midi = np.array([t[0] for t in tgt], float)
    voiced = midi > 0
    # fill unvoiced for smoothing, then glide
    filled = midi.copy()
    last = next((m for m in midi if m > 0), 69)
    for k in range(n):
        if filled[k] > 0:
            last = filled[k]
        else:
            filled[k] = last
    glide = int(0.06 * fs)
    win = np.ones(glide) / glide
    smooth = np.convolve(np.pad(filled, (glide, glide), mode="edge"), win, mode="same")[glide:-glide]
    # vibrato: per-syllable time since onset
    tsince = np.zeros(n)
    for k in range(1, n):
        tsince[k] = 0 if tgt[k][2] != tgt[k - 1][2] else tsince[k - 1] + 1 / fs
    vib_depth = 0.32 * np.clip((tsince - 0.28) / 0.35, 0, 1)
    tt = np.arange(n) / fs
    vib = vib_depth * np.sin(2 * np.pi * 5.4 * tt + rng.uniform(0, 6))
    drift = np.convolve(rng.normal(0, 0.15, n), np.ones(40) / 40, mode="same")
    f0_n = 440 * 2 ** ((smooth + vib + drift - 69) / 12)
    f0_n[~voiced] = 0
    # vowels sung clean: reduce aperiodicity in vowels for a purer tone
    is_v = np.array([t[1] == "v" for t in tgt])
    ap_n[is_v] = np.minimum(ap_n[is_v], 0.35 + 0.65 * ap_n[is_v] ** 2)
    # consonants +6 dB (power spectrum x4) - the classic singing-synth trick for intelligibility
    sp_n[~is_v] *= CONS_BOOST
    return f0_n, sp_n, ap_n, t0 / fs


def synth(f0, sp, ap, cents=0.0, breath=0.0):
    f = f0 * 2 ** (cents / 1200)
    a = ap.copy()
    if breath:
        a = np.clip(a + breath, 0, 1)
    y = pw.synthesize(np.ascontiguousarray(f), np.ascontiguousarray(sp), np.ascontiguousarray(a), VSR, FP)
    return y


def main():
    os.makedirs(BUILD, exist_ok=True)
    voice = PiperVoice.load(VOICE, include_alignments=True)
    total = int((C.TOTAL_BEATS * C.BEAT + 8) * OSR)
    out = np.zeros((total, 2))
    lines = []
    for sec_name in ["verse1", "chorus1", "verse2", "chorus2"]:
        key = "chorus" if sec_name.startswith("chorus") else sec_name
        lines += C.LYRICS[key]
    assert len(C.vocal) == 7 * len(lines)
    report = []
    for li, text in enumerate(lines):
        vnotes = C.vocal[li * 7:(li + 1) * 7]
        clean = text.replace("-", "").replace(",", "")
        audio, phon, lead, tail = phonemize_line(voice, clean)
        sylls = syllabify(phon, 7, word_sylls(text))
        x = audio.astype(np.float64)
        f0, t = pw.harvest(x, VSR, f0_floor=70, f0_ceil=500, frame_period=FP)
        f0 = pw.stonemask(x, f0, t, VSR)
        sp = pw.cheaptrick(x, f0, t, VSR)
        ap = pw.d4c(x, f0, t, VSR)
        F0, SP, AP, t0 = retime_and_pitch(f0, sp, ap, sylls, vnotes, lead, 0)
        layers = [
            (synth(F0, SP, AP, 0), 0.0, 1.0, 0.0),
            (synth(F0, SP, AP, +7), 0.012, 0.32, -0.55),
            (synth(F0, SP, AP, -6), 0.021, 0.32, 0.55),
            (synth(F0, SP, AP, 0, breath=0.6), 0.004, 0.22, 0.0),   # breathy whisper layer
        ]
        for y, dt, g, pan in layers:
            y = signal.resample_poly(y, 2, 1)
            i = int((t0 + dt) * OSR)
            if i < 0:
                y = y[-i:]
                i = 0
            y = y[: total - i]
            l, r = np.cos((pan + 1) * np.pi / 4) * 1.41, np.sin((pan + 1) * np.pi / 4) * 1.41
            out[i:i + len(y), 0] += y * g * l
            out[i:i + len(y), 1] += y * g * r
        report.append(f"line {li + 1:2d} @ {t0:6.2f}s  {text}")
        print(report[-1], flush=True)
    # voice EQ: cut mud, add air, soft de-ess-ish lowpass
    b, a = signal.butter(2, 180 / (OSR / 2), "high")
    out = signal.lfilter(b, a, out, axis=0)
    b, a = signal.butter(2, 9000 / (OSR / 2))
    out = signal.lfilter(b, a, out, axis=0)
    # light compression (rms follower)
    env = np.sqrt(np.convolve(np.mean(out ** 2, axis=1), np.ones(2205) / 2205, mode="same")) + 1e-6
    thr = np.percentile(env[env > 1e-4], 90) if np.any(env > 1e-4) else 1
    gain = np.where(env > thr, (thr / env) ** 0.5, 1.0)
    out *= gain[:, None]
    out /= np.max(np.abs(out)) / 0.5
    sf.write(os.path.join(BUILD, "vocal_stem.wav"), out.astype(np.float32), OSR, subtype="FLOAT")
    print("wrote build/vocal_stem.wav")


if __name__ == "__main__":
    main()
