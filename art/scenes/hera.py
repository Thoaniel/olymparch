"""Hera: påfuglens hale, Melkeveien (melken fra Hera), påfuglfjæren som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import constellation, sign
from pixel import H, TAU, W, hsh, mix


def peacock(c):
    p = c.p
    c.gradient(p.night(4))
    c.stars(70, 21, 36, 90, twinkle=0.25)
    cx, cy = W // 2, 168
    c.glow(cx, cy - 40, 150, 90, p.halo[:3], 0.7)
    shaft = mix(p.surface, p.line, 0.7)
    barb = mix(p.surface, p.line, 0.35)
    # halen: fjær i en vifte, tre rader; hver fjær har et øye ytterst
    eyes = []
    for row, (r, n) in enumerate(((104, 7), (80, 5), (56, 3))):
        for i in range(n):
            a = math.pi * (0.12 + 0.76 * i / max(1, n - 1))
            sway = 0.012 * c.wave(1, hsh(row, i))
            a += sway
            ex, ey = cx - math.cos(a) * r, cy - math.sin(a) * r * 0.92
            # fjærens skaft og skjegg
            for s in range(0, int(r), 2):
                x, y = cx - math.cos(a) * s, cy - math.sin(a) * s * 0.92
                c.put(x, y, shaft)
                if s > 20:
                    for side in (-1, 1):
                        c.put(x + side * math.sin(a) * 2, y - side * math.cos(a) * 2, barb)
            eyes.append((ex, ey, row, i))
    for ex, ey, row, i in eyes:
        rr = 5 - row
        tw = 0.5 + 0.5 * math.sin(TAU * (c.t + hsh(row, i, 3)))
        ring, iris = mix(p.surface, p.line, 0.6), mix(p.hi, p.surface, 0.45 if tw > 0.25 else 0.6)
        c.ellipse(ex, ey, rr + 1.5, rr + 2.5, ring)
        c.ellipse(ex, ey, rr, rr + 1, iris)
        c.ellipse(ex, ey + 0.5, rr * 0.6, rr * 0.7, mix(p.acc, p.surface, 0.4))
        c.ellipse(ex, ey + 1, rr * 0.3, rr * 0.35, p.bg)
    # fuglen selv: en liten mørk silhuett foran vifta
    body = """
..a.a.a...
...aaa....
....cc....
...cdcc...
...cccc...
....ccc...
....cc....
....cc....
...cccc...
..cccccc..
.cccccccc.
.cccccccc.
.cccccccc.
..cccccc..
...cccc...
"""
    c.sprite(body, cx - 15, cy - 46, {"a": p.hi, "c": mix(p.acc, p.bg, 0.55), "d": p.text}, scale=3)
    c.gradient([mix(p.bg, p.surface, 0.5), p.bottom], 160, 180)


def milkyway(c):
    p = c.p
    c.gradient(p.night(5))
    # Melkeveien: et skrått bånd av lys og tette stjerner
    band = [mix(p.bottom, p.surface, 0.6), mix(p.surface, p.line, 0.35), mix(p.line, p.acc, 0.25), mix(p.acc, p.hi, 0.35)]
    pulse = 0.04 * c.wave(1)
    for y in range(40, H):
        for x in range(W):
            # avstand fra linja fra (0,170) til (320,50), litt bølget
            d = abs((y - (170 - x * 0.375)) + 6 * math.sin(x / 37.0)) / 30.0
            g = 1 - d
            if g > 0:
                v = (g ** 1.4) * (0.7 + pulse) * (0.75 + 0.25 * hsh(x // 6, y // 6))
                col = c.pick([None, *band], v, x, y)
                if col is not None:
                    c.px[x, y] = col
    c.stars(140, 31, 36, H, twinkle=0.3)
    # tette stjerner i båndet
    for i in range(260):
        x = hsh(5, i, 1) * W
        y = 170 - x * 0.375 + (hsh(5, i, 2) - 0.5) * 40
        if y < 38:
            continue
        tw = 0.5 + 0.5 * math.sin(TAU * (c.t * (1 + i % 2) + hsh(5, i, 3)))
        c.put(x, y, p.text if hsh(5, i, 4) > 0.8 and tw > 0.5 else mix(p.muted, p.hi, 0.3))
    # åsene og en liten søyle (Heras tempel på Samos) i silhuett
    c.ridge(162, 6, 4, mix(p.bg, p.surface, 0.4), period=50)
    c.rect(226, 138, 229, 160, mix(p.bg, p.surface, 0.4))
    c.rect(224, 136, 231, 137, mix(p.bg, p.surface, 0.4))
    c.rect(240, 146, 243, 160, mix(p.bg, p.surface, 0.4))
    c.rect(238, 144, 245, 145, mix(p.bg, p.surface, 0.4))
    c.gradient([mix(p.bg, p.surface, 0.3), p.bottom], 168, 180)


# en påfuglfjær: et langt skaft, et dråpeformet øye med en stjerne i midten, skjegg som vifter ut
FEATHER = constellation(37, 40, lines=[[(18, 39), (18, 18)], [(24, 10), (23, 14), (21, 17), (18, 18), (15, 17), (13, 14), (12, 10), (13, 6), (15, 3), (18, 2), (21, 3), (23, 6), (24, 10)]] + [[(18, y), (18 - 7 + (y - 18) // 5, y - 5)] for y in range(22, 38, 4)]
                        + [[(18, y), (18 + 7 - (y - 18) // 5, y - 5)] for y in range(22, 38, 4)],
                        stars=[(18, 10), (18, 2), (18, 39)], small=[(12, 10), (24, 10), (11, 17), (25, 17)])


SCENES = {
    "peacock": (32, peacock),
    "milkyway": (32, milkyway),
    "sign": sign(FEATHER, scale=3, dy=-4),
}
