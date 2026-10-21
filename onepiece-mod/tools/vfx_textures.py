"""Effect textures: glows, slashes, rings, fire flipbook, clouds, impact stars, limbs and props."""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

BASE = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece', 'textures')
VFX = os.path.join(BASE, 'vfx')
os.makedirs(VFX, exist_ok=True)
rnd = random.Random(7)


def save(img, name, folder=VFX):
    img.save(os.path.join(folder, name + '.png'))


def clamp(x):
    return max(0, min(255, int(x)))


def radial(size, power=2.0):
    img = Image.new('RGBA', (size, size))
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = max(0.0, 1.0 - d) ** power
            img.putpixel((x, y), (255, 255, 255, clamp(a * 255)))
    return img


def noise2(w, h, scale, seed):
    r = random.Random(seed)
    gw, gh = int(w / scale) + 2, int(h / scale) + 2
    grid = [[r.random() for _ in range(gw)] for _ in range(gh)]
    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            fx, fy = x / scale, y / scale
            x0, y0 = int(fx), int(fy)
            tx, ty = fx - x0, fy - y0
            tx = tx * tx * (3 - 2 * tx)
            ty = ty * ty * (3 - 2 * ty)
            a = grid[y0][x0] * (1 - tx) + grid[y0][x0 + 1] * tx
            b = grid[y0 + 1][x0] * (1 - tx) + grid[y0 + 1][x0 + 1] * tx
            out[y][x] = a * (1 - ty) + b * ty
    return out


def fbm(w, h, seed, octaves=4, base=16.0):
    total = [[0.0] * w for _ in range(h)]
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        n = noise2(w, h, base / (2 ** o), seed + o * 31)
        for y in range(h):
            for x in range(w):
                total[y][x] += n[y][x] * amp
        norm += amp
        amp *= 0.5
    return [[v / norm for v in row] for row in total]


def glow():
    save(radial(64, 1.8), 'glow')


def beam():
    w, h = 16, 32
    img = Image.new('RGBA', (w, h))
    for y in range(h):
        v = y / (h - 1)
        a = math.exp(-((v - 0.5) / 0.22) ** 2)
        core = math.exp(-((v - 0.5) / 0.08) ** 2)
        for x in range(w):
            c = 215 + 40 * core
            img.putpixel((x, y), (clamp(c), clamp(c), clamp(c), clamp(a * 255)))
    save(img, 'beam')


def white():
    save(Image.new('RGBA', (16, 16), (255, 255, 255, 255)), 'white')


def slash():
    w, h = 128, 32
    img = Image.new('RGBA', (w, h))
    n = fbm(w, h, 3, 3, 8.0)
    for y in range(h):
        for x in range(w):
            u = x / (w - 1)
            v = y / (h - 1)
            ends = math.sin(u * math.pi) ** 0.6
            core = math.exp(-((v - 0.12) / 0.12) ** 2)
            tail = (1 - v) ** 2.2 * 0.75
            streak = 0.75 + 0.25 * n[y][x]
            a = max(core, tail) * ends * streak
            whiteness = 200 + 55 * core
            img.putpixel((x, y), (clamp(whiteness), clamp(whiteness), clamp(whiteness), clamp(a * 255)))
    save(img, 'slash')


def band():
    s = 64
    img = Image.new('RGBA', (s, s))
    for y in range(s):
        for x in range(s):
            t = (x + y) / (2 * (s - 1))
            a = math.exp(-((t - 0.78) / 0.18) ** 2) + 0.25 * t
            img.putpixel((x, y), (255, 255, 255, clamp(min(1.0, a) * 255)))
    save(img, 'band')


def fire():
    fw, fh, frames = 32, 32, 8
    img = Image.new('RGBA', (fw * frames, fh))
    for f in range(frames):
        n = fbm(fw, fh * 2, 100 + f * 7, 4, 7.0)
        m = fbm(fw, fh * 2, 300 + f * 11, 3, 4.0)
        life = f / (frames - 1)
        size = 0.7 + 0.3 * math.sin(min(1.0, life * 1.6) * math.pi / 2)
        fade = 1.0 - max(0.0, life - 0.55) / 0.45
        for y in range(fh):
            for x in range(fw):
                nx = (x - fw / 2 + 0.5) / (fw / 2)
                ny = (fh - 1 - y) / (fh - 1)
                turb = n[(y + f * 4) % (fh * 2)][x] - 0.5
                width = (1 - ny) ** 0.45 * size * (1.0 + 0.25 * math.sin(ny * 6 + f))
                d = abs(nx + turb * 0.7 * ny) / max(0.01, width)
                tongue = m[(y + f * 5) % (fh * 2)][x]
                body = max(0.0, 1 - d ** 1.6) * (1 - ny ** 2.2)
                body *= 0.55 + 0.75 * tongue
                a = min(1.0, body * 1.9) * fade
                core = max(0.0, 1 - d * 1.6) * (1 - ny) ** 0.8
                c = 175 + 80 * min(1.0, core * 1.6)
                img.putpixel((f * fw + x, y), (clamp(c), clamp(c * 0.96), clamp(c * 0.88), clamp(a * 255)))
    save(img, 'fire')


def cloud():
    s = 64
    big = Image.new('RGBA', (s * 4, s * 4))
    d = ImageDraw.Draw(big)
    blobs = [(0.5, 0.55, 0.3), (0.32, 0.6, 0.22), (0.68, 0.6, 0.22), (0.42, 0.42, 0.2), (0.6, 0.4, 0.18), (0.5, 0.7, 0.24)]
    for bx, by, br in blobs:
        r = br * s * 4
        d.ellipse((bx * s * 4 - r, by * s * 4 - r, bx * s * 4 + r, by * s * 4 + r), fill=(255, 255, 255, 255))
    big = big.filter(ImageFilter.GaussianBlur(10))
    img = big.resize((s, s), Image.LANCZOS)
    px = img.load()
    for y in range(s):
        for x in range(s):
            r, g, b, a = px[x, y]
            shadeval = 1.0 - 0.22 * (y / s)
            px[x, y] = (clamp(255 * shadeval), clamp(255 * shadeval), clamp(258 * shadeval), a)
    save(img, 'cloud')


def impact():
    s = 64
    big = Image.new('RGBA', (s * 4, s * 4))
    d = ImageDraw.Draw(big)
    cx = cy = s * 2
    pts = []
    spikes = 12
    for i in range(spikes * 2):
        ang = i / (spikes * 2) * math.tau
        r = (s * 1.9 if i % 2 == 0 else s * 0.75) * (0.85 + 0.3 * rnd.random())
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    d.polygon(pts, fill=(255, 255, 255, 235))
    inner = [(cx + (x - cx) * 0.55, cy + (y - cy) * 0.55) for x, y in pts]
    d.polygon(inner, fill=(255, 255, 255, 255))
    big = big.filter(ImageFilter.GaussianBlur(2))
    save(big.resize((s, s), Image.LANCZOS), 'impact')


def wind():
    w, h = 64, 64
    img = Image.new('RGBA', (w, h))
    n = fbm(w, h, 55, 3, 6.0)
    for y in range(h):
        for x in range(w):
            v = y / (h - 1)
            streak = n[y][(x * 3) % w]
            a = (math.sin(v * math.pi) ** 1.5) * (0.35 + 0.65 * streak ** 2)
            img.putpixel((x, y), (255, 255, 255, clamp(a * 255)))
    save(img, 'wind')


def tube_tex(name, base, edge, line=None, gloss=None, size=16):
    img = Image.new('RGBA', (size, size))
    for y in range(size):
        for x in range(size):
            # Lighting comes from the round tube's normals, so keep the colour even (no baked edges).
            u = x / (size - 1)
            f = 0.96 + 0.06 * math.sin(u * math.pi * 4 + y * 0.4)
            c = [base[i] * f for i in range(3)]
            if line and (y % 8 == 3) and 2 < x < size - 3:
                c = [c[i] * 0.88 for i in range(3)]
            if gloss and abs(u - 0.35) < 0.08:
                c = [c[i] * 0.5 + gloss[i] * 0.5 for i in range(3)]
            img.putpixel((x, y), (clamp(c[0]), clamp(c[1]), clamp(c[2]), 255))
    save(img, name)


def fist_tex(name, base, dark, gloss=None, size=16):
    img = Image.new('RGBA', (size, size))
    for y in range(size):
        for x in range(size):
            u, v = x / (size - 1), y / (size - 1)
            f = 0.8 + 0.3 * math.sin(u * math.pi) * math.sin(v * math.pi)
            c = [base[i] * f for i in range(3)]
            # finger grooves
            if x in (4, 8, 12) and 3 < y < 13:
                c = [dark[i] for i in range(3)]
            if y in (5, 6) and 2 < x < 14:
                c = [c[i] * 1.12 for i in range(3)]
            if gloss and (x + y) % 7 == 0:
                c = [gloss[i] for i in range(3)]
            img.putpixel((x, y), (clamp(c[0]), clamp(c[1]), clamp(c[2]), 255))
    save(img, name)


def foot_tex(name, base, strap):
    img = Image.new('RGBA', (16, 16))
    for y in range(16):
        for x in range(16):
            c = base
            if y in (4, 5) or (x in (7, 8) and y < 8) or y >= 13:
                c = strap
            f = 0.85 + 0.2 * math.sin(x / 15 * math.pi)
            img.putpixel((x, y), (clamp(c[0] * f), clamp(c[1] * f), clamp(c[2] * f), 255))
    save(img, name)


def limbs():
    looks = {
        'skin': ((242, 192, 148), (150, 90, 60), None),
        'haki': ((26, 18, 30), (0, 0, 0), (150, 80, 220)),
        'gear5': ((250, 236, 214), (200, 170, 150), None),
        'gear2': ((240, 140, 124), (160, 60, 60), None),
        'gear4': ((30, 20, 24), (0, 0, 0), (220, 50, 70)),
        'mochi': ((248, 236, 240), (200, 170, 190), None),
    }
    for name, (base, edge, gloss) in looks.items():
        tube_tex('arm_' + name, base, edge, line=True, gloss=gloss)
        tube_tex('leg_' + name, base, edge, line=True, gloss=gloss)
        fist_tex('fist_' + name, base, tuple(int(c * 0.6) for c in base), gloss)
        foot_tex('foot_' + name, base, (110, 70, 40) if name in ('skin', 'gear2', 'gear5') else tuple(int(c * 0.5) for c in base))


def straw():
    img = Image.new('RGBA', (32, 32))
    for y in range(32):
        for x in range(32):
            weave = ((x // 4) + (y // 4)) % 2
            stripe = (y if weave else x) % 4
            base = (232, 196, 110) if weave else (214, 176, 92)
            f = 1.0 - 0.12 * (stripe == 0) + 0.06 * (stripe == 2)
            img.putpixel((x, y), (clamp(base[0] * f), clamp(base[1] * f), clamp(base[2] * f), 255))
    save(img, 'straw')


def simple_pattern(name, fn, size=16):
    img = Image.new('RGBA', (size, size))
    for y in range(size):
        for x in range(size):
            img.putpixel((x, y), fn(x, y))
    save(img, name)


def props():
    simple_pattern('horn', lambda x, y: (clamp(236 - y * 4 - (x % 4 == 0) * 18), clamp(226 - y * 5 - (x % 4 == 0) * 18), clamp(206 - y * 6), 255))
    simple_pattern('club', lambda x, y: (60, 56, 70, 255) if (x * 3 + y * 5) % 11 else (120, 112, 130, 255))
    simple_pattern('scarf', lambda x, y: (clamp(170 - (x + y) % 3 * 18 + (y % 4 == 0) * 20), clamp(60 - (x + y) % 3 * 6), clamp(100 - (x + y) % 3 * 10), 255))
    spots = [(2, 2), (9, 3), (14, 9), (5, 9), (11, 14), (1, 13)]
    def fur(x, y):
        for sx, sy in spots:
            dx = min(abs(x - sx), 16 - abs(x - sx))
            dy = min(abs(y - sy), 16 - abs(y - sy))
            d = dx * dx + dy * dy
            if d <= 1:
                return (150, 96, 34, 255)
            if d <= 3:
                return (36, 24, 14, 255)
        return (clamp(232 - (y % 3) * 6), clamp(162 - (y % 3) * 5), 52, 255)
    simple_pattern('fur', fur)
    def scales(x, y):
        row = y // 4
        xx = (x + (row % 2) * 2) % 4
        yy = y % 4
        edge = yy == 3 or (xx == 0 and yy > 1)
        c = (58, 98, 216) if not edge else (30, 50, 140)
        if yy == 0 and xx in (1, 2):
            c = (110, 150, 240)
        return c + (255,)
    simple_pattern('dragon_scales', scales)
    simple_pattern('dragon_belly', lambda x, y: (238, 226, 196, 255) if y % 4 != 3 else (190, 170, 140, 255))
    # Wispy mane strands.
    img = Image.new('RGBA', (32, 32))
    for x in range(32):
        phase = rnd.random() * 6
        for y in range(32):
            wave = math.sin(y * 0.3 + phase) * 1.5
            d = abs((x % 8) - 4 - wave)
            a = max(0.0, 1 - d / 3) * (1 - y / 40)
            img.putpixel((x, y), (235, 240, 255, clamp(a * 255)))
    save(img, 'mane')


def haki_overlay():
    from skinlib import LAYOUT
    img = Image.new('RGBA', (64, 64))
    for part in ('rarm', 'larm', 'rleg', 'lleg'):
        for face, (x, y, w, h) in LAYOUT[part].items():
            for v in range(h):
                for u in range(w):
                    sheen = 0.5 + 0.5 * math.sin((u + v * 0.6) * 1.3)
                    c = (int(18 + 40 * sheen), int(10 + 14 * sheen), int(26 + 70 * sheen), 245)
                    if part in ('rarm', 'larm') and v < 3 and face not in ('top', 'bottom'):
                        c = c[:3] + (int(245 * v / 3),)
                    img.putpixel((x + u, y + v), c)
    out = os.path.join(BASE, 'entity')
    os.makedirs(out, exist_ok=True)
    img.save(os.path.join(out, 'haki_overlay.png'))


if __name__ == '__main__':
    glow(); beam(); white(); slash(); band(); fire(); cloud(); impact(); wind(); limbs(); straw(); props(); haki_overlay()
    print('vfx done')


def cracks():
    """Ground crack decal: dark branching fissures radiating from the centre."""
    import random
    S = 128
    k = 2
    img = Image.new('RGBA', (S * k, S * k))
    d = ImageDraw.Draw(img)
    r = random.Random(21)
    c = S * k / 2

    def branch(x, y, ang, length, width, depth):
        if depth > 4 or length < 4:
            return
        steps = int(length / 6)
        for i in range(steps):
            ang += (r.random() - 0.5) * 0.6
            nx, ny = x + math.cos(ang) * 6, y + math.sin(ang) * 6
            d.line((x, y, nx, ny), fill=(20, 14, 10, 230), width=max(1, int(width)))
            x, y = nx, ny
            width *= 0.97
            if r.random() < 0.08:
                branch(x, y, ang + (r.random() - 0.5) * 1.6, length * 0.5, width * 0.7, depth + 1)
    for i in range(9):
        a = i / 9 * math.tau + r.random() * 0.4
        branch(c, c, a, c * (0.6 + r.random() * 0.35), 7 * k / 2, 0)
    d.ellipse((c - 14 * k, c - 14 * k, c + 14 * k, c + 14 * k), fill=(24, 16, 12, 200))
    img = img.filter(ImageFilter.GaussianBlur(0.6 * k))
    img.resize((S, S), Image.LANCZOS).save(os.path.join(VFX, 'cracks.png'))


if __name__ == '__main__':
    cracks()
