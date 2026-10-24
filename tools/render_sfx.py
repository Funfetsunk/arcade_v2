"""Renders the original game's synthesized Web Audio sounds (src/sfx.ts) to WAV files.

The original built every sound at runtime from oscillators, envelopes and filtered
noise. Rendering them once to assets/audio/ lets Godot play them as ordinary
AudioStreams, with no per-sample work on the web build.

Usage (needs numpy):
    python tools/render_sfx.py assets/audio
"""
import os
import sys
import wave

import numpy as np

SFX_RATE = 44100
LOOP_RATE = 22050
TAIL = 0.02  # oscillators stop this long after their envelope ends, as in sfx.ts

out_dir = sys.argv[1]
os.makedirs(out_dir, exist_ok=True)
rng = np.random.default_rng(37)


def oscillator(wave_type, freqs, rate):
    """Band-limited waveform for a (possibly sliding) per-sample frequency array."""
    phase = 2 * np.pi * np.cumsum(freqs) / rate
    if wave_type == 'sine':
        return np.sin(phase)
    out = np.zeros_like(phase)
    top = rate / 2 / freqs.max()
    if wave_type == 'square':
        for k in range(1, int(top) + 1, 2):
            out += np.sin(k * phase) / k
        return out * 4 / np.pi
    if wave_type == 'sawtooth':
        for k in range(1, int(top) + 1):
            out += (-1) ** (k + 1) * np.sin(k * phase) / k
        return out * 2 / np.pi
    if wave_type == 'triangle':
        for i, k in enumerate(range(1, int(top) + 1, 2)):
            out += (-1) ** i * np.sin(k * phase) / (k * k)
        return out * 8 / np.pi ** 2
    raise ValueError(wave_type)


def blip(freq, dur, wave_type='square', vol=0.3, slide_to=None, rate=SFX_RATE):
    """sfx.ts blip(): 8 ms exponential attack, exponential decay to silence at `dur`."""
    n = int((dur + TAIL) * rate)
    t = np.arange(n) / rate
    if slide_to:
        freqs = np.where(t < dur, freq * (slide_to / freq) ** (np.minimum(t, dur) / dur), slide_to)
    else:
        freqs = np.full(n, float(freq))
    env = np.where(t < 0.008, 0.0001 * (vol / 0.0001) ** (t / 0.008),
                   vol * (0.0001 / vol) ** np.clip((t - 0.008) / (dur - 0.008), 0, 1))
    env[t >= dur] = 0.0
    return oscillator(wave_type, freqs, rate) * env


def lowpass(signal, cutoff, rate):
    """RBJ biquad low-pass (Q = 1/sqrt 2), the Web Audio BiquadFilter default shape."""
    w0 = 2 * np.pi * cutoff / rate
    alpha = np.sin(w0) / (2 * (1 / np.sqrt(2)))
    cos = np.cos(w0)
    b = np.array([(1 - cos) / 2, 1 - cos, (1 - cos) / 2]) / (1 + alpha)
    a1, a2 = -2 * cos / (1 + alpha), (1 - alpha) / (1 + alpha)
    out = np.zeros_like(signal)
    x1 = x2 = y1 = y2 = 0.0
    for i, x in enumerate(signal):
        y = b[0] * x + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        out[i] = y
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def noise(dur, vol, cutoff, rate=SFX_RATE):
    n = max(1, int(rate * dur))
    white = (rng.random(n) * 2 - 1) * (1 - np.arange(n) / n)
    return lowpass(white, cutoff, rate) * vol


def mix(*parts):
    """Layers (delay seconds, samples) parts into one buffer."""
    rate = SFX_RATE
    length = max(int(delay * rate) + len(s) for delay, s in parts)
    out = np.zeros(length)
    for delay, s in parts:
        start = int(delay * rate)
        out[start:start + len(s)] += s
    return out


def write(name, samples, rate=SFX_RATE):
    pcm = (np.clip(samples, -1, 1) * 32767).astype('<i2')
    with wave.open(os.path.join(out_dir, name + '.wav'), 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(pcm.tobytes())
    print('%-16s %6.2fs' % (name, len(samples) / rate))


# ── One-shot effects (sfx.ts sfxCoin … sfxGoal) ──
write('coin', mix((0, blip(988, 0.07)), (0.06, blip(1319, 0.13))))
write('buy', mix((0, blip(523, 0.09)), (0.08, blip(659, 0.09)), (0.16, blip(784, 0.16))))
write('day', mix((0, blip(659, 0.12, vol=0.34)), (0.12, blip(784, 0.12, vol=0.34)), (0.24, blip(1047, 0.22, vol=0.34))))
write('break', mix((0, blip(200, 0.3, 'sawtooth', 0.3, 70)), (0, noise(0.2, 0.2, 500))))
write('click', blip(760, 0.04, vol=0.18))
write('error', blip(170, 0.2, 'sawtooth', 0.26, 110))
write('goal', mix((0, blip(523, 0.1, vol=0.34)), (0.1, blip(659, 0.1, vol=0.34)),
                  (0.2, blip(784, 0.1, vol=0.34)), (0.3, blip(1047, 0.28, vol=0.36))))

# ── Ambient bleeps: the original picked a random note, wave, length and volume
# each time; these cover the notes and waves, and the player varies the volume.
for note in (523, 587, 659, 784, 880, 1047):
    for wave_type in ('square', 'triangle'):
        write('bleep_%d_%s' % (note, wave_type), blip(note, 0.09, wave_type, 0.075))

# ── Riff Master's note beeps (rhythm.ts beep(): square, 0.05 gain, 90 ms decay) ──
for note in (330, 440, 495, 660, 880):
    write('beep_%d' % note, blip(note, 0.09, 'square', 0.05))

# ── Loops ──
# Arcade hum: 55 Hz plus 110 Hz at 0.35, at the original's 0.035 level. Two
# seconds hold whole cycles of both, so it loops cleanly.
t = np.arange(2 * LOOP_RATE) / LOOP_RATE
write('hum', (np.sin(2 * np.pi * 55 * t) + 0.35 * np.sin(2 * np.pi * 110 * t)) * 0.035, LOOP_RATE)

# Crowd murmur: a 2 s brown-noise rumble through a 520 Hz low-pass, rendered at
# full murmur level (0.07); the game scales it with the crowd. The ends are
# cross-faded so the loop has no click.
n = 2 * LOOP_RATE
white = rng.random(n + LOOP_RATE // 4) * 2 - 1
brown = np.zeros_like(white)
last = 0.0
for i, w in enumerate(white):
    last = (last + 0.02 * w) / 1.02
    brown[i] = last * 3.2
murmur = lowpass(brown, 520, LOOP_RATE)
fade = LOOP_RATE // 4
body = murmur[:n].copy()
ramp = np.linspace(0, 1, fade)
body[:fade] = body[:fade] * ramp + murmur[n:n + fade] * (1 - ramp)
write('murmur', body * 0.07, LOOP_RATE)

# Jukebox: each track is four chords, every note a 0.03-gain oscillator with a
# 0.5 s linear swell and a linear fade over the chord. Rendered as one loop.
TRACKS = {
    'arcade': ('triangle', 2.4, [[220.00, 261.63, 329.63], [174.61, 220.00, 261.63], [261.63, 329.63, 392.00], [196.00, 246.94, 293.66]]),
    'synth': ('sawtooth', 2.0, [[196.00, 233.08, 293.66], [220.00, 261.63, 329.63], [174.61, 220.00, 261.63], [146.83, 174.61, 220.00]]),
    'chip': ('square', 1.6, [[261.63, 329.63, 392.00], [293.66, 369.99, 440.00], [329.63, 415.30, 493.88], [349.23, 440.00, 523.25]]),
    'lofi': ('sine', 3.2, [[164.81, 196.00, 246.94], [146.83, 174.61, 220.00], [130.81, 164.81, 196.00], [155.56, 185.00, 233.08]]),
}
for track, (wave_type, dur, chords) in TRACKS.items():
    seg = int(dur * LOOP_RATE)
    out = np.zeros(seg * len(chords))
    t = np.arange(seg) / LOOP_RATE
    env = np.where(t < 0.5, 0.0001 + (0.03 - 0.0001) * t / 0.5, 0.03 + (0.0001 - 0.03) * (t - 0.5) / (dur - 0.5))
    for i, chord in enumerate(chords):
        for f in chord:
            out[i * seg:(i + 1) * seg] += oscillator(wave_type, np.full(seg, f), LOOP_RATE) * env
    write('music_' + track, out, LOOP_RATE)
