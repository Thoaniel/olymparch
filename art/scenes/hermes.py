"""Hermes: de bevingede sandalene over skyene, hermesstaven under himmelen, den bevingede hjelmen som stjernebilde.
(Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, W, mix

SANDAL = """
W..........................
.WW........................
..WWW.....W................
...WWWW...WW...............
....WWWWW.WWW..............
.W...WWWWWWWWW.............
..WWW.WWWWWWWWV............
...WWWWWWWWWWVSS...........
.....WWWWWWVVSSS.S..S......
..........VVSSSSSSSSSSS....
.............SSSSSSSSSSSS..
............BBBBBBBBBBBBBB.
............BBBBBBBBBBBBBBB
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
    c.sprite(SANDAL, 72, 76 + round(bob * 2), {k: mix(v, p.bg, 0.3) for k, v in cols.items()}, scale=3)
    c.sprite(SANDAL, 166, 90 - round(bob * 2), cols, scale=3)
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


HELMET = """
.*.............................*.
.:#:.........................:#:.
..+##:.........+*+*+.......:##+..
...*###:.....*#######*...:###*...
....:###*...+#########+.*###:....
.....+###*.*###########*###+.....
......:#*:.+###########+:*#:.....
.....+*:::::::::::::::::::::*+...
....*#########################*..
.....+*+*+*+*+*+*+*+*+*+*+*+*+...
"""

SCENES = {
    "sandals": (32, sandals),
    "caduceus": (32, caduceus),
    "sign": sign(HELMET, scale=4, dy=-6),
}
