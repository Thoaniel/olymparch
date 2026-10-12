"""Hermes: de bevingede sandalene over skyene, hermesstaven under himmelen, den bevingede hjelmen som stjernebilde.
(Tempelet er art/torch.py.)"""
import math

from common import constellation, sign
from pixel import H, W, mix

SANDAL = """
WW..............................
.WWW............................
..WWWW..........................
WW.WWWWW.......SSS..............
.WWW.WWWW.....S...S.............
..WWWW.WWW....S...S.............
...WWWWWWWW...S.S.S.............
WW..WWWWWWWW..SS.SS.............
.WWWWWWWWWWWW.S.S.S.............
...WWWWWWWWWWSS.S.SS............
.....WWWWWWWWS.S.S..SS..........
.......WWWWWS.S...S...SS........
..........WS...S....S...SSS.....
..........SSSSSSSSSSSSSSSSSSSS..
..........BBBBBBBBBBBBBBBBBBBBBB
...........BBBBBBBBBBBBBBBBBBBB.
"""


def clouds(c, y0, n, col, edge, speed, seed, w=60, h=12):
    off = c.loop(speed) * (W + 80)
    for k in range(n):
        x = (k * (W + 80) / n + off) % (W + 80) - 40
        c.cloud(x, y0 + (k % 3) * 5, w + 10 * (k % 2), h, col, seed=seed + k, edge=edge)


def sandals(c):
    p = c.p
    c.gradient(p.night(5), 0, 180)
    c.stars(90, 51, 20, 110)
    # skyer langt nede som driver forbi, i to lag
    clouds(c, 132, 6, mix(p.surface, p.line, 0.35), mix(p.line, p.hi, 0.2), 1, 3)
    c.glow(160, 104, 100, 44, p.halo, 0.85)
    bob = c.wave(1)
    cols = {"W": mix(p.hi, p.text, 0.3), "V": mix(p.line, p.hi, 0.5), "S": p.gold[2], "B": p.gold[1]}
    # ett stort par: den bakerste litt dempet og forskjøvet, begge med en vinge ved hælen
    c.sprite(SANDAL, 96, 66 + round(bob * 2), {k: mix(v, p.bg, 0.35) for k, v in cols.items()}, scale=3)
    c.sprite(SANDAL, 114, 82 - round(bob * 2), cols, scale=3)
    # noen fjær som drysser fra vingene
    c.particles(8, 5, 120, 210, 110, 170, [mix(p.hi, p.text, 0.3), mix(p.line, p.hi, 0.4)], rise=False, sway=4)
    clouds(c, 160, 7, mix(p.surface, p.line, 0.15), mix(p.surface, p.line, 0.55), 2, 13, w=70, h=14)


def caduceus(c):
    p = c.p
    c.gradient(p.night(5))
    c.stars(140, 61, 20, 150)
    clouds(c, 150, 5, mix(p.surface, p.line, 0.2), mix(p.surface, p.line, 0.5), 1, 23, w=80, h=12)
    cx = 160
    c.glow(cx, 100, 60, 70, p.halo, 0.9 + 0.08 * c.wave(1))
    staff, hi, dark = p.gold[2], p.gold[3], p.gold[0]
    c.rect(cx - 1, 54, cx, 156, staff)
    c.rect(cx - 1, 54, cx - 1, 156, hi)
    # vingene øverst
    for side in (-1, 1):
        for k in range(4):
            y = 58 + k * 3
            ln = 26 - k * 5
            c.line([(cx + side * 3, y + 2), (cx + side * ln, y - 6 + k)], mix(p.hi, p.text, 0.3 - k * 0.05), 2)
    c.disc(cx - 0.5, 52, 3.5, hi)
    # to slanger som snor seg rundt staven
    for ph, col in ((0, p.gold[1]), (math.pi, p.gold[2])):
        prev = None
        for y in range(70, 152):
            u = (y - 70) / 82
            x = cx - 0.5 + (10 - 4 * u) * math.sin((y - 70) / 13 * math.pi + ph)
            if prev:
                c.line([prev, (x, y)], col, 2)
            prev = (x, y)
        # hodene vender mot hverandre øverst
        hx = cx - 0.5 + 10 * math.sin(ph - 0.4)
        c.disc(hx, 68, 2.5, col)
        c.put(hx + (2 if hx < cx else -3), 67, dark)
    c.gradient([mix(p.bg, p.surface, 0.4), p.bottom], 168, 180)


# den bevingede hjelmen: en rund kuppel med en kort skygge, og to vinger mye høyere enn kuppelen
HELMET = constellation(41, 34, lines=[[(12, 26), (13, 23), (14, 20), (17, 19), (20, 18), (23, 19), (26, 20), (27, 23), (28, 26)], [(10, 26), (30, 26)],
                                      [(12, 22), (2, 4), (5, 11), (0, 9), (4, 16), (1, 15), (11, 25)],
                                      [(28, 22), (38, 4), (35, 11), (40, 9), (36, 16), (39, 15), (29, 25)]],
                       stars=[(20, 18), (12, 22), (28, 22), (2, 4), (38, 4), (0, 9), (40, 9), (10, 26), (30, 26)],
                       small=[(5, 11), (35, 11), (1, 15), (39, 15)])


SCENES = {
    "sandals": (32, sandals),
    "caduceus": (32, caduceus),
    "sign": sign(HELMET, scale=3, dy=-2),
}
