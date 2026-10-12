"""Hefaistos: smia med ambolten, Etna om natten, hammer og tang som stjernebilde. (Tempelet er art/torch.py.)"""
from common import sign
from pixel import H, W, mix

ANVIL = """
AAAAAAAAAAAAAAAAAAAAAAAAAAAA......
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
.BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.
...CCCCCCCCCCCCCCCCCCCCCCCCCCC....
.......CCCCCCCCCCCCCCCCCCC........
..........CCCCCCCCCCCCC...........
..........CCCCCCCCCCCCC...........
..........CCCCCCCCCCCCC...........
.......CCCCCCCCCCCCCCCCCCC........
.....CCCCCCCCCCCCCCCCCCCCCCC......
.....DDDDDDDDDDDDDDDDDDDDDDD......
"""

HAMMER = """
..AAAAAAAA....
.ABBBBBBBBA...
.ABBBBBBBBA...
..AAAAAAAA....
.....CC.......
.....CC.......
.....CC.......
.....CC.......
.....CC.......
.....CC.......
.....CC.......
.....CC.......
"""


def forge(c):
    p = c.p
    wall = mix(p.bg, p.surface, 0.6)
    c.gradient([p.bottom, wall, mix(p.surface, p.raised, 0.5)], 0, 130)
    # steinvegg: svake fuger
    for y in range(40, 130, 9):
        off = 0 if (y // 9) % 2 else 11
        for x in range(off, W, 22):
            c.line([(x, y), (x, y + 8)], mix(wall, p.bg, 0.5))
        c.line([(0, y), (W, y)], mix(wall, p.bg, 0.5))
    # essa til venstre: en bue med glør som pulserer sakte
    breath = 0.85 + 0.15 * c.wave(1)
    c.glow(78, 112, 70, 50, p.halo, breath)
    c.poly([(40, 130), (40, 92), (56, 80), (100, 80), (116, 92), (116, 130)], mix(p.bg, p.surface, 0.4))
    c.rect(54, 96, 102, 122, p.bg)
    c.ellipse(78, 96, 24, 10, p.bg)
    # glør i bunnen og rolige flammetunger over dem
    for x in range(56, 101):
        h = 8 + 4 * c.wave(1, x / 17.0) + 3 * c.wave(2, x / 7.0 + 0.3)
        for y in range(int(122 - h), 122):
            v = (y - (122 - h)) / max(1.0, h)
            c.put(x, y, c.pick([p.gold[1], p.gold[2], p.gold[3], p.gold[2]], v * breath, x, y))
        for y in range(118, 122):
            c.put(x, y, c.pick([p.gold[0], p.gold[1], p.gold[2]], 0.4 + 0.3 * c.wave(1, x / 9.0), x, y))
    c.glow(78, 116, 26, 12, [p.gold[2], p.gold[3]], 0.35 * breath)
    # gulvet
    c.gradient([mix(p.surface, p.line, 0.3), p.surface, p.bottom], 130, 180)
    c.glow(190, 132, 120, 22, p.halo[:3], 0.8, top=130)
    # ambolten med hammeren lent mot
    c.sprite(ANVIL, 150, 112, {"A": mix(p.line, p.acc, 0.45), "B": mix(p.surface, p.line, 0.6), "C": mix(p.bg, p.surface, 0.5), "D": p.bg}, scale=2)
    c.sprite(HAMMER, 228, 108, {"A": mix(p.line, p.text, 0.2), "B": mix(p.surface, p.line, 0.8), "C": mix(p.line, p.acc, 0.25)}, scale=2)
    # et glødende emne på ambolten og rolige gnister som stiger
    c.rect(170, 110, 190, 111, p.gold[3])
    c.rect(191, 110, 192, 111, p.gold[4])
    c.particles(10, 5, 168, 194, 108, 70, [p.gold[4], p.gold[3], p.gold[2], p.gold[1]], sway=2.5, life=0.7)
    c.particles(8, 9, 60, 96, 92, 50, [p.gold[3], p.gold[2], p.gold[1]], sway=2, life=0.6)


def volcano(c):
    p = c.p
    c.gradient(p.night(4), 0, 150)
    c.stars(110, 13, 20, 90)
    c.glow(176, 70, 90, 50, p.halo[:3], 0.75 + 0.1 * c.wave(1))
    # røyksøylen driver sakte mot høyre
    for i in range(7):
        u = c.loop(1, i / 7)
        y = 66 - u * 46
        x = 176 + u * 40 + 3 * c.wave(1, i / 7)
        r = 7 + u * 12
        col = mix(p.surface, p.line, 0.35 * (1 - u))
        c.ellipse(x, y, r, r * 0.6, col)
    # fjerne åser og fjellet
    c.ridge(150, 6, 4, mix(p.bg, p.surface, 0.55), period=50)
    c.poly([(70, 180), (160, 72), (192, 72), (300, 180)], mix(p.bg, p.surface, 0.35))
    c.poly([(160, 72), (192, 72), (186, 78), (166, 78)], p.gold[1])
    # lavaelver ned flanken, som glør sakte
    for k, (x0, dx) in enumerate(((170, -1.1), (182, 0.9), (176, 0.2))):
        for j in range(60):
            x = x0 + dx * j * 0.6 + 2 * (((j // 6) % 2) - 0.5)
            y = 78 + j
            v = 0.9 - j / 75 + 0.15 * c.wave(1, j / 30 + k / 3)
            c.put(x, y, c.pick([None, p.gold[0], p.gold[1], p.gold[2], p.gold[3]], v, int(x), y))
    c.glow(176, 73, 16, 6, [p.gold[2], p.gold[3]], 0.8)
    c.poly([(0, 180), (0, 158), (90, 150), (180, 172), (200, 180)], p.bottom)
    c.poly([(200, 180), (260, 162), (320, 160), (320, 180)], p.bottom)


EMBLEM = """
..****####****......
..*##########*......
..****####****......
.......##...........
.......##.......*...
.......##......*#*..
.......##.....*#*...
.......##....*#*....
.......##...*#*.....
.......##..*#*......
.......##.*#*.......
.......*.*#*........
.........##*........
........*#*.*.......
.......*#*...*......
......*#*.....*.....
.....*#*.......*....
.....**.............
"""

SCENES = {
    "forge": (32, forge),
    "volcano": (32, volcano),
    "sign": sign(EMBLEM, scale=4, dy=-6),
}
