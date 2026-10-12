"""Scener flere guder deler. sign(EMBLEM): gudens tegn som et stjernebilde på nattehimmelen.

EMBLEM er tekstlinjer: '*' er en stjerne i tegnet (blinker sakte), '+' en svakere stjerne, '#' et svakt slør som
fyller formen, ':' en svak prikk langs linjene, '.' og mellomrom er tomt. Rundt 40×40 tegn; hvert tegn er 2×2 piksler.
"""
import math

from pixel import H, W, hsh, mix


def sign(emblem, frames=32, scale=2, dy=0):
    rows = [r for r in emblem.strip("\n").split("\n")]
    ew = max(len(r) for r in rows) * scale
    eh = len(rows) * scale

    def draw(c):
        p = c.p
        if p.light:
            sky = [mix(p.bg, p.hi, 0.18), mix(p.bg, p.raised, 0.6), p.bg, p.bg]
            c.gradient(sky)
            veil, faint, star, bright = mix(p.bg, p.raised, 0.8), mix(p.raised, p.line, 0.6), p.gold[1], p.gold[0]
            veil2 = mix(p.raised, p.line, 0.35)
            c.stars(70, 11, 40, H, colors=[mix(p.bg, p.line, 0.5), mix(p.bg, p.line, 0.8)], twinkle=0.3)
        else:
            c.gradient(p.night(5))
            c.stars(170, 11, 36, H)
            veil, faint, star, bright = mix(p.surface, p.line, 0.3), mix(p.line, p.acc, 0.3), p.gold[2], p.gold[4]
            veil2 = mix(p.surface, p.line, 0.6)
        x0, y0 = W // 2 - ew // 2, int(H * 0.55) - eh // 2 + dy
        c.glow(W / 2, y0 + eh / 2, ew * 0.9, eh * 0.8, p.halo[:2], 0.8)
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                x, y = x0 + i * scale, y0 + j * scale
                if ch == "#":   # the shape: a quiet two-tone checker, so it reads without shouting
                    for a in range(scale):
                        for b in range(scale):
                            c.put(x + a, y + b, veil if (x + a + y + b) % 2 else veil2)
                elif ch == ":":
                    for a in range(scale // 2):
                        for b in range(scale // 2):
                            c.put(x + scale // 4 + a, y + scale // 4 + b, faint)
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch not in "*+":
                    continue
                x, y = x0 + i * scale, y0 + j * scale
                k = 1 + int(hsh(i, j) * 2)
                tw = 0.5 + 0.5 * math.sin(2 * math.pi * (c.t * k + hsh(j, i)))
                col = (bright if tw > 0.55 else star) if ch == "*" else (star if tw > 0.7 else faint)
                c.put(x, y, col)
                if ch == "*":
                    for dx, dyy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        c.put(x + dx, y + dyy, star if tw > 0.55 else faint)
    return frames, draw
