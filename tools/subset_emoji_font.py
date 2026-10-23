"""Subsets Noto Color Emoji to the emoji the game's scripts, scenes and data use.

Usage (needs `pip install fonttools`; source font from
https://github.com/googlefonts/noto-emoji/tree/main/2D/fonts, NotoColorEmoji-noflags.ttf):
    python tools/subset_emoji_font.py . NotoColorEmoji-noflags.ttf assets/fonts/noto_color_emoji_subset.ttf
"""
import os
import sys
import unicodedata

from fontTools import subset
from fontTools.ttLib import TTFont

project, source, out = sys.argv[1], sys.argv[2], sys.argv[3]
font = TTFont(source)
cmap = font.getBestCmap()

used = set()
for root, dirs, files in os.walk(project):
    rel = os.path.relpath(root, project).replace('\\', '/')
    if rel.startswith(('.godot', 'addons', '.git', 'docs', 'tests/fixtures')):
        continue
    for name in files:
        if name.endswith(('.gd', '.tres', '.tscn')):
            text = open(os.path.join(root, name), encoding='utf-8', errors='ignore').read()
            used.update(ord(ch) for ch in text if ord(ch) > 0x2000 and ord(ch) in cmap)
# Joiners and the emoji presentation selector, so sequences like 👨‍🍳 still compose.
used.update(c for c in (0x200D, 0xFE0F, 0x20E3) if c in cmap)

options = subset.Options()
options.layout_features = ['*']
options.notdef_outline = True
options.name_IDs = ['*']
subsetter = subset.Subsetter(options)
subsetter.populate(unicodes=sorted(used))
subsetter.subset(font)
font.save(out)
print(f'{len(used)} codepoints -> {os.path.getsize(out) // 1024} KB')
