"""Renders the minigames' shared retro sound set to WAV files: the countdown, GO,
score blip, hit, miss, win, lose, star and new-best cues every cabinet uses, plus
pinball's own table sounds (flipper, bumper, drop target, lane, launch, drain) and
the slot machine's (lever, reel tick, reel stop, nudge, win, jackpot) and
hoops' (swish, rim, backboard, bounce, buzzer, on fire) and the coin
pusher's (clink, spill, bonus, prize) and whack-it's (bonk, whiff, pop, clang,
squeak, gold) the prize crane's (motor, drop, clack, prize) and the VR pod's (whoosh,
crystal, crash, shield, star).

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

# Hoops: the swish of the net, the clank of the rim, a thud off the backboard,
# the ball bouncing back down the ramp, the end buzzer and catching fire.
save('hp_swish', tone('noise', 0, 0, 0.22, 0.14, 2.5) * np.linspace(0.4, 1, int(RATE * 0.22)) + tone('triangle', 1760, 2349, 0.22, 0.08, 3.0))
save('hp_rim', tone('square', 880, 860, 0.16, 0.14, 4.0) + tone('square', 1320, 1290, 0.16, 0.08, 5.0))
save('hp_board', tone('triangle', 150, 90, 0.1, 0.35, 4.0) + tone('noise', 0, 0, 0.1, 0.1, 9.0))
save('hp_bounce', tone('triangle', 120, 70, 0.07, 0.3, 5.0))
save('hp_buzzer', tone('square', 196, 196, 0.7, 0.2, 0.6) + tone('square', 233, 233, 0.7, 0.12, 0.6))
save('hp_fire', tone('noise', 0, 0, 0.35, 0.12, 2.0) + tone('triangle', 330, 990, 0.35, 0.2, 2.0))

# Coin pusher: a coin clinking onto the shelf, coins spilling into the tray, a
# bonus fanfare and a prize dropping.
save('cp_clink', tone('triangle', 2637, 2637, 0.08, 0.16, 5.0) + tone('triangle', 3520, 3520, 0.08, 0.08, 6.0))
save('cp_spill', seq(*(tone('triangle', f, f, 0.04, 0.12, 4.0) for f in (2349, 2794, 2637, 3136))))
save('cp_bonus', seq(*(tone('square', f, f, 0.06, 0.18, 2.5) for f in (784, 988, 1175, 1568, 1175, 1568)), tone('square', 2093, 2093, 0.3, 0.2, 2.5)))
save('cp_prize', seq(tone('triangle', 523, 523, 0.1, 0.25, 2.5), tone('triangle', 784, 784, 0.1, 0.25, 2.5), tone('triangle', 1047, 1047, 0.3, 0.25, 3.0)))

# Whack-It: a rubbery bonk, a whiff of air, a mole popping up, the clang of a
# hard hat, a bunny's squeak and a golden mole's chime.
save('wk_bonk', tone('square', 220, 90, 0.09, 0.28, 4.0) + tone('noise', 0, 0, 0.09, 0.1, 12.0))
save('wk_whiff', tone('noise', 0, 0, 0.12, 0.08, 3.0) * np.linspace(0.3, 1, int(RATE * 0.12)))
save('wk_pop', tone('triangle', 300, 700, 0.06, 0.18, 4.0))
save('wk_clang', tone('square', 1175, 1150, 0.25, 0.14, 3.5) + tone('square', 1760, 1720, 0.25, 0.08, 4.0))
save('wk_squeak', tone('triangle', 1400, 1900, 0.12, 0.2, 3.0))
save('wk_gold', seq(*(tone('triangle', f, f, 0.06, 0.2, 2.5) for f in (1319, 1568, 2093, 2637))))

# Prize Crane: the gantry motor, the claw dropping and clacking shut, and a
# prize thumping down the chute.
save('cr_motor', tone('square', 110, 110, 0.08, 0.06, 1.0) + tone('square', 220, 220, 0.08, 0.03, 1.0))
save('cr_drop', tone('triangle', 600, 240, 0.4, 0.12, 1.5))
save('cr_clack', tone('noise', 0, 0, 0.05, 0.2, 7.0) + tone('square', 330, 180, 0.05, 0.14, 5.0))
save('cr_prize', seq(tone('triangle', 196, 98, 0.12, 0.35, 3.0), *(tone('square', f, f, 0.08, 0.2, 2.5) for f in (659, 784, 988)), tone('square', 1319, 1319, 0.3, 0.22, 3.0)))

# VR Pod: a whoosh past each wave, a crystal's chime, a crash, a shield
# coming back and a star.
save('vr_whoosh', tone('noise', 0, 0, 0.25, 0.08, 2.0) * np.sin(np.linspace(0, np.pi, int(RATE * 0.25))))
save('vr_crystal', tone('triangle', 1760, 1760, 0.1, 0.18, 3.0) + tone('triangle', 2637, 2637, 0.1, 0.1, 4.0))
save('vr_crash', tone('noise', 0, 0, 0.4, 0.3, 3.0) + tone('square', 120, 50, 0.4, 0.2, 3.0))
save('vr_shield', seq(tone('triangle', 523, 1047, 0.15, 0.22, 2.0), tone('triangle', 1047, 1568, 0.15, 0.22, 2.5)))
save('vr_star', seq(*(tone('square', f, f, 0.06, 0.18, 2.5) for f in (1047, 1319, 1568, 2093))))
