"""Draws a review sheet of the UI icons, and installs the picks. Icons still being
picked get a row each with the emoji they replace and every candidate (on a neon
button at game scale, and zoomed to 4x); the picks so far are shown together
along the bottom, each on a button that fits it so it sits on the button's trim.

Each pick is cropped to its pixels and centred on a 24x24 canvas, then saved as
assets/ui/icons/<name>.png.

Candidates live in assets/ui/icons/candidates/<name>_<suffix>.png (24x24);
PICKS names the chosen file for each icon.

Usage (needs Pillow; the emoji column needs a colour emoji font path as a third
argument, e.g. NotoColorEmoji.ttf, and is skipped without one):
    python tools/icon_sheet.py . docs/icon_sheet.png [emoji_font.ttf]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

EMOJI = {
    'floor': '🕹', 'shop': '🛒', 'staff': '👤', 'books': '💰', 'sound_on': '🔊', 'sound_off': '🔇',
    'mood_great': '😄', 'mood_good': '🙂', 'mood_ok': '😐', 'mood_low': '😟', 'mood_angry': '😠',
    'repairs': '🔧', 'event_log': '📜', 'help': '❓', 'scenarios': '🎯', 'daily': '📅',
    'marketing': '📣', 'contracts': '📋', 'research': '🔬', 'franchises': '🏬', 'decor': '🎨',
    'progress': '📈', 'achievements': '🏅', 'leaderboard': '🏆', 'credits': '🎬', 'restart': '🔄',
    'next_day': '🌙',
}
# The user's picks (candidate suffix); None = still to choose.
PICKS = {
    'floor': 'plan1', 'shop': 'a', 'staff': 'badge1', 'books': 'a', 'sound_on': 'c', 'sound_off': 'b',
    'mood_great': 'a', 'mood_good': 'b', 'mood_ok': 'a', 'mood_low': 'a', 'mood_angry': 'a',
    'repairs': 'b', 'event_log': 'a', 'help': 'b', 'scenarios': 'a', 'daily': 'a', 'marketing': 'a',
    'contracts': 'a', 'research': 'b', 'franchises': 'b', 'decor': 'a', 'progress': 'b',
    'achievements': 'a', 'leaderboard': 'a', 'credits': 'a', 'restart': 'b', 'next_day': 'b',
}
# Picks touched up by hand since the last review, shown again for a check.
TOUCHED = {}
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)
PER_LINE = 6
CELL = 64 + 8 + 96 + 14

project, out = sys.argv[1], sys.argv[2]
emoji_font = ImageFont.truetype(sys.argv[3], 109) if len(sys.argv) > 3 else None
assets = os.path.join(project, 'assets')
font = ImageFont.truetype(os.path.join(assets, 'fonts', 'arcade_empire_pixel.ttf'), 16)
folder = os.path.join(assets, 'ui', 'icons', 'candidates')
button = Image.open(os.path.join(assets, 'ui', 'frames', 'neon', 'button.png')).convert('RGBA')


def candidates(name):
    files = sorted(f[:-4] for f in os.listdir(folder) if f.endswith('.png') and f.startswith(name + '_'))
    # 'mood_ok' must not pick up another icon whose name merely starts the same way.
    return [f for f in files if f[len(name) + 1:] and not any(
        other != name and other.startswith(name + '_') and f.startswith(other + '_') for other in EMOJI)]


def centred(icon):
    """The icon's pixels centred on a 24x24 canvas."""
    box = icon.getbbox()
    art = icon.crop(box)
    out = Image.new('RGBA', (24, 24))
    out.alpha_composite(art, ((24 - art.width) // 2, (24 - art.height) // 2))
    return out


def nine(tex, w, h, c=4):
    out = Image.new('RGBA', (w, h))
    n = tex.width
    mid = tex.crop((c, c, n - c, n - c)).resize((w - 2 * c, h - 2 * c), Image.NEAREST)
    out.alpha_composite(mid, (c, c))
    out.alpha_composite(tex.crop((c, 0, n - c, c)).resize((w - 2 * c, c), Image.NEAREST), (c, 0))
    out.alpha_composite(tex.crop((c, n - c, n - c, n)).resize((w - 2 * c, c), Image.NEAREST), (c, h - c))
    out.alpha_composite(tex.crop((0, c, c, n - c)).resize((c, h - 2 * c), Image.NEAREST), (0, c))
    out.alpha_composite(tex.crop((n - c, c, n, n - c)).resize((c, h - 2 * c), Image.NEAREST), (w - c, c))
    for cx, cy in ((0, 0), (n - c, 0), (0, n - c), (n - c, n - c)):
        out.alpha_composite(tex.crop((cx, cy, cx + c, cy + c)), (0 if cx == 0 else w - c, 0 if cy == 0 else h - c))
    return out


def on_button(icon):
    """The icon on a neon button sized to fit it: it sits right on the button's
    trim, with no dark fill showing round it. Game scale (2 screen px a pixel)."""
    art = icon.crop(icon.getbbox())
    bg = nine(button, art.width + 6, art.height + 6)
    bg.alpha_composite(art, (3, 3))
    frame = Image.new('RGBA', (32, 32))
    frame.alpha_composite(bg, ((32 - bg.width) // 2, (32 - bg.height) // 2))
    return frame.resize((64, 64), Image.NEAREST)


def emoji(name):
    img = Image.new('RGBA', (136, 128))
    if not emoji_font:
        return img.resize((48, 48))
    ImageDraw.Draw(img).text((0, 0), EMOJI[name], font=emoji_font, embedded_color=True)
    box = img.getbbox()
    return (img.crop(box) if box else img).resize((48, 48), Image.LANCZOS)


def candidate_cell(sheet, draw, x, y, file, label, chosen=False):
    icon = Image.open(os.path.join(folder, file + '.png')).convert('RGBA')
    b = on_button(icon)
    sheet.paste(b, (x, y + 4), b)
    zoom = icon.resize((96, 96), Image.NEAREST)
    sheet.paste(zoom, (x + 72, y), zoom)
    if chosen:
        draw.rectangle((x - 3, y - 3, x + CELL - 10, y + 99), outline=GOLD, width=2)
    draw.text((x + 2, y + 72), label, font=font, fill=GOLD if chosen else DIM)


open_rows = [(n, candidates(n)) for n in EMOJI if PICKS[n] is None]
touched = [n for n in EMOJI if n in TOUCHED]
width = 8 + 64 + PER_LINE * CELL + 16
heights = [28 + ((len(c) + PER_LINE - 1) // PER_LINE) * 110 + 8 for _, c in open_rows]
touched_h = 28 + 110 + 8 if touched else 0
picks_per_line = 9
pick_lines = (len(EMOJI) + picks_per_line - 1) // picks_per_line
picks_h = 36 + pick_lines * 100
sheet = Image.new('RGB', (width, 50 + sum(h + 8 for h in heights) + touched_h + 8 + picks_h), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((16, 16), 'UI ICONS  still to pick: %s' % (', '.join(n for n, _ in open_rows) or 'none'), font=font, fill=GOLD)
y = 50
for (name, files), h in zip(open_rows, heights):
    draw.rectangle((8, y, width - 9, y + h - 1), fill=CARD_BG)
    draw.text((16, y + 6), '%s  (pick one)' % name.replace('_', ' '), font=font, fill=INK)
    e = emoji(name)
    sheet.paste(e, (16, y + 40), e)
    for i, f in enumerate(files):
        candidate_cell(sheet, draw, 80 + (i % PER_LINE) * CELL, y + 30 + (i // PER_LINE) * 110, f, f[len(name) + 1:])
    y += h + 8
if touched:
    draw.rectangle((8, y, width - 9, y + touched_h - 1), fill=CARD_BG)
    draw.text((16, y + 6), 'touched up by hand', font=font, fill=INK)
    for i, name in enumerate(touched):
        x = 80 + i * (CELL + 40)
        candidate_cell(sheet, draw, x, y + 30, '%s_%s' % (name, PICKS[name]), TOUCHED[name][:22], True)
    y += touched_h + 8
draw.rectangle((8, y, width - 9, y + picks_h - 1), fill=CARD_BG)
draw.text((16, y + 6), 'picks, each on a button that fits it, at game scale', font=font, fill=INK)
for i, name in enumerate(EMOJI):
    x = 16 + (i % picks_per_line) * 110
    yy = y + 36 + (i // picks_per_line) * 100
    if PICKS[name]:
        b = on_button(Image.open(os.path.join(folder, '%s_%s.png' % (name, PICKS[name]))).convert('RGBA'))
        sheet.paste(b, (x + 20, yy), b)
    draw.text((x, yy + 70), name.replace('_', ' ')[:13], font=font, fill=DIM if PICKS[name] else GOLD)
sheet.save(out)
installed = os.path.join(assets, 'ui', 'icons')
for name, pick in PICKS.items():
    if pick:
        centred(Image.open(os.path.join(folder, '%s_%s.png' % (name, pick))).convert('RGBA')).save(os.path.join(installed, name + '.png'))
print('wrote %s; installed %d icons' % (out, sum(1 for p in PICKS.values() if p)))
