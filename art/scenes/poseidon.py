"""Poseidon: treforken stiger av nattehavet, lysstråler i dypet, treforken som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, TAU, W, hsh, mix

TRIDENT = """
a....a....a
a....a....a
aa...a...aa
.a..aaa..a.
.aaaaaaaaa.
.....a.....
.....b.....
.....a.....
.....b.....
.....a.....
.....b.....
.....a.....
.....b.....
.....a.....
.....b.....
.....a.....
"""


def water(c, y0, y1, colors, speed=1, seed=0):
    """bølgerader: hver rad har sin egen bølge som glir sidelengs (helt antall ganger rundt)"""
    for y in range(y0, y1):
        k = (y - y0) / max(1, y1 - y0)
        for x in range(W):
            w = math.sin(x / (6 + 10 * k) + TAU * c.loop(speed) * (1 if y % 2 else -1) + y * 1.7 + seed)
            w += 0.6 * math.sin(x / (3 + 5 * k) - TAU * c.loop(speed * 2) + y * 0.9)
            v = 0.35 + 0.5 * k + 0.12 * w
            c.px[x, y] = c.pick(colors, v, x, y)


def waves(c):
    p = c.p
    horizon = 112
    c.gradient(p.night(4), 0, horizon)
    c.stars(90, 41, 30, 100, twinkle=0.25)
    c.moon(70, 64, 7, mix(p.text, p.hi, 0.2), shadow=mix(p.text, p.muted, 0.5), glow=[mix(p.bottom, p.surface, 0.8), mix(p.surface, p.line, 0.4)])
    water(c, horizon, H, [mix(p.surface, p.line, 0.5), p.surface, mix(p.bg, p.surface, 0.5), p.bottom])
    # månestripen på vannet
    for y in range(horizon + 1, H, 2):
        k = (y - horizon) / (H - horizon)
        half = 3 + int(12 * k)
        for x in range(70 - half, 70 + half):
            if math.sin(x * 0.9 + y * 1.3 + TAU * c.loop(2)) > 0.55:
                c.put(x, y, mix(p.muted, p.hi, 0.3))
    # treforken løfter seg litt og synker igjen
    lift = round(2 * c.wave(1))
    cx = 214
    c.glow(cx, 120, 46, 36, p.halo, 0.85 + 0.15 * c.wave(2), top=82)
    c.sprite(TRIDENT, cx - 16, 70 + lift, {"a": p.gold[3], "b": p.gold[2]}, scale=3)
    # skummet rundt skaftet
    for i in range(14):
        a = TAU * (i / 14 + c.loop(1) / 14)
        x = cx + 14 * math.cos(a) * (1 + 0.15 * c.wave(2, i / 14))
        y = 119 + 3 * math.sin(a)
        c.put(x, y, mix(p.hi, p.text, 0.4) if i % 3 else p.hi)
    for x in range(cx - 20, cx + 20):
        if math.sin(x * 0.7 + TAU * c.loop(1)) > 0.2:
            c.put(x, 121 + (x % 3 == 0), mix(p.line, p.acc, 0.5))


def deep(c):
    p = c.p
    c.gradient([p.bottom, mix(p.bg, p.surface, 0.7), mix(p.surface, p.line, 0.25), mix(p.bg, p.surface, 0.6), p.bottom], 0, H)
    # lysstråler skrått ned fra overflaten, de svaier sakte
    rays = [mix(p.surface, p.line, 0.55), mix(p.line, p.acc, 0.2)]
    for i, (x0, wdt) in enumerate(((70, 10), (120, 6), (170, 14), (225, 8), (270, 5))):
        sw = 6 * c.wave(1, i * 0.21)
        for y in range(24, 150):
            k = (y - 24) / 126
            xc = x0 + sw * k + (y - 24) * 0.45
            half = wdt * (0.5 + k)
            fade = min(1, (y - 24) / 30) * (1 - k) * (0.65 + 0.25 * c.wave(2, i * 0.37))
            for x in range(int(xc - half), int(xc + half) + 1):
                edge = 1 - abs(x - xc) / (half + 0.01)
                col = c.pick([None, *rays], fade * edge * 1.2, x, y)
                if col is not None:
                    c.put(x, y, col)
    # havbunnen: sand, en velt søyle, tang
    c.ridge(166, 4, 9, mix(p.bg, p.surface, 0.45), period=45)
    col = mix(p.surface, p.line, 0.45)
    c.rect(150, 150, 200, 155, col)
    for x in range(152, 200, 6):
        c.put(x, 152, mix(p.bg, p.surface, 0.5))
    c.rect(204, 140, 211, 160, col)
    c.rect(202, 138, 213, 140, col)
    for i, x0 in enumerate((24, 38, 92, 262, 280, 300)):
        hgt = 26 + int(hsh(3, i) * 22)
        for s in range(hgt):
            x = x0 + 3 * math.sin(s / 7 + TAU * c.loop(1) + i)
            c.put(x, 172 - s, mix(p.line, p.acc, 0.35) if s % 5 else mix(p.surface, p.line, 0.6))
            c.put(x + 1, 172 - s, mix(p.surface, p.line, 0.6))
    c.gradient([mix(p.bg, p.surface, 0.45), p.bottom], 168, 180)
    # bobler som stiger fra bunnen
    c.particles(16, 44, 40, 300, 170, 50, [p.hi, mix(p.hi, p.line, 0.4), mix(p.line, p.surface, 0.3)], rise=True, sway=2)


TRIDENT_SIGN = """
 *     *     *
 #     #     #
 #    ###    #
 #     #     #
 #     #     #
 ##    #    ##
  ##+#*#*#+##
   ####+####
       #
       +
       #
       :
       #
       +
       #
       :
       #
       *
"""

SCENES = {
    "waves": (32, waves),
    "deep": (32, deep),
    "sign": sign(TRIDENT_SIGN, scale=4, dy=-6),
}
