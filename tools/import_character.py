"""Imports a finished PixelLab character (4 rotations + a 6-frame walk) into the game.

Downloads the character's zip, places every frame on the game's 48x48 canvas with
the feet where customer A's are (each direction's offset comes from its standing
pose, so the walk cycle keeps its own motion), and writes
assets/sprites/actors/<name>/{idle_<dir>,walk_<dir>_<i>}.png plus <name>_frames.tres
(idle_<dir> and walk_<dir> animations, 10 fps).

Usage: python tools/import_character.py <name>:<character_id> [...]
"""
import io
import json
import os
import sys
import urllib.request
import zipfile

from PIL import Image

FACINGS = ('south', 'east', 'north', 'west')
CANVAS = 48
FEET_Y = 40     # customer A's lowest pixel row
CENTRE_X = 24
FPS = 10
ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'actors')


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'curl/8'})).read()


def place(src, offset):
    frame = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    frame.alpha_composite(src, offset) if offset[0] >= 0 and offset[1] >= 0 else frame.paste(src, offset, src)
    return frame


def write_frames(name, walk_frames):
    res = 'res://assets/sprites/actors/%s/' % name
    textures = ['idle_%s.png' % f for f in FACINGS] + ['walk_%s_%d.png' % (f, i) for f in FACINGS for i in range(walk_frames)]
    ids = {t: i + 1 for i, t in enumerate(textures)}
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(textures) + 1), '']
    lines += ['[ext_resource type="Texture2D" path="%s%s" id="%d"]' % (res, t, ids[t]) for t in textures]
    anims = []
    for f in FACINGS:
        anims.append((('idle_' + f), ['idle_%s.png' % f]))
        anims.append((('walk_' + f), ['walk_%s_%d.png' % (f, i) for i in range(walk_frames)]))
    body = []
    for anim, frames in anims:
        frame_text = ', '.join('{\n"duration": 1.0,\n"texture": ExtResource("%d")\n}' % ids[t] for t in frames)
        body.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %.1f\n}' % (frame_text, anim, FPS))
    lines += ['', '[resource]', 'animations = [' + ', '.join(body) + ']', '']
    with open(os.path.join(ROOT, name, name + '_frames.tres'), 'w', encoding='utf-8', newline='\n') as out:
        out.write('\n'.join(lines))


for arg in sys.argv[1:]:
    name, cid = arg.split(':')
    folder = os.path.join(ROOT, name)
    os.makedirs(folder, exist_ok=True)
    pack = zipfile.ZipFile(io.BytesIO(fetch('https://api.pixellab.ai/mcp/characters/%s/download' % cid)))
    state = json.loads(pack.read('metadata.json'))['states'][0]['frames']
    walk = next(iter(state['animations'].values()))
    for facing in FACINGS:
        idle = Image.open(io.BytesIO(pack.read(state['rotations'][facing]))).convert('RGBA')
        box = idle.getbbox()
        offset = (CENTRE_X - (box[0] + box[2]) // 2, FEET_Y + 1 - box[3])
        place(idle, offset).save(os.path.join(folder, 'idle_%s.png' % facing))
        for i, path in enumerate(walk[facing]):
            frame = Image.open(io.BytesIO(pack.read(path))).convert('RGBA')
            # Walk frames can sit on a bigger canvas than the rotation; keep them centred alike.
            dx = (frame.width - idle.width) // 2
            dy = frame.height - idle.height
            place(frame, (offset[0] - dx, offset[1] - dy)).save(os.path.join(folder, 'walk_%s_%d.png' % (facing, i)))
    write_frames(name, len(walk['south']))
    print('imported', name, '(%d walk frames, rotation canvas %s)' % (len(walk['south']), idle.size))
