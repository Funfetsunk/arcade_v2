"""Gives an exported web build's game files versioned names so browsers fetch new
ones after every deploy instead of reusing a cached copy.

GitHub Pages lets browsers keep files for 10 minutes, and Godot's loader always
asks for the same names (index.js / .wasm / .pck), so a fresh deploy could show
the old game. This renames them to <prefix>-<version>.* and points index.html at
the new names. index.html itself is small and revalidated, so it picks them up.

Usage: python tools/cache_bust.py build/web <version>
"""
import json
import os
import re
import sys

web, version = sys.argv[1], sys.argv[2]
old = 'index'
new = 'game-' + re.sub(r'[^A-Za-z0-9]', '', version)[:12]

# Everything the engine loads by its executable name (not index.html or the icons).
SUFFIXES = ('.js', '.wasm', '.pck', '.audio.worklet.js', '.audio.position.worklet.js')
for suffix in SUFFIXES:
    src = os.path.join(web, old + suffix)
    if os.path.exists(src):
        os.replace(src, os.path.join(web, new + suffix))

html_path = os.path.join(web, 'index.html')
html = open(html_path, encoding='utf-8').read()
match = re.search(r'const GODOT_CONFIG = (\{.*?\});', html)
config = json.loads(match.group(1))
config['executable'] = new
config['fileSizes'] = {name.replace(old + '.', new + '.', 1): size for name, size in config['fileSizes'].items()}
html = html[:match.start(1)] + json.dumps(config, separators=(',', ':')) + html[match.end(1):]
html = html.replace('<script src="%s.js"></script>' % old, '<script src="%s.js"></script>' % new)
open(html_path, 'w', encoding='utf-8').write(html)
print('renamed %s.* -> %s.*' % (old, new))
