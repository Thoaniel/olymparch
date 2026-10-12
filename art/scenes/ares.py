"""Ares: slagmarken i solnedgang med spyd og skjold, den korintiske hjelmen i gløden, spydet og skjoldet som
stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, W, hsh, mix

HELM = """
........CCCCCC........
.....CCCCCCCCCCCC......
...CCCCCCCCCCCCCCCC....
..CCCCCCCCCCCCCCCCCC...
.CCCCCCCC....CCCCCCCC..
.CCCCC..........CCCCC..
..........CC..........
......HHHHHHHHHH......
....HHHLLHHHHHHHHH....
...HHHLLHHHHHHHHHHH...
..HHHLLHHHHHHHHHHHHH..
..HHLLHHHHHHHHHHHHHD..
..HHLHHHHHHHHHHHHHHD..
..HH......HH......HD..
..HHH.....HH.....HHD..
..HHHH....HH....HHHD..
..HHHHH...HH...HHHHD..
..HLHHH...HH...HHHHD..
..HLHHHH..HH..HHHHHD..
..HLHHHH......HHHHHD..
..HHHHHH......HHHHHD..
..HHHHHH......HHHHHD..
...HHHHH......HHHHD...
...DHHHH......HHHHD...
....DHHH......HHHD....
.....DHH......HHD.....
"""


def battlefield(c):
    p = c.p
    # himmelen: mørk øverst, en blodrød stripe og bronse lavt ved horisonten
    c.gradient(p.night(3), 0, 80)
    c.gradient([p.night(3)[-1], mix(p.surface, p.danger, 0.18), mix(p.line, p.acc, 0.35), mix(p.acc, p.hi, 0.3)], 80, 132)
    c.disc(150, 132, 16, mix(p.acc, p.hi, 0.55))
    # fjerne åser og sletta
    c.ridge(134, 3, 6, mix(p.bg, p.line, 0.6), period=50)
    c.poly([(0, 180), (0, 146), (90, 140), (200, 144), (W, 138), (W, 180)], p.bottom)
    dark = p.bottom
    # spyd stukket i bakken, skrått, med blad
    for x0, lean, h in ((40, 6, 70), (58, -4, 64), (236, 5, 76), (262, -7, 62), (284, 3, 58)):
        top = (x0 + lean, 140 - h)
        c.line([(x0, 146), top], dark, 1)
        c.poly([(top[0] - 2, top[1] + 4), (top[0] + lean / 10, top[1] - 5), (top[0] + 2, top[1] + 4)], dark)
    # rundt skjold som lener seg mot et spyd, og ett som ligger
    c.disc(70, 132, 13, dark)
    c.disc(70, 132, 9, mix(dark, p.line, 0.35))
    c.disc(70, 132, 8, dark)
    c.ellipse(250, 146, 15, 4, dark)
    # en hjelm på et spydskaft
    c.sprite(HELM, 244, 54, {"C": dark, "H": dark, "L": dark, "D": dark}, scale=1)
    c.line([(254, 78), (254, 146)], dark)
    # støv som driver sakte over sletta (helt antall runder)
    dust = [mix(p.line, p.acc, 0.4), mix(p.line, p.acc, 0.2)]
    for i in range(40):
        u = (c.t + hsh(1, i)) % 1.0
        x = (hsh(2, i) * W + u * W) % W
        y = 120 + hsh(3, i) * 34 + 2 * math.sin(2 * math.pi * (u * 2 + hsh(4, i)))
        c.put(x, y, dust[i % 2])


def helm(c):
    p = c.p
    c.gradient(p.night(4))
    # gløden under hjelmen, pulserer sakte som glør
    c.glow(160, 150, 120, 70, p.halo, 0.95 + 0.08 * c.wave(1) + 0.03 * c.wave(3, 0.2))
    c.glow(160, 104, 60, 50, p.halo[:2], 0.7)
    bronze = {"H": p.gold[1], "L": p.gold[3], "D": p.gold[0], "C": mix(p.danger, p.bg, 0.45)}
    c.sprite(HELM, 160 - 33, 50, bronze, scale=3)
    # en hestehårskam med strå: ørlite lysere kant
    for x in range(160 - 24, 160 + 24, 3):
        c.put(x, 50, mix(p.danger, p.bg, 0.25))
    # glør som stiger
    c.particles(30, 7, 70, 250, 178, 110, [p.gold[4], p.gold[3], p.gold[2], p.gold[1]], sway=2.5, life=0.8)
    c.gradient([mix(p.bg, p.surface, 0.5), p.bottom], 160, 180)


SPEAR_SHIELD = """
.........................*
.......................+:.
......................:...
.......+*+*+.........:....
.....*#######*......:.....
....+#########+....:......
...*###########*..:.......
...+####:::####+.:........
..*####:###:####*.........
..+####:#*#:####+.........
..*####:###:####*.........
...+####:::####+..........
...*###########*..........
....+#########+...........
.....*#######*............
.......+*+*+..............
......:...................
.....:....................
....:.....................
...:......................
..+.......................
.*........................
"""

SCENES = {
    "battlefield": (32, battlefield),
    "helm": (32, helm),
    "sign": sign(SPEAR_SHIELD, scale=4, dy=-6),
}
