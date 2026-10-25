"""Packs the approved carpet variants into one atlas strip for the floor TileSet:
plain tiles first, then the accent and worn tiles, each 32x32, in name order.
floor/floor.gd's CARPET_PLAIN and CARPET_ACCENTS must match the counts it prints.

Usage (needs Pillow):
    python tools/carpet_atlas.py .
"""
import os
import sys

from PIL import Image

folder = os.path.join(sys.argv[1], 'assets', 'tiles', 'carpet_variants')
names = sorted(f[:-4] for f in os.listdir(folder) if f.endswith('.png'))
plain = [n for n in names if n.startswith('plain_')]
others = [n for n in names if not n.startswith('plain_')]
atlas = Image.new('RGBA', (32 * len(names), 32))
for i, name in enumerate(plain + others):
    atlas.paste(Image.open(os.path.join(folder, name + '.png')).convert('RGBA'), (32 * i, 0))
out = os.path.join(sys.argv[1], 'assets', 'tiles', 'carpet_variants.png')
atlas.save(out)
print('wrote %s: %d plain, %d accents (%s)' % (out, len(plain), len(others), ', '.join(plain + others)))
