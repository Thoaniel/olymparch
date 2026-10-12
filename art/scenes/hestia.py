"""Hestia: ildstedet i et stille hus, oljelampene i nisjene, flammen som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import TAU, H, W, hsh, mix

LAMP = """
.........FF..
........FFF..
.......BBB...
.......B.....
.AAAAAAAAA...
AAAAAAAAAAAAA
.AAAAAAAAAAA.
...AAAAAAA...
....CCCCC....
"""


def flame(c, cx, base, width, height, colors, seed=0):
    """en rolig flamme: tunger med høyde som bølger sakte; colors fra kanten til kjernen"""
    for x in range(int(cx - width), int(cx + width) + 1):
        d = abs(x - cx) / width
        if d > 1:
            continue
        h = height * (1 - d ** 1.5) * (0.82 + 0.12 * c.wave(1, x / 9.0 + seed) + 0.06 * c.wave(3, x / 4.0 + seed))
        for y in range(int(base - h), int(base) + 1):
            v = (y - (base - h)) / max(1.0, h) * (1 - d * 0.6)
            c.put(x, y, c.pick(colors, v, x, y))


def hearth(c):
    p = c.p
    wall = mix(p.bg, p.surface, 0.55)
    c.gradient([p.bottom, wall, mix(p.surface, p.raised, 0.6)], 0, 140)
    breath = 0.85 + 0.15 * c.wave(1)
    c.glow(160, 122, 150, 90, p.halo, breath)
    # det runde ildstedet av stein midt i rommet (Hestias ild), lave murer
    c.gradient([mix(p.surface, p.line, 0.35), p.surface, p.bottom], 140, 180)
    c.glow(160, 146, 110, 24, p.halo[:3], breath, top=140)
    stone = mix(p.surface, p.line, 0.6)
    c.ellipse(160, 146, 52, 10, mix(p.bg, p.surface, 0.5))
    for i in range(14):  # steinene rundt kanten
        a = math.pi * (i / 13)
        x = 160 - 50 * math.cos(a)
        c.rect(int(x) - 3, 140, int(x) + 3, 150, stone if i % 2 else mix(stone, p.bg, 0.25))
    c.rect(108, 146, 212, 154, mix(stone, p.bg, 0.35))
    # vedkubber og glør
    log = mix(p.bg, p.line, 0.45)
    c.line([(132, 141), (176, 133)], log, 3)
    c.line([(146, 133), (190, 141)], log, 3)
    flame(c, 160, 138, 22, 34, [p.gold[0], p.gold[1], p.gold[2], p.gold[3], p.gold[4]])
    flame(c, 160, 138, 10, 20, [p.gold[2], p.gold[3], p.gold[4]], seed=0.4)
    c.particles(8, 3, 146, 174, 104, 60, [p.gold[3], p.gold[2], p.gold[1]], sway=3, life=0.6)


def lamp(c):
    p = c.p
    wall = mix(p.bg, p.surface, 0.5)
    c.gradient([p.bottom, wall, mix(p.surface, p.raised, 0.4)], 0, 150)
    c.gradient([mix(p.surface, p.line, 0.25), p.bottom], 150, 180)
    # tre nisjer i veggen; en oljelampe i hver, den midterste størst
    for k, (cx, s, ph) in enumerate(((76, 2, 0.2), (160, 3, 0.0), (244, 2, 0.6))):
        hw = 10 * s
        bot = 150
        top = bot - 26 * s
        breath = 0.85 + 0.12 * c.wave(1, ph)
        c.rect(cx - hw, top + hw, cx + hw, bot, mix(p.bg, wall, 0.45))
        c.ellipse(cx, top + hw, hw, hw, mix(p.bg, wall, 0.45))
        lx, ly = cx - int(6.5 * s), bot - 9 * s
        fx, fy = lx + 9.5 * s, ly + 2 * s
        c.glow(fx, fy - 4 * s, 16 * s, 16 * s, p.halo, breath, top=top - hw)
        c.sprite(LAMP, lx, ly, {"A": mix(p.line, p.acc, 0.3), "B": p.gold[1], "C": mix(p.line, p.acc, 0.2), "F": None}, scale=s)
        flame(c, fx, fy, 1.6 * s, 6 * s, [p.gold[1], p.gold[2], p.gold[3], p.gold[4]], seed=ph)
    # en svak røykstripe fra den midterste lampa
    for i in range(10):
        u = c.loop(1, i / 10)
        c.put(173 + 3 * math.sin(TAU * (u * 1.5 + c.t)), 104 - u * 34, mix(wall, p.line, 0.6 * (1 - u)))


EMBLEM = """
........*.........
.......*#*........
......*##*........
......*###*.......
.....*####*..*....
....*#####*.*#*...
...*######**##*...
...*###########*..
..*####+##+####*..
..*###+####+###*..
..*###+####+###*..
...*###+##+###*...
....*###++###*....
.....**#####**....
.......*****......
"""

SCENES = {
    "hearth": (32, hearth),
    "lamp": (32, lamp),
    "sign": sign(EMBLEM, scale=4, dy=-6),
}
