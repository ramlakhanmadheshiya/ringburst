#!/usr/bin/env python3
"""
Ringburst -- procedural audio.

Synthesises every sound effect and all ten music loops from scratch (no
samples, no third-party material) using only the Python standard library:

    python3 tools/synth_audio.py

Writes 16-bit mono WAV files to assets/audio/sfx and assets/audio/music.
Deterministic (fixed seeds): rerunning gives identical files. Released with the
project under CC0 terms.

Music: one synthwave loop per world (its own key, mode and tempo), a calmer
menu loop and a heavier boss loop. Each is 8 bars of four-on-the-floor kick,
claps, hats, an eighth-note bass, a detuned pad and a sixteenth-note arp. The
tail is folded back onto the start so ringing notes cross the loop point.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SFX_SR = 44100
MUSIC_SR = 22050
TAU = 2 * math.pi


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def buf(seconds, sr):
    return [0.0] * int(seconds * sr)


def write_wav(path, data, sr, peak=0.89):
    m = max(1e-9, max(abs(v) for v in data))
    k = peak / m
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for v in data:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, v * k)) * 32767))
        w.writeframes(bytes(frames))


def env(t, attack, decay):
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def add_tone(out, sr, start, freq, dur, amp, attack=0.003, decay=0.15, wave_="sine", sweep=0.0, vibrato=0.0):
    """A pitched voice: sine, square-ish, saw-ish or triangle, with an optional sweep."""
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    phase = 0.0
    for i in range(max(0, n)):
        t = i / sr
        f = freq * (1.0 + sweep * t) if sweep >= -0.99 else freq
        if vibrato:
            f *= 1.0 + 0.004 * math.sin(TAU * 5.5 * t) * vibrato
        phase += TAU * max(1.0, f) / sr
        if wave_ == "sine":
            v = math.sin(phase)
        elif wave_ == "square":
            v = math.sin(phase) + 0.33 * math.sin(3 * phase) + 0.2 * math.sin(5 * phase)
        elif wave_ == "saw":
            v = math.sin(phase) + 0.5 * math.sin(2 * phase) + 0.33 * math.sin(3 * phase) + 0.25 * math.sin(4 * phase)
        else:
            v = math.sin(phase) - 0.11 * math.sin(3 * phase)
        out[s0 + i] += amp * env(t, attack, decay) * v


def add_sweep(out, sr, start, f0, f1, dur, amp, decay=0.2, wave_="sine"):
    """Exponential pitch glide from f0 to f1."""
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    phase = 0.0
    for i in range(max(0, n)):
        t = i / sr
        k = t / max(1e-6, dur)
        f = f0 * (f1 / f0) ** k
        phase += TAU * f / sr
        v = math.sin(phase) if wave_ == "sine" else (math.sin(phase) + 0.4 * math.sin(2 * phase))
        out[s0 + i] += amp * env(t, 0.002, decay) * v


def add_noise(out, sr, start, dur, amp, decay=0.1, attack=0.001, hp=0, seed=1, lp=0.0):
    """Noise burst; hp = number of differencing passes (brighter), lp = one-pole smoothing 0..1."""
    rnd = random.Random(seed)
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    prev = [0.0, 0.0, 0.0]
    low = 0.0
    for i in range(max(0, n)):
        t = i / sr
        v = rnd.uniform(-1, 1)
        for p in range(hp):
            v, prev[p] = v - prev[p], v
        if lp > 0:
            low = low + (v - low) * (1.0 - lp)
            v = low
        out[s0 + i] += amp * env(t, attack, decay) * v


def add_bell(out, sr, start, freq, dur, amp, decay=0.4):
    for mult, a in ((1, 1.0), (2.0, 0.4), (3.01, 0.16), (4.2, 0.08), (5.4, 0.04)):
        add_tone(out, sr, start, freq * mult, dur, amp * a, 0.002, decay / (1 + (mult - 1) * 0.6))


def fade_tail(out, sr, seconds=0.01):
    n = int(seconds * sr)
    for i in range(min(n, len(out))):
        out[-1 - i] *= i / n


# --- Sound effects -----------------------------------------------------------------

def sfx():
    sr = SFX_SR
    S = {}

    o = buf(0.06, sr); add_tone(o, sr, 0, 1400, 0.05, 0.6, 0.001, 0.012); add_tone(o, sr, 0, 700, 0.05, 0.3, 0.001, 0.02); S["click"] = o
    o = buf(0.18, sr); add_sweep(o, sr, 0, 420, 900, 0.16, 0.5, 0.08); add_tone(o, sr, 0.03, 1320, 0.12, 0.15, 0.005, 0.05); S["open"] = o
    o = buf(0.5, sr); add_bell(o, sr, 0, mtof(83), 0.4, 0.5, 0.25); add_bell(o, sr, 0.07, mtof(88), 0.4, 0.5, 0.3); S["coin"] = o
    o = buf(0.8, sr)
    for i, m in enumerate((72, 76, 79, 84)):
        add_bell(o, sr, i * 0.07, mtof(m), 0.6, 0.45, 0.35)
    S["unlock"] = o
    o = buf(0.3, sr); add_sweep(o, sr, 0, 220, 140, 0.25, 0.5, 0.12, "saw"); S["error"] = o
    o = buf(0.7, sr); add_bell(o, sr, 0, mtof(84), 0.6, 0.6, 0.35); add_noise(o, sr, 0, 0.3, 0.05, 0.1, hp=2, seed=3); S["star"] = o
    o = buf(0.03, sr); add_tone(o, sr, 0, 2200, 0.025, 0.5, 0.0005, 0.006); S["tick"] = o
    o = buf(0.09, sr); add_tone(o, sr, 0, 1760, 0.08, 0.5, 0.001, 0.03); add_tone(o, sr, 0, 2640, 0.08, 0.25, 0.001, 0.025); S["edge"] = o
    # Release: a soft thump and an airy whoosh outward.
    o = buf(0.45, sr)
    add_sweep(o, sr, 0, 160, 50, 0.3, 0.8, 0.12)
    add_noise(o, sr, 0, 0.42, 0.35, 0.16, attack=0.02, hp=1, seed=5, lp=0.6)
    S["release"] = o
    # Perfect: a bright chord bell with sparkle (pitched per combo in game).
    o = buf(0.9, sr)
    add_bell(o, sr, 0, mtof(72), 0.8, 0.55, 0.45)
    add_bell(o, sr, 0, mtof(79), 0.8, 0.35, 0.4)
    add_bell(o, sr, 0.02, mtof(84), 0.8, 0.25, 0.35)
    add_noise(o, sr, 0, 0.25, 0.08, 0.06, hp=2, seed=7)
    S["perfect"] = o
    o = buf(0.06, sr); add_noise(o, sr, 0, 0.05, 0.5, 0.012, hp=1, seed=9); add_tone(o, sr, 0, 900, 0.04, 0.2, 0.001, 0.01); S["hit"] = o
    o = buf(0.22, sr); add_sweep(o, sr, 0, 140, 60, 0.2, 0.8, 0.07); add_noise(o, sr, 0, 0.1, 0.3, 0.03, hp=1, seed=10); S["hit_boss"] = o
    o = buf(0.14, sr); add_sweep(o, sr, 0, 320, 980, 0.07, 0.6, 0.04); add_noise(o, sr, 0, 0.06, 0.25, 0.015, hp=2, seed=11); S["pop"] = o
    o = buf(1.4, sr)
    add_sweep(o, sr, 0, 120, 30, 1.0, 1.0, 0.35)
    add_noise(o, sr, 0, 1.3, 0.8, 0.35, seed=12, lp=0.85)
    add_noise(o, sr, 0, 0.3, 0.3, 0.06, hp=1, seed=13)
    S["boom"] = o
    o = buf(0.7, sr)
    rnd = random.Random(14)
    for i in range(14):
        add_tone(o, sr, rnd.uniform(0, 0.05), rnd.uniform(2500, 6500), 0.5, 0.12, 0.001, rnd.uniform(0.04, 0.2))
    add_noise(o, sr, 0, 0.2, 0.3, 0.05, hp=2, seed=15)
    S["shatter"] = o
    o = buf(0.3, sr); add_tone(o, sr, 0, 2500, 0.25, 0.4, 0.001, 0.08); add_tone(o, sr, 0, 3710, 0.25, 0.25, 0.001, 0.06); S["clink"] = o
    o = buf(0.6, sr)
    add_sweep(o, sr, 0, 200, 60, 0.4, 0.9, 0.18, "saw")
    add_noise(o, sr, 0, 0.35, 0.5, 0.1, seed=16, lp=0.5)
    add_sweep(o, sr, 0.05, 600, 180, 0.4, 0.25, 0.15)
    S["hurt"] = o
    o = buf(0.8, sr)
    for i, m in enumerate((67, 74, 79, 86)):
        add_tone(o, sr, i * 0.05, mtof(m), 0.6, 0.25, 0.01, 0.3, "tri")
    add_noise(o, sr, 0, 0.5, 0.05, 0.2, hp=2, seed=17)
    S["shield"] = o
    o = buf(0.07, sr); add_tone(o, sr, 0, 2400, 0.06, 0.4, 0.001, 0.02); add_tone(o, sr, 0.02, 3200, 0.05, 0.25, 0.001, 0.015); S["gem"] = o
    o = buf(0.9, sr)
    for i, m in enumerate((72, 76, 79, 84, 88)):
        add_tone(o, sr, i * 0.06, mtof(m), 0.4, 0.3, 0.002, 0.12, "square")
    add_bell(o, sr, 0.32, mtof(96), 0.5, 0.15, 0.3)
    S["levelup"] = o
    o = buf(0.5, sr); add_bell(o, sr, 0, mtof(79), 0.4, 0.4, 0.2); add_bell(o, sr, 0.08, mtof(86), 0.4, 0.45, 0.25); S["upgrade"] = o
    o = buf(1.8, sr)
    add_tone(o, sr, 0, 55, 1.7, 0.6, 0.25, 0.8, "saw", vibrato=1.0)
    add_tone(o, sr, 0, 82.4, 1.7, 0.4, 0.3, 0.7, "saw", vibrato=1.0)
    add_tone(o, sr, 0.1, 110, 1.6, 0.25, 0.4, 0.6, "square")
    add_noise(o, sr, 0, 1.6, 0.15, 0.6, attack=0.3, seed=18, lp=0.8)
    S["boss"] = o
    o = buf(0.3, sr); add_tone(o, sr, 0, 1000, 0.08, 0.4, 0.002, 0.03, "square"); add_tone(o, sr, 0.12, 1000, 0.08, 0.4, 0.002, 0.03, "square"); S["warn"] = o
    o = buf(0.18, sr)
    rnd = random.Random(19)
    phase = 0.0
    for i in range(len(o)):
        t = i / sr
        f = 1800 * math.exp(-t * 10) + 200 + rnd.uniform(-150, 150)
        phase += TAU * f / sr
        o[i] += 0.5 * math.copysign(1, math.sin(phase)) * env(t, 0.001, 0.05)
    S["zap"] = o
    o = buf(0.4, sr); add_sweep(o, sr, 0, 700, 160, 0.35, 0.35, 0.15, "saw"); add_noise(o, sr, 0, 0.3, 0.12, 0.1, seed=20, lp=0.5); S["fizzle"] = o
    o = buf(1.6, sr)
    for i, m in enumerate((72, 76, 79, 84)):
        add_tone(o, sr, i * 0.11, mtof(m), 0.5, 0.35, 0.003, 0.18, "square")
    for m in (72, 76, 79, 84):
        add_tone(o, sr, 0.5, mtof(m), 1.0, 0.2, 0.02, 0.5, "saw")
    add_bell(o, sr, 0.5, mtof(96), 1.0, 0.15, 0.6)
    S["win"] = o
    o = buf(1.4, sr)
    for i, m in enumerate((67, 63, 60, 55)):
        add_tone(o, sr, i * 0.16, mtof(m), 0.6, 0.35, 0.005, 0.25, "tri")
    add_sweep(o, sr, 0.6, 110, 40, 0.8, 0.5, 0.4)
    S["lose"] = o

    os.makedirs(SFX_DIR, exist_ok=True)
    for name, data in S.items():
        fade_tail(data, sr)
        write_wav(os.path.join(SFX_DIR, name + ".wav"), data, sr, 0.85)
    return len(S)


# --- Music ----------------------------------------------------------------------------

SCALES = {
    "minor": (0, 2, 3, 5, 7, 8, 10),
    "dorian": (0, 2, 3, 5, 7, 9, 10),
    "phrygian": (0, 1, 3, 5, 7, 8, 10),
    "major": (0, 2, 4, 5, 7, 9, 11),
    "lydian": (0, 2, 4, 6, 7, 9, 11),
    "mixolydian": (0, 2, 4, 5, 7, 9, 10),
}

# name: (bpm, root midi, scale, chord degrees for 8 bars (2 bars each x 4), drums, seed)
TRACKS = {
    "menu": (100, 45, "dorian", (0, 3, 5, 4), "soft", 101),
    "w1": (112, 45, "minor", (0, 5, 2, 6), "full", 1),
    "w2": (120, 47, "dorian", (0, 3, 6, 4), "full", 2),
    "w3": (108, 43, "mixolydian", (0, 6, 3, 4), "full", 3),
    "w4": (124, 44, "minor", (0, 2, 5, 4), "full", 4),
    "w5": (116, 46, "lydian", (0, 1, 4, 5), "full", 5),
    "w6": (126, 42, "phrygian", (0, 1, 5, 3), "full", 6),
    "w7": (110, 48, "dorian", (0, 4, 2, 5), "full", 7),
    "w8": (132, 40, "minor", (0, 5, 3, 6), "full", 8),
    "boss": (140, 40, "phrygian", (0, 1, 0, 6), "heavy", 9),
}


def chord(root, scale, degree):
    s = SCALES[scale]
    notes = []
    for k in (0, 2, 4, 6):
        d = degree + k
        notes.append(root + s[d % 7] + 12 * (d // 7))
    return notes


def track(name, spec):
    bpm, root, scale, prog, drums, seed = spec
    sr = MUSIC_SR
    beat = 60.0 / bpm
    bars = 8
    length = bars * 4 * beat
    tail = 2.0
    out = buf(length + tail, sr)
    rnd = random.Random(seed)
    soft = drums == "soft"
    heavy = drums == "heavy"
    # Drums.
    for b in range(bars * 4):
        t = b * beat
        if not soft or b % 2 == 0:
            add_sweep(out, sr, t, 150, 42, 0.3, 0.9 if not soft else 0.45, 0.11)
        if not soft and b % 4 in (1, 3):
            add_noise(out, sr, t, 0.2, 0.35 if not heavy else 0.45, 0.06, hp=1, seed=seed * 100 + b, lp=0.2)
            add_tone(out, sr, t, 220, 0.1, 0.15, 0.001, 0.03)
        for h in range(2 if not heavy else 4):
            step = beat / (2 if not heavy else 4)
            vel = (0.12 if h % 2 else 0.2) * (0.6 if soft else 1.0)
            add_noise(out, sr, t + h * step, 0.05, vel, 0.012, hp=2, seed=seed * 1000 + b * 4 + h)
    # Harmony: each chord lasts 2 bars.
    for ci, deg in enumerate(prog):
        notes = chord(root, scale, deg)
        t0 = ci * 8 * beat
        dur = 8 * beat
        # Pad.
        for k, m in enumerate(notes[:3]):
            for det in (-0.12, 0.12):
                add_tone(out, sr, t0, mtof(m + 12 + det), dur + 0.5, 0.05 if not soft else 0.07, 0.6, 2.5, "saw")
        # Bass: eighth notes on the root, octave pops.
        for e in range(16):
            m = notes[0] - 12 + (12 if e % 4 == 3 else 0)
            add_tone(out, sr, t0 + e * beat / 2, mtof(m), beat / 2, 0.32 if not soft else 0.2, 0.004, 0.12, "saw")
        # Arp: sixteenths over the chord, a different shape per track.
        pattern = [0, 1, 2, 3, 2, 1, 3, 2] if seed % 2 else [0, 2, 1, 3, 0, 3, 2, 1]
        steps = 32 if not soft else 16
        div = 4 if not soft else 2
        for s in range(steps):
            if rnd.random() < (0.12 if not heavy else 0.05):
                continue
            m = notes[pattern[s % len(pattern)]] + 24
            add_tone(out, sr, t0 + s * beat / div, mtof(m), beat / div * 1.6, 0.08 if not soft else 0.07, 0.003, 0.09, "square" if not soft else "tri")
    # A short lead motif in bars 5-8 (not in the menu).
    if not soft:
        s = SCALES[scale]
        t = 4 * 4 * beat
        motif = [0, 2, 4, 3, 2, 4, 5, 4]
        for i, d in enumerate(motif):
            m = root + 24 + s[d % 7] + 12 * (d // 7)
            add_tone(out, sr, t + i * beat, mtof(m), beat * 0.9, 0.1, 0.01, 0.35, "tri", vibrato=1.0)
            add_tone(out, sr, t + 8 * beat + i * beat, mtof(m + (12 if i % 2 else 7)), beat * 0.9, 0.06, 0.01, 0.3, "tri", vibrato=1.0)
    # Fold the tail onto the start for a seamless loop.
    n = int(length * sr)
    for i in range(len(out) - n):
        out[i] += out[n + i]
    return out[:n]


def music():
    os.makedirs(MUSIC_DIR, exist_ok=True)
    for name, spec in TRACKS.items():
        data = track(name, spec)
        write_wav(os.path.join(MUSIC_DIR, name + ".wav"), data, MUSIC_SR, 0.8)
        print("music", name, "%.1f s" % (len(data) / MUSIC_SR))
    return len(TRACKS)


if __name__ == "__main__":
    n = sfx()
    print("sfx:", n)
    music()
