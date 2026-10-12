"""Count Olymparch gold pixels in a QEMU screendump (PPM, stdlib only).

  pixels.py FILE.ppm [X0 Y0 X1 Y1]     prints: gold=<n> lit=<n> total=<n>
With a box, every pixel inside it is counted (x0 <= x < x1, y0 <= y < y1).
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
gold = lit = red = 0
if len(sys.argv) == 6:  # only a box: pixels.py FILE x0 y0 x1 y1
    x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
    idx = [(y * w + x) * 3 for y in range(max(0, y0), min(h, y1)) for x in range(max(0, x0), min(w, x1))]
else:
    idx = range(0, len(px), 3 * 4)  # every 4th pixel is plenty
for i in idx:
    r, g, b = px[i], px[i + 1], px[i + 2]
    if r + g + b > 90:
        lit += 1
    if r > 150 and 80 < g < 220 and b < 90 and r > g > b:
        gold += 1
    if r > 190 and g < 120 and b < 120:
        red += 1
print(f"gold={gold} lit={lit} red={red} total={len(idx) if len(sys.argv) == 6 else w * h // 4}")
