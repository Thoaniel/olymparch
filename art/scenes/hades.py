"""Hades: Kharon over Styx med lykta, glør i underverdenen, tohodet spyd (bidenten) som stjernebilde.
(Tempelet er art/torch.py.)"""
import math

from common import constellation, sign
from pixel import H, TAU, W, hsh, mix

BOAT = """
....................c.........
....................c.........
.........aa.........c.........
........aaaa........c.........
........aaaa.......cc.........
.......aaaaaa.....c...........
.......aaaaaa....c............
......aaaaaaaa..c.............
......aaaaaaaa.c..............
.....aaaaaaaaac...............
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
.bbbbbbbbbbbbbbbbbbbbbbbbbbbb.
..bbbbbbbbbbbbbbbbbbbbbbbbbb..
....bbbbbbbbbbbbbbbbbbbbbb....
"""

POMEGRANATE = """
....a.a....
.....a.....
...bbbbb...
..bbbbbbb..
.bbbcbbbbb.
.bbcbbbbbb.
.bbbbbbbbb.
.bbbbbbbbb.
..bbbbbbb..
...bbbbb...
"""


def cave(c, light):
    """hulens tak og vegger: mørke drypp-steiner ovenfra, knauser på sidene"""
    p = c.p
    rock = mix(p.bg, p.surface, 0.35)
    for x in range(W):
        h = 10 + 6 * math.sin(x / 13.0) + 4 * math.sin(x / 5.3 + 1) + 10 * hsh(x // 7, 1) * (x % 7 < 3)
        for y in range(0, int(h)):
            c.px[x, y] = rock
    c.poly([(0, 40), (24, 70), (16, 120), (34, 180), (0, 180)], rock)
    c.poly([(320, 30), (296, 80), (306, 128), (284, 180), (320, 180)], rock)


def styx(c):
    p = c.p
    horizon = 118
    c.gradient([p.bottom, mix(p.bg, p.surface, 0.8), mix(p.surface, p.line, 0.3)], 0, horizon)
    # tåke langs elva
    c.glow(160, horizon - 4, 190, 26, [mix(p.surface, p.line, 0.45), mix(p.surface, p.line, 0.75)], 0.9 + 0.1 * c.wave(1))
    c.ridge(horizon, 6, 3, mix(p.bg, p.surface, 0.55), period=30)
    # vannet
    for y in range(horizon, H):
        k = (y - horizon) / (H - horizon)
        for x in range(W):
            w = math.sin(x / 9.0 + y * 1.3 - TAU * c.loop(1)) * 0.1
            c.px[x, y] = c.pick([p.surface, mix(p.bg, p.surface, 0.5), p.bottom], k + w, x, y)
    cave(c, 0)
    # Kharon i båten; båten gynger litt, lykta flakker
    bob = round(1 * c.wave(1))
    bx, by = 136, horizon - 12 + bob
    fl = 0.85 + 0.1 * c.wave(3) + 0.05 * c.wave(7, 0.3)
    lx, ly = bx + 48, by - 6
    c.glow(lx, ly, 50 * fl, 42 * fl, [mix(p.bg, p.hi, 0.1), mix(p.bg, p.hi, 0.18), mix(p.bg, p.hi, 0.28), mix(p.bg, p.hi, 0.42)], fl)
    c.sprite(BOAT, bx, by - 10, {"a": p.bottom, "b": p.bottom, "c": mix(p.line, p.muted, 0.3)}, scale=2)
    # lyset fra lykta på kappa og båtripa
    for j in range(8, 20, 2):
        c.put(bx + 2 * (9 + j // 2 - 4) + 4, by - 10 + j, mix(p.hi, p.bg, 0.55))
    c.line([(bx + 30, by + 10), (bx + 58, by + 10)], mix(p.hi, p.bg, 0.5))
    # lykta på en stang i baugen
    c.line([(bx + 56, by + 10), (bx + 56, by - 10), (lx, by - 10)], mix(p.line, p.muted, 0.3))
    c.rect(lx - 2, ly - 3, lx + 2, ly + 3, p.gold[0])
    c.rect(lx - 1, ly - 2, lx + 1, ly + 2, p.hi)
    c.put(lx, ly - 1 + (c.wave(5) > 0), mix(p.hi, p.text, 0.6))
    # speilbildet av lykta: korte streker som skjelver
    for i, y in enumerate(range(horizon + 8, H - 6, 3)):
        half = 2 + i // 2
        off = round(2 * math.sin(TAU * c.loop(2) + i))
        for x in range(lx - half + off, lx + half + off):
            if (x + i) % 3:
                c.put(x, y, mix(p.hi, p.bg, 0.35 + 0.05 * i))
    # sjeler: noen svake lys som driver over vannet
    c.particles(5, 61, 30, 290, 150, 120, [mix(p.acc, p.bg, 0.4), mix(p.acc, p.bg, 0.6)], rise=True, sway=3)


def embers(c):
    p = c.p
    c.gradient([p.bottom, p.bottom, mix(p.bg, p.surface, 0.6), mix(p.surface, p.line, 0.25)], 0, H)
    # glødende sprekk i bunnen; den puster sakte
    fl = 0.9 + 0.1 * c.wave(2)
    warm = [mix(p.bg, p.hi, 0.12), mix(p.bg, p.hi, 0.22), mix(p.bg, p.hi, 0.36), mix(p.bg, p.hi, 0.55)]
    c.glow(160, 190, 230, 70, warm, fl)
    cave(c, 1)
    # bakken og en hylle med granateplet
    c.ridge(168, 5, 6, mix(p.bg, p.surface, 0.4), period=35)
    for x in range(40, 290):
        if math.sin(x / 9.0 + TAU * c.loop(1)) > 0.6 and x % 3:
            c.put(x, 171 + (x % 2), mix(p.hi, p.danger, 0.3))
    ledge = mix(p.bg, p.surface, 0.55)
    c.poly([(200, 132), (262, 128), (270, 138), (196, 140)], ledge)
    c.poly([(196, 140), (270, 138), (262, 180), (214, 180)], mix(p.bg, p.surface, 0.3))
    c.glow(232, 120, 22, 18, [mix(p.bg, p.acc, 0.25), mix(p.bg, p.acc, 0.4)], 0.8 + 0.1 * c.wave(1))
    c.sprite(POMEGRANATE, 221, 108, {"a": mix(p.line, p.acc, 0.4), "b": mix(p.danger, p.bg, 0.5), "c": mix(p.danger, p.text, 0.25)}, scale=2)
    # glør som stiger og slukner
    c.particles(26, 71, 50, 270, 168, 70, [p.gold[4], p.hi, mix(p.hi, p.danger, 0.4), mix(p.danger, p.bg, 0.55)], rise=True, sway=3)
    c.particles(14, 72, 80, 240, 168, 110, [p.hi, mix(p.hi, p.bg, 0.5)], rise=True, sway=1.5, life=0.7)


# tveforken: to brede tinder med mothaker, en tverrstang og et langt skaft
BIDENT = constellation(33, 42, lines=[[(16, 12), (16, 41)], [(4, 12), (28, 12)], [(4, 12), (4, 0)], [(28, 12), (28, 0)],
                                      [(4, 0), (1, 5)], [(28, 0), (31, 5)], [(4, 12), (7, 16), (16, 16)], [(28, 12), (25, 16), (16, 16)]],
                       stars=[(4, 0), (28, 0), (4, 12), (28, 12), (16, 41), (16, 12)], small=[(1, 5), (31, 5), (16, 16)])


SCENES = {
    "styx": (32, styx),
    "embers": (32, embers),
    "sign": sign(BIDENT, scale=3, dy=-6),
}
