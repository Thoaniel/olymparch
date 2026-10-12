"""Draft 2 of the Olymparch boot sequence as an animated preview (12 fps): Limine over the temple → a gold
scanline draws temple and wordmark → the torch lights → password (a spark per character) → checking shimmer →
unlock (lock opens, temple flash, spark burst; no ring) → progress bar → the desktop bar slides in, temple stays.

Usage: bootpreview.py <out.gif> [width height]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
OW, OH = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1280, 720)
S = max(2, round(OH / 180))
W, H = math.ceil(OW / S), math.ceil(OH / S)
cx, cy = W // 2, int(H * 0.56)
BG_TOP, BG_BOT = (13, 13, 18), (8, 8, 12)
HALO = [(30, 22, 10), (42, 29, 12), (60, 39, 12), (84, 52, 14)]
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
LINE, BOXBG, BARBG = (58, 54, 68), (13, 13, 18), (10, 10, 14)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

GL = {
    "O": [".#####.", "#######", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "#######", ".#####."],
    "L": ["##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "#######", "#######"],
    "Y": ["##...##", "##...##", "##...##", "###.###", ".#####.", "..###..", "..###..", "..###..", "..###..", "..###..", "..###.."],
    "M": ["##...##", "###.###", "#######", "##.#.##", "##.#.##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##"],
    "P": ["######.", "#######", "##...##", "##...##", "#######", "######.", "##.....", "##.....", "##.....", "##.....", "##....."],
    "A": [".#####.", "#######", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "##...##", "##...##", "##...##"],
    "R": ["######.", "#######", "##...##", "##...##", "#######", "######.", "##.##..", "##..##.", "##...##", "##...##", "##...##"],
    "C": [".######", "#######", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "##.....", "#######", ".######"],
    "H": ["##...##", "##...##", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "##...##", "##...##", "##...##"],
}


def ramp(colors, t, x, y):
    t = min(max(t, 0.0), 0.9999) * (len(colors) - 1)
    i, f = int(t), t - int(t)
    return colors[min(i + (f * 16 > BAYER[y % 4][x % 4] + 0.5), len(colors) - 1)]


def make_wordmark():
    text = "OLYMPARCH"
    w = (len(text) * 8 - 1) * 2
    img = Image.new("RGBA", (w + 2, 24), (0, 0, 0, 0))
    for i, ch in enumerate(text):
        for gy, row in enumerate(GL[ch]):
            for gx, c in enumerate(row):
                if c != "#":
                    continue
                for dy in range(2):
                    for dx in range(2):
                        y = gy * 2 + dy
                        col = GOLD[4] if y < 2 else GOLD[3] if y < 10 else GOLD[2] if y < 18 else GOLD[1]
                        img.putpixel((1 + i * 16 + gx * 2 + dx, 1 + y), col + (255,))
    return img


def make_temple():
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


def halo(px, n, strength, base):
    amp, rad, lift = flicker((n % 48) / 48)
    for y in range(max(0, cy - 60), min(H, cy + 12)):        # never behind the wordmark
        for x in range(max(0, cx - 70), min(W, cx + 70)):
            dy = y - cy + 8 + lift
            ry = 30 * rad * (1.18 if dy < 0 else 0.92)
            if dy < 0:
                th = math.atan2(dy, x - cx + 0.5)
                ry *= 1 + 0.11 * math.sin(5 * th + 2 * math.pi * n / 48 * 6) + 0.06 * math.sin(9 * th - 2 * math.pi * n / 48 * 10)
            g = max(0.0, 1 - math.hypot((x - cx + 0.5) / (46 * rad), dy / ry))
            if g > 0:
                v = min(1, (g ** 1.6) * amp * 0.85 * strength)
                if v > 0.02:
                    c = ramp([base[y], *HALO], v, x, y)
                    if sum(c) > sum(px[x, y]):   # only ever adds light
                        px[x, y] = c


SPK = ((-5, 0.0, 1), (6, 0.17, -1), (-1, 0.34, 1), (9, 0.5, -1), (-9, 0.67, 1), (2, 0.84, -1))
WM, TP = make_wordmark(), make_temple()
TX, TY = cx - 17, cy + 8 - 24
WX, WY = cx - WM.width // 2, cy + 15
BW = 64
BX, BY = cx - BW // 2 + 5, WY + 30
LOCK_C = ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
LOCK_O = ["..###..", ".#...#.", ".#.....", "#######", "###.###", "###.###", "#######"]
BASEROW = [tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * y / H) for i in range(3)) for y in range(H)]
try:
    FONT = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf", max(12, OH // 52))
except OSError:
    FONT = ImageFont.load_default()

frames, tick = [], 0
extra_sparks = []   # [x, y, life]


def canvas():
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = BASEROW[y]
    return img, px


def blit(img, sprite, x, y, rows=None, alpha=1.0):
    if rows is not None:
        sprite = sprite.crop((0, 0, sprite.width, max(1, min(sprite.height, rows))))
        if rows <= 0:
            return
    if alpha < 1:
        sprite = sprite.copy()
        sprite.putalpha(sprite.getchannel("A").point(lambda v: int(v * alpha)))
    img.paste(sprite, (x, y), sprite)


def draw_lock(px, opened=False, col=GOLD[3]):
    for y, row in enumerate(LOCK_O if opened else LOCK_C):
        for x, c in enumerate(row):
            if c == "#":
                px[BX - 10 + x, BY + y] = col


def draw_box(px, bullets=0, fill=None, shimmer=None):
    for x in range(BW):
        for y in range(7):
            edge = y in (0, 6) or x in (0, BW - 1)
            px[BX + x, BY + y] = fill if fill else (LINE if edge else BOXBG)
    for x, y in ((0, 0), (1, 0), (0, 1), (BW - 1, 6), (BW - 2, 6), (BW - 1, 5)):
        px[BX + x, BY + y] = GOLD[2] if not fill else fill
    if shimmer is not None:
        for d in range(3):
            x = shimmer + d
            if 1 <= x < BW - 1:
                for y in range(1, 6):
                    px[BX + x, BY + y] = GOLD[4] if d == 1 else GOLD[2]
    for k in range(bullets):
        px[BX + 4 + k * 3, BY + 3] = GOLD[3]


def draw_progress(px, p):
    for x in range(BW):
        for y in range(5):
            px[BX + x, BY + 1 + y] = LINE if (y in (0, 4) or x in (0, BW - 1)) else BOXBG
    n = round((BW - 2) * p)
    for x in range(n):
        for y, c in ((1, GOLD[4]), (2, GOLD[3]), (3, GOLD[2])):
            px[BX + 1 + x, BY + 1 + y] = c
    if n:
        for y in range(1, 4):
            px[BX + n, BY + 1 + y] = GOLD[4]


def ring(px, r):
    for a in range(0, 360, 2):
        for w in (0, 1):
            x = round(cx + (r + w) * math.cos(math.radians(a)))
            y = round(cy - 4 + (r + w) * 0.62 * math.sin(math.radians(a)))
            if 0 <= x < W and 0 <= y < H and (x + y) % 2 == 0:
                px[x, y] = GOLD[4] if r < 35 else GOLD[3] if r < 70 else GOLD[1]


def spread(px, k, strength):
    """Unlock: the torch light spreads out from the temple over the whole screen (k = 0..1 how far)."""
    rx, ry = 46 + k * (W * 0.75), 30 + k * (H * 0.75)
    for y in range(H):
        for x in range(W):
            g = max(0.0, 1 - math.hypot((x - cx + 0.5) / rx, (y - cy + 8) / ry))
            if g > 0:
                v = min(1, (g ** 1.3) * strength)
                if v > 0.03:
                    c = ramp([BASEROW[y], *HALO, GOLD[0]], v, x, y)
                    if sum(c) > sum(px[x, y]):
                        px[x, y] = c


def sparks(px):
    for x0, ph, sway in SPK:
        t = ((tick % 48) / 48 + ph) % 1
        if t > 0.65:
            continue
        px[cx + x0 + round(sway * 1.5 * math.sin(2 * math.pi * t * 2)), cy + 8 - 24 - round(t * 14)] = \
            GOLD[3] if t < 0.2 else GOLD[2] if t < 0.4 else GOLD[1]
    for s in extra_sparks:
        if 0 <= s[0] < W and 0 <= s[1] < H:
            px[round(s[0]), round(s[1])] = GOLD[4] if s[2] > 6 else GOLD[2]
        s[0] += s[3]; s[1] -= s[4] if len(s) > 4 else 1.2; s[2] -= 1
    extra_sparks[:] = [s for s in extra_sparks if s[2] > 0]


def finish(img, overlay=None):
    global tick
    big = img.resize((W * S, H * S), Image.NEAREST).crop((0, 0, OW, OH))
    d = big.load()
    for y in range(0, OH, max(2, S // 2)):
        for x in range(OW):
            r, g, b = d[x, y]
            d[x, y] = (r * 3 // 4, g * 3 // 4, b * 3 // 4)
    if overlay:
        overlay(ImageDraw.Draw(big))
    frames.append(big)
    tick += 1


def scene(halo_s=1.0, wm=1.0, temple_flash=False, after=None, bar=0, light=None):
    img, px = canvas()
    if light:
        spread(px, *light)
    if halo_s > 0:
        halo(px, tick, halo_s, BASEROW)
        sparks(px)
    blit(img, TP, TX, TY)
    if temple_flash:
        for y in range(TY, TY + 25):
            for x in range(TX, TX + 34):
                if px[x, y] != BASEROW[y] and px[x, y][0] > 120:
                    px[x, y] = GOLD[4]
    if wm > 0:
        blit(img, WM, WX - 1, WY - 1, alpha=wm)
    if after:
        after(px)
    if bar:
        for y in range(min(bar, 9)):
            for x in range(W):
                px[x, y] = BARBG if y < 8 else LINE
    return img


# 1. Limine: the temple is already there, menu in gold (0.8 s)
for i in range(10):
    img, px = canvas(); blit(img, TP, TX, TY)
    def menu(dr, i=i):
        f = FONT
        dr.text((OW // 2, OH * 0.05), "Olymparch", fill=GOLD[3], font=f, anchor="mm")
        dr.text((OW // 2, OH * 0.09), "ARROWS Select   ENTER Boot   E Edit", fill=(154, 150, 163), font=f, anchor="mm")
        dr.rectangle((OW // 2 - OW * 0.06, OH * 0.2, OW // 2 + OW * 0.06, OH * 0.235), fill=GOLD[3])
        dr.text((OW // 2, OH * 0.217), "Olymparch", fill=(10, 10, 14), font=f, anchor="mm")
        dr.text((OW // 2, OH * 0.27), "Snapshots", fill=(232, 230, 223), font=f, anchor="mm")
        dr.text((OW // 2, OH * 0.95), "Booting in 1...", fill=GOLD[2], font=f, anchor="mm")
    finish(img, menu)
# 2. Scanline: draws temple and wordmark, bright line with a weaker trailing line (1 s)
top, bot = TY, WY + 23
for i in range(12):
    y = top + (bot - top) * (i + 1) // 12
    img, px = canvas()
    blit(img, TP, TX, TY, rows=y - TY)
    blit(img, WM, WX - 1, WY - 1, rows=y - WY + 1)
    for x in range(cx - 75, cx + 75):
        if 0 <= y < H:
            px[x, y] = GOLD[4] if abs(x - cx) < 60 else GOLD[2]
        if 0 <= y - 2 < H and abs(x - cx) < 60:
            px[x, y - 2] = GOLD[2]
    finish(img)
# 3. The torch lights while the password box fades in (1.2 s)
for i in range(14):
    def a(px, i=i):
        if i > 6:
            draw_lock(px, col=GOLD[3] if i > 9 else GOLD[1])
            if i > 8:
                draw_box(px)
    finish(scene(halo_s=(i + 1) / 14, after=a))
# 4. Typing: a bullet and a little spark per character (8 characters)
for k in range(1, 9):
    extra_sparks.append([BX + 4 + (k - 1) * 3, BY + 2, 10, 0])
    for _ in range(3):
        finish(scene(after=lambda px, k=k: (draw_lock(px), draw_box(px, bullets=k))))
# 5. Enter: the bullets gather, a shimmer runs while the password is checked (about 2 s of argon2)
for i in range(4):
    finish(scene(after=lambda px, i=i: (draw_lock(px), draw_box(px, bullets=max(0, 8 - i * 3)))))
for i in range(16):
    finish(scene(after=lambda px, i=i: (draw_lock(px), draw_box(px, shimmer=(i * 5) % (BW + 6) - 3))))
# 6. Unlocked: lock opens, temple flashes, a thick ring runs out, a burst of sparks
for k in range(12):
    a = math.radians(200 + k * 12)   # a fan over the temple roof, each spark its own speed
    extra_sparks.append([cx + (k - 6), cy - 18 + (k % 3), 12 + (k * 7) % 6, math.cos(a) * 1.1, 0.6 + ((k * 5) % 7) * 0.18])
for i in range(12):   # the light spreads over the screen and settles back to the torch
    def a(px, i=i):
        draw_lock(px, opened=True, col=GOLD[4] if i < 4 else GOLD[3])
        if i < 3:
            draw_box(px, fill=GOLD[4] if i < 2 else GOLD[3])
        else:
            draw_progress(px, 0.0)
    k = (i + 1) / 12
    finish(scene(temple_flash=i < 3, after=a, light=(k ** 0.7, 1.15 * (1 - k) ** 1.4 + 0.15)))
# 7. Progress bar while the system starts (2.5 s, eases out)
for i in range(30):
    p = 1 - (1 - i / 29) ** 2
    finish(scene(after=lambda px, p=p: (draw_lock(px, opened=True), draw_progress(px, p))))
# 8. Hand-off: wordmark and bar fade, the shell's bar slides in, temple and torch stay
for i in range(10):
    finish(scene(wm=max(0, 1 - i / 6), bar=min(9, i), after=(lambda px: None) if i > 5 else
                 (lambda px: (draw_lock(px, opened=True), draw_progress(px, 1.0)))))
for i in range(14):
    finish(scene(wm=0, bar=9))
frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=83, loop=0, optimize=True)
print("ok", len(frames), "bilder,", round(len(frames) / 12, 1), "s")
