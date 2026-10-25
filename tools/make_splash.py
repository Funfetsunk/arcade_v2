"""Draws the loading / boot splash: the title in neon over a row of cabinets.

The web loader shows it with its progress bar while the game downloads, and the
engine shows it again while it boots.

Usage (needs Pillow): python tools/make_splash.py . assets/ui/splash.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

project, out = sys.argv[1], sys.argv[2]
W, H = 640, 360
BG = (11, 11, 20, 255)
GOLD = (255, 183, 3)
PINK = (255, 79, 123)
CABINETS = ['space_inv', 'pac', 'trivia', 'shooter', 'breakout']
SCALE = 2

img = Image.new('RGBA', (W, H), BG)
font = ImageFont.truetype(os.path.join(project, 'assets', 'fonts', 'arcade_empire_pixel.ttf'), 36)

# Title with a soft neon glow.
title = 'ARCADE EMPIRE'
box = ImageDraw.Draw(img).textbbox((0, 0), title, font=font)
tw = box[2] - box[0]
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ImageDraw.Draw(glow).text(((W - tw) // 2, 70), title, font=font, fill=PINK + (255,))
img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
ImageDraw.Draw(img).text(((W - tw) // 2, 70), title, font=font, fill=GOLD + (255,))

# A row of cabinets on a strip of carpet.
carpet = Image.open(os.path.join(project, 'assets', 'tiles', 'carpet.png')).convert('RGBA')
carpet = carpet.resize((carpet.width * SCALE, carpet.height * SCALE), Image.NEAREST)
floor_y = 270
for x in range(0, W, carpet.width):
    img.alpha_composite(carpet, (x, floor_y - 40))
shade = Image.new('RGBA', (W, 120), (11, 11, 20, 0))
for y in range(120):
    a = int(255 * max(0.0, (abs(y - 60) - 20) / 40))
    ImageDraw.Draw(shade).line([(0, y), (W, y)], fill=(11, 11, 20, min(255, a)))
img.alpha_composite(shade, (0, floor_y - 60))
step = 96
start = (W - step * (len(CABINETS) - 1)) // 2
for i, cab in enumerate(CABINETS):
    sprite = Image.open(os.path.join(project, 'assets', 'sprites', 'cabinets', cab, 'south.png')).convert('RGBA')
    sprite = sprite.resize((sprite.width * SCALE, sprite.height * SCALE), Image.NEAREST)
    img.alpha_composite(sprite, (start + i * step - sprite.width // 2, floor_y - sprite.height + 8))

os.makedirs(os.path.dirname(out), exist_ok=True)
img.save(out)
print('wrote', out)
