"""Draws every machine's cabinet sprites, in all four facings, onto one review sheet.

Machines whose art hasn't been generated yet show empty slots, so the sheet doubles
as a progress check. Rerun it after each batch of cabinet art.

Usage (needs Pillow):
    python tools/cabinet_sheet.py . docs/cabinet_sheet.png
"""
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

FACINGS = ('south', 'east', 'north', 'west')
SCALE = 2
SPRITE = 68 * SCALE
GAP = 8
PAD = 16
LABEL = 28
COLUMNS = 2
CARD = (SPRITE * 4 + GAP * 3 + PAD * 2, LABEL + SPRITE + PAD * 2)
INK = (233, 228, 255)
DIM = (140, 130, 170)
GOLD = (255, 183, 3)
CARD_BG = (28, 20, 48)
PAGE_BG = (14, 10, 26)

project, out = sys.argv[1], sys.argv[2]
machines_dir = os.path.join(project, 'data', 'catalogs', 'machines')


def res_path(path):
    return os.path.join(project, path.removeprefix('res://'))


def read_machine(name):
    text = open(os.path.join(machines_dir, name), encoding='utf-8').read()
    textures = dict(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
    textures = {rid: path for path, rid in textures.items()}
    sprites = {}
    for facing in FACINGS:
        m = re.search(r'^sprite_%s = ExtResource\("([^"]+)"\)' % facing, text, re.M)
        if m and m.group(1) in textures:
            sprites[facing] = res_path(textures[m.group(1)])
    machine_id = re.search(r'^id = &"([^"]+)"', text, re.M).group(1)
    in_game = len(sprites) == 4
    # Art that's been generated but not wired into the machine yet, awaiting review.
    if not in_game:
        folder = os.path.join(project, 'assets', 'sprites', 'cabinets', machine_id)
        for facing in FACINGS:
            path = os.path.join(folder, facing + '.png')
            if os.path.exists(path):
                sprites[facing] = path
    return {
        'id': machine_id,
        'name': re.search(r'^display_name = "([^"]+)"', text, re.M).group(1),
        'sprites': sprites,
        'status': 'IN GAME' if in_game else 'NEW - REVIEW' if len(sprites) == 4 else 'NOT GENERATED',
    }


machines = [read_machine(n) for n in sorted(os.listdir(machines_dir)) if n.endswith('.tres')]
# Art awaiting review first, then what's in the game, then the rest.
ORDER = {'NEW - REVIEW': 0, 'IN GAME': 1, 'NOT GENERATED': 2}
machines.sort(key=lambda m: (ORDER[m['status']], m['name']))
done = sum(len(m['sprites']) == 4 for m in machines)
review = sum(m['status'] == 'NEW - REVIEW' for m in machines)

font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 16)
carpet = Image.open(os.path.join(project, 'assets', 'tiles', 'carpet.png')).convert('RGBA')
carpet = carpet.resize((carpet.width * SCALE, carpet.height * SCALE), Image.NEAREST)

header = 48
rows = (len(machines) + COLUMNS - 1) // COLUMNS
sheet = Image.new('RGBA', (CARD[0] * COLUMNS + GAP * (COLUMNS + 1), header + (CARD[1] + GAP) * rows + GAP), PAGE_BG)
draw = ImageDraw.Draw(sheet)
draw.text((GAP + PAD, 16), 'CABINET ART  %d / %d machines done, %d awaiting review' % (done, len(machines), review),
          font=font, fill=GOLD)

for i, m in enumerate(machines):
    x = GAP + (i % COLUMNS) * (CARD[0] + GAP)
    y = header + (i // COLUMNS) * (CARD[1] + GAP)
    draw.rectangle((x, y, x + CARD[0] - 1, y + CARD[1] - 1), fill=CARD_BG)
    finished = len(m['sprites']) == 4
    draw.text((x + PAD, y + PAD - 4), '%s  (%s)' % (m['name'], m['id']), font=font, fill=INK if finished else DIM)
    status_fill = GOLD if m['status'] == 'NEW - REVIEW' else DIM
    status_width = draw.textlength(m['status'], font=font)
    draw.text((x + CARD[0] - PAD - status_width, y + PAD - 4), m['status'], font=font, fill=status_fill)
    for j, facing in enumerate(FACINGS):
        sx = x + PAD + j * (SPRITE + GAP)
        sy = y + PAD + LABEL
        if facing in m['sprites']:
            # Carpet behind the sprite, so it's judged against the real floor.
            for cx in range(0, SPRITE, carpet.width):
                for cy in range(0, SPRITE, carpet.height):
                    tile = carpet.crop((0, 0, min(carpet.width, SPRITE - cx), min(carpet.height, SPRITE - cy)))
                    sheet.paste(tile, (sx + cx, sy + cy))
            sprite = Image.open(m['sprites'][facing]).convert('RGBA')
            sprite = sprite.resize((sprite.width * SCALE, sprite.height * SCALE), Image.NEAREST)
            sheet.alpha_composite(sprite, (sx + (SPRITE - sprite.width) // 2, sy + (SPRITE - sprite.height) // 2))
        else:
            draw.rectangle((sx, sy, sx + SPRITE - 1, sy + SPRITE - 1), outline=(60, 50, 90), width=2)
        draw.text((sx + 4, sy + SPRITE - 18), facing, font=font, fill=DIM)

sheet.convert('RGB').save(out)
print('wrote %s: %d/%d machines have art' % (out, done, len(machines)))
