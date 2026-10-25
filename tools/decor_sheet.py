"""Draws a review sheet of decor props and facilities: each item's candidates at 3x,
beside a cabinet and a customer for scale. Floor items stand on the carpet; wall
items (poster, neon sign) hang on the wall colour.

Candidates live in assets/sprites/decor/<item>/<letter>.png (68x68, one direction).

Usage (needs Pillow):
    python tools/decor_sheet.py . docs/decor_sheet.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ITEMS = [
    ('plant', 'Potted Plant', 'decor'),
    ('rug', 'Arcade Rug', 'decor'),
    ('bench', 'Bench', 'decor'),
    ('poster', 'Wall Poster', 'decor, wall'),
    ('neon', 'Neon Sign', 'decor, wall'),
    ('trophy', 'Trophy Case', 'decor'),
    ('atm', 'ATM', 'facility'),
    ('seating', 'Seating Area', 'facility'),
    ('toilet', 'Restrooms', 'facility'),
    ('water', 'Water Fountain', 'facility'),
]
WALL = {'poster', 'neon'}
APPROVED = {item for item, _, _ in ITEMS}   # every item picked; plant keeps four variants
SCALE = 3
CELL = 68 * SCALE
GAP = 8
PAD = 14
LABEL = 26
COLUMNS = 6     # cabinet, customer, then up to four candidates
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)
WALL_BG = (81, 53, 58)

project, out = sys.argv[1], sys.argv[2]
root = os.path.join(project, 'assets', 'sprites')
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
carpet = Image.open(os.path.join(project, 'assets', 'tiles', 'carpet.png')).convert('RGBA')
carpet = carpet.resize((carpet.width * SCALE, carpet.height * SCALE), Image.NEAREST)


def big(path):
    img = Image.open(path).convert('RGBA')
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


cabinet = big(os.path.join(root, 'cabinets', 'space_inv', 'south.png'))
customer = big(os.path.join(root, 'actors', 'customer_a', 'idle_south.png'))

card_w = PAD * 2 + COLUMNS * CELL + (COLUMNS - 1) * GAP
card_h = PAD * 2 + LABEL + CELL
header = 44
sheet = Image.new('RGBA', (card_w + GAP * 2, header + (card_h + GAP) * len(ITEMS) + GAP), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((GAP + PAD, 14), 'DECOR AND FACILITIES  %d items' % len(ITEMS), font=font, fill=GOLD)


def background(x, y, wall):
    if wall:
        draw.rectangle((x, y, x + CELL - 1, y + CELL - 1), fill=WALL_BG)
        return
    for cx in range(0, CELL, carpet.width):
        for cy in range(0, CELL, carpet.height):
            sheet.alpha_composite(carpet.crop((0, 0, min(carpet.width, CELL - cx), min(carpet.height, CELL - cy))), (x + cx, y + cy))


def stand(sprite, x, y):
    # Bottom-centre, like the floor anchors sprites.
    box = sprite.getbbox()
    sheet.alpha_composite(sprite, (x + (CELL - sprite.width) // 2, y + CELL - 6 - box[3]))


for i, (item, name, kind) in enumerate(ITEMS):
    x = GAP
    y = header + i * (card_h + GAP)
    draw.rectangle((x, y, x + card_w - 1, y + card_h - 1), fill=CARD_BG)
    draw.text((x + PAD, y + PAD - 4), '%s  (%s)' % (name, kind), font=font, fill=INK)
    status = 'APPROVED' if item in APPROVED else 'PICK ONE'
    draw.text((x + card_w - PAD - draw.textlength(status, font=font), y + PAD - 4), status, font=font, fill=DIM if item in APPROVED else GOLD)
    folder = os.path.join(root, 'decor', item)
    letters = sorted(f[:-4] for f in os.listdir(folder) if f.endswith('.png')) if os.path.isdir(folder) else []
    cells = [('cabinet', cabinet, False), ('customer', customer, False)]
    cells += [(letter, big(os.path.join(folder, letter + '.png')), item in WALL) for letter in letters]
    for j, (label, sprite, wall) in enumerate(cells[:COLUMNS]):
        cx = x + PAD + j * (CELL + GAP)
        cy = y + PAD + LABEL
        background(cx, cy, wall)
        stand(sprite, cx, cy)
        draw.text((cx + 4, cy + CELL - 18), label, font=font, fill=DIM if j < 2 else GOLD)

sheet.convert('RGB').save(out)
print('wrote %s: %d items' % (out, len(ITEMS)))
