"""Draws a review sheet of characters (customers, staff): every one in its four
facings, standing on the carpet at 3x, with a cabinet beside the first for scale.

Each character is a folder under assets/sprites/actors/ holding idle_<facing>.png
(the in-game layout). Folders without walk frames yet are marked NEW - REVIEW.

Usage (needs Pillow):
    python tools/people_sheet.py . docs/customer_sheet.png customer_a customer_teen_jacket ...
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FACINGS = ('south', 'east', 'north', 'west')
SCALE = 3
CELL = 48 * SCALE
GAP = 8
PAD = 14
LABEL = 26
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)

project, out, names = sys.argv[1], sys.argv[2], sys.argv[3:]
actors = os.path.join(project, 'assets', 'sprites', 'actors')
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
carpet = Image.open(os.path.join(project, 'assets', 'tiles', 'carpet.png')).convert('RGBA')
carpet = carpet.resize((carpet.width * SCALE, carpet.height * SCALE), Image.NEAREST)
cabinet = Image.open(os.path.join(project, 'assets', 'sprites', 'cabinets', 'space_inv', 'south.png')).convert('RGBA')
cabinet = cabinet.resize((cabinet.width * SCALE // 2 * 2 // 2, cabinet.height * SCALE // 2 * 2 // 2), Image.NEAREST)

card_w = PAD * 2 + 4 * CELL + 3 * GAP
card_h = PAD * 2 + LABEL + CELL
header = 44
sheet = Image.new('RGBA', (card_w + GAP * 2, header + (card_h + GAP) * len(names) + GAP), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((GAP + PAD, 14), 'CHARACTERS  %d to review' % len(names), font=font, fill=GOLD)


def tile_carpet(x, y, w, h):
    for cx in range(0, w, carpet.width):
        for cy in range(0, h, carpet.height):
            sheet.alpha_composite(carpet.crop((0, 0, min(carpet.width, w - cx), min(carpet.height, h - cy))), (x + cx, y + cy))


for i, name in enumerate(names):
    folder = os.path.join(actors, name)
    x = GAP
    y = header + i * (card_h + GAP)
    draw.rectangle((x, y, x + card_w - 1, y + card_h - 1), fill=CARD_BG)
    animated = os.path.exists(os.path.join(folder, 'walk_south_0.png'))
    draw.text((x + PAD, y + PAD - 4), name, font=font, fill=INK)
    status = 'IN GAME' if animated else 'NEW - REVIEW'
    width = draw.textlength(status, font=font)
    draw.text((x + card_w - PAD - width, y + PAD - 4), status, font=font, fill=DIM if animated else GOLD)
    for j, facing in enumerate(FACINGS):
        cx = x + PAD + j * (CELL + GAP)
        cy = y + PAD + LABEL
        tile_carpet(cx, cy, CELL, CELL)
        path = os.path.join(folder, 'idle_%s.png' % facing)
        if os.path.exists(path):
            sprite = Image.open(path).convert('RGBA')
            sprite = sprite.resize((sprite.width * SCALE, sprite.height * SCALE), Image.NEAREST)
            sheet.alpha_composite(sprite, (cx + (CELL - sprite.width) // 2, cy + (CELL - sprite.height) // 2))
        draw.text((cx + 4, cy + CELL - 18), facing, font=font, fill=DIM)

sheet.convert('RGB').save(out)
print('wrote %s: %d characters' % (out, len(names)))
