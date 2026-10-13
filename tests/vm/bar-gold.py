"""Find a gold item in the bar's right half in a QEMU screendump (PPM, stdlib only): the Zeus bolt.

  bar-gold.py FILE.ppm [N]     prints: X Y (the centre of the N-th gold cluster from the left, 0 = first), or "none"
The bar is the top 34 px; the wordmark in the middle is gold too, so only the right half from 60 % of the width
counts. A cluster is a run of columns that have gold pixels, with at most 3 empty columns inside it.
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
n = int(sys.argv[2]) if len(sys.argv) > 2 else 0


def gold(x, y):
    i = (y * w + x) * 3
    r, g, b = px[i], px[i + 1], px[i + 2]
    return r > 150 and 80 < g < 220 and b < 90 and r > g > b


cols = [x for x in range(int(w * 0.6), w) if any(gold(x, y) for y in range(4, 30))]
clusters, cur = [], []
for x in cols:
    if cur and x - cur[-1] > 4:
        clusters.append(cur)
        cur = []
    cur.append(x)
if cur:
    clusters.append(cur)
clusters = [c for c in clusters if len(c) >= 4]
if n < len(clusters):
    c = clusters[n]
    print((c[0] + c[-1]) // 2, 17)
else:
    print("none")
