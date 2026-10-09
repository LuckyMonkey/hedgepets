#!/usr/bin/env python3
"""The backyard's sounds, synthesised (no recordings, no network): assets/audio/*.wav, 22050 Hz mono 16-bit.

    wind_loop.wav     30 s, seamless: leaves rustling high above the fence: soft swishes in irregular gusts
    chickadee_1..3    "fee-bee": two clear whistled notes, the second lower, a little room around them
    crow_1..2         two or three caws from somewhere behind the trees (rough, distant)
    creak_1..2        a branch creaking as it sways
    chimes_1..3       wind chimes from a neighbour's porch (bright metal, and a deeper set); bamboo_1..2 wooden clacks
    leaf_blower       two or three yards over, coming and going; dog_1..2 a couple of houses down
    car_1             a car going by out front; screen_door somebody's spring door; church_bell from town

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
def slow_random(n, seconds_per_change, seed_scale=1.0):
    """A slow, irregular drift in 0..1 (no rhythm: a smoothed random walk, not sine waves, which sound like surf)."""
    steps = max(4, int(n / SR / seconds_per_change))
    pts = rng.random(steps + 1)
    pts[-1] = pts[0]                                             # loops
    xs = np.linspace(0, n, steps + 1)
    curve = np.interp(np.arange(n), xs, pts)
    return lowpass(curve, 0.15)


def wind_loop(seconds=30.0):
    """Leaves in the wind high above the fence. Not a swell (surf), not an even hiss (static): soft "shhh" swishes,
    each a patch of leaves moving for half a second to a second, clustered in irregular gusts with calm between,
    a sprinkle of crisp leaf ticks inside them, a faint mid-range breath underneath, nothing above ~5 kHz."""
    n = int(SR * seconds)
    gust = slow_random(n, 4.0) ** 2.2                            # mostly calm; gusts now and then
    x = np.zeros(n)
    # swishes: placed where the gusts are
    weights = gust / gust.sum()
    starts = rng.choice(n, size=int(seconds * 3.2), p=weights)
    for st in starts:
        dur = int(SR * rng.uniform(0.35, 1.3))
        seg = rng.standard_normal(dur)
        seg = bandpass(seg, rng.uniform(800, 2400), rng.uniform(0.6, 1.1))
        shape = np.sin(np.linspace(0, np.pi, dur)) ** 2 * (0.6 + 0.4 * np.sin(np.linspace(0, np.pi * rng.uniform(2, 5), dur)) ** 2)
        end = min(n, st + dur)
        x[st:end] += (seg * shape)[:end - st] * rng.uniform(0.3, 1.0)
    # a few crisp ticks inside the gusts
    impulses = (rng.random(n) < 0.0015 + 0.012 * gust) * rng.uniform(0.1, 0.5, n) * np.sign(rng.standard_normal(n))
    k = np.arange(90)
    ticks = np.convolve(impulses, rng.standard_normal(90) * np.exp(-k / 15.0), mode='same')
    x += lowpass(highpass(ticks, 1500), 5000) * 0.6
    # the breath of the wind itself: faint, mid, irregular
    x += bandpass(rng.standard_normal(n), 650, 0.7) * 0.18 * (0.25 + gust)
    x = lowpass(x, 5200)
    f = int(SR * 1.0)                                           # seam: crossfade the last second into the start
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


# ------------------------------------------------------------------ more chimes: deep tubes, wooden bamboo
def chimes_deep():
    notes = [523, 587, 659, 784, 880]                           # lower, mellower metal tubes
    total = np.zeros(int(SR * 7.0))
    at = 0.0
    for k in range(5):
        f = notes[rng.integers(len(notes))]
        start = int(SR * at)
        n = chime_note(f, 4.5) * (0.5 + 0.5 * rng.random())
        total[start:start + len(n)] += n[:len(total) - start]
        at += 0.3 + 0.7 * rng.random()
    return room(lowpass(total, 3500), 0.4, 0.1)


def bamboo():
    """Hollow wooden clacks: short, resonant, knocking together a few times."""
    total = np.zeros(int(SR * 4.0))
    at = 0.0
    for k in range(rng.integers(5, 9)):
        f = rng.choice([310, 370, 415, 494, 554])
        t = t_of(0.25)
        tok = (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * f * 2.1 * t)) * np.exp(-t * 28)
        tok += highpass(rng.standard_normal(len(t)), 1500) * np.exp(-t * 160) * 0.5   # the knock
        start = int(SR * at)
        total[start:start + len(tok)] += tok[:len(total) - start] * (0.5 + 0.5 * rng.random())
        at += 0.08 + 0.35 * rng.random()
        if at > 3.3:
            break
    return room(lowpass(total, 5000), 0.3, 0.06)


# ------------------------------------------------------------------ the neighbourhood, all far off
def leaf_blower(seconds=16.0):
    """Two or three yards over: an engine whine with a roar of air, coming and going as they walk the lawn."""
    t = t_of(seconds)
    f = 118 * (1 + 0.04 * np.sin(2 * np.pi * 0.21 * t) + 0.02 * slow_random(len(t), 0.8))
    phase = np.cumsum(f) / SR
    engine = sum(np.sin(2 * np.pi * phase * h) / h for h in range(1, 7))
    air = lowpass(highpass(rng.standard_normal(len(t)), 500), 2400)
    near = 0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 9.0 - 1.0)) ** 2     # walking back and forth
    x = (engine * 0.5 + air * 0.9) * near * env(len(t), 2.5, 3.5)
    return room(lowpass(x, 1500), 0.5, 0.14)


def dog():
    """A dog a couple of houses down: a few short barks."""
    parts = []
    for k in range(rng.integers(2, 5)):
        t = t_of(0.18 + 0.05 * rng.random())
        f = 420 * (1.25 - 0.4 * t / t[-1])
        phase = np.cumsum(f) / SR
        voice = 2 * (phase - np.floor(phase + 0.5)) + 0.25 * rng.standard_normal(len(t))
        bark = (bandpass(voice, 900, 1.4) + 0.5 * bandpass(voice, 1900, 2.0)) * env(len(t), 0.01, 0.07)
        parts += [bark, np.zeros(int(SR * (0.18 + 0.3 * rng.random())))]
    return room(lowpass(np.concatenate(parts), 2200), 0.5, 0.12)


def car():
    """A car going by on the street out front: a swell of tyre hiss and engine, brighter as it passes."""
    secs = 6.0
    t = t_of(secs)
    pass_env = np.exp(-((t - secs * 0.5) / 1.3) ** 2)
    tyres = highpass(rng.standard_normal(len(t)), 300)
    bright = np.zeros_like(tyres)
    acc = 0.0
    for i, v in enumerate(tyres):                                # a cutoff that opens up as it comes close
        a = math.exp(-2 * math.pi * (400 + 2200 * pass_env[i]) / SR)
        acc = (1 - a) * v + a * acc
        bright[i] = acc
    hum = np.sin(2 * np.pi * np.cumsum(70 + 8 * pass_env) / SR) * 0.4
    return room((bright + hum) * (0.05 + pass_env), 0.3, 0.12)


def screen_door():
    """Somebody's screen door: the spring creaks open, then it slaps shut."""
    open_creak = creak(0.8) * 0.6
    slap_t = t_of(0.35)
    slap = (lowpass(rng.standard_normal(len(slap_t)), 1800) * np.exp(-slap_t * 30) + 0.6 * np.sin(2 * np.pi * 140 * slap_t) * np.exp(-slap_t * 22))
    rattle = highpass(rng.standard_normal(len(slap_t)), 2500) * np.exp(-slap_t * 12) * 0.25
    x = np.concatenate([open_creak, np.zeros(int(SR * 1.2)), slap + rattle, np.zeros(int(SR * 0.1)), (slap + rattle) * 0.3])
    return room(lowpass(x, 3000), 0.4, 0.1)


def church_bell():
    """A church bell from town: three slow strokes, mostly the hum and strike note, a long way off."""
    f = 196.0
    partials = [(0.5, 0.6, 0.35), (1.0, 1.0, 0.6), (1.2, 0.5, 0.8), (1.5, 0.35, 1.0), (2.0, 0.45, 1.3), (2.5, 0.2, 1.8)]
    one = t_of(6.0)
    stroke = sum(a * np.sin(2 * np.pi * f * m * one) * np.exp(-one * d) for m, a, d in partials)
    stroke *= env(len(one), 0.004, 0.5)
    total = np.zeros(int(SR * 13.0))
    for k in range(3):
        start = int(SR * k * 3.2)
        total[start:start + len(stroke)] += stroke[:len(total) - start]
    return room(lowpass(total, 1800), 0.55, 0.16)


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
    save('chimes_3', chimes_deep(), 0.6)
    save('bamboo_1', bamboo(), 0.6)
    save('bamboo_2', bamboo(), 0.6)
    save('leaf_blower', leaf_blower(), 0.55)
    for v in range(2):
        save('dog_%d' % (v + 1), dog(), 0.6)
    save('car_1', car(), 0.6)
    save('screen_door', screen_door(), 0.6)
    save('church_bell', church_bell(), 0.6)


if __name__ == '__main__':
    main()
