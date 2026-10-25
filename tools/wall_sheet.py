"""Draws a review sheet of the walls: the chosen design (F) built into a small mock
room (carpet, a few cabinets, a plant and a customer) once per arcade theme, the
way the floor draws it (floor/wall_face.gd, floor/room.gd, floor/wall_tint.gdshader), at 2x.

Wall textures are 32x32 seamless tiles in assets/tiles/walls/. The design is a stack
of bands down the 48 px back wall, each a texture (optionally a crop of its rows)
repeated across; the side and front walls show the cap texture, darkened. Each theme
tones the walls toward its wall hue and washes the floor with its floor tint.

Usage (needs Pillow):
    python tools/wall_sheet.py . docs/wall_sheet.png
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFont

TILE = 32
WALL_H = 48
ROOM = (10, 5)
SCALE = 2
TRIM = (170, 102, 34)
TRIM_DARK = (92, 61, 30)
DOOR_MAT = (32, 36, 59)
INK = (233, 228, 255)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)

# Design F: purple brick, a neon rail, more brick, wood wainscot.
BANDS = [('brick_purple', 12, None), ('neon_stripe', 9, (11, 20)), ('brick_purple', 7, None), ('wainscot', 16, (16, 32))]
CAP = 'brick_navy'
THEMES = ['classic', 'gold', 'mint', 'mono', 'retro', 'sunset']

project, out = sys.argv[1], sys.argv[2]
assets = os.path.join(project, 'assets')
font = ImageFont.truetype(os.path.join(assets, 'fonts', 'arcade_empire_pixel.ttf'), 16)
walls = {}


def texture(name):
    if name not in walls:
        walls[name] = Image.open(os.path.join(assets, 'tiles', 'walls', name + '.png')).convert('RGBA')
    return walls[name]


def sprite(*parts):
    return Image.open(os.path.join(assets, 'sprites', *parts)).convert('RGBA')


def fill(img, tex, box):
    """Repeats `tex` over box (x0, y0, x1, y1), anchored at the box's top-left."""
    x0, y0, x1, y1 = box
    for x in range(x0, x1, tex.width):
        for y in range(y0, y1, tex.height):
            piece = tex.crop((0, 0, min(tex.width, x1 - x), min(tex.height, y1 - y)))
            img.alpha_composite(piece, (x, y))


def theme(name):
    text = open(os.path.join(project, 'data', 'catalogs', 'themes', name + '.tres'), encoding='utf-8').read()
    colour = lambda key: tuple(float(v) for v in re.search(r'^%s = Color\(([^)]*)\)' % key, text, re.M).group(1).split(','))
    strength = re.search(r'^wall_tint_strength = ([0-9.]+)', text, re.M)
    title = re.search(r'^display_name = "([^"]*)"', text, re.M).group(1)
    return title, colour('wall'), float(strength.group(1)) if strength else 0.0, colour('floor_tint')


def luma(r, g, b):
    return 0.299 * r + 0.587 * g + 0.114 * b


def tone(img, hue, strength):
    """The wall_tint shader: blend each pixel toward the hue at its own brightness."""
    if strength <= 0:
        return img
    peak = max(hue[:3])
    tint = [c / peak for c in hue[:3]]
    tl = luma(*tint)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            l = luma(r, g, b) / tl
            px[x, y] = tuple(int(min(255, c * (1 - strength) + t * l * strength)) for c, t in zip((r, g, b), tint)) + (a,)
    return img


def room(bands, cap, hue, strength, floor_tint):
    w, h = ROOM[0] * TILE, ROOM[1] * TILE
    ox, oy = TILE, WALL_H              # floor (0, 0) in image pixels
    img = Image.new('RGBA', (w + 2 * TILE, h + WALL_H + TILE), PAGE_BG + (255,))
    fill(img, Image.open(os.path.join(assets, 'tiles', 'carpet.png')).convert('RGBA'), (ox, oy, ox + w, oy + h))
    if floor_tint[3] > 0:
        wash = Image.new('RGBA', (w, h), tuple(int(c * 255) for c in floor_tint))
        img.alpha_composite(wash, (ox, oy))
    walls_img = Image.new('RGBA', img.size, (0, 0, 0, 0))
    # Back wall bands, then the crown and the trim where it meets the floor.
    y = 0
    for name, height, crop in bands:
        tex = texture(name)
        if crop:
            tex = tex.crop((0, crop[0], tex.width, crop[1]))
        fill(walls_img, tex, (0, y, img.width, y + height))
        y += height
    dark = ImageEnhance.Brightness(texture(cap)).enhance(0.6)
    door_x = ox + w // 2
    gap = int(TILE * 1.25)
    fill(walls_img, dark, (0, oy, ox, oy + h + TILE // 2))
    fill(walls_img, dark, (ox + w, oy, img.width, oy + h + TILE // 2))
    fill(walls_img, dark, (ox, oy + h, door_x - gap // 2, oy + h + TILE // 2))
    fill(walls_img, dark, (door_x + gap // 2, oy + h, ox + w, oy + h + TILE // 2))
    img.alpha_composite(tone(walls_img, hue, strength))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, img.width, 3), fill=(12, 9, 22))
    draw.rectangle((0, WALL_H - 4, img.width, WALL_H - 1), fill=TRIM)
    draw.rectangle((0, WALL_H - 1, img.width, WALL_H - 1), fill=TRIM_DARK)
    draw.rectangle((door_x - gap // 2, oy + h, door_x + gap // 2 - 1, oy + h + TILE // 2 - 1), fill=DOOR_MAT)
    draw.rectangle((ox - 4, oy, ox - 1, oy + h - 1), fill=TRIM)
    draw.rectangle((ox + w, oy, ox + w + 3, oy + h - 1), fill=TRIM)
    draw.rectangle((0, oy + h, img.width, oy + h + 1), fill=TRIM)
    # A few things on the floor for scale and colour.
    stand = lambda spr, x, foot: img.alpha_composite(spr, (ox + x - spr.width // 2, oy + foot - spr.getbbox()[3]))
    for i, cab in enumerate(['space_inv', 'pac', 'breakout']):
        stand(sprite('cabinets', cab, 'south.png'), 80 + i * 40, 2 * TILE)
    stand(sprite('decor', 'plant', 'a.png'), 16, TILE - 3)
    poster = sprite('decor', 'poster', 'a.png')
    img.alpha_composite(poster, (ox + 7 * TILE - poster.width // 2, WALL_H - 8 - poster.getbbox()[3]))
    neon = sprite('decor', 'neon', 'a.png')
    img.alpha_composite(neon, (ox + 9 * TILE - neon.width // 2, WALL_H - 8 - neon.getbbox()[3]))
    stand(sprite('actors', 'customer_a', 'idle_south.png'), 6 * TILE, 4 * TILE)
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


rooms = []
for name in THEMES:
    title, hue, strength, floor_tint = theme(name)
    rooms.append((title, room(BANDS, CAP, hue, strength, floor_tint)))
cols = 2
cell_w, cell_h = rooms[0][1].width, rooms[0][1].height
pad, label, header = 14, 26, 44
card_w, card_h = cell_w + 2 * pad, cell_h + label + 2 * pad
rows = (len(rooms) + cols - 1) // cols
sheet = Image.new('RGB', (cols * (card_w + 8) + 8, header + rows * (card_h + 8) + 8), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((8 + pad, 14), 'WALLS  design F in %d themes' % len(rooms), font=font, fill=GOLD)
for i, (name, img) in enumerate(rooms):
    x = 8 + (i % cols) * (card_w + 8)
    y = header + (i // cols) * (card_h + 8)
    draw.rectangle((x, y, x + card_w - 1, y + card_h - 1), fill=CARD_BG)
    draw.text((x + pad, y + pad - 4), name, font=font, fill=INK)
    sheet.paste(img, (x + pad, y + pad + label))
sheet.save(out)
print('wrote %s: %d themes' % (out, len(rooms)))
