"""Zevs: uvær over Olympen, toppen over skyene, lynet som stjernebilde. (Tempelet er art/torch.py.)"""
from common import sign
from pixel import H, W, mix

TEMPLE = """
....AAAA....
..AAAAAAAA..
AAAAAAAAAAAA
.B.B.B.B.B..
.B.B.B.B.B..
.B.B.B.B.B..
CCCCCCCCCCCC
"""


def storm(c):
    p = c.p
    c.gradient([p.bottom, mix(p.surface, p.line, 0.2), mix(p.surface, p.line, 0.45)], 0, 130)
    # lynet: to bilder av 32 (én gang hver løkke på 4 s); himmelen lysner bare litt
    flash = c.n in (19, 20)
    if flash:
        c.glow(212, 60, 120, 70, [mix(p.surface, p.line, 0.6), mix(p.line, p.acc, 0.25)], 0.9 if c.n == 19 else 0.5)
    c.stars(40, 3, 30, 70, twinkle=0.2)
    # skyer i tre lag som driver sakte (helt antall ganger rundt)
    for layer, (y, speed, col, edge) in enumerate((
            (52, 1, mix(p.surface, p.line, 0.25), mix(p.line, p.acc, 0.15) if flash else mix(p.surface, p.line, 0.55)),
            (74, 1, p.surface, mix(p.surface, p.line, 0.4)),
            (92, 2, mix(p.bg, p.surface, 0.5), p.surface))):
        off = c.loop(speed) * W
        for k in range(5):
            x = (k * W / 4 + off + layer * 37) % (W + 80) - 40
            c.cloud(x, y + (k % 2) * 6, 70 + 10 * (k % 3), 16, col, seed=k + layer * 10, edge=edge)
    # Olympen: tre topper, tempelet på den høyeste
    c.ridge(150, 10, 2, mix(p.bg, p.surface, 0.6), period=40)
    c.poly([(60, 180), (150, 104), (168, 112), (186, 100), (290, 180)], mix(p.bg, p.surface, 0.3))
    c.poly([(150, 104), (158, 112), (166, 110), (168, 112), (175, 106), (186, 100), (180, 110), (160, 116)], mix(p.surface, p.line, 0.5))
    c.glow(186, 94, 22, 16, p.halo, 0.7)
    c.sprite(TEMPLE, 180, 90, {"A": p.gold[3], "B": p.gold[2], "C": p.gold[1]})
    c.poly([(0, 180), (0, 150), (60, 140), (120, 162), (160, 180)], p.bottom)
    if flash:  # lynet fra skyene ned mot en topp i det fjerne
        x, y = 222, 58
        pts = [(x, y)]
        for dx, dy in ((-4, 7), (3, 6), (-5, 8), (2, 5), (-3, 7), (4, 6)):
            x, y = x + dx, y + dy
            pts.append((x, y))
        c.line(pts, p.gold[4] if c.n == 19 else p.gold[3])
        c.line([(x + 2, y - 15), (x + 7, y - 9), (x + 6, y - 4)], p.gold[2])


def summit(c):
    p = c.p
    # skumring: mørk himmel, et smalt gyllent bånd lavt nede
    c.gradient(p.night(4), 0, 120)
    c.gradient([mix(p.surface, p.line, 0.45), mix(p.line, p.acc, 0.25), mix(p.acc, p.line, 0.6)], 100, 128)
    c.stars(120, 7, 20, 95)
    # toppen med tempelet
    c.poly([(70, 180), (160, 72), (250, 180)], mix(p.bg, p.surface, 0.5))
    c.poly([(160, 72), (150, 88), (156, 86), (162, 94), (168, 86), (176, 92)], mix(p.surface, p.line, 0.7))
    c.glow(160, 64, 30, 22, p.halo, 0.9 + 0.1 * c.wave(2))
    c.sprite(TEMPLE, 154, 60, {"A": p.gold[3], "B": p.gold[2], "C": p.gold[1]})
    # et skyhav under toppen som driver sakte forbi
    off = c.loop(1) * W
    for k in range(7):
        x = (k * W / 6 + off) % (W + 60) - 30
        c.cloud(x, 132 + (k % 3) * 4, 64, 14, mix(p.surface, p.line, 0.3), seed=k, edge=mix(p.line, p.acc, 0.2))
    c.gradient([mix(p.surface, p.line, 0.3), p.surface, p.bottom], 140, 180)
    for k in range(6):
        x = (k * W / 5 - off * 0.5 * 2 + 40) % (W + 60) - 30
        c.cloud(x, 156 + (k % 2) * 6, 70, 12, p.surface, seed=k + 20, edge=mix(p.surface, p.line, 0.5))


BOLT = """
..................*......
.................##......
................###......
...............###.......
..............*##........
.............###.........
............###..........
...........###...........
..........*#######*......
.............####........
............####.........
...........###...........
..........###............
.........*##.............
........##...............
.......##................
......*..................
"""

SCENES = {
    "storm": (32, storm),
    "summit": (32, summit),
    "sign": sign(BOLT, scale=4, dy=-10),
}
