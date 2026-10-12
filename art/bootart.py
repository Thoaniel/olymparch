"""Olymparch boot art: the OLYMPARCH pixel wordmark, the temple, torch-halo frames and sparks for Plymouth, and
an animated preview of the whole boot (Limine → Plymouth → unlock → desktop).

Usage: bootart.py <out-dir> [width height]          default 1280 720 (the preview size)
The temple sits exactly where it is on the desktop wallpaper, so the boot flows straight into the desktop.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
OW, OH = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1280, 720)
S = max(2, round(OH / 180))
W, H = math.ceil(OW / S), math.ceil(OH / S)
cx, cy = W // 2, int(H * 0.56)          # same temple position as the wallpaper (minimal.py / torch.py)
BG = (8, 8, 12)
HALO = [(30, 22, 10), (42, 29, 12), (60, 39, 12), (84, 52, 14)]
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
LINE = (58, 54, 68)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

GLYPHS = {
    "O": [".#######.", "###...###", "###...###", "###...###", "###...###", "###...###", "###...###",
          "###...###", "###...###", "###...###", "###...###", "###...###", ".#######."],
    "L": ["###......", "###......", "###......", "###......", "###......", "###......", "###......",
          "###......", "###......", "###......", "###......", "#########", "#########"],
    "Y": ["###...###", "###...###", "###...###", "###...###", ".###.###.", "..#####..", "...###...",
          "...###...", "...###...", "...###...", "...###...", "...###...", "...###..."],
    "M": ["###...###", "####.####", "#########", "###.#.###", "###...###", "###...###", "###...###",
          "###...###", "###...###", "###...###", "###...###", "###...###", "###...###"],
    "P": ["########.", "###...###", "###...###", "###...###", "###...###", "########.", "###......",
          "###......", "###......", "###......", "###......", "###......", "###......"],
    "A": [".#######.", "###...###", "###...###", "###...###", "###...###", "#########", "###...###",
          "###...###", "###...###", "###...###", "###...###", "###...###", "###...###"],
    "R": ["########.", "###...###", "###...###", "###...###", "###...###", "########.", "###.###..",
          "###..###.", "###...###", "###...###", "###...###", "###...###", "###...###"],
    "C": [".########", "###......", "###......", "###......", "###......", "###......", "###......",
          "###......", "###......", "###......", "###......", "###......", ".########"],
    "H": ["###...###", "###...###", "###...###", "###...###", "###...###", "#########", "###...###",
          "###...###", "###...###", "###...###", "###...###", "###...###", "###...###"],
}


def ramp(colors, t, x, y):
    t = min(max(t, 0.0), 0.9999) * (len(colors) - 1)
    i, f = int(t), t - int(t)
    return colors[min(i + (f * 16 > BAYER[y % 4][x % 4] + 0.5), len(colors) - 1)]


def wordmark():
    text = "OLYMPARCH"
    w = len(text) * 9 + (len(text) - 1) * 2
    img = Image.new("RGBA", (w, 13), (0, 0, 0, 0))
    for i, ch in enumerate(text):
        for y, row in enumerate(GLYPHS[ch]):
            for x, c in enumerate(row):
                if c == "#":
                    # gold gradient: bright top, deep bottom, a highlight on the top row
                    col = GOLD[4] if y == 0 else GOLD[3] if y < 5 else GOLD[2] if y < 10 else GOLD[1]
                    img.putpixel((i * 11 + x, y), col + (255,))
    return img


def temple():
    t = Image.new("RGBA", (34, 25), (0, 0, 0, 0))
    px = t.load()
    tcx, by = 17, 24
    for i, (w, c) in enumerate(((34, GOLD[1]), (30, GOLD[2]), (26, GOLD[3]))):
        for x in range(tcx - w // 2, tcx + w // 2):
            px[x, by - i] = c + (255,)
    for k in range(6):
        x = tcx - 11 + k * 4
        for y in range(by - 13, by - 2):
            px[x, y] = GOLD[3] + (255,)
            px[x + 1, y] = GOLD[1] + (255,)
    for x in range(tcx - 14, tcx + 14):
        px[x, by - 14] = GOLD[2] + (255,)
        px[x, by - 15] = GOLD[4] + (255,)
    for k in range(8):
        for x in range(tcx - 14 + k * 2, tcx + 14 - k * 2):
            edge = x in (tcx - 14 + k * 2, tcx + 13 - k * 2)
            px[x, by - 16 - k] = (GOLD[4] if edge else GOLD[1] if k > 1 else GOLD[2]) + (255,)
    return t


def flicker(t):
    a = 2 * math.pi * t
    s = 0.35 * math.sin(a * 2 + 0.3) + 0.30 * math.sin(a * 7 + 1.7) + 0.20 * math.sin(a * 13 + 4.0) + 0.15 * math.sin(a * 19 + 2.9)
    return 1 + 0.34 * s, 1 + 0.07 * s, round(0.8 * math.sin(a * 3 + 0.4) + 0.5 * math.sin(a * 11 + 1.1))


def halo(px, n, N, strength):
    """Draw the torch halo into an RGB pixel access at loop position n/N, scaled by strength (0..1)."""
    amp, rad, lift = flicker(n / N)
    for y in range(max(0, cy - 60), min(H, cy + 40)):
        for x in range(max(0, cx - 70), min(W, cx + 70)):
            dy = y - cy + 8 + lift
            ry = 30 * rad * (1.18 if dy < 0 else 0.92)
            if dy < 0:
                th = math.atan2(dy, x - cx + 0.5)
                ry *= 1 + 0.11 * math.sin(5 * th + 2 * math.pi * n / N * 6) + 0.06 * math.sin(9 * th - 2 * math.pi * n / N * 10)
            g = max(0.0, 1 - math.hypot((x - cx + 0.5) / (46 * rad), dy / ry))
            if g > 0:
                v = min(1, (g ** 1.6) * amp * 0.85 * strength)
                if v > 0.02:
                    px[x, y] = ramp([BG, *HALO], v, x, y)


SPARKS = ((-5, 0.0, 1), (6, 0.17, -1), (-1, 0.34, 1), (9, 0.5, -1), (-9, 0.67, 1), (2, 0.84, -1))


def sparks(px, n, N):
    for x0, ph, sway in SPARKS:
        t = (n / N + ph) % 1
        if t > 0.65:
            continue
        sx = cx + x0 + round(sway * 1.5 * math.sin(2 * math.pi * t * 2))
        sy = cy + 8 - 24 - round(t * 14)
        px[sx, sy] = GOLD[3] if t < 0.2 else GOLD[2] if t < 0.4 else GOLD[1]


WM, TP = wordmark(), temple()
TX, TY = cx - 17, cy + 8 - 24              # temple top-left (matches the wallpaper)
WX, WY = cx - WM.width // 2, cy + 8 + 10   # wordmark under the temple
BX, BY, BW = cx - 22, WY + 13 + 9, 44      # password box
LOCK = ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]

# --- Plymouth assets (art pixel size S) ---
def save(img, name):
    img.resize((img.width * S, img.height * S), Image.NEAREST).save(out / name, optimize=True)


save(WM, "wordmark.png")
save(TP, "temple.png")
lk = Image.new("RGBA", (7, 7), (0, 0, 0, 0))
for y, row in enumerate(LOCK):
    for x, ch in enumerate(row):
        if ch == "#":
            lk.putpixel((x, y), GOLD[3] + (255,))
save(lk, "lock.png")
box = Image.new("RGBA", (BW, 7), (13, 13, 18, 255))
for x in range(BW):
    box.putpixel((x, 0), LINE + (255,)); box.putpixel((x, 6), LINE + (255,))
for y in range(7):
    box.putpixel((0, y), LINE + (255,)); box.putpixel((BW - 1, y), LINE + (255,))
for x, y in ((0, 0), (1, 0), (0, 1), (BW - 1, 6), (BW - 2, 6), (BW - 1, 5)):
    box.putpixel((x, y), GOLD[2] + (255,))
save(box, "box.png")
save(Image.new("RGBA", (1, 1), GOLD[3] + (255,)), "bullet.png")
save(Image.new("RGBA", (1, 1), GOLD[3] + (255,)), "spark.png")
pb = Image.new("RGBA", (BW, 3), (13, 13, 18, 255))
for x in range(BW):
    pb.putpixel((x, 0), LINE + (255,)); pb.putpixel((x, 2), LINE + (255,))
pb.putpixel((0, 1), LINE + (255,)); pb.putpixel((BW - 1, 1), LINE + (255,))
save(pb, "progress_box.png")
save(Image.new("RGBA", (BW - 2, 1), GOLD[3] + (255,)), "progress_bar.png")
# halo frames as transparent layers (Plymouth draws them under the temple)
HN = 48
for n in range(HN):
    layer = Image.new("RGB", (W, H), BG)
    halo(layer.load(), n, HN, 1.0)
    crop = layer.crop((cx - 70, cy - 60, cx + 70, cy + 40)).convert("RGBA")
    data = [(r, g, b, 0) if (r, g, b) == BG else (r, g, b, 255) for r, g, b, _ in crop.getdata()]
    crop.putdata(data)
    save(crop, f"halo-{n:02d}.png")

# --- Animated preview of the whole boot (12 fps) ---
try:
    font = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf", 14)
except OSError:
    font = ImageFont.load_default()


def base(scan=None):
    img = Image.new("RGB", (W, H), BG)
    for y in range(H):
        k = y / H
        c = tuple(int(13 + (8 - 13) * k) if i < 2 else int(18 + (12 - 18) * k) for i in range(3))
        for x in range(W):
            img.putpixel((x, y), c)
    return img


BASE = base()
frames = []


def finish(img, overlay=None):
    big = img.resize((W * S, H * S), Image.NEAREST).crop((0, 0, OW, OH))
    d = big.load()
    for y in range(0, OH, max(2, S // 2)):
        for x in range(OW):
            r, g, b = d[x, y]
            d[x, y] = (r * 3 // 4, g * 3 // 4, b * 3 // 4)
    if overlay:
        overlay(ImageDraw.Draw(big))
    frames.append(big)


def paste(img, sprite, x, y, rows=None):
    if rows is None:
        img.paste(sprite, (x, y), sprite)
    else:
        part = sprite.crop((0, 0, sprite.width, max(0, min(sprite.height, rows))))
        if part.height:
            img.paste(part, (x, y), part)


f = 0
# 1. Limine: the temple already on screen (no halo yet), the menu over it
for i in range(18):
    img = BASE.copy(); paste(img, TP, TX, TY)
    def menu(dr, i=i):
        dr.text((OW // 2, 24), "Olymparch", fill=GOLD[3], font=font, anchor="mm")
        dr.text((OW // 2, 50), "ARROWS Select   ENTER Boot   E Edit", fill=(154, 150, 163), font=font, anchor="mm")
        dr.rectangle((OW // 2 - 60, OH // 2 - 230, OW // 2 + 60, OH // 2 - 210), fill=GOLD[3])
        dr.text((OW // 2, OH // 2 - 220), "Olymparch", fill=(10, 10, 14), font=font, anchor="mm")
        dr.text((OW // 2, OH - 30), f"Booting automatically in {3 - i // 6}...", fill=GOLD[2], font=font, anchor="mm")
    finish(img, menu)
# 2. Plymouth: black, then a gold scanline draws the temple and the wordmark from the top
top, bot = TY, WY + 13
for i in range(20):
    y = top + (bot - top) * i // 19
    img = BASE.copy()
    paste(img, TP, TX, TY, rows=y - TY)
    paste(img, WM, WX, WY, rows=y - WY)
    for x in range(cx - 60, cx + 60):
        if 0 <= y < H:
            img.putpixel((x, y), GOLD[4] if abs(x - cx) < 45 else GOLD[2])
    finish(img)
# 3. The torch lights: halo grows in, sparks start
for i in range(18):
    img = BASE.copy(); px = img.load()
    halo(px, f, 48, (i + 1) / 18); f += 1
    if i > 8:
        sparks(px, f, 48)
    paste(img, TP, TX, TY); paste(img, WM, WX, WY)
    finish(img)
# 4. Password box, then 8 typed characters (a tiny spark jumps from each new bullet)


def scene(bullets=0, box_on=True, flash=0, ring=None, progress=None, fade=1.0, bar=0):
    global f
    img = BASE.copy(); px = img.load()
    halo(px, f, 48, 1.0); sparks(px, f, 48); f += 1
    paste(img, TP, TX, TY)
    if fade > 0:
        wm = WM.copy()
        if fade < 1:
            a = wm.getchannel("A").point(lambda v: int(v * fade))
            wm.putalpha(a)
        paste(img, wm, WX, WY)
    if box_on:
        b = box.copy()
        if flash:
            b = Image.new("RGBA", box.size, GOLD[3] + (255,))
        paste(img, lk, BX - 10, BY)
        paste(img, b, BX, BY)
        for k in range(bullets):
            px[BX + 3 + k * 2, BY + 3] = GOLD[3] if not flash else BG
    if ring is not None:
        for a in range(0, 360, 6):
            x = round(cx + ring * math.cos(math.radians(a)))
            y = round(cy - 4 + ring * 0.7 * math.sin(math.radians(a)))
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = GOLD[4] if ring < 30 else GOLD[2]
    if progress is not None:
        paste(img, pb, BX, BY + 2)
        for x in range(round((BW - 2) * progress)):
            px[BX + 1 + x, BY + 3] = GOLD[3]
    if bar:
        for y in range(min(bar, 9)):
            for x in range(W):
                px[x, y] = (10, 10, 14)
        if bar >= 9:
            for x in range(W):
                px[x, 8] = LINE
    finish(img)


for i in range(6):
    scene(bullets=0, box_on=i > 2)
for k in range(1, 9):
    for _ in range(3):
        scene(bullets=k)
# 5. Unlock: the box flashes gold, a ring of pixels runs out from the temple
for i in range(4):
    scene(bullets=8, flash=i < 2, ring=8 + i * 10)
for i in range(6):
    scene(box_on=False, ring=48 + i * 12)
# 6. Progress bar under the wordmark, like Omarchy (eases toward the end while the system starts)
for i in range(30):
    p = 1 - (1 - i / 29) ** 2
    scene(box_on=False, progress=p)
# 7. Desktop: the wordmark fades, the bar slides down; the temple and its torch stay put
for i in range(14):
    scene(box_on=False, fade=max(0, 1 - i / 7), bar=min(9, i))
for i in range(12):
    scene(box_on=False, fade=0, bar=9)
frames[0].save(out / "boot-preview.gif", save_all=True, append_images=frames[1:], duration=83, loop=0, optimize=True)
print("ok", len(frames), "bilder i forhåndsvisningen, kunst-piksel", S)
