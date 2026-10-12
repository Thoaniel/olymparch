"""Find a button on the AI approval card (McpApproval.qml) in a QEMU screendump (PPM, stdlib only).

  card-button.py FILE.ppm N     prints: X Y (centre of button N: 0 «Tillat én gang», 1 «Avvis», 2 «Alltid for …»)
                                or "none"
The card is 480 px wide, centred at the top. Button 0 is filled gold (#d4a73a) and at least 20 rows high (the
card's 1 px border and the badge outline are thin lines); the others are filled `raised` (#1c1c25) on the same
rows, to its right (or on the next row when they wrap).
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
want = int(sys.argv[2]) if len(sys.argv) > 2 else 0
GOLD, RAISED, LINE = (0xd4, 0xa7, 0x3a), (0x1c, 0x1c, 0x25), (0x3a, 0x36, 0x44)
left, right = max(0, w // 2 - 250), min(w, w // 2 + 250)


def color(x, y):
    i = (y * w + x) * 3
    return (px[i], px[i + 1], px[i + 2])


def runs(y, c, minlen):
    out, x = [], left
    while x < right:
        if color(x, y) == c:
            s = x
            while x < right and color(x, y) == c:
                x += 1
            if x - s >= minlen:
                out.append((s, x))
        else:
            x += 1
    return out


top = None
for y in range(40, min(h, 800)):
    for s, e in runs(y, GOLD, 60):
        if e - s <= 400 and all(any(abs(s2 - s) <= 2 and abs(e2 - e) <= 2 for s2, e2 in runs(y + k, GOLD, 40)) for k in (3, 6, 25)):
            top = (y, s, e)
            break
    if top:
        break
if not top:
    print("none")
    sys.exit(0)
y0, s0, e0 = top
if want == 0:
    print((s0 + e0) // 2, y0 + 14)
    sys.exit(0)
found = []   # (first row seen, start, end) of every raised run right of / below the gold button
for y in range(y0 - 2, min(h, y0 + 90)):
    for s, e in runs(y, RAISED, 30):
        if (y > y0 + 6 or s > e0) and color((s + e) // 2, y - 1) != RAISED and color(s - 1, y) == LINE and all(abs(s - fs) > 5 or y - fy > 20 for fy, fs, _ in found):
            found.append((y, s, e))
found.sort()
if len(found) < want:
    print("none")
else:
    y, s, e = found[want - 1]
    print((s + e) // 2, y + 13)
