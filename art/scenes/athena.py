"""Athene: ugla på olivengrenen i måneskinn, Parthenon i måneskinn, ugla som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, W, hsh, mix

OWL = """
..a..........a..
..aa........aa..
..abbbbbbbbbba..
.bbbbbbbbbbbbbb.
.bccccbbbbccccb.
bcceeccbbcceeccb
bcceEccbbcceEccb
bccceccbbcccccb.
.bccccbddbccccb.
.bbbbbbddbbbbbb.
.bbfbbbbbbbbfbb.
bbbbfbbbbbbfbbbb
bbfbbbfbbfbbbfbb
bbbbfbbbbbbfbbbb
bbfbbbfbbfbbbfbb
.bbbbfbbbbfbbbb.
.bbfbbbbbbbbfbb.
..bbbbbbbbbbbb..
...bbbbbbbbbb...
....gg....gg....
"""

OWL_SHUT = """
bcccccbbbccccccb
bceeeccbbceeeccb
bccccccbbcccccb.
"""

PARTHENON = """
...............aaaaaaaa...............
..........aaaaaaaaaaaaaaaaaa..........
.....aaaaaaaaaaaaaaaaaaaaaaaaaaaa.....
..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa..
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
cccccccccccccccccccccccccccccccccccccc
.dd.dd.dd.dd.dd.dd.dd.dd.dd.dd.dd.dd..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
.de.de.de.de.de.de.de.de.de.de.de.de..
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
cccccccccccccccccccccccccccccccccccccc
"""


def owl(c):
    p = c.p
    c.gradient(p.night(4))
    c.stars(110, 51, 34, 120, twinkle=0.25)
    c.moon(214, 86, 26, mix(mix(p.text, p.hi, 0.3), p.line, 0.4), shadow=mix(mix(p.hi, p.muted, 0.6), p.line, 0.4),
           glow=[mix(p.bottom, p.surface, 0.8), mix(p.surface, p.line, 0.35)])
    # olivengrenen inn fra venstre, svaier litt
    sway = c.wave(1)
    wood = mix(p.bg, p.surface, 0.25)
    pts = [(0, 132), (60, 128), (120, 124), (180, 121), (250, 126), (290, 132)]
    c.line(pts, wood, width=4)
    leaf, leaf2 = mix(p.acc, p.bg, 0.45), mix(p.acc, p.bg, 0.65)
    for i in range(22):
        x = 8 + i * 13
        y = 128 - x * 0.05 + (x > 200) * (x - 200) * 0.12
        side = 1 if i % 2 else -1
        dx = round(sway * (1 + hsh(i, 2)) * 0.8)
        for k in range(7):
            c.put(x + k + dx * (k > 3), y + side * (2 + k * 0.6), leaf if k % 2 else leaf2)
            c.put(x + k + dx * (k > 3), y + side * (3 + k * 0.6), leaf2)
        if i % 4 == 1:  # oliven
            c.disc(x + 3, y + side * 8, 1.6, mix(p.surface, p.line, 0.6))
    # ugla, i silhuett mot månen; blunker én gang i løkka
    ox, oy = 198, 82
    cols = {"a": mix(p.line, p.muted, 0.2), "b": mix(p.bg, p.surface, 0.55), "c": mix(p.surface, p.line, 0.5),
            "d": p.gold[2], "e": p.gold[3], "E": p.bg, "f": mix(p.surface, p.line, 0.25), "g": p.gold[1]}
    c.sprite(OWL, ox, oy, cols, scale=2)
    if c.n in (22, 23):
        c.sprite(OWL_SHUT, ox, oy + 10, cols, scale=2)
    c.gradient([mix(p.bg, p.surface, 0.3), p.bottom], 166, 180)


def parthenon(c):
    p = c.p
    c.gradient(p.night(5), 0, 140)
    c.stars(130, 53, 34, 110, twinkle=0.3)
    c.moon(78, 64, 9, mix(p.text, p.hi, 0.3), shadow=mix(p.hi, p.muted, 0.6),
           glow=[mix(p.bottom, p.surface, 0.8), mix(p.surface, p.line, 0.35)])
    # Akropolis-klippen
    rock = mix(p.bg, p.surface, 0.5)
    c.poly([(40, 180), (80, 140), (110, 132), (230, 130), (262, 140), (300, 180)], rock)
    c.poly([(80, 140), (110, 132), (230, 130), (262, 140), (240, 146), (100, 148)], mix(p.surface, p.line, 0.35))
    # Parthenon, lyst av månen fra venstre
    x0, y0 = 160 - 38, 106
    c.glow(160, 122, 70, 30, p.halo[:3], 0.7 + 0.08 * c.wave(1))
    stone, lit, dark = mix(mix(p.muted, p.acc, 0.3), p.bg, 0.25), mix(mix(p.text, p.hi, 0.6), p.bg, 0.3), mix(p.line, p.muted, 0.3)
    c.sprite(PARTHENON, x0, y0, {"a": dark, "b": lit, "c": stone, "d": lit, "e": dark}, scale=2)
    # sypresser og byen nedenfor
    for i, (x, hgt) in enumerate(((22, 40), (32, 30), (284, 44), (298, 34), (308, 26))):
        for y in range(hgt):
            half = max(1, int(4 * math.sin(math.pi * (y + 4) / (hgt + 6))))
            c.rect(x - half, 180 - y, x + half, 180 - y, mix(p.bg, p.surface, 0.25))
    c.gradient([mix(p.bg, p.surface, 0.4), p.bottom], 160, 180)
    for i in range(30):  # lys i vinduene nede i byen; noen tennes og slukkes sakte
        x = 60 + hsh(i, 9) * 200
        y = 166 + hsh(i, 8) * 12
        if math.sin(2 * math.pi * (c.t + hsh(i, 7))) > -0.6:
            c.put(x, y, mix(p.acc, p.bg, 0.3))


OWL_SIGN = """
  *          *
  #+        +#
  ############
 ##::##++##::##
 #:*##:##:##*:#
 #:##:####:##:#
 ##::##::##::##
  ####:##:####
  #####**#####
  ############
 ##:########:##
 #####:##:#####
 ##:########:##
  #####:#:####
   ##########
    ########
     +    +
"""

SCENES = {
    "owl": (32, owl),
    "parthenon": (32, parthenon),
    "sign": sign(OWL_SIGN, scale=4, dy=-6),
}
