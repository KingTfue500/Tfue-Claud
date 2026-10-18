"""Builds a flat front + back preview of skins, scaled up, to eyeball the pixel art."""
import sys
from PIL import Image
from skinlib import LAYOUT, OVERLAY


def crop(img, part, face, overlay=False):
    x, y, w, h = LAYOUT[part][face]
    if overlay:
        ox, oy = OVERLAY[part]
        x, y = x + ox, y + oy
    return img.crop((x, y, x + w, y + h))


def figure(img, back=False):
    canvas = Image.new('RGBA', (16, 32), (60, 70, 90, 255))
    f = 'back' if back else 'front'
    parts = [('head', 4, 0), ('body', 4, 8), ('rarm', 0, 8), ('larm', 12, 8), ('rleg', 4, 20), ('lleg', 8, 20)]
    if back:
        parts = [('head', 4, 0), ('body', 4, 8), ('larm', 0, 8), ('rarm', 12, 8), ('lleg', 4, 20), ('rleg', 8, 20)]
    for part, x, y in parts:
        for ov in (False, True):
            c = crop(img, part, f, ov)
            canvas.alpha_composite(c, (x, y))
    return canvas


def sheet(paths, out, scale=6):
    figs = []
    for p in paths:
        img = Image.open(p).convert('RGBA')
        figs.append(figure(img))
        figs.append(figure(img, True))
    w = len(figs) * 18
    canvas = Image.new('RGBA', (w, 34), (40, 44, 56, 255))
    for i, fimg in enumerate(figs):
        canvas.alpha_composite(fimg, (i * 18 + 1, 1))
    canvas = canvas.resize((w * scale, 34 * scale), Image.NEAREST)
    canvas.save(out)


if __name__ == '__main__':
    sheet(sys.argv[2:], sys.argv[1])
