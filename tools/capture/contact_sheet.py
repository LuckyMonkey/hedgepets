#!/usr/bin/env python3
"""Lay the acceptance captures out on one sheet (and a true phone-size thumbnail of the distant view)."""
import os
from PIL import Image, ImageDraw
D = '/tmp/hedgepets-views'
names = ['view_front', 'view_side', 'view_three_quarter', 'view_distant', 'foliage_low', 'foliage_medium', 'foliage_full', 'foliage_flowering']
ims = []
for n in names:
    im = Image.open(f'{D}/{n}.png').convert('RGB')
    w, h = im.size
    im = im.crop((0, int(h * 0.22), w, int(h * 0.76)))
    ims.append((n, im))
w, h = ims[0][1].size
sheet = Image.new('RGB', (w * 4, (h + 24) * 2), (255, 255, 255))
d = ImageDraw.Draw(sheet)
for i, (n, im) in enumerate(ims):
    x, y = (i % 4) * w, (i // 4) * (h + 24)
    sheet.paste(im, (x, y + 24))
    d.text((x + 6, y + 6), n, fill=(60, 50, 40))
sheet.save(f'{D}/sheet.png')
# the distant view at an actual phone size: 1/3 of a 1080-wide screen
Image.open(f'{D}/view_distant.png').convert('RGB').resize((180, 320), Image.LANCZOS).save(f'{D}/phone_small.png')
print(sheet.size)
