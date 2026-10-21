"""
Tiny pixel-art toolkit for 64x64 Minecraft player skins.

Each body part is painted with a function paint(face, u, v, w, h) -> RGBA or None,
called for every pixel of each face in the standard skin layout.
"""
from PIL import Image
import random

# (x, y, w, h) of each face for the base layer of each part, wide arms.
LAYOUT = {
    'head':  {'top': (8, 0, 8, 8), 'bottom': (16, 0, 8, 8), 'right': (0, 8, 8, 8), 'front': (8, 8, 8, 8), 'left': (16, 8, 8, 8), 'back': (24, 8, 8, 8)},
    'body':  {'top': (20, 16, 8, 4), 'bottom': (28, 16, 8, 4), 'right': (16, 20, 4, 12), 'front': (20, 20, 8, 12), 'left': (28, 20, 4, 12), 'back': (32, 20, 8, 12)},
    'rarm':  {'top': (44, 16, 4, 4), 'bottom': (48, 16, 4, 4), 'right': (40, 20, 4, 12), 'front': (44, 20, 4, 12), 'left': (48, 20, 4, 12), 'back': (52, 20, 4, 12)},
    'larm':  {'top': (36, 48, 4, 4), 'bottom': (40, 48, 4, 4), 'right': (32, 52, 4, 12), 'front': (36, 52, 4, 12), 'left': (40, 52, 4, 12), 'back': (44, 52, 4, 12)},
    'rleg':  {'top': (4, 16, 4, 4), 'bottom': (8, 16, 4, 4), 'right': (0, 20, 4, 12), 'front': (4, 20, 4, 12), 'left': (8, 20, 4, 12), 'back': (12, 20, 4, 12)},
    'lleg':  {'top': (20, 48, 4, 4), 'bottom': (24, 48, 4, 4), 'right': (16, 52, 4, 12), 'front': (20, 52, 4, 12), 'left': (24, 52, 4, 12), 'back': (28, 52, 4, 12)},
}
OVERLAY = {'head': (32, 0), 'body': (0, 16), 'rarm': (0, 16), 'larm': (16, 0), 'rleg': (0, 16), 'lleg': (-16, 0)}


def rgb(hexv, a=255):
    return ((hexv >> 16) & 255, (hexv >> 8) & 255, hexv & 255, a)


def shade(c, f):
    r, g, b, a = c
    if f >= 1:
        return (min(255, int(r + (255 - r) * (f - 1))), min(255, int(g + (255 - g) * (f - 1))), min(255, int(b + (255 - b) * (f - 1))), a)
    return (int(r * f), int(g * f), int(b * f), a)


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


class Skin:
    def __init__(self, seed=1):
        self.img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        self.rand = random.Random(seed)

    def paint(self, part, fn, overlay=False):
        ox, oy = OVERLAY[part] if overlay else (0, 0)
        for face, (x, y, w, h) in LAYOUT[part].items():
            for v in range(h):
                for u in range(w):
                    c = fn(face, u, v, w, h)
                    if c is not None:
                        self.img.putpixel((x + ox + u, y + oy + v), c)

    def px(self, part, face, u, v, c, overlay=False):
        ox, oy = OVERLAY[part] if overlay else (0, 0)
        x, y, w, h = LAYOUT[part][face]
        if 0 <= u < w and 0 <= v < h:
            self.img.putpixel((x + ox + u, y + oy + v), c)

    def noise(self, c, amt=0.06):
        f = 1 + (self.rand.random() - 0.5) * 2 * amt
        return shade(c, f)

    def save(self, path):
        self.img.save(path)


def side_shade(face, u, v, w, h):
    """Soft directional lighting factor so flat colours look rounded."""
    f = 1.0
    if face == 'top':
        f = 1.12
    elif face == 'bottom':
        f = 0.72
    elif face == 'back':
        f = 0.86
    elif face in ('right', 'left'):
        f = 0.93
    if face not in ('top', 'bottom'):
        f *= 1.04 - 0.1 * (v / max(1, h - 1))
        if u == 0 or u == w - 1:
            f *= 0.94
    return f
