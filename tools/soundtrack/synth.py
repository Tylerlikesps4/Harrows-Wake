"""Harrow's Wake soundtrack synth: FluidSynth stems + numpy layers + PS1 tape/crush mix.

usage: python synth.py [instrumental|vocal|both]
Writes build/mix_<version>.wav (pre-master, 44.1 kHz stereo float) and then
masters to HarrowsWake_MainTheme_<Version>.wav/.ogg/.mp3 via ffmpeg loudnorm.
"""
import os
import subprocess
import sys
import json

import numpy as np
import soundfile as sf
from scipy import signal

import compose as C

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
SF2 = os.environ.get("SF2", "/usr/share/sounds/sf2/FluidR3_GM.sf2")
TAIL = 7.0
N = int((C.TOTAL_BEATS * C.BEAT + TAIL) * SR)
rng = np.random.default_rng(1998)


def sec(beats):
    return beats * C.BEAT


# ------------------------------------------------------------------ DSP blocks
def fluid_stem(name, tracks=None, exclude=(), gain=0.5):
    mid = os.path.join(BUILD, f"{name}.mid")
    wav = os.path.join(BUILD, f"{name}.wav")
    C.write_midi(mid, tracks=tracks, exclude=exclude)
    fresh = os.path.exists(wav) and os.path.getmtime(wav) > os.path.getmtime(os.path.join(HERE, "compose.py"))
    if not fresh:
      subprocess.run(["fluidsynth", "-ni", "-q", "-R", "0", "-C", "0", "-g", str(gain), "-r", str(SR),
                     "-F", wav, SF2, mid], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    x, sr = sf.read(wav, dtype="float32", always_2d=True)
    assert sr == SR
    out = np.zeros((N, 2), np.float32)
    n = min(N, len(x))
    out[:n] = x[:n]
    return out


def handbell(f0, dur=6.0, dist=1.0):
    """Inharmonic additive hand bell (partials of a real bell: hum, prime, tierce, quint, nominal...)."""
    t = np.arange(int(dur * SR)) / SR
    ratios = [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011, 4.166, 5.433]
    amps = [0.35, 1.0, 0.55, 0.3, 0.6, 0.25, 0.2, 0.18, 0.1, 0.06]
    decs = [2.2, 3.0, 2.0, 1.4, 1.6, 0.8, 0.7, 0.6, 0.35, 0.25]
    y = np.zeros_like(t)
    for r, a, d in zip(ratios, amps, decs):
        f = f0 * r * (1 + rng.normal(0, 0.0015))
        if f > SR / 2.2:
            continue
        beat = 1 + 0.08 * np.sin(2 * np.pi * (0.7 + r * 0.3) * t)   # slight beating
        y += a * beat * np.exp(-t / (d * (0.7 + 0.3 * dist))) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28))
    clang = np.exp(-t * 60) * rng.normal(0, 1, len(t)) * 0.3       # clapper strike
    y += signal.lfilter(*signal.butter(2, [2000 / (SR / 2), 7000 / (SR / 2)], "band"), clang)
    if dist > 0.3:  # far away: darker
        y = signal.lfilter(*signal.butter(2, (9000 - 6000 * dist) / (SR / 2)), y)
    return y / np.max(np.abs(y))


def drone(f0, dur):
    t = np.arange(int(dur * SR)) / SR
    y = np.zeros_like(t)
    for k, det in enumerate([-0.15, 0.0, 0.11]):           # detuned saws
        ph = np.cumsum(2 * np.pi * f0 * (1 + det / 100) * (1 + 0.002 * np.sin(2 * np.pi * 0.07 * t + k)) / SR)
        y += signal.sawtooth(ph)
    y += 1.5 * np.sin(2 * np.pi * f0 / 2 * t)               # sub
    b, a = signal.butter(2, 380 / (SR / 2))
    y = signal.lfilter(b, a, y)
    env = np.minimum(1, t / 6.0) * np.minimum(1, (dur - t) / 6.0)
    return y * env * (0.8 + 0.2 * np.sin(2 * np.pi * 0.05 * t))


def wind(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    w = rng.normal(0, 1, n)
    out = np.zeros(n)
    # sweep a resonant band-pass through the noise (block-wise)
    blk = 2048
    zi = None
    for i in range(0, n, blk):
        fc = 400 + 300 * np.sin(2 * np.pi * 0.05 * t[i]) + 200 * np.sin(2 * np.pi * 0.13 * t[i] + 1)
        b, a = signal.iirpeak(max(120, fc) / (SR / 2), 3.0)
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        out[i:i + blk], zi = signal.lfilter(b, a, w[i:i + blk], zi=zi)
    gust = 0.6 + 0.4 * np.sin(2 * np.pi * 0.08 * t) * np.sin(2 * np.pi * 0.031 * t + 2)
    env = np.minimum(1, t / 4) * np.minimum(1, (dur - t) / 4)
    return out * gust * env


def hiss(dur):
    n = int(dur * SR)
    x = rng.normal(0, 1, n)
    b, a = signal.butter(1, [3000 / (SR / 2), 12000 / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.normal(0, 1, n)
    out = np.zeros(n)
    blk = 1024
    for i in range(0, n, blk):
        fc = 200 * (20 ** (t[i] / dur))
        b, a = signal.iirpeak(min(fc, 8000) / (SR / 2), 4)
        out[i:i + blk] = signal.lfilter(b, a, x[i:i + blk])
    return out * (t / dur) ** 2


def impulse_response(seconds=4.5, predelay=0.03, damp=6000):
    """Generated stereo IR: exponentially decaying noise with HF damping (cold chapel)."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        x = rng.normal(0, 1, n) * np.exp(-t * 6.9 / seconds)
        b, a = signal.butter(1, damp / (SR / 2))
        ir[:, c] = signal.lfilter(b, a, x)
    pd = int(predelay * SR)
    ir = np.vstack([np.zeros((pd, 2)), ir])
    return ir / np.sqrt(np.sum(ir ** 2, axis=0))


IR = None


def reverb(x, wet=0.3):
    global IR
    if IR is None:
        IR = impulse_response()
    y = np.stack([signal.fftconvolve(x[:, c], IR[:, c])[:len(x)] for c in range(2)], axis=1)
    return x * (1 - wet) + y * wet


def tape_wobble(x, depth_curve, rate=0.6, max_ms=3.5):
    """Variable delay (wow/flutter) - depth_curve per sample in 0..1"""
    n = len(x)
    t = np.arange(n) / SR
    mod = (np.sin(2 * np.pi * rate * t) * 0.7 + np.sin(2 * np.pi * 5.3 * t) * 0.08
           + np.sin(2 * np.pi * 0.17 * t + 1) * 0.3)
    d = (max_ms / 1000 * SR) * (0.15 + 0.85 * depth_curve) * (1 + mod) / 2 + 2
    idx = np.clip(np.arange(n) - d, 0, n - 1)
    i0 = np.floor(idx).astype(int)
    fr = idx - i0
    i1 = np.minimum(i0 + 1, n - 1)
    return x[i0] * (1 - fr[:, None]) + x[i1] * fr[:, None]


def ps1_crush(x, sr_target=22050, bits=12):
    """PS1 SPU flavour: 22 kHz resample (alias-y), 12-bit quantise, back to 44.1 kHz."""
    y = signal.resample_poly(x, 1, 2, axis=0)
    q = 2 ** (bits - 1)
    y = np.round(y * q) / q
    return signal.resample_poly(y, 2, 1, axis=0)[:len(x)]


def place(buf, y, t_sec, gain=1.0, pan=0.0):
    i = int(t_sec * SR)
    if i >= len(buf):
        return
    y = y[: len(buf) - i]
    if y.ndim == 1:
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        buf[i:i + len(y), 0] += y * gain * l * 1.41
        buf[i:i + len(y), 1] += y * gain * r * 1.41
    else:
        buf[i:i + len(y)] += y * gain


def midi_hz(p):
    return 440.0 * 2 ** ((p - 69) / 12)


# ------------------------------------------------------------------ render
def render_layers():
    os.makedirs(BUILD, exist_ok=True)
    stems = {}
    stems["mbox"] = fluid_stem("stem_mbox", tracks=["mbox"], gain=0.55)
    stems["band"] = fluid_stem("stem_band", exclude=["mbox"], gain=0.5)
    fx = np.zeros((N, 2), np.float32)       # numpy layers that get reverb
    dry = np.zeros((N, 2), np.float32)      # wind / hiss (no reverb)
    wob = np.zeros(N)
    cuts = []
    for e in C.events:
        t = sec(e["t"])
        k = e["kind"]
        if k == "handbell":
            y = handbell(midi_hz(e["pitch"]), 7.0, e["dist"])
            place(fx, y, t, e["gain"], pan=0.5 * (e["dist"] - 0.5))
        elif k == "drone":
            place(fx, drone(midi_hz(e["pitch"]), sec(e["dur"])), t, e["gain"])
        elif k == "wind":
            w = wind(sec(e["dur"]))
            place(dry, w, t, e["gain"] * 2.0, pan=-0.3)
            place(dry, np.roll(w, 12345), t, e["gain"] * 2.0, pan=0.3)
        elif k == "hiss":
            place(dry, hiss(sec(e["dur"])), t, e["gain"], 0.0)
        elif k == "riser":
            place(fx, riser(sec(e["dur"])), t, e["gain"])
        elif k == "wobble":
            i, j = int(t * SR), int((t + sec(e["dur"])) * SR)
            ramp = np.linspace(0, 1, j - i) ** 0.5
            wob[i:j] = np.maximum(wob[i:j], e["depth"] * np.minimum(ramp * 3, 1))
        elif k == "silence_cut":
            cuts.append((t, sec(e["dur"])))
    stems["fx"] = fx
    stems["dry"] = dry
    return stems, wob, cuts


def section_curve(names, val_in, val_out=1.0, fade=0.8):
    """per-sample gain curve: val_in inside the named sections, val_out elsewhere"""
    g = np.full(N, val_out, np.float32)
    for n in names:
        a = int(sec(C.SEC_START[n]) * SR)
        bars = dict(C.SECTIONS)[n]
        b = int(sec(C.SEC_START[n] + bars * 4) * SR)
        g[a:b] = val_in
    k = int(fade * SR)
    win = np.hanning(k) / np.sum(np.hanning(k))
    return np.convolve(g, win, mode="same").astype(np.float32)


def mix(version, stems, wob, cuts, vocal_stem=None):
    mbox = stems["mbox"].copy()
    band = stems["band"].copy()
    fx = stems["fx"].copy()
    if version == "vocal":
        sung = ["verse1", "chorus1", "verse2", "chorus2"]
        duck = section_curve(sung, 10 ** (-4.5 / 20))       # duck the band ~4.5 dB under the singer
        mduck = section_curve(sung, 10 ** (-7 / 20))        # music box doubles the voice quietly
        band *= duck[:, None]
        fx *= duck[:, None]
        mbox *= mduck[:, None]
    music = mbox * 1.0 + band * 1.0 + fx * 1.0
    music = reverb(music, wet=0.28)
    if vocal_stem is not None:   # the singer sits closer: own, drier reverb send
        music = music + reverb(vocal_stem, wet=0.2)
    music = tape_wobble(music, wob)
    music = music + stems["dry"]
    for t, d in cuts:  # sudden silence before the lullaby returns (keeps reverb tail short)
        a, b = int(t * SR), int((t + d) * SR)
        music[a:b] *= np.linspace(1, 0.05, b - a)[:, None]
        music[b:b + int(0.05 * SR)] *= np.linspace(0.05, 1, int(0.05 * SR))[:, None]
    # clean the sub rumble, gentle tape low-pass + PS1 crush
    b, a = signal.butter(2, 38 / (SR / 2), "high")
    music = signal.lfilter(b, a, music, axis=0)
    b, a = signal.butter(2, 11000 / (SR / 2))
    music = signal.lfilter(b, a, music, axis=0)
    music = ps1_crush(music)
    # final fade to silence after the last bell
    end = int(len(music) - 1.5 * SR)
    music[end:] *= np.linspace(1, 0, len(music) - end)[:, None]
    music /= max(1e-9, np.max(np.abs(music))) / 0.8
    return music.astype(np.float32)


def master(src_wav, base):
    """two-pass loudnorm to -14 LUFS / -1.5 dBTP; WAV 16-bit, OGG q5, MP3 V2"""
    p1 = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", src_wav, "-af",
                         "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                        capture_output=True, text=True).stderr
    js = json.loads(p1[p1.rindex("{"):p1.rindex("}") + 1])
    af = ("loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={input_i}:measured_TP={input_tp}:"
          "measured_LRA={input_lra}:measured_thresh={input_thresh}:offset={target_offset}:linear=true").format(**js)
    wav = base + ".wav"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src_wav, "-af", af, "-ar", "44100",
                    "-c:a", "pcm_s16le", wav], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", base + ".ogg"], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libmp3lame", "-q:a", "2", base + ".mp3"], check=True)
    return js


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    stems, wob, cuts = render_layers()
    for v in (["instrumental", "vocal"] if which == "both" else [which]):
        voc = None
        if v == "vocal":
            vx, sr = sf.read(os.path.join(BUILD, "vocal_stem.wav"), dtype="float32", always_2d=True)
            voc = np.zeros((N, 2), np.float32)
            n = min(N, len(vx))
            voc[:n] = vx[:n]
            voc *= float(os.environ.get("VOCAL_GAIN", "1.4"))
        m = mix(v, stems, wob, cuts, voc)
        pre = os.path.join(BUILD, f"mix_{v}.wav")
        sf.write(pre, m, SR, subtype="FLOAT")
        base = os.path.join(HERE, "HarrowsWake_MainTheme_" + v.capitalize())
        js = master(pre, base)
        print(v, "input LUFS", js["input_i"], "-> -14")
