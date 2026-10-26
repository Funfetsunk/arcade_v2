"""Draws a review sheet of the housing candidates for minigames that aren't upright
cabinets (tables, prize cases, booths): each candidate raw, then stretched around
a 360x460 board the way the game would show it.

Candidates live in assets/sprites/minigames/candidates/housing/<game>_<letter>.png.
The screen is found by scanning out from the centre while the colour stays close
to the centre's (the generator's "empty" areas are dark but not always black).

Usage (needs Pillow):
    python tools/minigame_housing_sheet.py . docs/minigame_housings_sheet.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import build_minigame_cabinets as cab  # noqa: E402

project, out = sys.argv[1], sys.argv[2]
folder = os.path.join(project, 'assets', 'sprites', 'minigames', 'candidates', 'housing')
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
small = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'jersey10.ttf'), 16)
PAGE_BG = (14, 10, 26)
CARD_BG = (28, 20, 48)
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
PINK = (255, 79, 123)

GAMES = {
    'airhockey': 'Air Hockey', 'whack': 'Whack-It', 'pinball': 'Pinball', 'claw': 'Claw Machine',
    'crane': 'Prize Crane', 'coinpush': 'Coin Cascade', 'slots': 'Mega Jackpot', 'hoops': 'Pro Hoops',
    'aim': 'Skee Roll', 'motionsim': 'Motion Simulator', 'vrpod': 'VR Pod', 'snap': 'Snap Booth',
    'social': 'Social Hub',
}


def hole(im, tolerance=60):
    px = im.load()
    w, h = im.size
    cx, cy = w // 2, h // 2
    base = px[cx, cy][:3]
    near = lambda x, y: sum(abs(px[x, y][i] - base[i]) for i in range(3)) < tolerance
    l, r, t, b = cx, cx, cy, cy
    while l > 0 and near(l - 1, cy): l -= 1
    while r < w - 1 and near(r + 1, cy): r += 1
    while t > 0 and near(cx, t - 1): t -= 1
    while b < h - 1 and near(cx, b + 1): b += 1
    return l, t, r, b


cab.hole = hole


def placeholder(name):
    board = Image.new('RGBA', cab.SCREEN, (10, 10, 22, 255))
    d = ImageDraw.Draw(board)
    for y in range(0, cab.SCREEN[1], 20):
        d.line((0, y, cab.SCREEN[0], y), fill=(22, 20, 40))
    tw = d.textlength(name.upper(), font=font)
    d.text(((cab.SCREEN[0] - tw) / 2, cab.SCREEN[1] / 2 - 10), name.upper(), font=font, fill=GOLD)
    return board


THUMB_H = 300
cards = []
for game, name in GAMES.items():
    for letter in 'ab':
        path = os.path.join(folder, '%s_%s.png' % (game, letter))
        raw = Image.open(path).convert('RGBA')
        l, t, r, b = hole(raw.copy())
        found = (r - l) * (b - t) > raw.width * raw.height * 0.12
        if found:
            fitted, (sx, sy) = cab.fit_screen(raw.copy())
            fitted.alpha_composite(placeholder(name), (sx, sy))
        else:
            fitted = None
        cards.append((game, letter, name, raw, fitted))

COLS = 4
card_w = 2 * 240 + 30
card_h = THUMB_H + 40
rows = (len(cards) + COLS - 1) // COLS
sheet = Image.new('RGB', (16 + COLS * (card_w + 12), 50 + rows * (card_h + 12)), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((16, 16), 'MINIGAME HOUSINGS  raw / fitted around the board', font=font, fill=GOLD)
for i, (game, letter, name, raw, fitted) in enumerate(cards):
    x = 16 + (i % COLS) * (card_w + 12)
    y = 50 + (i // COLS) * (card_h + 12)
    draw.rectangle((x, y, x + card_w, y + card_h), fill=CARD_BG)
    draw.text((x + 8, y + 6), '%s %s' % (name, letter), font=small, fill=INK)
    k = (THUMB_H - 20) / raw.height
    thumb = raw.resize((int(raw.width * k), int(raw.height * k)), Image.NEAREST)
    sheet.paste(thumb, (x + 8, y + 30), thumb)
    if fitted:
        k = (THUMB_H - 20) / fitted.height
        f = fitted.resize((int(fitted.width * k), int(fitted.height * k)), Image.LANCZOS)
        sheet.paste(f, (x + 260, y + 30), f)
    else:
        draw.text((x + 280, y + THUMB_H / 2), 'no clear screen area', font=small, fill=PINK)
sheet.save(out)
print('wrote', out)
