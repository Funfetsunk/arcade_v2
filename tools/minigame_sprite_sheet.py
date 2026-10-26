"""Draws a review sheet of minigame sprite candidates: for each sprite, which
minigame it's for and what it replaces, then each candidate on the minigame
board's background at game scale (2 screen px a pixel) and zoomed to 4x.

Candidates live in assets/sprites/minigames/candidates/<name>_<letter>.png.

Usage (needs Pillow), with the batch number last:
    python tools/minigame_sprite_sheet.py . docs/minigame_sprites_sheet.png 1
    python tools/minigame_sprite_sheet.py . docs/minigame_sprites_sheet_2.png 2
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

# batch -> name -> (minigame, what it replaces)
BATCHES = {
    '1': {
        'alien': ('Space Defend', 'the 👾 invaders'),
        'cannon': ('Space Defend', 'the green triangle ship'),
        'saucer': ('Star Squad', 'the 🛸 enemies'),
        'fighter': ('Star Squad', 'the player ship triangle'),
        'gorilla': ('Barrel Hop', 'the 🦍 at the top'),
        'princess': ('Barrel Hop', 'who waits at the top (the 👸)'),
        'runner': ('Barrel Hop', 'the stick-figure runner'),
        'barrel': ('Barrel Hop', 'the round drawn barrels'),
        'mole': ('Whack-a-Mole', 'the brown boxes'),
        'muncher': ('Dot Maze', 'the yellow wedge'),
        'ghost': ('Dot Maze', 'the box ghost'),
        'ghost_scared': ('Dot Maze', 'the box ghost when blue'),
        'fist': ('Car Smash', 'the 👊'),
        'boom': ('Car Smash', 'the 💥'),
        'racecar': ('Racing', 'the amber box car'),
    },
    '2': {
        'prize_bunny': ('Claw', 'the 🐰 prize'),
        'prize_bear': ('Claw', 'the 🐻 prize'),
        'prize_teddy': ('Claw and Crane', 'the 🧸 prize'),
        'prize_star': ('Claw and Slots', 'the ⭐'),
        'prize_lollipop': ('Crane', 'the 🍭 prize'),
        'prize_bow': ('Crane', 'the 🎀 prize'),
        'prize_gift': ('Crane', 'the 🎁 prize'),
        'prize_toycar': ('Crane', 'the 🚗 prize'),
        'prize_unicorn': ('Crane', 'the 🦄 prize'),
        'slot_lemon': ('Slots', 'the 🍋'),
        'slot_cherry': ('Slots', 'the 🍒'),
        'slot_money': ('Slots', 'the 💰'),
        'slot_bell': ('Slots', 'the 🔔'),
        'target': ('Light Gun', 'the 🎯 targets'),
        'civilian': ('Light Gun', 'the ✋ civilians: a: the hand, c-k: people'),
        'face_grin': ('Photo Booth and Social', 'the 😀'),
        'face_cool': ('Photo Booth and Social', 'the 😎'),
        'face_wink': ('Photo Booth', 'the 😜'),
        'face_starstruck': ('Photo Booth', 'the 🤩'),
        'face_party': ('Photo Booth', 'the 🥳'),
        'social_note': ('Trend Match', 'the 🎵: c-h notes, i-k a like'),
        'social_dancer': ('Social', 'the 💃'),
        'social_heart': ('Trend Match', 'the 💜 (a cleaned up)'),
        'social_fire': ('Social', 'the 🔥'),
    },
    '3': {
        'ball': ('Pong, Breakout, Pinball', 'the white circle ball'),
        'paddle': ('Pong and Breakout', 'the flat paddles'),
        'brick': ('Breakout', 'the coloured bricks (tinted per row)'),
        'mallet_pink': ('Air Hockey', "the opponent's mallet"),
        'mallet_gold': ('Air Hockey', 'your mallet'),
        'puck': ('Air Hockey', 'the white puck'),
        'bumper': ('Pinball', 'the round bumpers'),
        'basketball': ('Hoops', 'the orange ball'),
        'hoop': ('Hoops', 'the backboard, rim and net'),
        'coin_gold': ('Coin Cascade', 'the gold coins'),
        'coin_silver': ('Coin Cascade', 'the silver coins'),
        'dropper': ('Coin Cascade', 'the pink coin dropper'),
        'note_gem': ('Rhythm', 'the round notes (tinted per lane)'),
        'arrow': ('Dance', 'the arrows (turned per lane)'),
        'crosshair': ('Aim Trainer', 'the drawn crosshair'),
        'vr_pod': ('VR Pod', 'the gold dot'),
        'sim_pod': ('Motion Sim', 'the pink box pod'),
        'smash_car': ('Car Crusher', 'the drawn car (128 px art, shown at 2x)'),
    },
    # Batch 3 clean-ups and builds.
    '3b': {
        'paddle_built': ('Pong and Breakout', 'g: yours, p: the AI (stretches)'),
        'mallet_pink': ('Air Hockey', 'c: a with the colouring cleaned'),
        'bumper': ('Pinball', 'd: c in one teal ramp'),
        'coin_gold': ('Coin Cascade', 'c: a with the clean star'),
        'coin_silver': ('Coin Cascade', 'd: c with a clean star'),
        'arrow': ('Dance', 'c: a with the gaps and red fixed'),
        'crosshair': ('Aim Trainer', 'c: even arms, redrawn'),
        'car_state': ('Car Crusher', '1 intact, 2 dented, 3 smashed, 4 wrecked'),
    },
}
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)
BOARD_BG = (10, 10, 22)

project, out = sys.argv[1], sys.argv[2]
batch = sys.argv[3] if len(sys.argv) > 3 else '1'
SPRITES = BATCHES[batch]
# Optional fourth argument: only these sprites (comma separated), for a follow-up review.
if len(sys.argv) > 4:
    SPRITES = {k: v for k, v in SPRITES.items() if k in sys.argv[4].split(',')}
ONLY = sys.argv[5].split(',') if len(sys.argv) > 5 else None
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
small = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'jersey10.ttf'), 16)
folder = os.path.join(project, 'assets', 'sprites', 'minigames', 'candidates')


def letters(name):
    found = sorted(f[len(name) + 1:-4] for f in os.listdir(folder)
                  if f.startswith(name + '_') and f.endswith('.png') and len(f) == len(name) + 6)
    # Optional fifth argument: only these letters, to show just the fixed candidates.
    return [x for x in found if ONLY is None or x in ONLY or name in ('paddle_built', 'car_state')]


PER_ROW = 3
cell_w = 16 + PER_ROW * (56 + 8 + 96 + 16)

COLUMNS = 2
heights = [56 + 100 * ((len(letters(n)) + PER_ROW - 1) // PER_ROW) for n in SPRITES]
rows = (len(SPRITES) + COLUMNS - 1) // COLUMNS
row_h = [max(heights[r * COLUMNS:(r + 1) * COLUMNS]) for r in range(rows)]
sheet = Image.new('RGB', (8 + COLUMNS * (cell_w + 8), 50 + sum(h + 8 for h in row_h)), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((16, 16), 'MINIGAME SPRITES  batch %s, %d sprites (game scale / 4x)' % (batch, len(SPRITES)), font=font, fill=GOLD)
for i, (name, (game, replaces)) in enumerate(SPRITES.items()):
    x = 8 + (i % COLUMNS) * (cell_w + 8)
    y = 50 + sum(h + 8 for h in row_h[:i // COLUMNS])
    draw.rectangle((x, y, x + cell_w - 1, y + row_h[i // COLUMNS] - 1), fill=CARD_BG)
    draw.text((x + 8, y + 6), name.replace('_', ' '), font=font, fill=INK)
    draw.text((x + 8, y + 26), '%s: %s' % (game, replaces), font=small, fill=DIM, embedded_color=True)
    for j, letter in enumerate(letters(name)):
        sprite = Image.open(os.path.join(folder, '%s_%s.png' % (name, letter))).convert('RGBA')
        cx = x + 8 + (j % PER_ROW) * (56 + 8 + 96 + 16)
        y_off = (j // PER_ROW) * 100
        side = max(28, sprite.width)
        tile = Image.new('RGBA', (side, side), BOARD_BG + (255,))
        tile.alpha_composite(sprite, ((side - sprite.width) // 2, (side - sprite.height) // 2))
        sheet.paste(tile.resize((56, 56), Image.NEAREST), (cx, y + 56 + y_off))
        # Big art is shown whole at 96 px rather than blown up.
        # Wide art keeps its shape, centred in the 96 px box.
        k = 96 / max(sprite.size)
        zoom = sprite.resize((round(sprite.width * k), round(sprite.height * k)),
                             Image.NEAREST if max(sprite.size) <= 32 else Image.LANCZOS)
        sheet.paste(zoom, (cx + 64 + (96 - zoom.width) // 2, y + 52 + y_off + (96 - zoom.height) // 2), zoom)
        draw.text((cx + 2, y + 118 + y_off), letter, font=font, fill=DIM)
sheet.save(out)
print('wrote %s' % out)
