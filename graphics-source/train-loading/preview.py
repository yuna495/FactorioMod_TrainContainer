"""Compose exact Lua layer positions for visual QA; requires Python + Pillow.
Run tests/train_loading_graphics.lua first with a manifest output argument.
"""
from pathlib import Path
from collections import defaultdict
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
manifest = Path(sys.argv[1])
groups = defaultdict(list)
for line in manifest.read_text().splitlines():
    orient, length, filename, width, height, x, y, kind = line.split('\t')
    groups[(orient, int(length))].append((filename, int(width), int(height), float(x), float(y), kind))

for (orient, length), layers in groups.items():
    w, h = (length * 64 + 192, 256) if orient == 'wide' else (256, length * 64 + 192)
    canvas = Image.new('RGBA', (w, h), (52, 55, 51, 255))
    draw = ImageDraw.Draw(canvas)
    for x in range(int(w / 2) % 64, w, 64):
        draw.line((x, 0, x, h), fill=(64, 67, 62))
    for y in range(int(h / 2) % 64, h, 64):
        draw.line((0, y, w, y), fill=(64, 67, 62))
    for filename, width, height, x, y, kind in layers:
        sprite = Image.open(ROOT / filename).convert('RGBA')
        assert sprite.size == (width, height), filename
        bbox = sprite.getchannel('A').getbbox()
        assert bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < width and bbox[3] < height, ('clipped', filename, bbox)
        # Compose denser source art at the established 64px QA scale.
        width, height = round(width * 2 / 3), round(height * 2 / 3)
        sprite = sprite.resize((width, height), Image.Resampling.LANCZOS)
        if kind == 'shadow':
            sprite.putalpha(sprite.getchannel('A').point(lambda a: round(a * .35)))
        canvas.alpha_composite(sprite, (round(w / 2 + x * 64 - width / 2), round(h / 2 + y * 64 - height / 2)))
    canvas.convert('RGB').save(ROOT / 'graphics-source/train-loading' / f'preview-{orient}-{length}.png')

sheet = Image.new('RGB', (1600, 1100), (36, 39, 37))
draw = ImageDraw.Draw(sheet)
draw.text((28, 22), 'TRAIN CONTAINER / T6 + J + END CAPS', fill=(225, 215, 180))
for i, length in enumerate((6, 13, 20)):
    im = Image.open(ROOT / f'graphics-source/train-loading/preview-wide-{length}.png')
    draw.text((28, 65 + i * 185), f'{length} x 1 / 64px preview / 96px source', fill=(225, 215, 180))
    sheet.paste(im, (24, 85 + i * 185))
for i, length in enumerate((6, 13, 20)):
    im = Image.open(ROOT / f'graphics-source/train-loading/preview-high-{length}.png')
    im.thumbnail((160, 430))
    sheet.paste(im, (70 + i * 205, 650))
    draw.text((70 + i * 205, 625), f'1 x {length}', fill=(225, 215, 180))
im = Image.open(ROOT / 'graphics-source/train-loading/preview-wide-13.png')
im = im.resize((im.width // 2, im.height // 2), Image.Resampling.LANCZOS)
draw.text((740, 690), '13 x 1 / game scale (32 pixels per tile)', fill=(225, 215, 180))
sheet.paste(im, (740, 725))
sheet.save(ROOT / 'graphics-source/train-loading/preview.png')
print('Validated image sizes/transparent margins and composed Lua layers.')
