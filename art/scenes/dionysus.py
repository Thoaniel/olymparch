"""Dionysos: vinmarken i skumringen, en drueklase over vinskålen, druene som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import TAU, H, W, hsh, mix

LEAF = """
..LL.LL..
.LLLLLLL.
LLLLlLLLL
.LLLlLLL.
..LLlLL..
...LLL...
....L....
"""

KYLIX = """
CCCCCCCCCCCCCCCCCCCCCCCCCC
.CWWWWWWWWWWWWWWWWWWWWWWC.
H.CCCCCCCCCCCCCCCCCCCCCC.H
HH..CCCCCCCCCCCCCCCCCC..HH
.......CCCCCCCCCCCC.......
...........CCCC...........
...........CCCC...........
.........CCCCCCCC.........
.......CCCCCCCCCCCC.......
"""


def vineyard(c):
    p = c.p
    c.gradient(p.night(4), 0, 100)
    c.gradient([mix(p.surface, p.line, 0.35), mix(p.line, p.acc, 0.3), mix(p.acc, p.line, 0.5)], 88, 118)
    c.stars(80, 41, 20, 80, twinkle=0.25)
    c.ridge(116, 7, 5, mix(p.bg, p.surface, 0.7), period=50)
    # radene med vinstokker løper mot en forsvinningslinje midt i bildet
    c.gradient([mix(p.bg, p.surface, 0.6), mix(p.bg, p.surface, 0.3)], 116, 180)
    vx, vy = 160, 112
    for r in range(-7, 8):
        bx = 160 + r * 70
        n = 16
        for i in range(n):
            u = (i / n) ** 1.6
            x = vx + (bx - vx) * u
            y = vy + (180 - vy) * u + 4 * u
            size = 1 + u * 7
            col = mix(p.bg, p.line, 0.25 + 0.4 * u)
            c.ellipse(x, y - size * 0.7, size * 1.3, size * 0.8, col)
            if u > 0.3 and hsh(r, i) > 0.5:  # druer i de nære radene
                c.disc(x + size * 0.4, y, max(1, size * 0.28), mix(p.acc, p.bg, 0.35))
    # ildfluer som svever sakte
    for i in range(14):
        x = hsh(5, i) * W + 6 * math.sin(TAU * (c.t + hsh(6, i)))
        y = 104 + hsh(7, i) * 60 + 4 * math.sin(TAU * (c.t * 2 + hsh(8, i)))
        on = 0.5 + 0.5 * math.sin(TAU * (c.t * (1 + i % 2) + hsh(9, i)))
        if on > 0.35:
            c.put(x, y, p.hi if on > 0.75 else mix(p.hi, p.bg, 0.4))


def grapes(c):
    p = c.p
    c.gradient(p.night(5))
    c.stars(60, 51, 30, 110, twinkle=0.2)
    c.glow(160, 112, 110, 70, p.halo[:3], 0.9 + 0.08 * c.wave(1))
    # en vinranke som henger ned fra oven til venstre, svaier knapt
    sway = 1.5 * c.wave(1)
    vine = mix(p.line, p.text, 0.1)
    pts = [(0, 58), (40, 64), (80, 62), (112, 68), (120 + sway, 74)]
    c.line(pts, vine, 2)
    c.line([(60, 63), (66, 72), (60, 80), (64, 86)], vine)
    leaf = {"L": mix(p.surface, p.line, 0.75), "l": mix(p.line, p.text, 0.2)}
    for x, y in ((20, 62), (78, 64), (126, 60)):
        c.sprite(LEAF, x, y, leaf, scale=3)
    # drueklasen: blå-lilla druer med en lys flekk, litt ujevn
    gx, gy = 120 + sway, 78
    c.line([(gx, 72), (gx, 82)], vine, 2)
    dark, mid, hi = mix(p.hi, p.bg, 0.62), mix(mix(p.hi, p.acc, 0.25), p.bg, 0.25), mix(p.hi, p.text, 0.3)
    rows = [5, 6, 6, 5, 5, 4, 3, 2, 1]
    for j, n in enumerate(rows):
        for i in range(n):
            x = gx - (n - 1) * 3.4 + i * 6.8 + (hsh(i, j) - 0.5) * 2 + (j % 2) * 1.5
            y = gy + 8 + j * 5.6 + (hsh(j, i) - 0.5) * 1.5
            c.disc(x, y, 3.6, dark)
            c.disc(x - 0.7, y - 0.7, 2.6, mid)
            c.put(x - 1.5, y - 1.5, hi)
    # vinskålen (kylix) på et bord, med vin som skinner svakt
    c.rect(0, 152, W, 180, mix(p.bg, p.surface, 0.45))
    c.line([(0, 152), (W, 152)], mix(p.surface, p.line, 0.6))
    c.sprite(KYLIX, 166, 134, scale=2, colors={"C": mix(p.line, p.acc, 0.35), "H": mix(p.line, p.acc, 0.35),
                               "W": mix(p.acc, p.danger, 0.3)})
    c.rect(170 + int(36 * (0.5 + 0.5 * c.wave(1))), 136, 171 + int(36 * (0.5 + 0.5 * c.wave(1))), 137, mix(p.acc, p.hi, 0.5))  # lyset glir sakte over vinen


EMBLEM = """
.......*##*.......
......*####*......
.......*##*.......
........##........
...*#*.*##*.*#*...
..*###*####*###*..
...*#*######*#*...
....*#########....
...*##*####*##*...
....*########*....
.....*##*##*##....
......*#####*.....
.......*###*......
........*#*.......
.........*........
"""


SCENES = {
    "vineyard": (32, vineyard),
    "grapes": (32, grapes),
    "sign": sign(EMBLEM, scale=4, dy=-6),
}
