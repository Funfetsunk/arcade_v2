"""Draws a review sheet of the cashier's desk in every theme, beside a strip of
back wall so the colours can be compared. The whole desk is toned toward the
theme the way the walls' shader does it (design B, the one the user picked).

Usage (needs Pillow):
    python tools/desk_sheet.py . docs/desk_sheet.png
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

SCALE = 3
THEMES = ['classic', 'gold', 'mint', 'mono', 'retro', 'sunset']
BANDS = [('brick_purple', 12, None), ('neon_stripe', 9, (11, 20)), ('brick_purple', 7, None), ('wainscot', 16, (16, 32))]
INK = (233, 228, 255)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)

project, out = sys.argv[1], sys.argv[2]
assets = os.path.join(project, 'assets')
font = ImageFont.truetype(os.path.join(assets, 'fonts', 'arcade_empire_pixel.ttf'), 16)
desk = Image.open(os.path.join(assets, 'sprites', 'decor', 'cashier_desk.png')).convert('RGBA')
cashier = Image.open(os.path.join(assets, 'sprites', 'actors', 'staff_cashier', 'idle_south.png')).convert('RGBA')
carpet = Image.open(os.path.join(assets, 'tiles', 'carpet.png')).convert('RGBA')


def theme(name):
    text = open(os.path.join(project, 'data', 'catalogs', 'themes', name + '.tres'), encoding='utf-8').read()
    wall = tuple(float(v) for v in re.search(r'^wall = Color\(([^)]*)\)', text, re.M).group(1).split(','))
    strength = re.search(r'^wall_tint_strength = ([0-9.]+)', text, re.M)
    title = re.search(r'^display_name = "([^"]*)"', text, re.M).group(1)
    return title, wall, float(strength.group(1)) if strength else 0.0


def luma(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


def tone(img, hue, strength):
    """floor/wall_tint.gdshader: blend each pixel toward the hue at its own brightness."""
    img = img.copy()
    if strength <= 0:
        return img
    peak = max(hue[:3])
    tint = [c / peak for c in hue[:3]]
    tl = luma(*tint)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            l = luma(r, g, b) / tl
            px[x, y] = tuple(int(min(255, c * (1 - strength) + t * l * strength)) for c, t in zip((r, g, b), tint)) + (a,)
    return img


def mock(hue, strength):
    w, wall_h, floor_h = 120, 48, 64
    img = Image.new('RGBA', (w, wall_h + floor_h))
    strip = Image.new('RGBA', (w, wall_h))
    y = 0
    for name, height, crop in BANDS:
        tex = Image.open(os.path.join(assets, 'tiles', 'walls', name + '.png')).convert('RGBA')
        if crop:
            tex = tex.crop((0, crop[0], 32, crop[1]))
        for x in range(0, w, 32):
            for yy in range(y, y + height, tex.height):
                strip.alpha_composite(tex.crop((0, 0, min(32, w - x), min(tex.height, y + height - yy))), (x, yy))
        y += height
    img.alpha_composite(tone(strip, hue, strength))
    for x in range(0, w, 32):
        for yy in range(wall_h, wall_h + floor_h, 32):
            img.alpha_composite(carpet, (x, yy))
    box = desk.getbbox()
    foot = wall_h + floor_h - 6
    left = w // 2 - (box[0] + box[2]) // 2
    cb = cashier.getbbox()
    img.alpha_composite(cashier, (w // 2 - (cb[0] + cb[2]) // 2, foot - 14 - cb[3]))
    img.alpha_composite(tone(desk, hue, strength), (left, foot - box[3]))
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


pad, label, header = 14, 26, 44
cells = []
for name in THEMES:
    title, hue, strength = theme(name)
    cells.append((title, mock(hue, strength)))
cw = cells[0][1].width + 2 * pad
ch = cells[0][1].height + label + 2 * pad
rows = (len(cells) + 1) // 2
sheet = Image.new('RGB', (8 + 2 * (cw + 8), header + rows * (ch + 8)), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((8 + pad, 14), 'CASHIER DESK  toned like the walls in every theme', font=font, fill=GOLD)
for i, (title, img) in enumerate(cells):
    x = 8 + (i % 2) * (cw + 8)
    y = header + (i // 2) * (ch + 8)
    draw.rectangle((x, y, x + cw - 1, y + ch - 1), fill=CARD_BG)
    draw.text((x + pad, y + pad - 4), title, font=font, fill=INK)
    sheet.paste(img, (x + pad, y + pad + label))
sheet.save(out)
print('wrote %s: %d themes' % (out, len(cells)))
