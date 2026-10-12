"""Afrodite: skjellet i havskummet, roser med kronblad som daler, skjellet og duen som stjernebilde.
(Tempelet er art/torch.py.)"""
import math

from common import sign
from pixel import H, W, hsh, mix

ROSE = """
...AAA...
.AABBBAA.
ABBCCCBBA
ABCBBBCBA
ABCBDBCBA
ABCCBCCBA
.ABBCBBA.
..AABAA..
"""


def shell(c, cx, by, R, cols):
    """et kamskjell: en vifte med ribber fra hengselet (cx, by) og bølget kant"""
    ribs = 13
    for y in range(int(by - R * 1.1), by + 1):
        for x in range(int(cx - R * 1.1), int(cx + R * 1.1) + 1):
            dx, dy = x - cx + 0.5, by - y + 0.5
            a = math.atan2(dx, dy)  # 0 rett opp
            if abs(a) > 1.25:
                continue
            r = math.hypot(dx, dy)
            k = (a + 1.25) / 2.5 * ribs
            edge = R * (0.96 + 0.05 * abs(math.cos(math.pi * k)))
            if r > edge:
                continue
            rib = int(k) % 2
            groove = abs((k % 1) - 0.5) > 0.42
            v = r / R
            col = cols[0] if groove else cols[1 + rib] if v < 0.85 else cols[3]
            if v < 0.25:
                col = cols[1]
            c.put(x, y, col)
    # ørene ved hengselet
    c.rect(cx - 8, by - 3, cx + 7, by, cols[1])
    c.rect(cx - 6, by - 4, cx + 5, by - 4, cols[2])


def seafoam(c):
    p = c.p
    c.gradient(p.night(4), 0, 112)
    c.stars(90, 41, 20, 100)
    c.moon(90, 62, 9, mix(p.hi, p.text, 0.4), glow=[mix(p.bottom, p.line, 0.3), mix(p.surface, p.line, 0.6)])
    # havet: mørke bånd som bølger sakte; skumlinjer som ruller inn
    c.gradient([mix(p.surface, p.line, 0.5), p.surface, p.bottom], 112, 180)
    for i, y in enumerate(range(116, 176, 6)):
        amp = 1 + (y - 112) / 30
        for x in range(0, W):
            yy = y + amp * math.sin(x / (14 + i * 2) + 2 * math.pi * (c.t + i * 0.13))
            if math.sin(x / 9 + i * 2.1 + 2 * math.pi * c.t) > 0.35:
                c.put(x, yy, mix(p.line, p.hi, 0.12 + 0.03 * i))
    # månestripe i vannet
    for y in range(114, 150, 2):
        w = 3 + (y - 114) // 6
        off = round(2 * math.sin(y / 3 + 2 * math.pi * c.t))
        for x in range(90 - w, 90 + w, 2):
            if (x + y) % 4 == 0:
                c.put(x + off, y, mix(p.hi, p.line, 0.4))
    # skjellet på skummet, skumboblene rundt pulserer sakte
    cols = [p.gold[0], p.gold[1], p.gold[2], p.gold[3]]
    c.glow(200, 140, 70, 34, p.halo, 0.9)
    shell(c, 200, 150, 38, cols)
    foam = [mix(p.text, p.acc, 0.25), mix(p.line, p.text, 0.5)]
    for i in range(70):
        a = hsh(3, i) * math.pi
        rr = 34 + hsh(4, i) * 14
        x = 200 + math.cos(a) * rr * 1.4 - 0 * a
        y = 152 + math.sin(a) * rr * 0.25 + 2
        if math.sin(2 * math.pi * (c.t * 2 + hsh(5, i))) > -0.3:
            c.put(x, y, foam[i % 2])
    c.ellipse(200, 153, 50, 4, mix(p.surface, p.muted, 0.45))
    c.ellipse(200, 153, 40, 2, mix(p.line, p.text, 0.45))


def roses(c):
    p = c.p
    c.gradient(p.night(4))
    c.glow(160, 150, 150, 60, p.halo, 0.9)
    leaf = [mix(p.bg, (60, 110, 70), 0.35), mix(p.bg, (80, 140, 90), 0.5)]
    stem = mix(p.bg, p.line, 0.5)
    # en rosebusk langs bunnen: stilker, blader, blomster
    for i in range(15):
        x = 8 + i * 22 + int(hsh(1, i) * 10)
        top = 112 + int(hsh(2, i) * 36)
        sway = round(math.sin(2 * math.pi * (c.t + hsh(3, i))) * 0.8)
        c.line([(x, 180), (x + sway, top)], stem)
        for k in range(5):
            ly = top + 12 + k * 10
            side = 1 if (i + k) % 2 else -1
            c.poly([(x, ly), (x + side * 4, ly - 3), (x + side * 10, ly - 2), (x + side * 5, ly + 2)], leaf[k % 2])
        if hsh(4, i) > 0.35:
            cols = {"A": p.gold[1], "B": p.gold[2], "C": p.gold[0], "D": p.gold[3]}
            c.sprite(ROSE, x - 9 + sway, top - 14, cols, scale=2)
    c.gradient([mix(p.bg, p.surface, 0.4), p.bottom], 170, 180)
    # kronblad som daler sakte og vugger
    petals = [p.gold[3], p.gold[2], p.gold[1]]
    for i in range(16):
        u = (c.t + hsh(6, i)) % 1.0
        x = hsh(7, i) * W + 10 * math.sin(2 * math.pi * (u * 2 + hsh(8, i))) - u * 20
        y = 30 + u * 140
        col = petals[i % 3]
        c.put(x, y, col)
        if math.sin(2 * math.pi * (u * 4 + hsh(9, i))) > 0:
            c.put(x + 1, y, col)


SHELL_DOVE = """
........................+.....
.......................*#*....
...............+:....:#####:..
.............:##*:::*####.....
...........:#####:...*#.......
..........*####.......:.......
...........::.................
..............................
..........+*+*+*+.............
.......*:#:#:#:#:#:*..........
......+#:#:#:#:#:#:#+.........
.....*##:#:#:#:#:#:##*........
.....+##:#:#:#:#:#:##+........
......*#:#:#:#:#:#:#*.........
.......+##:#:#:#:##+..........
.........*#######*............
..........+*+*+*+.............
"""

SCENES = {
    "seafoam": (32, seafoam),
    "roses": (32, roses),
    "sign": sign(SHELL_DOVE, scale=4, dy=-6),
}
