"""Builds the upright minigame cabinets from the PixelLab pieces in
assets/sprites/minigames/candidates/cabinet: each is a marquee stacked on a
bezel whose screen hole is stretched to exactly fit the 360x460 board, at 1 art
pixel per board pixel.

Stretching never scales the art: it repeats the plainest column (or row) inside
the hole's span, the way a 9-slice repeats its edges, so corners, bolts and
buttons stay crisp. Marquees are made symmetrical by mirroring their left half
(two came out clipped on the right), and the opaque generator background is
cleared by flood-filling from the corners.

Writes assets/sprites/minigames/housings/<kit>.png and prints each cabinet's
screen and marquee-panel rects for its MinigameHousing resource.

Usage (needs Pillow):
    python tools/build_minigame_cabinets.py .
"""
import colorsys
import os
import sys

from PIL import Image

project = sys.argv[1]
src = os.path.join(project, 'assets', 'sprites', 'minigames', 'candidates', 'cabinet')
dst = os.path.join(project, 'assets', 'sprites', 'minigames', 'housings')
os.makedirs(dst, exist_ok=True)
SCREEN = (360, 460)

# kit -> (bezel, marquee, columns of the marquee's left half to mirror, hue for the
# marquee or None, bezel column to stretch or None for the plainest)
KITS = {
    'neon': ('bezel_a', 'marquee_c', 160, None, None),
    'steel': ('bezel_b', 'marquee_a', 106, 0.52, None),
    # Between the small and big buttons, so the deck's red slot doesn't stretch.
    'classic': ('bezel_c', 'marquee_b', 160, None, 84),
}


def load(name):
    return Image.open(os.path.join(src, name + '.png')).convert('RGBA')


def clear_background(im, tolerance=40):
    """Makes the flat generator background transparent, flood-filling from each corner."""
    px = im.load()
    w, h = im.size
    for start in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        base = px[start][:3]
        stack, seen = [start], set()
        while stack:
            x, y = stack.pop()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
                continue
            seen.add((x, y))
            p = px[x, y]
            if p[3] == 0 or sum(abs(p[i] - base[i]) for i in range(3)) > tolerance:
                continue
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def hole(im):
    """The black screen's bounds (inclusive), scanning out from just above the centre."""
    px = im.load()
    w, h = im.size
    dark = lambda x, y: sum(px[x, y][:3]) < 45
    cx, cy = w // 2, h // 2 - 10
    l, r, t, b = cx, cx, cy, cy
    while l > 0 and dark(l - 1, cy): l -= 1
    while r < w - 1 and dark(r + 1, cy): r += 1
    while t > 0 and dark(cx, t - 1): t -= 1
    while b < h - 1 and dark(cx, b + 1): b += 1
    return l, t, r, b


def col_diff(im, x):
    px = im.load()
    return sum(sum(abs(px[x, y][i] - px[x - 1, y][i]) for i in range(4)) for y in range(im.height))


def row_diff(im, y):
    px = im.load()
    return sum(sum(abs(px[x, y][i] - px[x, y - 1][i]) for i in range(4)) for x in range(im.width))


def plainest(diff, lo, hi, centre):
    """The index in [lo, hi) most like its neighbour, ties going to the one nearest centre."""
    return min(range(lo, hi), key=lambda i: (diff(i), abs(i - centre)))


def repeat_col(im, x, n):
    out = Image.new('RGBA', (im.width + n, im.height))
    out.paste(im.crop((0, 0, x, im.height)), (0, 0))
    strip = im.crop((x, 0, x + 1, im.height))
    for i in range(n + 1):
        out.paste(strip, (x + i, 0))
    out.paste(im.crop((x + 1, 0, im.width, im.height)), (x + n + 1, 0))
    return out


def repeat_row(im, y, n):
    return repeat_col(im.transpose(Image.TRANSPOSE), y, n).transpose(Image.TRANSPOSE)


def period(im):
    """The repeat length of a patterned border (a row of bulbs), from its top rows."""
    px = im.load()
    c = im.width // 2
    rows = range(min(8, im.height))
    score = lambda p: sum(sum(abs(px[x, y][i] - px[x + p, y][i]) for i in range(3)) for x in range(c - 40, c) for y in rows)
    return min(range(4, 24), key=score)


def repeat_block(im, x, width, n):
    """Widens im by n, inserting copies of the `width` columns from x (a whole pattern repeat)."""
    block = im.crop((x, 0, x + width, im.height))
    out = Image.new('RGBA', (im.width + n, im.height))
    out.paste(im.crop((0, 0, x, im.height)), (0, 0))
    for i in range(0, n, width):
        out.paste(block.crop((0, 0, min(width, n - i), im.height)), (x + i, 0))
    out.paste(im.crop((x, 0, im.width, im.height)), (x + n, 0))
    return out


def symmetric(im, half):
    left = im.crop((0, 0, half, im.height))
    out = Image.new('RGBA', (half * 2, im.height))
    out.paste(left, (0, 0))
    out.paste(left.transpose(Image.FLIP_LEFT_RIGHT), (half, 0))
    return out


def hue_shift(im, hue):
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if a and s > 0.25:
                r, g, b = colorsys.hsv_to_rgb(hue, s, v)
                px[x, y] = (round(r * 255), round(g * 255), round(b * 255), a)
    return im


def fit_screen(im, stretch_x=None):
    """Cuts out im's screen and stretches it to exactly SCREEN; returns (image, screen top-left)."""
    l, t, r, b = hole(im)
    # Clear the screen itself, then the backdrop around the machine.
    px = im.load()
    for y in range(t, b + 1):
        for x in range(l, r + 1):
            px[x, y] = (0, 0, 0, 0)
    im = clear_background(im)
    x = stretch_x or plainest(lambda i: col_diff(im, i), l + 2, r - 1, (l + r) // 2)
    im = repeat_col(im, x, SCREEN[0] - (r - l + 1))
    y = plainest(lambda i: row_diff(im, i), t + 2, b - 1, (t + b) // 2)
    im = repeat_row(im, y, SCREEN[1] - (b - t + 1))
    return im, (l, t)


def build_cabinets():
    for kit, (bezel_name, marquee_name, half, hue, stretch_x) in KITS.items():
        bezel, (l, t) = fit_screen(load(bezel_name), stretch_x)

        marquee = symmetric(clear_background(load(marquee_name)), half)
        if hue is not None:
            marquee = hue_shift(marquee, hue)
        # Widen (or crop) the marquee to the cabinet's width, repeating whole pattern
        # steps (bulbs) from just left of its middle.
        if marquee.width < bezel.width:
            p = period(marquee)
            marquee = repeat_block(marquee, marquee.width // 2 - p, p, bezel.width - marquee.width)
        else:
            cut = (marquee.width - bezel.width) // 2
            marquee = marquee.crop((cut, 0, cut + bezel.width, marquee.height))
        marquee = marquee.crop((0, 0, marquee.width, marquee.getbbox()[3]))

        cabinet = Image.new('RGBA', (bezel.width, marquee.height + bezel.height))
        cabinet.alpha_composite(marquee, (0, 0))
        cabinet.alpha_composite(bezel, (0, marquee.height))
        cabinet.save(os.path.join(dst, kit + '.png'))
        # The title sits in the marquee's middle 70%, vertically centred.
        title = (round(bezel.width * 0.15), 0, round(bezel.width * 0.7), marquee.height)
        print('%s: size %s screen %s title %s' % (kit, cabinet.size, (l, t + marquee.height, SCREEN[0], SCREEN[1]), title))


if __name__ == '__main__':
    build_cabinets()
