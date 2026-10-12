"""Find the gold primary button of the newest notification in a QEMU screendump (PPM, stdlib only).

  button.py FILE.ppm [N]     prints: X Y WIDTH HEIGHT (the centre of button N, default 0 = the gold one)
The notification column is the top-right 380 px. A button row is a band of rows where one long run of
pixels has the same colour; the gold button is the first band whose run is gold. N=1 gives the button to its
right (the outlined one), found as the next text run on the same rows.
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


def gold(x, y):
    i = (y * w + x) * 3
    r, g, b = px[i], px[i + 1], px[i + 2]
    return r > 170 and 120 < g < 200 and b < 90


x0 = max(0, w - 370) + 8      # past the card's gold stripe
x1 = w - 12                    # before a window's gold right border
rows = []
for y in range(40, min(h, 600)):
    xs = [x for x in range(x0, x1) if gold(x, y)]
    if len(xs) >= 25:          # a filled button row (its label leaves plenty of gold around it)
        rows.append((y, min(xs), max(xs)))
# a button is a band of at least 15 consecutive such rows (a window's 2 px gold border is not)
bands, cur = [], []
for r in rows:
    if cur and r[0] != cur[-1][0] + 1:
        bands.append(cur)
        cur = []
    cur.append(r)
if cur:
    bands.append(cur)
bands = [b for b in bands if len(b) >= 15]
if not bands:
    sys.exit("no gold button")
band = bands[0]
y1, y2 = band[0][0], band[-1][0]
left = sorted(r[1] for r in band)[len(band) // 2]   # medians: stray anti-aliased text nearby is ignored
right = sorted(r[2] for r in band)[len(band) // 2]
cy = (y1 + y2) // 2
if want == 0:
    print((left + right) // 2, cy, w, h)
else:
    print(right + 8 + 40, cy, w, h)  # the second button starts 8 px to the right; aim inside it
