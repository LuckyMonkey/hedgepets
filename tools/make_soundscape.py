#!/usr/bin/env python3
"""The backyard's sounds, synthesised (no recordings, no network): assets/audio/*.wav, 22050 Hz mono 16-bit.

    wind_loop.wav     12 s, seamless: wind in the leaves high above the fence (soft gusts, a dry rustle on top)
    chickadee_1..3    "fee-bee": two clear whistled notes, the second lower, a little room around them
    crow_1..2         two or three caws from somewhere behind the trees (rough, distant)
    creak_1..2        a branch creaking as it sways
    chimes_1..2       a few notes of wind chimes, faint, from a neighbour's porch

Scripts/garden/soundscape.gd plays them: the wind always, the rest now and then, with long quiet in between.

    python3 tools/make_soundscape.py
"""
import math
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
rng = np.random.default_rng(1775)


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(ROOT, 'assets/audio', name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, '%.1f s' % (len(x) / SR))


def lowpass(x, hz):
    a = math.exp(-2 * math.pi * hz / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, hz):
    return x - lowpass(x, hz)


def bandpass(x, hz, q):
    """A biquad band-pass (RBJ cookbook), constant peak gain."""
    w0 = 2 * math.pi * hz / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def room(x, wet=0.25, size=0.06):
    """A little space: a few soft, decaying echoes (a garden, not a hall)."""
    out = np.concatenate([x, np.zeros(int(SR * 1.2))])
    for k, (delay, g) in enumerate([(size, 0.5), (size * 1.7, 0.35), (size * 2.9, 0.22), (size * 4.3, 0.12)]):
        d = int(SR * delay)
        out[d:d + len(x)] += lowpass(x, 2500 - k * 400) * g * wet
    return out


def env(n, attack, release):
    e = np.ones(n)
    a, r = int(SR * attack), int(SR * release)
    e[:a] = np.linspace(0, 1, a) ** 2
    e[n - r:] *= np.linspace(1, 0, r) ** 2
    return e


def t_of(seconds):
    return np.arange(int(SR * seconds)) / SR


# ------------------------------------------------------------------ wind in the leaves (seamless loop)
def wind_loop(seconds=12.0):
    n = int(SR * seconds)
    t = np.arange(n) / SR
    white = rng.standard_normal(n)
    body = lowpass(lowpass(white, 500), 900)                       # the deep air movement
    # gusts: slow swells whose periods divide the loop, so it joins seamlessly
    gust = 0.55 + 0.25 * np.sin(2 * np.pi * t / seconds + 0.4) + 0.15 * np.sin(2 * np.pi * 3 * t / seconds + 1.1) \
        + 0.08 * np.sin(2 * np.pi * 7 * t / seconds)
    # the rustle: leaves high up, little dry bursts riding on the gusts
    crackle = highpass(rng.standard_normal(n), 2500) * (rng.random(n) < 0.06)
    crackle = lowpass(crackle, 6000)
    rustle_env = np.clip(gust - 0.45, 0, None) ** 1.5
    x = body * gust + crackle * rustle_env * 0.9
    # seam: crossfade the last half second into the start
    f = int(SR * 0.5)
    fade = np.linspace(0, 1, f)
    x[:f] = x[:f] * fade + x[-f:] * (1 - fade)
    return x[:n - f]


# ------------------------------------------------------------------ chickadee: "fee-bee"
def whistle(f0, f1, seconds, vibrato=7.0):
    t = t_of(seconds)
    f = np.linspace(f0, f1, len(t)) * (1 + 0.004 * np.sin(2 * np.pi * vibrato * t))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(phase) + 0.08 * np.sin(2 * phase)) * env(len(t), 0.03, 0.08)


def chickadee(variant):
    hi = 3950 + variant * 60
    fee = whistle(hi, hi - 40, 0.34)
    bee = whistle(hi * 0.86, hi * 0.84, 0.38)
    x = np.concatenate([fee, np.zeros(int(SR * 0.07)), bee])
    if variant == 2:                                             # sometimes the "bee" is split: fee-bee-ee
        x = np.concatenate([fee, np.zeros(int(SR * 0.06)), whistle(hi * 0.86, hi * 0.85, 0.18), np.zeros(int(SR * 0.03)), whistle(hi * 0.86, hi * 0.84, 0.2)])
    return room(lowpass(x, 7000), 0.3, 0.05)


# ------------------------------------------------------------------ crow, far off behind the trees
def caw(seconds=0.38, f0=520.0):
    t = t_of(seconds)
    f = f0 * (1.05 - 0.2 * t / seconds) * (1 + 0.03 * np.sin(2 * np.pi * 31 * t))
    phase = np.cumsum(f) / SR
    saw = 2 * (phase - np.floor(phase + 0.5))                   # buzzy
    rough = saw * (0.75 + 0.25 * np.sin(2 * np.pi * 70 * t)) + 0.12 * rng.standard_normal(len(t))   # buzzy voice, a little breath
    voice = bandpass(rough, 1250, 1.6) + 0.6 * bandpass(rough, 2400, 2.5)
    return voice * env(len(t), 0.02, 0.12)


def crow(count):
    parts = []
    for k in range(count):
        parts.append(caw(0.36 + 0.05 * rng.random(), 500 + 40 * rng.random()))
        parts.append(np.zeros(int(SR * (0.32 + 0.12 * rng.random()))))
    x = np.concatenate(parts)
    return room(lowpass(x, 2600), 0.45, 0.11)                   # distant: duller, more room


# ------------------------------------------------------------------ a branch creaking as it sways
def creak(seconds):
    t = t_of(seconds)
    # stick-slip: a pulse train whose rate wanders slowly (wood grinding on wood)
    rate = 95 + 45 * np.sin(2 * np.pi * t / seconds * 1.3) + 12 * rng.standard_normal(len(t)).cumsum() / SR
    phase = np.cumsum(rate) / SR
    pulses = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
    x = bandpass(pulses, 700, 1.2) + 0.5 * bandpass(pulses, 1600, 2.0)
    swell = np.sin(np.pi * t / seconds) ** 1.5
    return room(lowpass(x * swell, 3000), 0.3, 0.07)


# ------------------------------------------------------------------ wind chimes, a neighbour's porch
def chime_note(f, seconds=3.2):
    t = t_of(seconds)
    partials = [(1.0, 1.0, 1.4), (2.76, 0.45, 2.2), (5.40, 0.22, 3.5), (8.93, 0.1, 5.0)]   # a free bar's partials
    x = sum(a * np.sin(2 * np.pi * f * m * t) * np.exp(-t * d) for m, a, d in partials)
    return x * env(len(t), 0.002, 0.3)


def chimes(variant):
    notes = [1047, 1175, 1319, 1568, 1760, 2093]                # a pentatonic set, like most chimes
    total = np.zeros(int(SR * 6.0))
    at = 0.0
    for k in range(4 + variant):
        f = notes[rng.integers(len(notes))]
        start = int(SR * at)
        n = chime_note(f) * (0.5 + 0.5 * rng.random())
        total[start:start + len(n)] += n[:len(total) - start]
        at += 0.25 + 0.6 * rng.random()
        if at > 2.6:
            break
    return room(lowpass(total, 4500), 0.35, 0.09)


def main():
    os.makedirs(os.path.join(ROOT, 'assets/audio'), exist_ok=True)
    save('wind_loop', wind_loop(), 0.7)
    for v in range(3):
        save('chickadee_%d' % (v + 1), chickadee(v), 0.7)
    for v, c in enumerate((2, 3)):
        save('crow_%d' % (v + 1), crow(c), 0.7)
    for v, secs in enumerate((1.4, 2.0)):
        save('creak_%d' % (v + 1), creak(secs), 0.6)
    for v in range(2):
        save('chimes_%d' % (v + 1), chimes(v), 0.6)


if __name__ == '__main__':
    main()
