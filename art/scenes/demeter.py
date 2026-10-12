"""Demeter: kornåkeren i skumringen, valmuer under høstmånen, kornbandet som stjernebilde. (Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import TAU, H, W, hsh, mix


def stalks(c, y_base, count, seed, h0, h1, stem, head, sway=1.5, k=1):
    """aks som vaier: toppen flytter seg med en bølge som går over åkeren"""
    for i in range(count):
        x0 = hsh(seed, i, 1) * W
        h = h0 + hsh(seed, i, 2) * (h1 - h0)
        lean = sway * math.sin(TAU * (c.t * k - x0 / W * 2 + hsh(seed, i, 3) * 0.2))
        for j in range(int(h)):
            u = j / h
            c.put(x0 + lean * u * u, y_base - j, stem)
        tx = x0 + lean
        for j in range(5):  # akset
            c.put(tx + (j % 2) * 0.6, y_base - h - j, head)
            if j % 2:
                c.put(tx - 1, y_base - h - j, head)
                c.put(tx + 1, y_base - h - j, head)


def wheat(c):
    p = c.p
    c.gradient(p.night(4), 0, 96)
    c.gradient([mix(p.surface, p.line, 0.3), mix(p.line, p.hi, 0.18), mix(p.line, p.hi, 0.32)], 84, 116)
    c.stars(60, 21, 22, 70, twinkle=0.25)
    # solen er nettopp gått ned bak åsen: en halv skive
    c.disc(220, 116, 13, mix(p.hi, p.line, 0.25))
    c.ridge(116, 4, 3, mix(p.bg, p.surface, 0.7), period=70)
    # åkeren: fjerne rader mørke, nære rader lysere; aksene vaier i en langsom bølge
    c.gradient([mix(p.bg, p.surface, 0.8), mix(p.surface, p.hi, 0.12), mix(p.bg, p.surface, 0.5)], 116, 180)
    far_head = mix(p.surface, p.hi, 0.3)
    stalks(c, 130, 140, 1, 6, 10, mix(p.surface, p.line, 0.5), far_head, sway=1.0)
    stalks(c, 150, 60, 2, 12, 18, mix(p.surface, p.line, 0.7), mix(p.line, p.hi, 0.3), sway=1.6)
    stalks(c, 178, 26, 3, 22, 32, mix(p.surface, p.line, 0.8), mix(p.line, p.hi, 0.4), sway=2.2)
    c.particles(6, 4, 40, 300, 140, 110, [p.gold[3], p.gold[2], p.gold[1]], sway=3, life=0.8)


def poppies(c):
    p = c.p
    c.gradient(p.night(5), 0, 140)
    c.stars(110, 31, 20, 100)
    # høstmånen, stor og varm, lavt over åsen
    c.moon(96, 92, 20, mix(p.hi, p.gold[3], 0.4), shadow=mix(p.hi, p.gold[2], 0.35), glow=p.halo[:3])
    c.ridge(118, 6, 7, mix(p.bg, p.surface, 0.75), period=55)
    c.gradient([mix(p.bg, p.surface, 0.7), mix(p.bg, p.surface, 0.4)], 118, 180)
    stalks(c, 140, 120, 5, 6, 10, mix(p.surface, p.line, 0.5), mix(p.surface, p.hi, 0.25), sway=0.8)
    stalks(c, 178, 34, 6, 22, 30, mix(p.surface, p.line, 0.75), mix(p.line, p.hi, 0.3), sway=1.6)
    red, dark = p.danger, mix(p.danger, p.bg, 0.45)
    for i in range(26):  # valmuene: en rød blomst på en tynn stilk, som nikker sakte
        x0 = 10 + hsh(9, i) * 300
        near = hsh(9, i, 2)
        yb = 148 + near * 30
        h = 8 + near * 16
        lean = (1 + near) * math.sin(TAU * (c.t - x0 / W * 2))
        for j in range(int(h)):
            c.put(x0 + lean * (j / h) ** 2, yb - j, mix(p.line, p.acc, 0.3))
        tx, ty = x0 + lean, yb - h
        r = 1.5 + near * 1.6
        c.disc(tx, ty - r * 0.3, r, dark if near < 0.4 else red)
        c.put(tx, ty - r * 0.3, p.bg)
    c.particles(5, 8, 30, 300, 150, 100, [p.gold[3], p.gold[2]], sway=3, life=0.7)


EMBLEM = """
                *
                #
               #:#
     *         #:#         *
     #         #:#         #
    #:#       # : #       #:#
    #:#       + : +       #:#
    #:#       # : #       #:#
   # : #       #:#       # : #
   + : +        #        + : +
    #:#         #         #:#
    #:#         #         #:#
    # #         #         # #
     #          #          #
      #         #         #
       #        #        #
        #       #       #
         #      #      #
          ##    #    ##
            #   #   #
             #  #  #
              # # #
            *#######*
               ###
              # # #
              # # #
             #  #  #
             #  #  #
            #   #   #
            #   #   #
            #   #   #
           #    #    #
           #    #    #
          #     #     #
          *     *     *
"""

SCENES = {
    "wheat": (32, wheat),
    "poppies": (32, poppies),
    "sign": sign(EMBLEM, scale=4, dy=-6),
}
