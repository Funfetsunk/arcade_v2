"""Renders the minigames' shared retro sound set to WAV files: the countdown, GO,
score blip, hit, miss, win, lose, star and new-best cues every cabinet uses, plus
pinball's own table sounds (flipper, bumper, drop target, lane, launch, drain) and
the slot machine's (lever, reel tick, reel stop, nudge, win, jackpot).

Each is a few square or triangle notes with a quick attack and decay, in the same
spirit as tools/render_sfx.py (the original game's own sounds).

Usage (needs numpy):
    python tools/render_minigame_sfx.py assets/audio
"""
import os
import sys
import wave

import numpy as np

RATE = 44100
out_dir = sys.argv[1]
os.makedirs(out_dir, exist_ok=True)
rng = np.random.default_rng(11)


def tone(wave_type, f0, f1, length, volume=0.3, decay=6.0):
    """One note sliding from f0 to f1 Hz, with a 5 ms attack and exponential decay."""
    n = int(RATE * length)
    t = np.arange(n) / RATE
    freqs = np.linspace(f0, f1, n)
    phase = 2 * np.pi * np.cumsum(freqs) / RATE
    if wave_type == 'square':
        # A few odd harmonics keep it chiptune-y without harsh aliasing.
        out = sum(np.sin(k * phase) / k for k in range(1, 12, 2)) * 4 / np.pi
    elif wave_type == 'triangle':
        out = 2 / np.pi * np.arcsin(np.sin(phase))
    else:
        out = rng.uniform(-1, 1, n)
    env = np.minimum(1, t / 0.005) * np.exp(-decay * t / length)
    return out * env * volume


def seq(*notes):
    return np.concatenate(notes)


def save(name, samples):
    samples = np.clip(samples, -1, 1)
    with wave.open(os.path.join(out_dir, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((samples * 32767).astype('<i2').tobytes())
    print('wrote', name)


save('mg_count', tone('square', 660, 660, 0.09, 0.22))
save('mg_go', tone('square', 880, 1320, 0.28, 0.25, 3.0))
save('mg_score', tone('triangle', 1175, 1760, 0.06, 0.18))
save('mg_hit', tone('noise', 0, 0, 0.04, 0.2) + tone('square', 220, 160, 0.04, 0.15))
save('mg_miss', tone('square', 320, 110, 0.26, 0.22, 3.0))
save('mg_win', seq(*(tone('square', f, f, 0.09, 0.22, 2.5) for f in (523, 659, 784)), tone('square', 1047, 1047, 0.32, 0.24, 3.0)))
save('mg_lose', seq(*(tone('triangle', f, f * 0.97, 0.13, 0.3, 2.5) for f in (392, 330, 262)), tone('triangle', 196, 180, 0.35, 0.3, 3.0)))
save('mg_star', tone('triangle', 1568, 1568, 0.22, 0.25, 4.0) + tone('triangle', 2093, 2093, 0.22, 0.12, 5.0))
save('mg_best', seq(*(tone('square', f, f, 0.07, 0.2, 2.0) for f in (784, 988, 1175)), tone('square', 1568, 1568, 0.4, 0.22, 2.5)))

# Pinball: mechanical knocks and pops rather than blips.
save('pb_flip', tone('noise', 0, 0, 0.03, 0.16, 8.0) + tone('square', 140, 90, 0.03, 0.18, 6.0))
save('pb_bump', tone('square', 520, 260, 0.07, 0.2, 5.0) + tone('noise', 0, 0, 0.07, 0.08, 9.0))
save('pb_drop', tone('triangle', 220, 110, 0.09, 0.35, 4.0) + tone('noise', 0, 0, 0.09, 0.06, 10.0))
save('pb_lane', tone('triangle', 1320, 1320, 0.14, 0.18, 4.0))
save('pb_launch', tone('noise', 0, 0, 0.25, 0.1, 2.5) + tone('triangle', 180, 520, 0.25, 0.22, 2.0))
save('pb_drain', tone('triangle', 330, 70, 0.45, 0.3, 2.5))

# Slot machine: a ratchety lever, clicking reels, a clunk as each stops, bells for wins.
save('sl_pull', tone('noise', 0, 0, 0.18, 0.12, 3.0) + tone('square', 90, 60, 0.18, 0.15, 3.0))
save('sl_tick', tone('noise', 0, 0, 0.02, 0.08, 10.0))
save('sl_stop', tone('square', 160, 110, 0.06, 0.2, 5.0) + tone('noise', 0, 0, 0.06, 0.08, 8.0))
save('sl_nudge', seq(tone('triangle', 660, 660, 0.06, 0.2, 3.0), tone('triangle', 880, 880, 0.08, 0.2, 3.0)))
save('sl_win', seq(*(tone('triangle', f, f, 0.07, 0.22, 2.5) for f in (1047, 1319, 1568, 1319, 1568)), tone('triangle', 2093, 2093, 0.25, 0.22, 3.0)))
save('sl_jackpot', seq(*(tone('square', f, f, 0.08, 0.2, 2.0) for f in (523, 659, 784, 1047, 784, 1047, 1319, 1568)), tone('square', 2093, 2093, 0.5, 0.22, 2.0)))
