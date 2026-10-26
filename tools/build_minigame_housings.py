"""Builds the housings for minigames that aren't upright cabinets (tables, prize
cases, booths) from the picked PixelLab candidates in
assets/sprites/minigames/candidates/housing.

Each machine's play area is stretched to exactly fit the 360x460 board by
repeating plain columns and rows (never scaling), like build_minigame_cabinets.py.
Two kinds:
  over:  the art is drawn over the board with its screen cut out by shape (a
         rounded window, a pinball playfield's slanted foot), so it overlaps the
         board's edges naturally.
  under: the art is the playing surface (an air hockey table); the board draws on
         top of it with no background of its own.

Fake lettering from the generator (pinball's "BACK BOX", scoreboard digits) is
wiped so the game's name or live score can go there instead.

Writes assets/sprites/minigames/housings/<game>.png and <game>.tres.

Usage (needs Pillow):
    python tools/build_minigame_housings.py .
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import build_minigame_cabinets as cab  # noqa: E402

project = sys.argv[1]
src = os.path.join(project, 'assets', 'sprites', 'minigames', 'candidates', 'housing')
dst = os.path.join(project, 'assets', 'sprites', 'minigames', 'housings')
W, H = cab.SCREEN

# game -> settings. screen: a fixed (x, y, w, h) play area, else it's found by
# flood-filling from the centre. cols / rows: [(at, count)] stretch points, else
# the plainest one. wipe: [(rect, light_text?, fill colour from (x, y))].
# title / score: (rect, colour) in the source art's pixels.
GAMES = {
    'airhockey': dict(pick='airhockey_a', mode='under', screen=(10, 13, 180, 230),
                      # Through the goals so they widen to the game's 100 px, the rest beside them.
                      cols=[(100, 60), (62, 60), (138, 60)], rows=[(100, 230)]),
    'whack': dict(pick='whack_b', wipe=[((78, 19, 44, 12), True, (100, 25))], tolerance=20,
                  score=((77, 18, 46, 14), (1.0, 0.85, 0.2))),
    'pinball': dict(pick='pinball_a', wipe=[((52, 0, 96, 12), True, (56, 9))],
                    title=((52, 0, 96, 12), (0.3, 0.12, 0.05))),
    'claw': dict(pick='claw_a', screen=(57, 53, 84, 97), title=((48, 14, 104, 19), (0.75, 0.2, 0.45))),
    'crane': dict(pick='crane_b', title=((44, 20, 104, 18), (1.0, 1.0, 1.0))),
    # The bulbs repeat in whole steps so none go missing.
    'coinpush': dict(pick='coinpush_a', period=True),
    # The JACKPOT sign is wider than the reel window, so it's lifted off and
    # put back centred, unstretched.
    'slots': dict(pick='slots_b', screen=(59, 69, 81, 50), keep_top=55),
    'hoops': dict(pick='hoops_b', title=((56, 17, 90, 22), (0.6, 0.12, 0.15))),
    # The wooden lane is the playing surface; the (wiped) score panel stretches.
    'aim': dict(pick='aim_a', mode='under', wipe=[((70, 1, 68, 10), False, (72, 3))], cols=[(105, None)],
                score=((70, 0, 68, 12), (0.25, 0.12, 0.05))),
    'motionsim': dict(pick='motionsim_a'),
    'vrpod': dict(pick='vrpod_b', clear=False),
    # Either side of the camera, so it stays centred over the window.
    'snap': dict(pick='snap_a', screen=(72, 72, 57, 87), cols=[(76, None), (124, None)]),
    'social': dict(pick='social_b'),
}


def flood(im, start, tolerance=55):
    """The 4-connected area around start whose colour stays near start's."""
    px = im.load()
    w, h = im.size
    base = px[start][:3]
    region, stack = set(), [start]
    while stack:
        x, y = stack.pop()
        if (x, y) in region or not (0 <= x < w and 0 <= y < h):
            continue
        if sum(abs(px[x, y][i] - base[i]) for i in range(3)) > tolerance:
            continue
        region.add((x, y))
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return region


def wipe(im, rect, light, at):
    """Paints over generator lettering in rect with the panel colour at `at`."""
    px = im.load()
    fill = px[at]
    lum = lambda p: p[0] * 0.3 + p[1] * 0.59 + p[2] * 0.11
    base = lum(fill)
    x0, y0, w, h = rect
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            # Letters are the pixels well lighter (or darker) than the panel.
            if (lum(px[x, y]) - base > 40) if light else (base - lum(px[x, y]) > 40):
                px[x, y] = fill


def stretch(im, points, axis, need, lo, hi, mid):
    """Repeats columns (axis 0) or rows (axis 1); returns (image, [(at, count)] used).
    A count of None shares what's left evenly between those points."""
    if points and any(n is None for _, n in points):
        free = [at for at, n in points if n is None]
        left = need - sum(n for _, n in points if n is not None)
        shares = [left // len(free) + (1 if i < left % len(free) else 0) for i in range(len(free))]
        fixed = [(at, n) for at, n in points if n is not None]
        points = fixed + list(zip(free, shares))
    if not points:
        diff = (lambda i: cab.col_diff(im, i)) if axis == 0 else (lambda i: cab.row_diff(im, i))
        points = [(cab.plainest(diff, lo + 2, hi - 1, mid), need)]
    assert sum(n for _, n in points) == need, (points, need)
    # Right to left, so earlier insertions don't move later points.
    for at, n in sorted(points, reverse=True):
        im = cab.repeat_col(im, at, n) if axis == 0 else cab.repeat_row(im, at, n)
    return im, points


def shift(v, points):
    return v + sum(n for at, n in points if at < v)


def remap(rect, cols, rows):
    x, y, w, h = rect
    x0, x1 = shift(x, cols), shift(x + w, cols)
    y0, y1 = shift(y, rows), shift(y + h, rows)
    return (x0, y0, x1 - x0, y1 - y0)


def tres(game, size, screen, mode, title, score):
    lines = [
        '[gd_resource type="Resource" script_class="MinigameHousing" format=3]',
        '',
        '[ext_resource type="Script" path="res://minigames/minigame_housing.gd" id="1"]',
        '[ext_resource type="Texture2D" path="res://assets/sprites/minigames/housings/%s.png" id="2"]' % game,
        '',
        '[resource]',
        'script = ExtResource("1")',
        'texture = ExtResource("2")',
        'screen = Rect2i(%d, %d, %d, %d)' % (screen[0], screen[1], W, H),
    ]
    if mode == 'under':
        lines.append('board_on_top = true')
    if title:
        lines.append('title_rect = Rect2i(%d, %d, %d, %d)' % title[0])
        lines.append('title_color = Color(%.3f, %.3f, %.3f, 1)' % title[1])
    if score:
        lines.append('score_rect = Rect2i(%d, %d, %d, %d)' % score[0])
        lines.append('score_color = Color(%.3f, %.3f, %.3f, 1)' % score[1])
    with open(os.path.join(dst, game + '.tres'), 'w', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')


for game, cfg in GAMES.items():
    im = Image.open(os.path.join(src, cfg['pick'] + '.png')).convert('RGBA')
    sign = im.crop((0, 0, im.width, cfg['keep_top'])) if 'keep_top' in cfg else None
    for rect, light, at in cfg.get('wipe', []):
        wipe(im, rect, light, at)
    mode = cfg.get('mode', 'over')
    if 'screen' in cfg:
        x, y, w, h = cfg['screen']
        area = {(i, j) for i in range(x, x + w) for j in range(y, y + h)}
    else:
        area = flood(im, (im.width // 2, im.height // 2), cfg.get('tolerance', 55))
    xs = [p[0] for p in area]
    ys = [p[1] for p in area]
    l, t, r, b = min(xs), min(ys), max(xs), max(ys)
    if mode == 'over':
        px = im.load()
        for p in area:
            px[p] = (0, 0, 0, 0)
    if cfg.get('clear', True):
        im = cab.clear_background(im)
    if cfg.get('period'):
        # Whole pattern steps from the middle, both ways (bulbs down the sides too).
        cols = [((l + r) // 2, W - (r - l + 1))]
        p = cab.period(im)
        im = cab.repeat_block(im, (l + r) // 2 - p, p, cols[0][1])
        rows = [((t + b) // 2, H - (b - t + 1))]
        im = cab.repeat_block(im.transpose(Image.TRANSPOSE), (t + b) // 2 - p, p, rows[0][1]).transpose(Image.TRANSPOSE)
    else:
        im, cols = stretch(im, cfg.get('cols'), 0, W - (r - l + 1), l, r, (l + r) // 2)
        im, rows = stretch(im, cfg.get('rows'), 1, H - (b - t + 1), t, b, (t + b) // 2)
    if sign:
        if cfg.get('clear', True):
            sign = cab.clear_background(sign)
        top = Image.new('RGBA', (im.width, sign.height))
        im.paste(top, (0, 0))
        im.alpha_composite(sign, ((im.width - sign.width) // 2, 0))
    im.save(os.path.join(dst, game + '.png'))
    title = (remap(cfg['title'][0], cols, rows), cfg['title'][1]) if 'title' in cfg else None
    score = (remap(cfg['score'][0], cols, rows), cfg['score'][1]) if 'score' in cfg else None
    tres(game, im.size, (l, t), mode, title, score)
    print('%s: %s screen at %s' % (game, im.size, (l, t)))
