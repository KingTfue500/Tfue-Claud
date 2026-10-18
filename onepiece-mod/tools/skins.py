"""Generates every fighter/form skin (64x64, wide arms) for the mod."""
import os
import random
from skinlib import Skin, rgb, shade, mix, side_shade

OUT = os.path.join(os.path.dirname(__file__), '..', 'src', 'main', 'resources', 'assets', 'onepiece', 'textures', 'entity', 'skin')
os.makedirs(OUT, exist_ok=True)

BLACK = rgb(0x111014)
WHITE = rgb(0xF4F4F0)
EYE_W = rgb(0xF6F6F2)


def lit(c, face, u, v, w, h, rnd=None, amt=0.05):
    f = side_shade(face, u, v, w, h)
    if rnd is not None:
        f *= 1 + (rnd.random() - 0.5) * 2 * amt
    return shade(c, f)


# ---------------------------------------------------------------- hair styles
# Each returns True if the pixel is hair.
def hair_messy(face, u, v, w, h):
    if face == 'top':
        return True
    if face == 'bottom':
        return False
    if face == 'back':
        return v <= 5 or (v == 6 and u % 2 == 0)
    if face == 'front':
        return v == 0 or (v == 1 and u in (0, 1, 3, 4, 6, 7)) or (v == 2 and u in (0, 7))
    # sides: right face u=7 is the front edge, left face u=0 is the front edge
    front = u if face == 'left' else 7 - u
    return v <= 2 or (v <= 4 and front >= 3) or (v == 5 and front >= 5 and u % 2 == 0)


def hair_buzz(face, u, v, w, h):
    if face == 'top':
        return True
    if face == 'bottom':
        return False
    if face == 'back':
        return v <= 4
    if face == 'front':
        return v == 0 or (v == 1 and u in (0, 1, 6, 7))
    front = u if face == 'left' else 7 - u
    return v <= 1 or (v <= 3 and front >= 4)


def hair_sanji(face, u, v, w, h):
    if face == 'top':
        return True
    if face == 'bottom':
        return False
    if face == 'back':
        return v <= 6
    if face == 'front':
        # Fringe sweeps over his left eye (viewer's right).
        return v <= 1 or (u >= 5 and v <= 5) or (u == 4 and v <= 3) or (v == 2 and u == 0)
    front = u if face == 'left' else 7 - u
    return v <= 4 or (v <= 6 and front >= 4)


def hair_long(face, u, v, w, h):
    if face == 'top':
        return True
    if face == 'bottom':
        return False
    if face == 'back':
        return True
    if face == 'front':
        return v <= 1 or (u in (0, 7) and v <= 6)
    front = u if face == 'left' else 7 - u
    return v <= 2 or front >= 2


def hair_spiky(face, u, v, w, h):
    if face == 'top':
        return True
    if face == 'bottom':
        return False
    if face == 'back':
        return v <= 5
    if face == 'front':
        return v <= 1 or (v == 2 and u in (1, 3, 4, 6))
    front = u if face == 'left' else 7 - u
    return v <= 3


def hair_curly(face, u, v, w, h):
    if face == 'top':
        return True
    if face == 'bottom':
        return False
    if face == 'back':
        return v <= 7
    if face == 'front':
        return v <= 1 or (u in (0, 7) and v <= 4)
    front = u if face == 'left' else 7 - u
    return v <= 5 or front >= 3


def head(skin, tone, hair_col, hair_fn, face_fn, rnd, extra=None):
    def fn(face, u, v, w, h):
        if extra:
            c = extra(face, u, v)
            if c is not None:
                return c
        if hair_fn(face, u, v, w, h):
            c = hair_col
            # soft strands: darker every third column, sheen near the crown
            if face != 'top' and u % 3 == 1:
                c = shade(c, 0.86)
            if face != 'top' and v == 0:
                c = shade(c, 1.14)
            if face == 'top' and (u + v) % 4 == 0:
                c = shade(c, 1.1)
            return lit(c, face, u, v, w, h, rnd, 0.02)
        if face == 'front':
            c = face_fn(u, v)
            if c is not None:
                return c
        return lit(tone, face, u, v, w, h, rnd, 0.02)
    skin.paint('head', fn)


def limbs_skin(skin, part, tone, rnd, top_fn=None):
    def fn(face, u, v, w, h):
        if top_fn:
            c = top_fn(face, u, v, w, h)
            if c is not None:
                return c
        c = tone
        if face == 'bottom':
            c = shade(tone, 0.85)
        return lit(c, face, u, v, w, h, rnd, 0.03)
    skin.paint(part, fn)


# ---------------------------------------------------------------- LUFFY
def luffy(name, tone=0xF2C094, hair=0x18141A, vest=0xC81E28, shorts=0x3E6FB4, sash=0xE8C03A, cuff=0x8FB4E0,
          arms=None, legs_tone=None, eye_ring=None, marks=None, veins=False, thumb=False, seed=1):
    rnd = random.Random(seed)
    s = Skin(seed)
    T = rgb(tone)
    H = rgb(hair)
    V = rgb(vest)
    S = rgb(shorts)
    SA = rgb(sash)

    def face(u, v):
        brow = rgb(hair) if hair != 0xF4F4F0 else rgb(0xE8E8E8)
        if v == 3 and u in (1, 2, 5, 6):
            return brow
        if v == 4:
            if eye_ring and u in (1, 6):
                return rgb(eye_ring)
            if u in (1, 6):
                return EYE_W
            if u in (2, 5):
                return BLACK
        if v == 5 and u in (5, 6):
            return rgb(0x9A4A3A)
        if v == 6:
            if u in (2, 3, 4, 5):
                return WHITE
            if u in (1, 6):
                return rgb(0x5A2A20)
        if v == 7 and u in (3, 4):
            return rgb(0x7A3020)
        return None
    head(s, T, H, hair_messy, face, rnd)

    def body(face, u, v, w, h):
        if v >= 10:
            c = S
        elif v >= 8:
            c = SA if not (face == 'front' and u == 3 and v == 9) else shade(SA, 0.7)
        elif face == 'front':
            if u <= 1 or u >= 6:
                c = V if u not in (1, 6) else shade(V, 0.8)
            else:
                c = T
                # X scar
                if (v, u) in ((2, 2), (3, 3), (4, 4), (5, 5), (2, 5), (3, 4), (4, 3), (5, 2)):
                    c = rgb(0xD88A7A)
                if marks:
                    m = marks('body', face, u, v)
                    if m is not None:
                        c = m
        else:
            c = V
        if face == 'top':
            c = V if (u <= 1 or u >= 6) else T
        if face == 'bottom':
            c = S
        if marks and face in ('back', 'left', 'right') and v < 8:
            m = marks('body', face, u, v)
            if m is not None:
                c = m
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('body', body)

    arm_tone = rgb(arms) if arms is not None else T

    def arm(face, u, v, w, h):
        c = arm_tone
        if face == 'bottom':
            c = shade(arm_tone, 0.85)
            if thumb and u == 0:
                c = rgb(0xC03030)
        if veins and face in ('front', 'right', 'left') and (u + v) % 4 == 0 and 2 < v < 10:
            c = shade(arm_tone, 1.25)
        if marks and face != 'bottom':
            m = marks('arm', face, u, v)
            if m is not None:
                c = m
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('rarm', arm)
    s.paint('larm', arm)

    lt = rgb(legs_tone) if legs_tone is not None else T

    def leg(face, u, v, w, h):
        if face == 'top':
            return lit(S, face, u, v, w, h)
        if face == 'bottom':
            return rgb(0x5A3A22)
        if v <= 5:
            c = S
            if (u + v) % 6 == 0:
                c = shade(S, 1.12)
        elif v == 6:
            c = rgb(cuff)
        elif v <= 10:
            c = lt
        else:
            c = rgb(0x6A4428) if u % 2 == 0 or face in ('right', 'left') else lt
        if marks and 7 <= v <= 10:
            m = marks('leg', face, u, v)
            if m is not None:
                c = m
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('rleg', leg)
    s.paint('lleg', leg)
    s.save(os.path.join(OUT, name + '.png'))


def flame_marks(dark, glow):
    """Gear 4's flame tattoos: licks of black flame on the chest, red flame streaks up the haki arms."""
    chest = {(2, 1), (2, 2), (3, 0), (4, 0), (5, 1), (5, 2), (2, 3), (5, 3)}

    def m(part, face, u, v):
        if part == 'body' and face == 'front':
            return rgb(dark) if (u, v) in chest else None
        if part == 'arm' and face != 'top':
            if v <= 7 and (u * 3 + v) % 5 == 0:
                return rgb(glow) if v <= 2 else shade(rgb(glow), 0.55)
        if part == 'leg' and (u * 3 + v) % 6 == 0:
            return shade(rgb(glow), 0.5)
        return None
    return m


# ---------------------------------------------------------------- ZORO
def zoro(name, coat=0x2C5A38, sash=0x7A2424, hair=0x3DAA4C, darken=1.0, eye=None, seed=2):
    rnd = random.Random(seed)
    s = Skin(seed)
    T = shade(rgb(0xE2B48A), darken)
    H = shade(rgb(hair), darken)
    C = shade(rgb(coat), darken)
    SA = shade(rgb(sash), darken)
    P = rgb(0x18181C)

    def face(u, v):
        if v == 3 and u in (0, 1, 2, 5, 6, 7):
            return shade(H, 0.6)
        if v == 4 and u == 1:
            return EYE_W if not eye else rgb(eye)
        if v == 4 and u == 2:
            return BLACK if not eye else shade(rgb(eye), 0.6)
        if u in (5, 6) and v == 4:
            return rgb(0x3A2A20)
        if u == 5 and v in (2, 3, 5):
            return rgb(0xB06A5A)
        if v == 6 and u in (3, 4):
            return rgb(0x6A3A2A)
        return None

    def earrings(face, u, v):
        if face == 'left' and u == 1 and v in (4, 5, 6):
            return rgb(0xF0C030)
        return None
    head(s, T, H, hair_buzz, face, rnd, earrings)

    def body(face, u, v, w, h):
        if face == 'front':
            if u <= 1 or u >= 6:
                c = C if u not in (1, 6) else shade(C, 0.8)
            elif 7 <= v <= 9:
                c = SA
            elif v >= 10:
                c = P
            else:
                c = T
                if u + 1 == v or u == v:  # diagonal chest scar
                    c = rgb(0xC88070)
        elif face == 'top':
            c = C
        elif face == 'bottom':
            c = P
        else:
            c = C if not (7 <= v <= 9 and face != 'back') else SA
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('body', body)

    def arm(face, u, v, w, h, left=False):
        if face == 'bottom' or v >= 11:
            c = T
        elif face == 'top':
            c = C
        else:
            c = C
            if v == 10:
                c = shade(C, 0.7)
            if left and v in (2, 3):
                c = rgb(0x1A1A1E)
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rarm', arm)
    s.paint('larm', lambda f, u, v, w, h: arm(f, u, v, w, h, True))

    def leg(face, u, v, w, h):
        if face == 'bottom':
            return rgb(0x221A16)
        if v >= 10:
            c = rgb(0x2A1E18)
        else:
            c = P
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rleg', leg)
    s.paint('lleg', leg)

    def coat_tail(face, u, v, w, h):
        if face in ('top', 'bottom') or v > 7:
            return None
        if face == 'front' and 1 <= u <= 2:
            return None
        return lit(C, face, u, v, w, h, rnd, 0.05)
    s.paint('rleg', coat_tail, overlay=True)
    s.paint('lleg', coat_tail, overlay=True)
    s.save(os.path.join(OUT, name + '.png'))


# ---------------------------------------------------------------- SANJI
def sanji(name, suit=0x15151C, shirt=0x3A5ACF, burn=None, glow=None, raid=False, seed=3):
    rnd = random.Random(seed)
    s = Skin(seed)
    T = rgb(0xF0C8A4)
    H = rgb(0xF2D04A)
    SU = rgb(suit)
    SH = rgb(shirt)

    def face(u, v):
        if raid and v in (3, 4) and u <= 4:
            return rgb(0x0E1A2E) if v == 4 or u in (1, 2) else rgb(0x2E56C9)
        if v == 2 and u in (1, 2, 3):
            return shade(H, 0.8)
        if v == 3 and u == 3:
            return shade(H, 0.8)
        if v == 4 and u == 1:
            return EYE_W
        if v == 4 and u == 2:
            return rgb(0x2A4A8A)
        if v == 6 and u in (2, 3):
            return rgb(0x6A3A2A)
        if v == 6 and u in (4, 5):
            return WHITE
        if v == 6 and u == 6:
            return rgb(0xFF7A20)
        if v == 7 and u in (3, 4):
            return shade(H, 0.85)
        return None
    head(s, T, H, hair_sanji, face, rnd)

    def body(face, u, v, w, h):
        if raid:
            c = rgb(0x101018)
            if face == 'front' and 2 <= u <= 5 and 2 <= v <= 5:
                ring = (u in (2, 5) or v in (2, 5))
                c = rgb(0x2E56C9) if ring else (WHITE if (u, v) in ((3, 3), (4, 3), (4, 4), (3, 4)) else rgb(0x2E56C9))
            elif v in (0, 8) or (face in ('right', 'left') and u == 1):
                c = rgb(0x2E56C9)
        elif face == 'front':
            if 2 <= u <= 5 and v <= 6:
                c = SH
                if u in (3, 4) and 1 <= v <= 6:
                    c = rgb(0x0A0A10)
            else:
                c = SU
                if v == 8 and u in (2, 5):
                    c = rgb(0xC8B050)
        else:
            c = SU
        if glow and (u * 3 + v * 5) % 9 == 0:
            c = rgb(glow)
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('body', body)

    def arm(face, u, v, w, h):
        if face == 'bottom' or v == 11:
            c = T if not raid else rgb(0x2E56C9)
        elif v == 10:
            c = SH if not raid else rgb(0x2E56C9)
        else:
            c = SU if not raid else rgb(0x101018)
            if raid and face in ('right', 'left') and u == 1:
                c = rgb(0x2E56C9)
        if glow and (u + v * 3) % 5 == 0 and v < 10:
            c = rgb(glow)
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('rarm', arm)
    s.paint('larm', arm)

    def leg(face, u, v, w, h, right):
        if face == 'bottom':
            return rgb(0x0A0A0A)
        c = SU if not raid else rgb(0x101018)
        if v >= 10:
            c = rgb(0x0C0C0E) if not raid else rgb(0x2E56C9)
            if v == 10 and face == 'front':
                c = rgb(0x3A3A44)
        if burn and right and v >= 3:
            heat = (v - 3) / 8.0
            if (u + v) % 4 != 0:
                c = mix(c, rgb(burn), min(0.85, 0.3 + heat * 0.6))
            else:
                c = mix(c, rgb(0xFFE070), heat * 0.8)
        if glow and (u * 2 + v) % 4 == 0:
            c = rgb(glow)
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('rleg', lambda f, u, v, w, h: leg(f, u, v, w, h, True))
    s.paint('lleg', lambda f, u, v, w, h: leg(f, u, v, w, h, False))
    s.save(os.path.join(OUT, name + '.png'))


# ---------------------------------------------------------------- KAIDO
def kaido(name, scales=False, eye=None, seed=4):
    rnd = random.Random(seed)
    s = Skin(seed)
    T = rgb(0xC89268)
    H = rgb(0x141016)
    COAT = rgb(0x433478)
    PANTS = rgb(0x2A2246)
    ROPE = rgb(0xEDE4D0)
    SC = rgb(0x3A62D8)
    SC2 = rgb(0x2A44A8)

    def face(u, v):
        if v == 3 and u in (0, 1, 2, 5, 6, 7):
            return H
        if v == 4 and u in (1, 6):
            return rgb(eye) if eye else EYE_W
        if v == 4 and u in (2, 5):
            return BLACK
        if v == 5 and u in (2, 5):
            return shade(H, 1.4)
        if v == 6 and u in (1, 2, 5, 6):
            return shade(H, 1.4)
        if v == 6 and u in (3, 4):
            return rgb(0x5A2A20)
        if v == 7 and u in (3, 4):
            return shade(H, 1.4)
        return None
    head(s, T, H, hair_long, face, rnd)

    def body(face, u, v, w, h):
        if v >= 10:
            c = PANTS
        elif v in (8, 9):
            c = ROPE if (u + v) % 3 else shade(ROPE, 0.75)
        elif face == 'front':
            if u <= 1 or u >= 6:
                c = COAT
            else:
                c = T
                if (u, v) in ((2, 2), (3, 3), (5, 1), (4, 2), (3, 5), (4, 6)):
                    c = rgb(0xA06A50)
                if scales and v <= 2 and (u + v) % 2 == 0:
                    c = SC
        else:
            c = COAT
            if face == 'back' and (u * 3 + v * 2) % 7 == 0:
                c = shade(COAT, 1.35)
        if face == 'top':
            c = COAT if (u <= 1 or u >= 6) else T
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('body', body)

    def arm(face, u, v, w, h, left):
        if face == 'top' or v <= 3:
            c = COAT
        elif face == 'bottom' or v == 11:
            c = T
        elif v in (9, 10):
            c = rgb(0xD8A830)
        else:
            c = T
            if left and 4 <= v <= 8:
                c = SC if (u + v) % 2 == 0 else SC2
            if scales:
                c = SC if (u + v // 2) % 2 == 0 else SC2
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rarm', lambda f, u, v, w, h: arm(f, u, v, w, h, False))
    s.paint('larm', lambda f, u, v, w, h: arm(f, u, v, w, h, True))

    def leg(face, u, v, w, h):
        if face == 'bottom':
            return rgb(0x18120E)
        c = PANTS if v < 10 else rgb(0x221812)
        if v < 10 and u % 2 == 0:
            c = shade(PANTS, 1.08)
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rleg', leg)
    s.paint('lleg', leg)
    s.save(os.path.join(OUT, name + '.png'))


# ---------------------------------------------------------------- KATAKURI
def katakuri(name, glow=None, seed=5):
    rnd = random.Random(seed)
    s = Skin(seed)
    T = rgb(0xD8A07C)
    H = rgb(0x5A1426)
    VEST = rgb(0x1C181E)
    PANTS = rgb(0x4E1E3A)
    TAT = rgb(glow) if glow else rgb(0x8A2A4A)

    def face(u, v):
        if v == 3 and u in (1, 2, 5, 6):
            return shade(H, 0.7)
        if v == 4 and u in (1, 6):
            return EYE_W
        if v == 4 and u in (2, 5):
            return rgb(0x8A1020) if not glow else rgb(glow)
        if v == 6 and u in (1, 2, 5, 6):
            return rgb(0x9A5A4A)
        return None
    head(s, T, H, hair_spiky, face, rnd)

    def body(face, u, v, w, h):
        if v >= 10:
            c = PANTS
        elif v == 9:
            c = rgb(0x5A3A22)
        else:
            c = VEST
            if face == 'front' and u in (3, 4):
                c = rgb(0x9A9AA4) if v % 2 == 0 else VEST
            if v == 0 and u % 2 == 0:
                c = rgb(0xC8C8D0)
            if glow and (u + v) % 4 == 0:
                c = rgb(glow)
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('body', body)

    def arm(face, u, v, w, h):
        if face == 'top':
            c = VEST
        elif v in (9, 10):
            c = rgb(0x1A1A1E)
            if u % 2 == 0 and v == 9:
                c = rgb(0xC8C8D0)
        elif face == 'bottom' or v == 11:
            c = T
        else:
            c = T
            if 2 <= v <= 7 and ((u + v) % 3 == 0 or (u == 1 and v % 2)):
                c = TAT
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rarm', arm)
    s.paint('larm', arm)

    def leg(face, u, v, w, h):
        if face == 'bottom':
            return rgb(0x141010)
        c = PANTS if v < 9 else rgb(0x181416)
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rleg', leg)
    s.paint('lleg', leg)
    s.save(os.path.join(OUT, name + '.png'))


# ---------------------------------------------------------------- LUCCI
def lucci_human(name, seed=6):
    rnd = random.Random(seed)
    s = Skin(seed)
    T = rgb(0xEAC4A0)
    H = rgb(0x121014)
    SUIT = rgb(0x16161C)

    def face(u, v):
        if v == 3 and u in (1, 2, 5, 6):
            return H
        if v == 4 and u in (1, 6):
            return EYE_W
        if v == 4 and u in (2, 5):
            return BLACK
        if v == 6 and u in (3, 4):
            return rgb(0x6A3A2A)
        if v == 7 and u in (2, 3, 4, 5):
            return H
        return None
    head(s, T, H, hair_curly, face, rnd)

    def body(face, u, v, w, h):
        if face == 'front' and 2 <= u <= 5 and v <= 6:
            c = WHITE
            if u in (3, 4) and 1 <= v <= 6:
                c = rgb(0x0A0A0E)
        else:
            c = SUIT
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('body', body)

    def arm(face, u, v, w, h):
        if face == 'bottom' or v == 11:
            c = T
        elif v == 10:
            c = WHITE
        else:
            c = SUIT
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('rarm', arm)
    s.paint('larm', arm)

    def leg(face, u, v, w, h):
        if face == 'bottom':
            return rgb(0x080808)
        c = SUIT if v < 10 else rgb(0x0A0A0C)
        return lit(c, face, u, v, w, h, rnd, 0.04)
    s.paint('rleg', leg)
    s.paint('lleg', leg)
    s.save(os.path.join(OUT, name + '.png'))


def leopard(name, fur=0xE8A030, spot=0x2A1A10, eye=0xD0E040, mane=None, seed=7):
    rnd = random.Random(seed)
    s = Skin(seed)
    F = rgb(fur)
    SP = rgb(spot)
    BELLY = rgb(0xF6EEDC)
    PANTS = rgb(0x16161C)

    def furc(u, v, face_id):
        # Leopard rosettes: dark ring with a lighter centre.
        k = (u * 7 + v * 13 + face_id * 5) % 11
        if k == 0:
            return SP
        if k == 1 and (u + v) % 2 == 0:
            return shade(SP, 1.5)
        return F

    def hd(face, u, v, w, h):
        fid = len(face)
        if mane and (face == 'back' or (face in ('left', 'right') and v >= 2) or (face == 'top' and v >= 5)):
            c = rgb(mane)
            return lit(shade(c, 1.1 if (u + v) % 3 else 0.9), face, u, v, w, h, rnd, 0.04)
        if face == 'front':
            if v in (3, 4) and u in (1, 2, 5, 6):
                if v == 4 and u in (2, 5):
                    return BLACK
                return rgb(eye)
            if v >= 5 and 2 <= u <= 5:
                if v == 5 and u in (3, 4):
                    return rgb(0x6A3A3A)
                if v == 6 and u in (2, 5):
                    return rgb(0x3A2A20)
                return BELLY
            if v >= 5 and u in (1, 6):
                return BELLY if v > 5 else F
        return lit(furc(u, v, fid), face, u, v, w, h, rnd, 0.04)
    s.paint('head', hd)

    def body(face, u, v, w, h):
        if v >= 10:
            c = PANTS
        elif face == 'front' and 2 <= u <= 5 and v >= 3:
            c = BELLY
        else:
            c = furc(u, v, len(face) + 3)
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('body', body)

    def arm(face, u, v, w, h):
        c = furc(u, v, len(face) + 7)
        if face == 'bottom':
            c = BELLY
        if v == 11 and face == 'front':
            c = WHITE
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rarm', arm)
    s.paint('larm', arm)

    def leg(face, u, v, w, h):
        if face == 'bottom':
            return BELLY
        c = PANTS if v < 9 else furc(u, v, 2)
        return lit(c, face, u, v, w, h, rnd, 0.05)
    s.paint('rleg', leg)
    s.paint('lleg', leg)
    s.save(os.path.join(OUT, name + '.png'))


def main():
    luffy('base_luffy')
    luffy('gear_2', tone=0xF0907E, arms=0xEE8A78, legs_tone=0xEE8A78, seed=11)
    luffy('gear_3', veins=True, thumb=True, seed=12)
    g4 = flame_marks(0x1A1014, 0xE04050)
    luffy('gear_4_boundman', tone=0xD8846A, arms=0x1C1418, legs_tone=0x1C1418, marks=g4, seed=13)
    luffy('gear_4_snakeman', tone=0xB8604E, vest=0x8A1420, arms=0x1A1016, legs_tone=0x1A1016, marks=flame_marks(0x14080C, 0xFF3040), seed=14)
    luffy('gear_4_tankman', tone=0xD8846A, arms=0x1C1418, legs_tone=0x1C1418, marks=g4, seed=15)
    luffy('gear_5', hair=0xF4F4F0, vest=0xF2F0EA, shorts=0xEDEBE4, sash=0xF6F2E2, cuff=0xFFFFFF, eye_ring=0xE0202A, seed=16)
    zoro('base_zoro')
    zoro('asura', coat=0x2A2240, sash=0x40182A, darken=0.82, eye=0xC090FF, seed=21)
    zoro('king_of_hell', coat=0x1E1428, sash=0x5A1A3A, eye=0xD060FF, seed=22)
    sanji('base_sanji')
    sanji('diable_jambe', burn=0xFF5A1A, seed=31)
    sanji('ifrit_jambe', glow=0x45B5FF, seed=32)
    sanji('raid_suit', raid=True, seed=33)
    kaido('base_kaido')
    kaido('kaido_hybrid', scales=True, eye=0xFFD040, seed=41)
    kaido('kaido_dragon', scales=True, eye=0xFFD040, seed=42)
    katakuri('base_katakuri')
    katakuri('katakuri_awakened', glow=0xFF70B0, seed=51)
    lucci_human('base_lucci')
    leopard('lucci_hybrid')
    leopard('lucci_awakened', fur=0xF2C870, spot=0x6A1A10, eye=0xFF2A20, mane=0xF6F2EA, seed=61)


if __name__ == '__main__':
    main()
