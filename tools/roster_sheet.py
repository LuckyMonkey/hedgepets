#!/usr/bin/env python3
"""Contact sheet of /tmp/hedgepets-views/roster/*.png -> docs/acceptance/roster.png (6 across, cropped to the pet)."""
import glob
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = sorted(glob.glob('/tmp/hedgepets-views/roster/*.png'))
cols, tw, th = 6, 270, 300
out = Image.new('RGB', (cols * tw, ((len(files) + cols - 1) // cols) * th), (247, 241, 227))
for i, f in enumerate(files):
    im = Image.open(f).convert('RGB')
    w, h = im.size
    im = im.crop((0, int(h * 0.12), w, int(h * 0.12) + int(w * 300 / 270))).resize((tw, th))
    out.paste(im, ((i % cols) * tw, (i // cols) * th))
out.save(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs/acceptance/roster.png'))
print(len(files))
