"""Images for the Olymparch Plymouth theme (the disk-password screen): the temple, a pixel lock, the
password box and the gold bullet. No text, so the screen looks the same in every language.

Usage: plymouth.py <out-dir> [pixel=6]
"""
import sys
from pathlib import Path

from PIL import Image

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
S = int(sys.argv[2]) if len(sys.argv) > 2 else 6
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
LINE = (58, 54, 68)
BOX_BG = (13, 13, 18)


def save(img, name):
    img.resize((img.width * S, img.height * S), Image.NEAREST).save(out / name, optimize=True)


# Temple: the same drawing as the wallpaper (34 x 25 art pixels)
t = Image.new("RGBA", (34, 25), (0, 0, 0, 0))
px = t.load()
cx, by = 17, 24
for i, (w, c) in enumerate(((34, GOLD[1]), (30, GOLD[2]), (26, GOLD[3]))):
    for x in range(cx - w // 2, cx + w // 2):
        px[x, by - i] = c + (255,)
for k in range(6):
    x = cx - 11 + k * 4
    for y in range(by - 13, by - 2):
        px[x, y] = GOLD[3] + (255,)
        px[x + 1, y] = GOLD[1] + (255,)
for x in range(cx - 14, cx + 14):
    px[x, by - 14] = GOLD[2] + (255,)
    px[x, by - 15] = GOLD[4] + (255,)
for k in range(8):
    for x in range(cx - 14 + k * 2, cx + 14 - k * 2):
        edge = x in (cx - 14 + k * 2, cx + 13 - k * 2)
        px[x, by - 16 - k] = (GOLD[4] if edge else GOLD[1] if k > 1 else GOLD[2]) + (255,)
save(t, "temple.png")

# Lock icon (7 x 8)
LOCK = ["..###..",
        ".#...#.",
        ".#...#.",
        "#######",
        "###.###",
        "###.###",
        "#######",
        "......."]
lk = Image.new("RGBA", (7, 8), (0, 0, 0, 0))
for y, row in enumerate(LOCK):
    for x, ch in enumerate(row):
        if ch == "#":
            lk.putpixel((x, y), GOLD[3] + (255,))
save(lk, "lock.png")

# Password box (40 x 6): dark fill, grey frame, gold corner marks like the shell's focused popups
bw, bh = 40, 6
box = Image.new("RGBA", (bw, bh), BOX_BG + (255,))
for x in range(bw):
    box.putpixel((x, 0), LINE + (255,))
    box.putpixel((x, bh - 1), LINE + (255,))
for y in range(bh):
    box.putpixel((0, y), LINE + (255,))
    box.putpixel((bw - 1, y), LINE + (255,))
for x, y in ((0, 0), (1, 0), (0, 1), (bw - 1, bh - 1), (bw - 2, bh - 1), (bw - 1, bh - 2)):
    box.putpixel((x, y), GOLD[2] + (255,))
save(box, "box.png")

bullet = Image.new("RGBA", (1, 1), GOLD[3] + (255,))
save(bullet, "bullet.png")
print("ok", out, "pixel", S)
