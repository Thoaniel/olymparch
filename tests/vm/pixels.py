"""Count Olymparch gold pixels in a QEMU screendump (PPM, stdlib only).

  pixels.py FILE.ppm     prints: gold=<n> lit=<n> total=<n>
gold = close to the theme golds (bar text, temple); lit = anything that isn't near-black.
"""
import sys

data = open(sys.argv[1], "rb").read()
parts, pos = [], 0
while len(parts) < 4:  # header: P6, width, height, maxval (comments not used by QEMU)
    while data[pos:pos + 1].isspace():
        pos += 1
    end = pos
    while not data[end:end + 1].isspace():
        end += 1
    parts.append(data[pos:end])
    pos = end
pos += 1
w, h = int(parts[1]), int(parts[2])
px = data[pos:pos + w * h * 3]
gold = lit = 0
for i in range(0, len(px), 3 * 4):  # every 4th pixel is plenty
    r, g, b = px[i], px[i + 1], px[i + 2]
    if r + g + b > 90:
        lit += 1
    if r > 150 and 80 < g < 220 and b < 90 and r > g > b:
        gold += 1
print(f"gold={gold} lit={lit} total={w * h // 4}")
