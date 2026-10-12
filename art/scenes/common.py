"""Scener flere guder deler. sign(EMBLEM): gudens tegn som et stjernebilde på nattehimmelen.

EMBLEM er tekstlinjer: '*' er en klar stjerne (på hjørnene av tegnet), '+' en mindre, '#' en prikk på linjene
mellom stjernene, ':' en svakere prikk, '.' og mellomrom er tomt. Ingen fyll: et stjernebilde er stjerner og linjer.
Hvert tegn er scale×scale piksler (3–4).
"""
import math

from pixel import H, W, hsh, mix


def sign(emblem, frames=32, scale=2, dy=0):
    rows = [r for r in emblem.strip("\n").split("\n")]
    ew = max(len(r) for r in rows) * scale
    eh = len(rows) * scale

    def draw(c):
        p = c.p
        seed = sum(ord(ch) for ch in p.id) % 97   # every god its own starfield
        if p.light:   # Apollon: warm cream, no grey band under the bar
            c.gradient([p.bg, p.bg, mix(p.bg, p.hi, 0.1), mix(p.bg, p.hi, 0.16)])
            line, faint, star, bright = mix(p.bg, p.acc, 0.45), mix(p.bg, p.acc, 0.28), p.gold[1], p.gold[0]
            c.stars(60, seed, 40, H, colors=[mix(p.bg, p.line, 0.4), mix(p.bg, p.line, 0.7)], twinkle=0.3)
        else:
            c.gradient(p.night(5))
            c.stars(150, seed, 36, H)
            line, faint, star, bright = mix(p.line, p.acc, 0.45), mix(p.surface, p.line, 0.8), p.gold[3], p.gold[4]
        x0, y0 = W // 2 - ew // 2, int(H * 0.55) - eh // 2 + dy
        # the lines of the constellation: one dot per cell ('#' clear, ':' faint), no fill
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in "#:":
                    c.put(x0 + i * scale + scale // 2, y0 + j * scale + scale // 2, line if ch == "#" else faint)
        # the stars on the corners: '*' bright with a cross, '+' smaller; they twinkle slowly
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch not in "*+":
                    continue
                x, y = x0 + i * scale + scale // 2, y0 + j * scale + scale // 2
                k = 1 + int(hsh(i, j) * 2)
                tw = 0.5 + 0.5 * math.sin(2 * math.pi * (c.t * k + hsh(j, i)))
                c.put(x, y, bright if ch == "*" or tw > 0.6 else star)
                if ch == "*":
                    for dx, dyy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        c.put(x + dx, y + dyy, star if tw > 0.4 else line)
    return frames, draw


def constellation(w, h, lines=(), stars=(), small=(), rings=()):
    """Et stjernebilde som tekst for common.sign: lines = lister av punkter (x, y) som trekkes med '#', stars = klare
    stjerner ('*'), small = små ('+'), rings = (cx, cy, rx, ry) som prikkede ellipser."""
    import math
    g = [[" "] * w for _ in range(h)]

    def dot(x, y, ch):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < w and 0 <= y < h and (ch != "#" or g[y][x] == " "):
            g[y][x] = ch
    for pts in lines:
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = max(abs(x1 - x0), abs(y1 - y0), 1)
            for i in range(int(n) + 1):
                dot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, "#")
    for cx, cy, rx, ry in rings:
        n = int(2 * math.pi * max(rx, ry))
        for i in range(n):
            a = 2 * math.pi * i / n
            dot(cx + rx * math.cos(a), cy + ry * math.sin(a), "#")
    for x, y in stars:
        dot(x, y, "*")
    for x, y in small:
        dot(x, y, "+")
    return "\n".join("".join(r) for r in g)


# et skarpt sikksakk-lyn med stjerner på hjørnene
