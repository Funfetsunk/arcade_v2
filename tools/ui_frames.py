"""Draws the pixel-art UI frames: small 9-slice textures (12x12, 4 px corners) for
panels, cards and buttons, using the ART.md palette. Each style
is a list of rings drawn from the outside in, then a fill; the outermost corner
pixel is left clear so corners read as rounded.

Writes assets/ui/frames/<style>/<piece>.png.

Usage (needs Pillow):
    python tools/ui_frames.py .
"""
import os
import sys

from PIL import Image

SIZE = 12
OUTLINE = (12, 9, 22)
NAVY = (43, 54, 77)
NAVY_DARK = (28, 22, 48)
NAVY_LIGHT = (59, 74, 102)
SLATE = (111, 134, 163)
SLATE_LIGHT = (160, 179, 204)
PINK = (236, 101, 209)
PINK_DIM = (130, 52, 122)
CYAN = (79, 216, 255)
CYAN_DIM = (40, 104, 130)
AMBER = (255, 183, 3)
AMBER_LIGHT = (255, 216, 102)
AMBER_DARK = (170, 102, 34)
WOOD = (170, 102, 34)
WOOD_LIGHT = (200, 149, 107)
WOOD_DARK = (92, 61, 30)
GREY = (70, 72, 92)
GREY_LIGHT = (110, 112, 130)


def frame(rings, fill, top=None, bottom=None):
    """rings: colours from the outside in. top/bottom: (colour, ring index) to
    recolour one edge of a ring, for a lit top or a shadowed bottom."""
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            d = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
            corner = min(x, SIZE - 1 - x) + min(y, SIZE - 1 - y)
            if corner == 0:
                continue                      # rounded corner
            ring = d if corner > 1 or d > 0 else 0
            colour = rings[ring] if ring < len(rings) else fill
            if top and ring == top[1] and y == top[1] and 0 < x < SIZE - 1:
                colour = top[0]
            if bottom and ring == bottom[1] and y == SIZE - 1 - bottom[1] and 0 < x < SIZE - 1:
                colour = bottom[0]
            px[x, y] = colour + (255,)
    return img


RED = (255, 79, 123)
RED_DIM = (150, 40, 72)

# The user picked style B, the neon bezel (docs/ui_frames_sheet.png); slate and
# wood trim were the other candidates. Pink trim like the wall rail around dark
# glass; cyan-edged buttons; amber for the selected tab and primary buttons.
STYLES = {
    'neon': {
        'panel': frame([OUTLINE, PINK, PINK_DIM], NAVY_DARK),
        'bar': frame([OUTLINE, PINK_DIM], (24, 20, 42)),
        'card': frame([OUTLINE, (60, 48, 96)], (36, 28, 62)),
        'button': frame([OUTLINE, CYAN_DIM, CYAN_DIM], (30, 40, 70), top=(CYAN, 1)),
        'button_hover': frame([OUTLINE, CYAN, CYAN_DIM], (40, 56, 92), top=((200, 245, 255), 1)),
        'button_pressed': frame([OUTLINE, CYAN_DIM], (20, 26, 48)),
        'button_selected': frame([OUTLINE, AMBER_LIGHT, AMBER], AMBER, top=((255, 240, 190), 1), bottom=(AMBER_DARK, 2)),
        'button_disabled': frame([OUTLINE, GREY], (34, 34, 48)),
        'primary_hover': frame([OUTLINE, (255, 240, 190), AMBER_LIGHT], AMBER_LIGHT, bottom=(AMBER, 2)),
        'primary_pressed': frame([OUTLINE, AMBER_DARK], (200, 120, 0), top=(AMBER_DARK, 1)),
        'primary_disabled': frame([OUTLINE, (107, 90, 51)], (80, 66, 40)),
        'danger': frame([OUTLINE, RED, RED_DIM], (122, 34, 56), top=((255, 160, 185), 1)),
        'danger_hover': frame([OUTLINE, (255, 160, 185), RED], (154, 44, 72)),
        'danger_pressed': frame([OUTLINE, RED_DIM], (90, 26, 42)),
    },
}

root = os.path.join(sys.argv[1], 'assets', 'ui', 'frames')
for style, pieces in STYLES.items():
    os.makedirs(os.path.join(root, style), exist_ok=True)
    for name, img in pieces.items():
        img.save(os.path.join(root, style, name + '.png'))
print('wrote %d styles to %s' % (len(STYLES), root))
