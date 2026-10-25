"""Draws a review sheet for carpet variants: every candidate tile at 3x, then a
16x10 floor laid three ways (the current single tile, plain variants mixed in,
and plain variants plus the odd accent tile) at 2x, so repetition shows.

Candidates live in assets/tiles/carpet_variants/<name>.png (32x32, seamless);
names starting plain_ are plain, accent_ or worn carry a feature.

Usage (needs Pillow):
    python tools/carpet_sheet.py . docs/carpet_sheet.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

TILE = 32
ROOM = (16, 10)
INK = (233, 228, 255)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)

project, out = sys.argv[1], sys.argv[2]
tiles_dir = os.path.join(project, 'assets', 'tiles')
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
base = Image.open(os.path.join(tiles_dir, 'carpet.png')).convert('RGB')
folder = os.path.join(tiles_dir, 'carpet_variants')
variants = {f[:-4]: Image.open(os.path.join(folder, f)).convert('RGB') for f in sorted(os.listdir(folder)) if f.endswith('.png')}
plain = [v for k, v in variants.items() if k.startswith('plain_')]
accents = [v for k, v in variants.items() if not k.startswith('plain_')]


def pick(x, y):
    """A fixed pseudo-random number per tile, so the floor never shuffles."""
    h = ((x * 73856093) ^ (y * 19349663)) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) & 0xFFFF


def floor(mix):
    img = Image.new('RGB', (ROOM[0] * TILE, ROOM[1] * TILE))
    for y in range(ROOM[1]):
        for x in range(ROOM[0]):
            r = pick(x, y)
            tile = base
            if mix >= 1 and r % 100 < 50:
                tile = plain[(r >> 7) % len(plain)]
            if mix >= 2 and r % 100 >= 96:
                tile = accents[(r >> 7) % len(accents)]
            img.paste(tile, (x * TILE, y * TILE))
    return img.resize((img.width * 2, img.height * 2), Image.NEAREST)


floors = [('1  now: one tile everywhere', floor(0)),
          ('2  half the tiles swapped for plain variants', floor(1)),
          ('3  as 2, plus an accent tile now and then (about 1 in 25)', floor(2))]
pad, label, header = 14, 26, 44
card_w = floors[0][1].width + 2 * pad
swatch = TILE * 3
row_h = swatch + label + 2 * pad
height = header + row_h + 8 + sum(f.height + label + 2 * pad + 8 for _, f in floors)
sheet = Image.new('RGB', (card_w + 16, height), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((8 + pad, 14), 'CARPET  %d variants' % len(variants), font=font, fill=GOLD)
y = header
draw.rectangle((8, y, 8 + card_w - 1, y + row_h - 1), fill=CARD_BG)
x = 8 + pad
for name, tile in [('carpet (now)', base)] + list(variants.items()):
    sheet.paste(tile.resize((swatch, swatch), Image.NEAREST), (x, y + pad + label))
    draw.text((x, y + pad - 4), name.replace('accent_', '').replace('plain_', ''), font=font, fill=INK)
    x += swatch + 8
y += row_h + 8
for name, img in floors:
    draw.rectangle((8, y, 8 + card_w - 1, y + img.height + label + 2 * pad - 1), fill=CARD_BG)
    draw.text((8 + pad, y + pad - 4), name, font=font, fill=INK)
    sheet.paste(img, (8 + pad, y + pad + label))
    y += img.height + label + 2 * pad + 8
sheet.save(out)
print('wrote %s: %d variants' % (out, len(variants)))
