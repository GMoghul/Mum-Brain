"""Render the Mum Brain "brain in rows" icon at several sizes (no SVG renderer needed)."""
import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
BG = (241, 237, 251)
LILAC, BLUE, TEAL = (201, 184, 238), (169, 198, 242), (191, 227, 224)

# Outline in a 100x100 box: start point, then cubic segments (c1, c2, end) or lines (end,)
START = (24, 58)
SEGS = [
    ((16, 54), (16, 44), (24, 40.5)), ((24, 30), (34, 22), (42, 25)), ((47, 18), (60, 18), (64, 25)),
    ((74, 23), (82, 31), (80, 40)), ((87, 44), (86, 54), (79, 56.5)), ((78, 64), (72, 69), (67, 68)),
    ((66, 70), (66, 73), (68, 76)), ((69.5, 78), (68, 80), (66, 79)), ((61, 77), (58, 73), (57, 69)),
    ((50, 70), (42, 70), (36, 68)), ((28, 69), (22, 64), (24, 58)),
]
BANDS = [(0, 39, LILAC), (42, 55, BLUE), (58, 100, TEAL)]


def outline(scale, steps=80):
    pts, p0 = [], START
    for c1, c2, p3 in SEGS:
        for i in range(1, steps + 1):
            t = i / steps; u = 1 - t
            x = u**3*p0[0] + 3*u*u*t*c1[0] + 3*u*t*t*c2[0] + t**3*p3[0]
            y = u**3*p0[1] + 3*u*u*t*c1[1] + 3*u*t*t*c2[1] + t**3*p3[1]
            pts.append((x*scale, y*scale))
        p0 = p3
    return pts


def render(size, ss=4):
    big = size * ss; k = big / 100
    img = Image.new("RGB", (big, big), BG)
    bands = Image.new("RGB", (big, big), BG)
    d = ImageDraw.Draw(bands)
    for y0, y1, col in BANDS:
        d.rectangle([0, y0*k, big, y1*k], fill=col)
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).polygon(outline(k), fill=255)
    img.paste(bands, (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)


for s in (1024, 512, 192, 180):
    render(s).save(f"{OUT}/icon-{s}.png", optimize=True)
print("done")
