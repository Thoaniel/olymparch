"""Levende bakgrunn: glorien rundt tempelet flakker som en fakkel. Samme tegning som minimal.py, men glorien
endrer størrelse, styrke og høyde fra bilde til bilde. Bevegelsen er en sum av sinuser med helt antall
perioder per løkke, så den ser uregelmessig ut men går sømløst rundt.

Bruk: torch.py <ut-mappe> <bredde> <høyde> [bilder=24]  ->  frame-00.png … og preview.gif (fps 8)
"""
import math
import sys
from pathlib import Path

from PIL import Image

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
OW, OH = int(sys.argv[2]), int(sys.argv[3])
N = int(sys.argv[4]) if len(sys.argv) > 4 else 48
S = max(2, round(OH / 180))
W, H = math.ceil(OW / S), math.ceil(OH / S)

BG_TOP, BG_BOT = (13, 13, 18), (8, 8, 12)
HALO = [(30, 22, 10), (42, 29, 12), (60, 39, 12), (84, 52, 14)]  # ett ekstra, varmere trinn for flammetoppene
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
cx, cy = W // 2, int(H * 0.56)


def ramp(colors, t, x, y):
    t = min(max(t, 0.0), 0.9999) * (len(colors) - 1)
    i, f = int(t), t - int(t)
    return colors[min(i + (f * 16 > BAYER[y % 4][x % 4] + 0.5), len(colors) - 1)]


def flicker(t):
    """0..1 over løkka -> (styrke, radius, løft). Helt antall perioder: sømløs løkke."""
    a = 2 * math.pi * t
    s = 0.35 * math.sin(a * 2 + 0.3) + 0.30 * math.sin(a * 7 + 1.7) + 0.20 * math.sin(a * 13 + 0.9) + 0.15 * math.sin(a * 19 + 2.2)
    lift = round(0.8 * math.sin(a * 3 + 0.4) + 0.5 * math.sin(a * 11 + 1.1))  # hele piksler: ingen dither-kryp
    return 1 + 0.22 * s, 1 + 0.05 * s, lift


def temple(px):
    by = cy + 8
    for i, (w, c) in enumerate(((34, GOLD[1]), (30, GOLD[2]), (26, GOLD[3]))):
        for x in range(cx - w // 2, cx + w // 2):
            px[x, by - i] = c
    for k in range(6):
        x = cx - 11 + k * 4
        for y in range(by - 13, by - 2):
            px[x, y] = GOLD[3]
            px[x + 1, y] = GOLD[1]
    for x in range(cx - 14, cx + 14):
        px[x, by - 14] = GOLD[2]
        px[x, by - 15] = GOLD[4]
    for k in range(8):
        for x in range(cx - 14 + k * 2, cx + 14 - k * 2):
            edge = x in (cx - 14 + k * 2, cx + 13 - k * 2)
            px[x, by - 16 - k] = GOLD[4] if edge else GOLD[1] if k > 1 else GOLD[2]


frames = []
for n in range(N):
    amp, rad, lift = flicker(n / N)
    img = Image.new("RGB", (W, H)); px = img.load()
    for y in range(H):
        k = y / H
        base = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * k) for i in range(3))
        for x in range(W):
            dy = (y - cy + 8 + lift)
            # flammeform: glorien strekker seg litt høyere over tempelet enn under
            ry = 30 * rad * (1.18 if dy < 0 else 0.92)
            if dy < 0:  # flammetunger: kanten over tempelet bølger oppover og forskyves over løkka
                th = math.atan2(dy, x - cx + 0.5)
                ry *= 1 + 0.07 * math.sin(5 * th + 2 * math.pi * n / N * 6) + 0.04 * math.sin(9 * th - 2 * math.pi * n / N * 10)
            g = max(0.0, 1 - math.hypot((x - cx + 0.5) / (46 * rad), dy / ry))
            px[x, y] = ramp([base, *HALO], min(1, (g ** 1.6) * amp * 0.85), x, y) if g > 0 else base
    temple(px)
    # gnister: tre stykker stiger fra gavlen og slukner; hver bruker hele løkka, så den går sømløst rundt
    for k, (x0, ph, sway) in enumerate(((-5, 0.0, 1), (6, 0.37, -1), (-1, 0.71, 1))):
        t = (n / N + ph) % 1
        if t > 0.55:
            continue
        sx = cx + x0 + round(sway * 1.5 * math.sin(2 * math.pi * t * 2))
        sy = cy + 8 - 24 - round(t * 20)
        px[sx, sy] = GOLD[3] if t < 0.2 else GOLD[2] if t < 0.4 else GOLD[1]
    big = img.resize((W * S, H * S), Image.NEAREST).crop((0, 0, OW, OH))
    d = big.load()
    P = max(2, S // 2)
    for y in range(0, OH, P):
        for x in range(OW):
            r, g_, b = d[x, y]
            d[x, y] = (r * 3 // 4, g_ * 3 // 4, b * 3 // 4)
    big.save(out / f"frame-{n:02d}.png", optimize=True)
    frames.append(big)

frames[0].save(out / "preview.gif", save_all=True, append_images=frames[1:], duration=125, loop=0, optimize=True)
print("ok", N, "bilder", (OW, OH), "piksel", S)
