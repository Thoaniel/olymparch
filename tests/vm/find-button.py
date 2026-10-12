"""Find the first action button («Undo») on a notification toast in a QEMU screendump (PPM, stdlib only).

  find-button.py FILE.ppm     prints: X Y WIDTH HEIGHT (button centre and screen size), or "none"
Buttons are filled with the shell's `raised` colour (#1c1c25); toasts sit top right, 360 px wide.
"""
import sys

data = open(sys.argv[1], "rb").read()
parts, pos = [], 0
while len(parts) < 4:
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


def raised(x, y):
    i = (y * w + x) * 3
    return px[i] == 0x1c and px[i + 1] == 0x1c and px[i + 2] == 0x25


hits = [(x, y) for y in range(30, min(h, 500)) for x in range(max(0, w - 380), w) if raised(x, y)]
if len(hits) < 50:
    print("none")
    sys.exit(0)
x0 = min(x for x, _ in hits)
ys = sorted(y for x, y in hits if x - x0 < 4)
y0, y1 = ys[0], ys[-1]
row = y0 + 1
x1 = x0
while x1 + 1 < w and raised(x1 + 1, row):
    x1 += 1
print((x0 + x1) // 2, (y0 + y1) // 2, w, h)
