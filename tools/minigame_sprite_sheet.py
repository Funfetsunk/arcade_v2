"""Draws a review sheet of minigame sprite candidates: for each sprite, which
minigame it's for and what it replaces, then each candidate on the minigame
board's background at game scale (2 screen px a pixel) and zoomed to 4x.

Candidates live in assets/sprites/minigames/candidates/<name>_<letter>.png.

Usage (needs Pillow):
    python tools/minigame_sprite_sheet.py . docs/minigame_sprites_sheet.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

# name -> (minigame, what it replaces)
SPRITES = {
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
}
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)
BOARD_BG = (10, 10, 22)

project, out = sys.argv[1], sys.argv[2]
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
small = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'jersey10.ttf'), 16)
folder = os.path.join(project, 'assets', 'sprites', 'minigames', 'candidates')


def letters(name):
    return sorted(f[len(name) + 1:-4] for f in os.listdir(folder)
                  if f.startswith(name + '_') and f.endswith('.png') and len(f) == len(name) + 6)


PER_ROW = 3
cell_w = 16 + PER_ROW * (56 + 8 + 96 + 16)

COLUMNS = 2
heights = [56 + 100 * ((len(letters(n)) + PER_ROW - 1) // PER_ROW) for n in SPRITES]
rows = (len(SPRITES) + COLUMNS - 1) // COLUMNS
row_h = [max(heights[r * COLUMNS:(r + 1) * COLUMNS]) for r in range(rows)]
sheet = Image.new('RGB', (8 + COLUMNS * (cell_w + 8), 50 + sum(h + 8 for h in row_h)), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((16, 16), 'MINIGAME SPRITES  batch 1, %d sprites (game scale / 4x)' % len(SPRITES), font=font, fill=GOLD)
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
        tile = Image.new('RGBA', (28, 28), BOARD_BG + (255,))
        tile.alpha_composite(sprite, ((28 - sprite.width) // 2, (28 - sprite.height) // 2))
        sheet.paste(tile.resize((56, 56), Image.NEAREST), (cx, y + 56 + y_off))
        zoom = sprite.resize((96, 96), Image.NEAREST)
        sheet.paste(zoom, (cx + 64, y + 52 + y_off), zoom)
        draw.text((cx + 2, y + 118 + y_off), letter, font=font, fill=DIM)
sheet.save(out)
print('wrote %s' % out)
