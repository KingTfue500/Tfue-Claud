"""GUI art: skill wheel, slots, HUD frame, stamina bar, skill icons, form badges, crew emblems, Haki icons."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

BASE = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece', 'textures', 'gui')
for sub in ('', 'icons', 'forms', 'emblems', 'haki'):
    os.makedirs(os.path.join(BASE, sub), exist_ok=True)

GOLD = (232, 186, 74, 255)
GOLD_DARK = (150, 104, 30, 255)
NAVY = (14, 20, 38, 230)
NAVY2 = (26, 36, 64, 235)


def ss(size, k=4):
    img = Image.new('RGBA', (size * k, size * k))
    return img, ImageDraw.Draw(img), k


def finish(img, size, path, blur=0):
    if blur:
        img = img.filter(ImageFilter.GaussianBlur(blur))
    img.resize((size, size) if isinstance(size, int) else size, Image.LANCZOS).save(path)


def circle(d, cx, cy, r, **kw):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), **kw)


# ---------------------------------------------------------------- frames
def wheel_ring():
    S = 512
    img, d, k = ss(S, 2)
    c = S * k / 2
    circle(d, c, c, 250 * k, fill=(8, 12, 24, 150))
    circle(d, c, c, 246 * k, outline=GOLD, width=5 * k)
    circle(d, c, c, 236 * k, outline=GOLD_DARK, width=2 * k)
    circle(d, c, c, 150 * k, outline=GOLD_DARK, width=2 * k)
    circle(d, c, c, 140 * k, fill=(0, 0, 0, 0))
    # Compass ticks and rope knots.
    for i in range(72):
        a = i / 72 * math.tau
        r0, r1 = (226 if i % 6 else 214) * k, 236 * k
        d.line((c + math.cos(a) * r0, c + math.sin(a) * r0, c + math.cos(a) * r1, c + math.sin(a) * r1), fill=GOLD if i % 6 == 0 else GOLD_DARK, width=2 * k)
    for i in range(8):
        a = i / 8 * math.tau + math.pi / 8
        circle(d, c + math.cos(a) * 246 * k, c + math.sin(a) * 246 * k, 8 * k, fill=GOLD, outline=GOLD_DARK, width=2 * k)
    # punch out the middle
    mask = Image.new('L', img.size, 255)
    ImageDraw.Draw(mask).ellipse((c - 140 * k, c - 140 * k, c + 140 * k, c + 140 * k), fill=0)
    img.putalpha(Image.composite(img.getchannel('A'), Image.new('L', img.size, 0), mask))
    finish(img, S, os.path.join(BASE, 'wheel_ring.png'))


def wheel_center():
    S = 256
    img, d, k = ss(S, 2)
    c = S * k / 2
    circle(d, c, c, 124 * k, fill=(10, 14, 28, 235), outline=GOLD, width=5 * k)
    circle(d, c, c, 112 * k, outline=GOLD_DARK, width=2 * k)
    for i in range(16):
        a = i / 16 * math.tau
        d.line((c + math.cos(a) * 100 * k, c + math.sin(a) * 100 * k, c + math.cos(a) * 110 * k, c + math.sin(a) * 110 * k), fill=GOLD_DARK, width=2 * k)
    finish(img, S, os.path.join(BASE, 'wheel_center.png'))


def slots():
    S = 128
    img, d, k = ss(S)
    c = S * k / 2
    circle(d, c, c, 60 * k, fill=(12, 18, 34, 235), outline=GOLD, width=5 * k)
    circle(d, c, c, 50 * k, outline=(70, 80, 110, 255), width=2 * k)
    finish(img, S, os.path.join(BASE, 'slot.png'))
    img, d, k = ss(S)
    glow = Image.new('RGBA', img.size)
    gd = ImageDraw.Draw(glow)
    circle(gd, c, c, 62 * k, fill=(255, 255, 255, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(6 * k))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    circle(d, c, c, 58 * k, fill=(40, 40, 50, 240), outline=(255, 255, 255, 255), width=6 * k)
    circle(d, c, c, 48 * k, outline=(200, 200, 210, 255), width=2 * k)
    finish(img, S, os.path.join(BASE, 'slot_hover.png'))


def hud_frame():
    W, H = 512, 160
    k = 2
    img = Image.new('RGBA', (W * k, H * k))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((4 * k, 4 * k, (W - 4) * k, (H - 4) * k), radius=26 * k, fill=(10, 14, 28, 205), outline=GOLD, width=5 * k)
    d.rounded_rectangle((14 * k, 14 * k, (W - 14) * k, (H - 14) * k), radius=18 * k, outline=GOLD_DARK, width=2 * k)
    # sea waves along the bottom
    for x in range(20, W - 20, 4):
        y = H - 30 + math.sin(x * 0.08) * 6
        d.ellipse(((x - 1.5) * k, (y - 1.5) * k, (x + 1.5) * k, (y + 1.5) * k), fill=(40, 80, 140, 120))
    img.resize((W, H), Image.LANCZOS).save(os.path.join(BASE, 'hud_frame.png'))


def stamina_bar():
    W, H = 256, 32
    k = 2
    img = Image.new('RGBA', (W * k, H * k))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2 * k, 2 * k, (W - 2) * k, (H - 2) * k), radius=13 * k, fill=(255, 255, 255, 255))
    for y in range(H * k):
        f = 1.15 - 0.5 * (y / (H * k))
        for x in range(W * k):
            r, g, b, a = img.getpixel((x, y))
            if a:
                v = max(0, min(255, int(230 * f)))
                img.putpixel((x, y), (v, v, v, a))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8 * k, 5 * k, (W - 8) * k, 11 * k), radius=3 * k, fill=(255, 255, 255, 200))
    img.resize((W, H), Image.LANCZOS).save(os.path.join(BASE, 'stamina_bar.png'))


# ---------------------------------------------------------------- icons
OUTLINE = (12, 12, 18, 255)
FILL = (255, 255, 255, 255)


def icon(name, draw_fn):
    S = 64
    k = 4
    img = Image.new('RGBA', (S * k, S * k))
    d = ImageDraw.Draw(img)
    draw_fn(d, k)
    # dark outline around the white silhouette so it reads on any tint
    alpha = img.getchannel('A')
    outline = alpha.filter(ImageFilter.MaxFilter(13))
    base = Image.new('RGBA', img.size, OUTLINE)
    base.putalpha(outline)
    base.alpha_composite(img)
    base.resize((S, S), Image.LANCZOS).save(os.path.join(BASE, 'icons', name + '.png'))


def P(k, *pts):
    return [(x * k, y * k) for x, y in pts]


def fist(d, k, cx, cy, s, fill=FILL):
    d.rounded_rectangle(((cx - 10 * s) * k, (cy - 9 * s) * k, (cx + 10 * s) * k, (cy + 9 * s) * k), radius=5 * s * k, fill=fill)
    for i in range(3):
        x = cx - 5 * s + i * 5 * s
        d.line((x * k, (cy - 8 * s) * k, x * k, (cy - 1 * s) * k), fill=(60, 60, 70, 255), width=max(1, int(1.5 * s * k)))
    d.rounded_rectangle(((cx - 12 * s) * k, (cy - 2 * s) * k, (cx - 6 * s) * k, (cy + 6 * s) * k), radius=3 * s * k, fill=fill)


def speed_lines(d, k, x0, x1, ys, w=3):
    for y in ys:
        d.line((x0 * k, y * k, x1 * k, y * k), fill=FILL, width=w * k)


def flame(d, k, cx, by, w, h):
    pts = []
    for i in range(21):
        t = i / 20
        a = t * math.pi
        x = cx - math.cos(a) * w
        y = by - math.sin(a) * h * (0.4 + 0.6 * abs(math.sin(t * 5))) - (h * 0.6 if 0.4 < t < 0.6 else 0)
        pts.append((x * k, y * k))
    pts.append((cx * k, (by - h * 1.3) * k))
    d.polygon(pts, fill=FILL)


def leg(d, k, x0, y0, x1, y1, w=8):
    d.line((x0 * k, y0 * k, x1 * k, y1 * k), fill=FILL, width=w * k)
    circle(d, x1 * k, y1 * k, w * 0.8 * k, fill=FILL)


def make_icons():
    icon('fist', lambda d, k: (fist(d, k, 38, 32, 1.3), speed_lines(d, k, 4, 18, (24, 32, 40))))
    def gatling(d, k):
        for (x, y, s) in ((20, 18, 0.7), (44, 20, 0.7), (30, 34, 0.85), (16, 46, 0.65), (46, 46, 0.7)):
            fist(d, k, x, y, s)
    icon('gatling', gatling)
    icon('giant_fist', lambda d, k: (fist(d, k, 34, 32, 2.0), speed_lines(d, k, 2, 8, (16, 32, 48), 4)))
    def palms(d, k):
        for y in (20, 44):
            d.rounded_rectangle((20 * k, (y - 9) * k, 50 * k, (y + 9) * k), radius=6 * k, fill=FILL)
        speed_lines(d, k, 2, 14, (20, 32, 44))
    icon('palms', palms)
    def rocket(d, k):
        d.polygon(P(k, (32, 4), (52, 30), (40, 30), (40, 58), (24, 58), (24, 30), (12, 30)), fill=FILL)
    icon('rocket', rocket)
    def whip(d, k):
        d.arc((6 * k, 10 * k, 58 * k, 58 * k), 200, 340, fill=FILL, width=9 * k)
        circle(d, 52 * k, 26 * k, 7 * k, fill=FILL)
    icon('whip', whip)
    def balloon(d, k):
        circle(d, 32 * k, 34 * k, 24 * k, fill=FILL)
        circle(d, 24 * k, 26 * k, 5 * k, fill=(200, 200, 210, 255))
    icon('balloon', balloon)
    def dash(d, k):
        d.polygon(P(k, (30, 14), (56, 32), (30, 50), (34, 36), (8, 36), (8, 28), (34, 28)), fill=FILL)
        speed_lines(d, k, 2, 20, (18, 46), 3)
    icon('dash', dash)
    def stomp(d, k):
        d.rounded_rectangle((18 * k, 6 * k, 40 * k, 40 * k), radius=6 * k, fill=FILL)
        d.rounded_rectangle((14 * k, 34 * k, 50 * k, 46 * k), radius=5 * k, fill=FILL)
        d.line((4 * k, 56 * k, 60 * k, 56 * k), fill=FILL, width=4 * k)
        for x in (12, 32, 52):
            d.line((x * k, 56 * k, (x - 6) * k, 62 * k), fill=FILL, width=3 * k)
    icon('stomp', stomp)
    icon('fire_fist', lambda d, k: (flame(d, k, 24, 56, 18, 30), fist(d, k, 40, 34, 1.1)))
    icon('lightning', lambda d, k: d.polygon(P(k, (38, 2), (14, 36), (30, 36), (22, 62), (50, 24), (34, 24), (44, 2)), fill=FILL))
    def cloud(d, k):
        for x, y, r in ((22, 36, 13), (36, 30, 15), (48, 38, 11), (32, 42, 13)):
            circle(d, x * k, y * k, r * k, fill=FILL)
    icon('cloud', cloud)
    def giant(d, k):
        circle(d, 32 * k, 14 * k, 9 * k, fill=FILL)
        d.rounded_rectangle((18 * k, 24 * k, 46 * k, 46 * k), radius=6 * k, fill=FILL)
        d.rectangle((20 * k, 44 * k, 29 * k, 62 * k), fill=FILL)
        d.rectangle((35 * k, 44 * k, 44 * k, 62 * k), fill=FILL)
        d.line((6 * k, 4 * k, 6 * k, 60 * k), fill=FILL, width=3 * k)
        d.line((2 * k, 8 * k, 10 * k, 4 * k), fill=FILL, width=3 * k)
    icon('giant', giant)
    def snake(d, k):
        pts = [((8 + i * 2.4) * k, (32 + math.sin(i * 0.45) * 16) * k) for i in range(20)]
        d.line(pts, fill=FILL, width=8 * k, joint='curve')
        fist(d, k, 54, 32 + math.sin(19 * 0.45) * 16, 0.6)
    icon('snake', snake)
    icon('slash', lambda d, k: d.polygon(P(k, (6, 58), (54, 4), (60, 8), (14, 60)), fill=FILL))
    def slash_wave(d, k):
        d.chord((4 * k, 6 * k, 56 * k, 58 * k), 290, 70, fill=FILL)
        d.chord((-4 * k, 10 * k, 48 * k, 54 * k), 290, 70, fill=(0, 0, 0, 0))
    icon('slash_wave', slash_wave)
    def tornado(d, k):
        for i in range(6):
            w = 26 - i * 4
            y = 8 + i * 9
            d.arc(((32 - w) * k, (y - 4) * k, (32 + w) * k, (y + 4) * k), 0, 360, fill=FILL, width=5 * k)
    icon('tornado', tornado)
    def xs(d, k):
        d.polygon(P(k, (4, 10), (10, 4), (60, 54), (54, 60)), fill=FILL)
        d.polygon(P(k, (54, 4), (60, 10), (10, 60), (4, 54)), fill=FILL)
    icon('x_slash', xs)
    def dragon(d, k):
        pts = [((6 + i * 2.6) * k, (46 - math.sin(i * 0.38) * 14 - i * 0.6) * k) for i in range(20)]
        d.line(pts, fill=FILL, width=9 * k, joint='curve')
        d.polygon(P(k, (50, 18), (62, 22), (54, 30), (46, 26)), fill=FILL)
        d.line((52 * k, 18 * k, 44 * k, 6 * k), fill=FILL, width=3 * k)
    icon('dragon', dragon)
    def spin_blades(d, k):
        for i in range(9):
            a = i / 9 * math.tau
            x0, y0 = 32 + math.cos(a) * 8, 32 + math.sin(a) * 8
            x1, y1 = 32 + math.cos(a + 0.3) * 28, 32 + math.sin(a + 0.3) * 28
            d.line((x0 * k, y0 * k, x1 * k, y1 * k), fill=FILL, width=4 * k)
    icon('spin_blades', spin_blades)
    icon('kick', lambda d, k: (leg(d, k, 14, 56, 30, 34), leg(d, k, 30, 34, 58, 16), speed_lines(d, k, 34, 50, (44,), 3)))
    def kick_spin(d, k):
        d.arc((8 * k, 8 * k, 56 * k, 56 * k), 0, 300, fill=FILL, width=6 * k)
        leg(d, k, 32, 32, 54, 12)
        leg(d, k, 32, 32, 10, 52)
    icon('kick_spin', kick_spin)
    def kick_down(d, k):
        leg(d, k, 32, 4, 32, 44, 9)
        d.polygon(P(k, (20, 46), (44, 46), (32, 60)), fill=FILL)
    icon('kick_down', kick_down)
    icon('fire_kick', lambda d, k: (flame(d, k, 36, 56, 20, 26), leg(d, k, 8, 58, 44, 22, 8)))
    def sky_walk(d, k):
        for (x, y) in ((16, 48), (32, 34), (48, 20)):
            d.ellipse(((x - 8) * k, (y - 5) * k, (x + 8) * k, (y + 5) * k), fill=FILL)
            d.arc(((x - 12) * k, (y + 2) * k, (x + 12) * k, (y + 12) * k), 20, 160, fill=FILL, width=2 * k)
    icon('sky_walk', sky_walk)
    def stealth(d, k):
        d.ellipse((6 * k, 18 * k, 58 * k, 46 * k), outline=FILL, width=5 * k)
        circle(d, 32 * k, 32 * k, 8 * k, fill=FILL)
        d.line((10 * k, 54 * k, 54 * k, 10 * k), fill=FILL, width=5 * k)
    icon('stealth', stealth)
    icon('shield', lambda d, k: d.polygon(P(k, (32, 4), (56, 12), (54, 36), (32, 60), (10, 36), (8, 12)), fill=FILL))
    def club(d, k):
        d.line((10 * k, 54 * k, 50 * k, 14 * k), fill=FILL, width=12 * k)
        for i in range(5):
            x, y = 26 + i * 6, 38 - i * 6
            for ox, oy in ((-7, -7), (7, 7)):
                circle(d, (x + ox) * k, (y + oy) * k, 3 * k, fill=FILL)
    icon('club', club)
    def breath(d, k):
        d.polygon(P(k, (6, 28), (6, 36), (58, 58), (62, 32), (58, 6)), fill=FILL)
    icon('breath', breath)
    def roar(d, k):
        for r in (10, 20, 30):
            d.arc(((32 - r) * k, (32 - r) * k, (32 + r) * k, (32 + r) * k), 300, 60, fill=FILL, width=4 * k)
            d.arc(((32 - r) * k, (32 - r) * k, (32 + r) * k, (32 + r) * k), 120, 240, fill=FILL, width=4 * k)
    icon('roar', roar)
    def mochi(d, k):
        d.ellipse((8 * k, 22 * k, 56 * k, 54 * k), fill=FILL)
        d.ellipse((18 * k, 10 * k, 46 * k, 34 * k), fill=FILL)
    icon('mochi', mochi)
    def trident(d, k):
        d.line((32 * k, 60 * k, 32 * k, 16 * k), fill=FILL, width=5 * k)
        d.line((16 * k, 20 * k, 48 * k, 20 * k), fill=FILL, width=5 * k)
        for x in (16, 32, 48):
            d.polygon(P(k, (x - 4, 20), (x + 4, 20), (x, 4)), fill=FILL)
    icon('trident', trident)
    def claw(d, k):
        for i in range(3):
            x = 16 + i * 14
            d.polygon(P(k, (x, 4), (x + 6, 6), (x - 6, 60), (x - 10, 58)), fill=FILL)
    icon('claw', claw)
    def finger(d, k):
        d.rounded_rectangle((26 * k, 30 * k, 50 * k, 56 * k), radius=6 * k, fill=FILL)
        d.rounded_rectangle((30 * k, 4 * k, 38 * k, 34 * k), radius=4 * k, fill=FILL)
        speed_lines(d, k, 6, 22, (10, 18), 2)
    icon('finger', finger)
    def pounce(d, k):
        circle(d, 32 * k, 40 * k, 14 * k, fill=FILL)
        for x, y in ((14, 22), (26, 12), (38, 12), (50, 22)):
            circle(d, x * k, y * k, 6 * k, fill=FILL)
    icon('pounce', pounce)


# ---------------------------------------------------------------- badges
def badge(path, color, draw_fn, size=64, ring=GOLD):
    k = 4
    img = Image.new('RGBA', (size * k, size * k))
    d = ImageDraw.Draw(img)
    c = size * k / 2
    r = size * k / 2 - 2 * k
    dark = tuple(int(x * 0.35) for x in color[:3]) + (255,)
    circle(d, c, c, r, fill=dark, outline=ring, width=3 * k)
    circle(d, c, c, r - 6 * k, outline=color, width=2 * k)
    draw_fn(d, k, size)
    img.resize((size, size), Image.LANCZOS).save(path)


def hexc(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255, 255)


FORMS = {
    'base_luffy': 0xE8332F, 'gear_2': 0xFF6B8A, 'gear_3': 0xFFA14A, 'gear_4_boundman': 0x9E1B32, 'gear_4_snakeman': 0xB0213D,
    'gear_4_tankman': 0x7A1530, 'gear_5': 0xF4F1E8, 'base_zoro': 0x3FBF5A, 'asura': 0x6E4AA8, 'king_of_hell': 0x8E2BD6,
    'base_sanji': 0xF2C744, 'diable_jambe': 0xFF5A1F, 'ifrit_jambe': 0x3FA9FF, 'raid_suit': 0x2E56C9,
    'base_kaido': 0x7A6BFF, 'kaido_hybrid': 0x4F8BFF, 'kaido_dragon': 0x3FC8FF, 'base_katakuri': 0xE0457E,
    'katakuri_awakened': 0xFFB8D8, 'base_lucci': 0xE8B030, 'lucci_hybrid': 0xF0C040, 'lucci_awakened': 0xFF4A30,
}

FORM_SYMBOL = {
    'base_luffy': 'hat', 'gear_2': 'steam', 'gear_3': 'fist', 'gear_4_boundman': 'muscle', 'gear_4_snakeman': 'snake',
    'gear_4_tankman': 'round', 'gear_5': 'sun', 'base_zoro': 'swords', 'asura': 'nine', 'king_of_hell': 'horns',
    'base_sanji': 'leg', 'diable_jambe': 'flame', 'ifrit_jambe': 'flame', 'raid_suit': 'three', 'base_kaido': 'club',
    'kaido_hybrid': 'horns', 'kaido_dragon': 'dragon', 'base_katakuri': 'donut', 'katakuri_awakened': 'mochi',
    'base_lucci': 'tophat', 'lucci_hybrid': 'paw', 'lucci_awakened': 'eyes',
}


def symbol(kind, color):
    W = (255, 255, 255, 255)

    def draw(d, k, size):
        def p(*pts):
            return [(x * k, y * k) for x, y in pts]
        if kind == 'hat':
            d.ellipse(p((10, 34), (54, 44)), fill=(232, 196, 110, 255))
            d.ellipse(p((20, 20), (44, 40)), fill=(232, 196, 110, 255))
            d.rectangle(p((20, 30), (44, 34)), fill=(200, 30, 40, 255))
        elif kind == 'steam':
            for x, y, r in ((24, 38, 9), (36, 30, 11), (30, 22, 7), (42, 42, 7)):
                circle(d, x * k, y * k, r * k, fill=W)
        elif kind == 'fist':
            fist(d, k, 32, 32, 1.2, fill=W)
        elif kind == 'muscle':
            d.ellipse(p((14, 18), (50, 46)), fill=(28, 20, 24, 255), outline=W, width=2 * k)
            d.arc(p((20, 22), (44, 40)), 200, 340, fill=(230, 60, 80, 255), width=3 * k)
        elif kind == 'snake':
            pts = [((14 + i * 1.9) * k, (32 + math.sin(i * 0.5) * 10) * k) for i in range(20)]
            d.line(pts, fill=W, width=6 * k, joint='curve')
        elif kind == 'round':
            circle(d, 32 * k, 34 * k, 16 * k, fill=W)
        elif kind == 'sun':
            for i in range(12):
                a = i / 12 * math.tau
                d.line((32 * k, 32 * k, (32 + math.cos(a) * 20) * k, (32 + math.sin(a) * 20) * k), fill=(255, 220, 120, 255), width=3 * k)
            circle(d, 32 * k, 32 * k, 11 * k, fill=W)
        elif kind == 'swords':
            for a in (-0.6, 0.0, 0.6):
                dx, dy = math.sin(a) * 20, math.cos(a) * 20
                d.line(((32 - dx) * k, (32 + dy) * k, (32 + dx) * k, (32 - dy) * k), fill=W, width=3 * k)
        elif kind == 'nine':
            for i in range(9):
                a = i / 9 * math.tau
                d.line((32 * k, 32 * k, (32 + math.cos(a) * 20) * k, (32 + math.sin(a) * 20) * k), fill=W, width=2 * k)
            circle(d, 32 * k, 32 * k, 6 * k, fill=W)
        elif kind == 'horns':
            d.polygon(p((18, 44), (14, 14), (26, 36)), fill=W)
            d.polygon(p((46, 44), (50, 14), (38, 36)), fill=W)
            circle(d, 32 * k, 40 * k, 8 * k, fill=W)
        elif kind == 'leg':
            leg(d, k, 18, 48, 46, 18, 7)
        elif kind == 'flame':
            flame(d, k, 32, 50, 14, 24)
        elif kind == 'three':
            circle(d, 32 * k, 32 * k, 14 * k, outline=W, width=3 * k)
            d.text((26 * k, 20 * k), '3', fill=W)
            d.line(p((26, 24), (38, 24), (30, 32), (38, 36), (30, 42)), fill=W, width=3 * k)
        elif kind == 'club':
            d.line(p((18, 46), (46, 18)), fill=W, width=7 * k)
        elif kind == 'dragon':
            pts = [((12 + i * 2.1) * k, (40 - math.sin(i * 0.45) * 10 - i * 0.4) * k) for i in range(20)]
            d.line(pts, fill=W, width=6 * k, joint='curve')
        elif kind == 'donut':
            circle(d, 32 * k, 32 * k, 16 * k, fill=(250, 210, 230, 255))
            circle(d, 32 * k, 32 * k, 6 * k, fill=(0, 0, 0, 0))
        elif kind == 'mochi':
            d.ellipse(p((14, 28), (50, 48)), fill=W)
            d.ellipse(p((22, 18), (42, 34)), fill=W)
        elif kind == 'tophat':
            d.rectangle(p((22, 16), (42, 40)), fill=(20, 20, 26, 255), outline=W, width=k)
            d.rectangle(p((14, 40), (50, 44)), fill=W)
        elif kind == 'paw':
            circle(d, 32 * k, 38 * k, 9 * k, fill=W)
            for x, y in ((20, 26), (28, 20), (36, 20), (44, 26)):
                circle(d, x * k, y * k, 4 * k, fill=W)
        elif kind == 'eyes':
            for x in (22, 42):
                d.ellipse(p((x - 7, 26), (x + 7, 36)), fill=(255, 60, 40, 255))
                d.line(p((x, 26), (x, 36)), fill=(20, 0, 0, 255), width=2 * k)
    return draw


def make_forms():
    for name, col in FORMS.items():
        badge(os.path.join(BASE, 'forms', name + '.png'), hexc(col), symbol(FORM_SYMBOL[name], hexc(col)))


def jolly(d, k, size, extra):
    W = (245, 245, 240, 255)
    B = (10, 10, 14, 255)
    s = size / 128
    def p(*pts):
        return [(x * s * k, y * s * k) for x, y in pts]
    # crossbones
    d.line(p((30, 96), (98, 40)), fill=W, width=int(10 * s * k))
    d.line(p((30, 40), (98, 96)), fill=W, width=int(10 * s * k))
    for x, y in ((28, 98), (100, 38), (28, 38), (100, 98)):
        circle(d, x * s * k, y * s * k, 8 * s * k, fill=W)
    # skull
    d.ellipse(p((40, 34), (88, 82)), fill=W)
    d.rectangle(p((50, 72), (78, 92)), fill=W)
    circle(d, 54 * s * k, 60 * s * k, 7 * s * k, fill=B)
    circle(d, 74 * s * k, 60 * s * k, 7 * s * k, fill=B)
    d.polygon(p((64, 66), (60, 74), (68, 74)), fill=B)
    for x in (56, 64, 72):
        d.line(p((x, 82), (x, 92)), fill=B, width=int(2 * s * k))
    extra(d, k, s, p)


def make_emblems():
    size = 128

    def luffy(d, k, s, p):
        d.ellipse(p((26, 38), (102, 52)), fill=(232, 196, 110, 255))
        d.chord(p((40, 16), (88, 60)), 180, 360, fill=(232, 196, 110, 255))
        d.rectangle(p((40, 32), (88, 38)), fill=(200, 30, 40, 255))

    def zoro(d, k, s, p):
        for a in (-0.7, 0.0, 0.7):
            dx, dy = math.sin(a) * 52, math.cos(a) * 52
            d.line(p((64 - dx, 64 + dy), (64 + dx, 64 - dy)), fill=(200, 210, 220, 255), width=int(4 * s * k))
        d.chord(p((40, 26), (88, 50)), 180, 360, fill=(30, 30, 34, 255))

    def sanji(d, k, s, p):
        d.arc(p((46, 44), (62, 56)), 180, 360, fill=(240, 200, 60, 255), width=int(3 * s * k))
        d.line(p((74, 76), (96, 72)), fill=(255, 255, 255, 255), width=int(4 * s * k))
        circle(d, 97 * s * k, 72 * s * k, 3 * s * k, fill=(255, 120, 30, 255))

    def kaido(d, k, s, p):
        d.polygon(p((44, 42), (30, 6), (54, 36)), fill=(240, 230, 210, 255))
        d.polygon(p((84, 42), (98, 6), (74, 36)), fill=(240, 230, 210, 255))

    def katakuri(d, k, s, p):
        d.rectangle(p((40, 70), (88, 86)), fill=(170, 60, 100, 255))

    def lucci(d, k, s, p):
        d.rectangle(p((46, 8), (82, 38)), fill=(20, 20, 26, 255), outline=(240, 240, 240, 255), width=int(2 * s * k))
        d.rectangle(p((36, 36), (92, 42)), fill=(20, 20, 26, 255), outline=(240, 240, 240, 255), width=int(2 * s * k))

    colors = {'luffy': 0xE8332F, 'zoro': 0x3FBF5A, 'sanji': 0xF2C744, 'kaido': 0x7A6BFF, 'katakuri': 0xE0457E, 'lucci': 0xE8B030}
    extras = {'luffy': luffy, 'zoro': zoro, 'sanji': sanji, 'kaido': kaido, 'katakuri': katakuri, 'lucci': lucci}
    for name, col in colors.items():
        badge(os.path.join(BASE, 'emblems', name + '.png'), hexc(col), lambda d, k, sz, e=extras[name]: jolly(d, k, sz, e), size=size)
    # Mod icon: the Straw Hat jolly roger.
    badge(os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece', 'icon.png'), hexc(0xE8332F),
          lambda d, k, sz: jolly(d, k, sz, luffy), size=128)


def make_haki():
    def armament(d, k):
        fist(d, k, 32, 32, 1.6)
    def observation(d, k):
        d.ellipse((4 * k, 16 * k, 60 * k, 48 * k), outline=FILL, width=6 * k)
        circle(d, 32 * k, 32 * k, 10 * k, fill=FILL)
    def conqueror(d, k):
        d.polygon(P(k, (6, 52), (10, 14), (22, 32), (32, 8), (42, 32), (54, 14), (58, 52)), fill=FILL)
    for name, fn in (('armament', armament), ('observation', observation), ('conqueror', conqueror)):
        S, k = 32, 8
        img = Image.new('RGBA', (64 * 4, 64 * 4))
        fn(ImageDraw.Draw(img), 4)
        img.resize((S, S), Image.LANCZOS).save(os.path.join(BASE, 'haki', name + '.png'))


if __name__ == '__main__':
    wheel_ring(); wheel_center(); slots(); hud_frame(); stamina_bar(); make_icons(); make_forms(); make_emblems(); make_haki()
    print('gui done')


def speed_lines():
    """Radial anime speed lines with a clear centre, stretched over the whole screen."""
    import random
    S = 512
    k = 2
    img = Image.new('RGBA', (S * k, S * k))
    d = ImageDraw.Draw(img)
    c = S * k / 2
    r = random.Random(3)
    for i in range(160):
        a = r.random() * math.tau
        w = (0.004 + r.random() * 0.012)
        inner = (0.32 + r.random() * 0.25) * c
        outer = c * 1.5
        p0 = (c + math.cos(a - w) * outer, c + math.sin(a - w) * outer)
        p1 = (c + math.cos(a + w) * outer, c + math.sin(a + w) * outer)
        p2 = (c + math.cos(a) * inner, c + math.sin(a) * inner)
        d.polygon([p0, p1, p2], fill=(255, 255, 255, 255))
    img.resize((S, S), Image.LANCZOS).save(os.path.join(BASE, 'speed_lines.png'))


def vignette():
    S = 256
    img = Image.new('RGBA', (S, S))
    c = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = math.hypot((x - c) / c, (y - c) / c)
            a = max(0.0, min(1.0, (d - 0.55) / 0.6)) ** 1.6
            img.putpixel((x, y), (0, 0, 0, int(a * 255)))
    img.save(os.path.join(BASE, 'vignette.png'))


def title_banner():
    """Brush-stroke banner behind cutscene titles."""
    import random
    W, H = 512, 96
    k = 2
    img = Image.new('RGBA', (W * k, H * k))
    d = ImageDraw.Draw(img)
    r = random.Random(9)
    for i in range(70):
        y = H * k / 2 + (r.random() - 0.5) * H * k * 0.55
        x0 = r.random() * 60 * k
        x1 = W * k - r.random() * 60 * k
        th = (4 + r.random() * 10) * k
        d.line((x0, y, x1, y + (r.random() - 0.5) * 10 * k), fill=(255, 255, 255, int(120 + r.random() * 120)), width=int(th))
    img = img.filter(ImageFilter.GaussianBlur(1.5 * k))
    # ragged ends
    alpha = img.getchannel('A')
    for x in range(W * k):
        edge = min(x, W * k - 1 - x) / (90 * k)
        if edge < 1:
            col = alpha.crop((x, 0, x + 1, H * k)).point(lambda v, e=edge: int(v * e))
            alpha.paste(col, (x, 0))
    img.putalpha(alpha)
    img.resize((W, H), Image.LANCZOS).save(os.path.join(BASE, 'title_banner.png'))


if __name__ == '__main__':
    speed_lines(); vignette(); title_banner()
    print('overlays done')
