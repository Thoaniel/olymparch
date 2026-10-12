"""Artemis: måne over skogen med ildfluer, hjorten og buen under stjernene, buen som stjernebilde.
(Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, W, hsh, mix


def pine(c, x, base, h, col):
    """et grantre: trekanter i lag oppå hverandre"""
    for k in range(4):
        top = base - h + k * h // 4
        w = 2 + (k + 1) * h // 9
        c.poly([(x, top), (x - w, top + h // 3), (x + w, top + h // 3)], col)
    c.rect(x - 1, base - 3, x, base, col)


def forest(c, base, h, seed, col, step):
    x = -step // 2
    i = 0
    while x < W + step:
        hh = int(h * (0.7 + 0.5 * hsh(seed, i)))
        pine(c, x + int(hsh(seed, i, 2) * step * 0.5), base, hh, col)
        x += step
        i += 1
    c.rect(0, base, W, H, col)


def moonforest(c):
    p = c.p
    c.gradient(p.night(5), 0, 150)
    c.stars(120, 21, 20, 110)
    c.moon(214, 74, 15, mix(p.acc, p.hi, 0.5), shadow=mix(p.acc, p.hi, 0.1),
           glow=[mix(p.bottom, p.line, 0.35), mix(p.surface, p.line, 0.6)])
    # skogen i tre lag, fra blek i det fjerne til nesten svart foran
    forest(c, 140, 34, 3, mix(p.surface, p.line, 0.45), 14)
    forest(c, 156, 40, 5, mix(p.bg, p.surface, 0.9), 18)
    forest(c, 176, 52, 9, p.bottom, 24)
    # ildfluer: svever og blinker sakte mellom trærne
    for i in range(14):
        x = 20 + hsh(4, i) * 280 + 6 * math.sin(2 * math.pi * (c.t + hsh(5, i)))
        y = 140 + hsh(6, i) * 30 + 3 * math.sin(2 * math.pi * (c.t * 2 + hsh(7, i)))
        b = 0.5 + 0.5 * math.sin(2 * math.pi * (c.t * (1 + i % 2) + hsh(8, i)))
        if b > 0.35:
            col = mix(p.hi, (255, 236, 150), 0.45)
            c.put(x, y, col if b > 0.7 else mix(col, p.bottom, 0.45))
            if b > 0.7:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    c.put(x + dx, y + dy, mix(col, p.bottom, 0.65))


DEER = """
..A.A....A.A..........
...AA.....AA..........
....A.A.A.A...........
.....AA.AA............
......AAA.............
.....AAAA.............
....AAAAA.............
.......AA.............
.......AAA............
........AAAAAAAAAAAAA.
........AAAAAAAAAAAAAA
........AAAAAAAAAAAAAA
.........AAAAAAAAAAAA.
.........AA.A.....AA.A
.........A..A.....A..A
.........A..A.....A..A
.........A..A.....A..A
"""


def hind(c):
    p = c.p
    c.gradient(p.night(5), 0, 140)
    c.stars(150, 33, 20, 130)
    # en tynn nymåne
    c.glow(92, 70, 30, 30, [mix(p.bottom, p.line, 0.3)], 0.6)
    for y in range(58, 83):
        for x in range(80, 105):
            if (x - 92) ** 2 + (y - 70) ** 2 <= 100 and (x - 96) ** 2 + (y - 67) ** 2 > 90:
                c.put(x, y, mix(p.acc, p.hi, 0.5))
    # bakken: en ås, hjorten på toppen i silhuett
    c.ridge(150, 6, 4, mix(p.surface, p.line, 0.3), period=80)
    c.poly([(0, 180), (0, 160), (120, 150), (190, 136), (260, 146), (W, 158), (W, 180)], p.bottom)
    c.sprite(DEER, 160, 139 - 51, {"A": p.bottom}, scale=3)
    # noen gress-strå som vaier
    for i in range(30):
        x = int(hsh(9, i) * W)
        top = 150 + int(hsh(10, i) * 20)
        sway = round(math.sin(2 * math.pi * (c.t + hsh(11, i))) * 1.2)
        c.line([(x, top + 8), (x + sway, top)], mix(p.bottom, p.surface, 0.6))


BOW = """
........*..........
.......+#:.........
......*#..:........
.....+#....:.......
....*#......:......
....+#.......:.....
...*#.........:....
...+#..........:...
..*#............:..
..+#.............:.
*:*#::::::::::::::*
..+#.............:.
..*#............:..
...+#..........:...
...*#.........:....
....+#.......:.....
....*#......:......
.....+#....:.......
......*#..:........
.......+#:.........
........*..........
"""

SCENES = {
    "moonforest": (32, moonforest),
    "hind": (32, hind),
    "sign": sign(BOW, scale=4, dy=-8),
}
