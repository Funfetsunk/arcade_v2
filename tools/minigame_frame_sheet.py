"""Draws a review sheet of minigame cabinet frame candidates: each kit (bezel,
marquee, side art) mocked up around a real game screen at game scale, then the
raw pieces.

The bezel is used as a 9-slice: its corners stay put and its edges stretch to fit
the 360x460 board. Margins come from the bezel's black screen hole.

Usage (needs Pillow), with one or more game screenshots (1280x720 editor
captures, board at 440-840 x 90-600):
    python tools/minigame_frame_sheet.py . docs/minigame_frames_sheet.png shot1.png [shot2.png ...]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

project, out, shots = sys.argv[1], sys.argv[2], sys.argv[3:]
folder = os.path.join(project, 'assets', 'sprites', 'minigames', 'candidates', 'cabinet')
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
big = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 24)
small = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'jersey10.ttf'), 16)
PAGE_BG = (14, 10, 26)
CARD_BG = (28, 20, 48)
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
BOARD = (360, 460)
ZOOM = 2  # frame pixels per board pixel

# name -> (bezel, marquee, side art, what it is)
KITS = {
    'A': ('bezel_a', 'marquee_c', 'side_a', 'pink neon bezel, neon tube marquee, stripe sides'),
    'B': ('bezel_b', 'marquee_b', 'side_b', 'steel and cyan bezel, bulb marquee, synthwave sides'),
    'C': ('bezel_c', 'marquee_b', 'side_a', 'navy and gold bezel, bulb marquee, stripe sides'),
}
TITLES = ['PADDLE BLIP', 'COIN CASCADE', 'AIR HOCKEY']


def load(name):
    return Image.open(os.path.join(folder, name + '.png')).convert('RGBA')


def hole(im):
    """The black screen's bounds, scanning out from just above the centre."""
    px = im.load()
    w, h = im.size
    dark = lambda x, y: sum(px[x, y][:3]) < 45
    cx, cy = w // 2, h // 2 - 10
    l, r, t, b = cx, cx, cy, cy
    while l > 0 and dark(l - 1, cy): l -= 1
    while r < w - 1 and dark(r + 1, cy): r += 1
    while t > 0 and dark(cx, t - 1): t -= 1
    while b < h - 1 and dark(cx, b + 1): b += 1
    return l, t, w - 1 - r, h - 1 - b


def nine_slice(im, margins, size):
    """Stretches im to size keeping the margin bands (left, top, right, bottom)."""
    l, t, r, b = margins
    w, h = im.size
    W, H = size
    out = Image.new('RGBA', size)
    xs = [(0, l, 0, l), (l, w - r, l, W - r), (w - r, w, W - r, W)]
    ys = [(0, t, 0, t), (t, h - b, t, H - b), (h - b, h, H - b, H)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if sx1 > sx0 and sy1 > sy0 and dx1 > dx0 and dy1 > dy0:
                out.paste(im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST), (dx0, dy0))
    return out


def board_from(shot):
    return Image.open(shot).convert('RGBA').crop((440, 90, 840, 600)).resize(BOARD, Image.LANCZOS)


def mock(kit, board, title):
    bezel_name, marquee_name, side_name, _ = KITS[kit]
    bezel = load(bezel_name)
    m = hole(bezel)
    bezel = bezel.resize((bezel.width * ZOOM, bezel.height * ZOOM), Image.NEAREST)
    m = tuple(v * ZOOM for v in m)
    frame_size = (BOARD[0] + m[0] + m[2], BOARD[1] + m[1] + m[3])
    frame = nine_slice(bezel, m, frame_size)
    frame.paste(board, (m[0], m[1]))
    marquee = load(marquee_name)
    marquee = marquee.resize((frame_size[0], int(marquee.height * frame_size[0] / marquee.width)), Image.NEAREST)
    side = load(side_name)
    side = side.resize((side.width * frame_size[1] // side.height, frame_size[1] + marquee.height), Image.NEAREST)
    W = frame_size[0] + 2 * side.width + 16
    H = marquee.height + frame_size[1]
    canvas = Image.new('RGBA', (W, H), (6, 4, 12, 255))
    canvas.alpha_composite(side, (0, 0))
    canvas.alpha_composite(side.transpose(Image.FLIP_LEFT_RIGHT), (W - side.width, 0))
    x0 = side.width + 8
    canvas.alpha_composite(marquee, (x0, 0))
    d = ImageDraw.Draw(canvas)
    tw = d.textlength(title, font=big)
    d.text((x0 + (frame_size[0] - tw) / 2, marquee.height / 2 - 14), title, font=big, fill=GOLD)
    canvas.alpha_composite(frame, (x0, marquee.height))
    return canvas


boards = [board_from(s) for s in shots]
mocks = []
for i, kit in enumerate(KITS):
    mocks.append(mock(kit, boards[i % len(boards)], TITLES[i % len(TITLES)]))
scale = 0.6
mocks = [m.resize((int(m.width * scale), int(m.height * scale)), Image.LANCZOS) for m in mocks]

pieces = sorted(f[:-4] for f in os.listdir(folder) if f.endswith('.png'))
row_h = max(m.height for m in mocks)
sheet_w = sum(m.width for m in mocks) + 16 * (len(mocks) + 1)
sheet_h = 60 + row_h + 50 + 2 * 250
sheet = Image.new('RGB', (sheet_w, sheet_h), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((16, 16), 'MINIGAME CABINET FRAMES  kits mocked around real games', font=font, fill=GOLD)
x = 16
for kit, m in zip(KITS, mocks):
    draw.text((x, 40), 'Kit %s: %s' % (kit, KITS[kit][3]), font=small, fill=INK)
    sheet.paste(m, (x, 64), m)
    x += m.width + 16
# The raw pieces, each at 1x on a card.
y = 64 + row_h + 30
draw.text((16, y - 22), 'Pieces', font=font, fill=INK)
x = 16
for name in pieces:
    im = load(name)
    k = min(1.0, 200 / im.height)
    im = im.resize((int(im.width * k), int(im.height * k)), Image.NEAREST)
    if x + im.width > sheet_w - 16:
        x, y = 16, y + 250
    draw.rectangle((x - 4, y - 4, x + im.width + 4, y + im.height + 24), fill=CARD_BG)
    sheet.paste(im, (x, y), im)
    draw.text((x, y + im.height + 4), name, font=small, fill=DIM)
    x += im.width + 20
sheet.save(out)
print('wrote', out)
