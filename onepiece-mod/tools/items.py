"""16x16 item sprites, armor equipment textures and every item/equipment JSON."""
import json
import math
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece')
TEX = os.path.join(ROOT, 'textures', 'item')
for d in (TEX, os.path.join(ROOT, 'items'), os.path.join(ROOT, 'models', 'item'), os.path.join(ROOT, 'equipment'),
          os.path.join(ROOT, 'textures', 'entity', 'equipment', 'humanoid')):
    os.makedirs(d, exist_ok=True)


def h(c, a=255):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255, a)


def sprite(rows, palette):
    img = Image.new('RGBA', (16, 16))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != '.' and ch in palette:
                img.putpixel((x, y), palette[ch])
    return img


def outline(img, color=(20, 14, 20, 255)):
    out = img.copy()
    for y in range(16):
        for x in range(16):
            if img.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 16 and 0 <= ny < 16 and img.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), color)
                        break
    return out


def fruit(base, light, dark, stem=0x3E8A3A, swirl=None):
    """Devil fruit: round body covered in swirl patterns with a curly stem."""
    img = Image.new('RGBA', (16, 16))
    cx, cy, r = 7.5, 9.0, 6.2
    sw = h(swirl) if swirl else h(light)
    for y in range(16):
        for x in range(16):
            dx, dy = x - cx, (y - cy) * 1.05
            d = math.hypot(dx, dy)
            if d <= r:
                ang = math.atan2(dy, dx)
                spiral = math.sin(d * 1.9 - ang * 2.0)
                c = h(base)
                if spiral > 0.55:
                    c = sw
                elif spiral < -0.7:
                    c = h(dark)
                if dx < -2 and dy < -2 and d > r - 2:
                    c = tuple(min(255, v + 60) for v in c[:3]) + (255,)
                if d > r - 1.0 and dx + dy > 2:
                    c = h(dark)
                img.putpixel((x, y), c)
    for x, y in ((7, 2), (8, 2), (8, 1), (9, 1), (10, 1), (6, 3), (5, 3), (5, 2)):
        img.putpixel((x, y), h(stem))
    return outline(img)


def sword(blade, edge, guard, hilt, wrap):
    img = Image.new('RGBA', (16, 16))
    for i in range(3, 15):
        x, y = i, 15 - i
        img.putpixel((x, y), h(blade))
        if x + 1 < 16:
            img.putpixel((x + 1, y), h(edge) if i % 2 else h(blade))
    for i in range(0, 4):
        x, y = i, 15 - i
        img.putpixel((x, y), h(hilt) if i % 2 else h(wrap))
    for gx, gy in ((3, 11), (4, 12), (2, 12), (3, 13), (5, 11), (4, 10)):
        img.putpixel((gx, gy), h(guard))
    return outline(img)


ITEMS = {}


def make_sprites():
    ITEMS['gum_gum_fruit'] = fruit(0x7A3AB0, 0xB070E0, 0x40186A)
    ITEMS['dragon_fruit'] = fruit(0x2E6AD8, 0x7AB8FF, 0x14306A, stem=0x2A6A6A)
    ITEMS['mochi_fruit'] = fruit(0xF0C8DC, 0xFFFFFF, 0xC07898, stem=0x6A8A3A)
    ITEMS['leopard_fruit'] = fruit(0xE8A030, 0xFFE070, 0x6A3A10, stem=0x4A6A2A)
    ITEMS['wado_ichimonji'] = sword(0xDCE4EC, 0xFFFFFF, 0xD0A040, 0xF4F0E8, 0xFFFFFF)
    ITEMS['shusui'] = sword(0x2A2A30, 0x6A6A78, 0xC09030, 0x1A1A1A, 0x8A1A1A)
    ITEMS['enma'] = sword(0x3A2A50, 0xB060FF, 0xC09030, 0x2A1A3A, 0x6A2AA0)
    pal = {'B': h(0x2E4A9A), 'b': h(0x1C2E6A), 'P': h(0xF0EAD8), 'G': h(0xE0B040), 'S': h(0xC8C8D0), 'w': h(0xFFFFFF)}
    ITEMS['sanji_cookbook'] = outline(sprite([
        '................', '..BBBBBBBBBBB...', '..BbbbbbbbbbBP..', '..Bb..GGG..bBP..', '..Bb.G...G.bBP..', '..Bb..GGG..bBP..',
        '..Bb...S...bBP..', '..Bb...S...bBP..', '..Bb..SSS..bBP..', '..Bb..SwS..bBP..', '..Bb...S...bBP..', '..Bb.......bBP..',
        '..BbbbbbbbbbBP..', '..BBBBBBBBBBBP..', '...PPPPPPPPPPP..', '................'], pal))
    pal = {'Y': h(0xE8C46E), 'y': h(0xC89A48), 'R': h(0xC81E28), 'r': h(0x8A1018)}
    ITEMS['straw_hat'] = outline(sprite([
        '................', '................', '................', '......YYYY......', '.....YYyYYY.....', '....YYYYyYYY....',
        '....RRRRRRRR....', '....rrrrrrrr....', '..YYYYYYYYYYYY..', '.YYyYYYYYYYyYYY.', 'YYYYYyYYYYYYYYYY', '.YYYYYYYYYYYYYY.',
        '...YYYYYYYYYY...', '................', '................', '................'], pal))
    pal = {'K': h(0x1A1A20), 'k': h(0x30303A), 'w': h(0x6A6A78)}
    ITEMS['zoro_bandana'] = outline(sprite([
        '................', '................', '....KKKKKKK.....', '...KkkkkkkkK....', '..KkkwkkkkkkK...', '..KkkkkkkkkkK...',
        '..KKKKKKKKKKKK..', '...........KkK..', '..........KkK...', '.........KkkK...', '........KkK.....', '........KK......',
        '................', '................', '................', '................'], pal))
    pal = {'K': h(0x16161C), 'k': h(0x2A2A34), 'B': h(0x3A5ACF), 'T': h(0x0A0A10), 'G': h(0xC8B050)}
    ITEMS['sanji_suit'] = outline(sprite([
        '................', '...KKK....KKK...', '..KKkKBBBBKkKK..', '.KKkkKBTTBKkkKK.', '.KkkkKBTTBKkkkK.', '.KkkkkKBTBkkkkK.',
        '.KkkkkKBTBkkkkK.', '.KkkkkkKTKkkkkK.', '.KKkkkkKGKkkkKK.', '..KkkkkKkKkkkK..', '..KkkkkKGKkkkK..', '..KkkkkKkKkkkK..',
        '..KKKKKKKKKKKK..', '................', '................', '................'], pal))
    pal = {'B': h(0x3A62D8), 'b': h(0x223C90), 'L': h(0x9CC0FF), 'D': h(0x14245A)}
    ITEMS['dragon_scale'] = outline(sprite([
        '................', '.......BB.......', '......BLLB......', '.....BLLBBB.....', '....BLBBBBbB....', '...BLBBBBBBbB...',
        '...BLBBBBBBbB...', '..BLBBBBBBBBbB..', '..BBBBBBBBBBbB..', '..BBBBBBBBBbbB..', '...BBBBBBBbbB...', '...DBBBBBbbbD...',
        '....DBBBbbbD....', '.....DDbbDD.....', '.......DD.......', '................'], pal))
    pal = {'W': h(0xFAF4F6), 'w': h(0xE0CCD4), 'P': h(0xF0A0C0), 'G': h(0x6AA040)}
    ITEMS['mochi'] = outline(sprite([
        '................', '................', '................', '.......GG.......', '.....WWGWWW.....', '....WWWWWWWW....',
        '...WWPPWWWWWW...', '..WWWPPWWWWWWW..', '..WWWWWWWWWWww..', '..wWWWWWWWWwww..', '...wwWWWWWwww...', '....wwwwwwww....',
        '................', '................', '................', '................'], pal))
    pal = {'W': h(0xF4EEDC), 'w': h(0xC8BCA0), 'R': h(0xA02020)}
    ITEMS['leopard_fang'] = outline(sprite([
        '................', '.....WWWW.......', '....WWWWWW......', '....WWWWWW......', '.....WWWWW......', '.....WWWWw......',
        '......WWWw......', '......WWww......', '.......Www......', '.......Ww.......', '........w.......', '........w.......',
        '................', '................', '................', '................'], pal))
    for name, (a, b) in {'kaido_spawn_egg': (0x433478, 0x3A62D8), 'katakuri_spawn_egg': (0x5A1426, 0xF0C8DC), 'lucci_spawn_egg': (0x16161C, 0xE8A030)}.items():
        img = Image.new('RGBA', (16, 16))
        for y in range(16):
            for x in range(16):
                dx, dy = (x - 7.5) / 5.5, (y - 8.5) / 7.0
                if dx * dx + dy * dy <= 1:
                    c = h(a)
                    if (x * 3 + y * 5) % 7 == 0 or (x + y) % 9 == 0:
                        c = h(b)
                    if dx < -0.3 and dy < -0.3:
                        c = tuple(min(255, v + 50) for v in c[:3]) + (255,)
                    img.putpixel((x, y), c)
        ITEMS[name] = outline(img)
    for name, img in ITEMS.items():
        img.save(os.path.join(TEX, name + '.png'))


def make_json():
    handheld = {'wado_ichimonji', 'shusui', 'enma'}
    for name in ITEMS:
        with open(os.path.join(ROOT, 'items', name + '.json'), 'w') as f:
            json.dump({'model': {'type': 'minecraft:model', 'model': 'onepiece:item/' + name}}, f, indent=2)
        with open(os.path.join(ROOT, 'models', 'item', name + '.json'), 'w') as f:
            json.dump({'parent': 'minecraft:item/handheld' if name in handheld else 'minecraft:item/generated',
                       'textures': {'layer0': 'onepiece:item/' + name}}, f, indent=2)
    # The Straw Hat is drawn as a 3D model by the mod, so its armor layer is empty.
    json.dump({'layers': {}}, open(os.path.join(ROOT, 'equipment', 'straw_hat.json'), 'w'), indent=2)
    json.dump({'layers': {'humanoid': [{'texture': 'onepiece:zoro_bandana'}]}}, open(os.path.join(ROOT, 'equipment', 'zoro_bandana.json'), 'w'), indent=2)
    json.dump({'layers': {'humanoid': [{'texture': 'onepiece:sanji_suit'}]}}, open(os.path.join(ROOT, 'equipment', 'sanji_suit.json'), 'w'), indent=2)


def armor_textures():
    """64x32 armor layout: head at (0,0), body at (16,16), arms at (40,16)."""
    out = os.path.join(ROOT, 'textures', 'entity', 'equipment', 'humanoid')
    bandana = Image.new('RGBA', (64, 32))
    # head: top (8,0) 8x8, sides at y 8..16: right(0,8) front(8,8) left(16,8) back(24,8)
    for x in range(8, 16):
        for y in range(0, 8):
            bandana.putpixel((x, y), h(0x1A1A20) if (x + y) % 5 else h(0x30303A))
    for face_x in (0, 8, 16, 24):
        for x in range(face_x, face_x + 8):
            for y in range(8, 11):
                bandana.putpixel((x, y), h(0x1A1A20) if (x + y) % 4 else h(0x34343E))
    for x, y in ((26, 11), (27, 11), (27, 12), (28, 13), (26, 12)):
        bandana.putpixel((x, y), h(0x1A1A20))
    bandana.save(os.path.join(out, 'zoro_bandana.png'))
    suit = Image.new('RGBA', (64, 32))
    K, k, B, T = h(0x16161C), h(0x24242C), h(0x3A5ACF), h(0x0A0A10)
    # body faces: top(20,16) bottom(28,16) right(16,20) front(20,20) left(28,20) back(32,20)
    for x in range(16, 40):
        for y in range(16, 32):
            if y < 20 and not (20 <= x < 36):
                continue
            c = K if (x + y) % 3 else k
            if 20 <= x < 28 and 20 <= y < 32:
                fx, fy = x - 20, y - 20
                if 2 <= fx <= 5 and fy <= 6:
                    c = B
                    if fx in (3, 4) and fy >= 1:
                        c = T
            suit.putpixel((x, y), c)
    for x in range(40, 56):
        for y in range(16, 32):
            if y < 20 and not (44 <= x < 52):
                continue
            c = K if (x + y) % 3 else k
            if y == 30:
                c = B
            suit.putpixel((x, y), c)
    suit.save(os.path.join(out, 'sanji_suit.png'))


if __name__ == '__main__':
    make_sprites(); make_json(); armor_textures()
    print('items done', len(ITEMS))
