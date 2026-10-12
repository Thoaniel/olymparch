"""Minimal Olympus-bakgrunn: nær svart flate, et lite pikseltempel i gull med dithret glorie og svake skannelinjer.

Bruk: minimal.py <ut.png> <bredde> <høyde>. Pikselstørrelsen følger høyden (1440 → 8 px, 1080 → 6 px), så
tempelet er like stort i forhold til skjermen på begge.
"""
import math
import sys

from PIL import Image

out, OW, OH = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
S = max(2, round(OH / 180))
W, H = math.ceil(OW / S), math.ceil(OH / S)

BG_TOP, BG_BOT = (13, 13, 18), (8, 8, 12)
HALO = [(13, 13, 18), (30, 22, 10), (42, 29, 12), (60, 39, 12)]
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

img = Image.new("RGB", (W, H))
px = img.load()
cx, cy = W // 2, int(H * 0.56)  # litt under midten: vinduene dekker sjelden midten nede


def ramp(colors, t, x, y):
    t = min(max(t, 0.0), 0.9999) * (len(colors) - 1)
    i, f = int(t), t - int(t)
    return colors[min(i + (f * 16 > BAYER[y % 4][x % 4] + 0.5), len(colors) - 1)]


for y in range(H):
    k = y / H
    base = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * k) for i in range(3))
    for x in range(W):
        g = max(0.0, 1 - math.hypot((x - cx + 0.5) / 46, (y - cy + 8) / 30))
        px[x, y] = ramp([base, *HALO[1:]], g ** 1.6, x, y) if g > 0 else base

# tempelet (34 x 28 piksler): tre trinn, seks søyler, bjelke og gavl
by = cy + 8
for i, (w, c) in enumerate(((34, GOLD[1]), (30, GOLD[2]), (26, GOLD[3]))):
    for x in range(cx - w // 2, cx + w // 2):
        px[x, by - i] = c
for k in range(6):
    x = cx - 11 + k * 4  # seks søyler med like mellomrom, speilet om midten
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

big = img.resize((W * S, H * S), Image.NEAREST).crop((0, 0, OW, OH))
d = big.load()
P = max(2, S // 2)  # skannelinjer med halv pikselperiode: jevnt mønster på både 1440p (4) og 1080p (3)
for y in range(0, OH, P):
    for x in range(OW):
        r, g, b = d[x, y]
        d[x, y] = (r * 3 // 4, g * 3 // 4, b * 3 // 4)
big.save(out, optimize=True)
print("ok", out, big.size, "piksel", S)
