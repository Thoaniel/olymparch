"""Apollon (lyst tema): soloppgang med solvognen, den gylne lyren, sola som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, W, mix

HORSE = """
...........AA.......
..........AAAA......
.........AAAAA......
........AAAA.A......
.......AAAA.........
AA....AAAAA.........
.AAAAAAAAAAA........
..AAAAAAAAAA........
..AAAAAAAAA.........
..AA.AA..AA.........
.AA...A...AA........
.A....A....A........
"""

LYRE = """
...AA..................AA...
..AAAA................AAAA..
..A..AA..............AA..A..
.....AA..............AA.....
......A..............A......
......AA............AA......
......AABBBBBBBBBBBBAA......
.......A.C..C..C..C.A.......
.......A.C..C..C..C.A.......
.......A.C..C..C..C.A.......
.......AA.C.C..C.C.AA.......
........A.C.C..C.C.A........
........AA.CC..CC.AA........
.........A.CC..CC.A.........
.........AA.C..C.AA.........
..........AAAAAAAA..........
.........AAAAAAAAAA.........
..........AAAAAAAA..........
"""


def sunrise(c):
    p = c.p
    sky = [p.bg, p.bg, mix(p.bg, p.hi, 0.06), mix(p.bg, (255, 214, 120), 0.22), mix(p.bg, (255, 196, 110), 0.38)]
    c.gradient(sky, 0, 130)
    cx, cy = 160, 128
    # strålene: en vifte som dreier sakte (to av 16 posisjoner per løkke: sømløst)
    ray = mix(p.bg, (255, 214, 120), 0.3)
    rot = c.loop(1) * (math.pi / 8)
    # dithret: bare annenhver piksel, så strålene blir et mildt slør
    for y in range(44, cy):
        for x in range(W):
            if (x + y) % 2:
                continue
            ang = math.atan2(y - cy, x - cx) - rot
            if ang % (math.pi / 8) < math.pi / 26:
                c.put(x, y, ray)
    c.glow(cx, cy, 80, 60, p.halo, 1.0)
    c.disc(cx, cy, 30, mix(p.bg, (255, 205, 110), 0.55))
    c.disc(cx, cy, 25, mix(p.bg, (255, 190, 90), 0.7))
    # solvognen i silhuett foran sola, gyngende ørlite
    bob = round(c.wave(2) * 0.6)
    dark = p.gold[1]
    c.sprite(HORSE, cx - 14, cy - 27 + bob, {"A": mix(dark, p.bg, 0.25)}, scale=2)
    c.sprite(HORSE, cx - 6, cy - 25 - bob, {"A": dark}, scale=2)
    # vogna: kassa og et hjul med eiker bak hestene
    c.line([(cx - 14, cy - 12), (cx - 6, cy - 12)], dark, 2)
    # vognkassa: lav bak, buet og høy foran
    c.poly([(cx - 29, cy - 11), (cx - 14, cy - 11), (cx - 12, cy - 14), (cx - 13, cy - 19), (cx - 16, cy - 22),
            (cx - 17, cy - 18), (cx - 23, cy - 15), (cx - 29, cy - 15)], dark)
    for a in range(28):
        ang = a * math.pi / 14
        c.put(cx - 21 + 7 * math.cos(ang), cy - 5 + 7 * math.sin(ang), dark)
        c.put(cx - 21 + 6 * math.cos(ang), cy - 5 + 6 * math.sin(ang), dark)
    for a in range(4):
        ang = a * math.pi / 4 + c.loop(1) * math.pi / 2
        c.line([(cx - 21 - 5 * math.cos(ang), cy - 5 - 5 * math.sin(ang)), (cx - 21 + 5 * math.cos(ang), cy - 5 + 5 * math.sin(ang))], dark)
    # havet: lyse bånd med glitter under sola
    c.gradient([mix(p.bg, p.line, 0.35), mix(p.bg, p.line, 0.2), p.bg], 130, 180)
    for y in range(132, 180, 3):
        w = int(10 + (y - 130) * 0.9)
        for x in range(cx - w, cx + w, 2):
            if (x + y + c.n * 2) % 9 < 3:
                c.put(x + int(c.wave(1, y / 30) * 2), y, mix(p.bg, (255, 196, 110), 0.5))
    land = mix(p.bg, p.line, 0.55)
    c.poly([(0, 180), (0, 146), (30, 143), (60, 148), (95, 160), (130, 180)], land)
    c.poly([(W, 180), (W, 142), (280, 145), (250, 152), (215, 166), (195, 180)], land)


def lyre(c):
    p = c.p
    c.gradient([p.bg, p.bg, mix(p.bg, p.raised, 0.6), mix(p.bg, p.raised, 1.0)])
    c.glow(160, 100, 100, 80, p.halo, 0.95 + 0.05 * c.wave(1))
    # lyren, skalert ×3, i et mildt gull-brunt (ikke tyngre enn vinduene foran den)
    c.sprite(LYRE, 160 - 42, 100 - 27, {"A": mix(p.bg, p.acc, 0.55), "B": mix(p.bg, p.acc, 0.7), "C": mix(p.bg, p.acc, 0.3)}, scale=3)
    # gylne lysfnugg som stiger sakte
    c.particles(26, 4, 70, 250, 150, 50, [p.gold[3], p.gold[2], mix(p.bg, p.gold[2], 0.5)], sway=3, life=0.9)
    # et lavt marmorgulv
    c.gradient([mix(p.bg, p.line, 0.25), mix(p.bg, p.line, 0.4)], 160, 180)
    for x in range(0, W, 32):
        c.line([(x, 160), (x - 6, 180)], mix(p.bg, p.line, 0.55))


SUN = """
            *           *
            #           #
             #         #
             #         #
             #         #
              #       #
              +       +

               ###+###
   *#         #       #         #*
     ###     #         #     ###
        #+  #           #  +#
            #           #
           #             #
           #             #
           +      *      +
           #             #
           #             #
            #           #
        #+  #           #  +#
     ###     #         #     ###
   *#         #       #         #*
               ###+###

              +       +
              #       #
             #         #
             #         #
             #         #
            #           #
            *           *
"""

SCENES = {
    "sunrise": (32, sunrise),
    "lyre": (32, lyre),
    "sign": sign(SUN, scale=4, dy=-6),
}
