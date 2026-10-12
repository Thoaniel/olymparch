"""Draft 5 of the Olymparch boot sequence as an animated preview (12 fps).

Limine (big temple + OLYMPARCH wordmark as its wallpaper, gold menu) → a gold scanline draws temple and
wordmark → the torch lights → password (a spark per character) → checking shimmer → unlock (lock opens, temple
flash, the light spreads over the screen, spark burst) → progress bar → the wordmark fades and the temple shrinks
smoothly to its place on the desktop wallpaper while the shell's bar slides in.

Usage: bootpreview.py <out.gif> [width height]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
OW, OH = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) > 3 else (1280, 720)
S = max(2, round(OH / 180))
W, H = math.ceil(OW / S), math.ceil(OH / S)
cx, cy = W // 2, int(H * 0.56)            # the desktop wallpaper's temple position
BG_TOP, BG_BOT = (13, 13, 18), (8, 8, 12)
HALO = [(30, 22, 10), (42, 29, 12), (60, 39, 12), (84, 52, 14)]
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
LINE, BOXBG, BARBG = (58, 54, 68), (13, 13, 18), (10, 10, 14)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
TEMPLE_BIG, WM_SCALE = 2, 3

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


def make_wordmark(k):
    text = "OLYMPARCH"
    w, h = (len(text) * 8 - 1) * k, 11 * k
    img = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    for i, ch in enumerate(text):
        for gy, row in enumerate(GL[ch]):
            for gx, c in enumerate(row):
                if c != "#":
                    continue
                for dy in range(k):
                    for dx in range(k):
                        y = gy * k + dy
                        f = y / h
                        col = GOLD[4] if f < 0.09 else GOLD[3] if f < 0.45 else GOLD[2] if f < 0.82 else GOLD[1]
                        img.putpixel((1 + i * 8 * k + gx * k + dx, 1 + y), col + (255,))
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


TP, WM = make_temple(), make_wordmark(WM_SCALE)
BIG_TOP = 30                                   # temple top when big; then wordmark, then box
WX, WY = cx - WM.width // 2, BIG_TOP + 25 * TEMPLE_BIG + 9
BW = 64
BX, BY = cx - BW // 2 + 5, WY + WM.height + 10
SMALL_TOP = cy - 16                            # where the wallpaper's temple sits
pose = [float(TEMPLE_BIG), float(BIG_TOP)]     # [scale, top]; the hand-off animates it to [1, SMALL_TOP]
LOCK_C = ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
LOCK_O = ["..###..", ".#...#.", ".#.....", "#######", "###.###", "###.###", "#######"]
BASEROW = [tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * y / H) for i in range(3)) for y in range(H)]
try:
    FONT = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf", max(12, OH // 48))
except OSError:
    FONT = ImageFont.load_default()


def temple_sprite():
    sc = pose[0]
    return TP.resize((round(34 * sc), round(25 * sc)), Image.NEAREST)


def temple_xy():
    sp = temple_sprite()
    return cx - sp.width // 2, round(pose[1])


def flicker(t):
    a = 2 * math.pi * t
    s = 0.35 * math.sin(a * 2 + 0.3) + 0.30 * math.sin(a * 7 + 1.7) + 0.20 * math.sin(a * 13 + 4.0) + 0.15 * math.sin(a * 19 + 2.9)
    return 1 + 0.34 * s, 1 + 0.07 * s, round(0.8 * math.sin(a * 3 + 0.4) + 0.5 * math.sin(a * 11 + 1.1))


def halo(px, n, strength, wm_top):
    sc, top = pose
    hcy = top + 8 * sc
    amp, rad, lift = flicker((n % 48) / 48)
    y_end = min(H, int(hcy + 20 * sc))
    if wm_top:
        y_end = min(y_end, wm_top)
    for y in range(max(0, int(hcy - 52 * sc)), y_end):
        for x in range(max(0, int(cx - 70 * sc)), min(W, int(cx + 70 * sc))):
            dy = y - hcy + lift * sc
            ry = 30 * sc * rad * (1.18 if dy < 0 else 0.92)
            if dy < 0:
                th = math.atan2(dy, x - cx + 0.5)
                ry *= 1 + 0.11 * math.sin(5 * th + 2 * math.pi * n / 48 * 6) + 0.06 * math.sin(9 * th - 2 * math.pi * n / 48 * 10)
            g = max(0.0, 1 - math.hypot((x - cx + 0.5) / (46 * sc * rad), dy / ry))
            if g > 0:
                v = min(1, (g ** 1.6) * amp * 0.85 * strength)
                if v > 0.02:
                    c = ramp([BASEROW[y], *HALO], v, x, y)
                    if sum(c) > sum(px[x, y]):
                        px[x, y] = c


def spread(px, k, strength):
    sc, top = pose
    hcy = top + 8 * sc
    rx, ry = 46 * sc + k * W, 30 * sc + k * H
    for y in range(H):
        for x in range(W):
            g = max(0.0, 1 - math.hypot((x - cx + 0.5) / rx, (y - hcy) / ry))
            if g > 0:
                v = min(1, (g ** 2.0) * strength)
                if v > 0.03:
                    c = ramp([BASEROW[y], (19, 15, 11), *HALO, GOLD[0]], v, x, y)
                    if sum(c) > sum(px[x, y]):
                        px[x, y] = c


SPK = ((-5, 0.0, 1), (6, 0.17, -1), (-1, 0.34, 1), (9, 0.5, -1), (-9, 0.67, 1), (2, 0.84, -1))
frames, tick = [], 0
extra_sparks = []


def sparks(px):
    sc, top = pose
    for x0, ph, sway in SPK:
        t = ((tick % 48) / 48 + ph) % 1
        if t > 0.65:
            continue
        x = round(cx + x0 * sc + sway * 1.5 * sc * math.sin(2 * math.pi * t * 2))
        y = round(top - t * 14 * sc)
        c = GOLD[3] if t < 0.2 else GOLD[2] if t < 0.4 else GOLD[1]
        for dx in range(max(1, int(sc))):
            if 0 <= x + dx < W and 0 <= y < H:
                px[x + dx, y] = c
    for s in extra_sparks:
        if 0 <= s[0] < W and 0 <= s[1] < H:
            px[round(s[0]), round(s[1])] = GOLD[4] if s[2] > 6 else GOLD[2]
        s[0] += s[3]; s[1] -= s[4]; s[2] -= 1
    extra_sparks[:] = [s for s in extra_sparks if s[2] > 0]


def canvas():
    img = Image.new("RGB", (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = BASEROW[y]
    return img, px


def blit(img, sprite, x, y, rows=None, alpha=1.0):
    if rows is not None:
        if rows <= 0:
            return
        sprite = sprite.crop((0, 0, sprite.width, min(sprite.height, rows)))
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
    if not fill:
        for x, y in ((0, 0), (1, 0), (0, 1), (BW - 1, 6), (BW - 2, 6), (BW - 1, 5)):
            px[BX + x, BY + y] = GOLD[2]
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
        halo(px, tick, halo_s, WY - 1 if wm > 0 else None)
        sparks(px)
    sp = temple_sprite()
    tx, ty = temple_xy()
    blit(img, sp, tx, ty)
    if temple_flash:
        for y in range(ty, ty + sp.height):
            for x in range(tx, tx + sp.width):
                if px[x, y][0] > 120:
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


# 1. Limine: big temple and wordmark are its wallpaper; the menu in gold under them, no help text (1 s)
for i in range(12):
    img, px = canvas()
    blit(img, temple_sprite(), *temple_xy())
    blit(img, WM, WX - 1, WY - 1)
    def menu(dr, i=i):
        y0 = (BY + 2) * S
        dr.rectangle((OW // 2 - OW * 0.075, y0 - OH * 0.022, OW // 2 + OW * 0.075, y0 + OH * 0.022), fill=GOLD[3])
        dr.text((OW // 2, y0), "Olymparch", fill=(10, 10, 14), font=FONT, anchor="mm")
        dr.text((OW // 2, y0 + OH * 0.055), "Snapshots  ›", fill=(154, 150, 163), font=FONT, anchor="mm")
        dr.text((OW // 2, OH * 0.94), f"{3 - i // 4}", fill=GOLD[2], font=FONT, anchor="mm")
    finish(img, menu)
# 2. Scanline: draws temple and wordmark from the top (1 s)
top, bot = BIG_TOP, WY + WM.height
for i in range(12):
    y = top + (bot - top) * (i + 1) // 12
    img, px = canvas()
    tx, ty = temple_xy()
    blit(img, temple_sprite(), tx, ty, rows=y - ty)
    blit(img, WM, WX - 1, WY - 1, rows=y - WY + 1)
    for x in range(cx - 110, cx + 110):
        if 0 <= y < H:
            px[x, y] = GOLD[4] if abs(x - cx) < 95 else GOLD[2]
        if 0 <= y - 2 < H and abs(x - cx) < 95:
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
# 4. Typing: a bullet and a little spark per character
for k in range(1, 9):
    extra_sparks.append([BX + 4 + (k - 1) * 3, BY + 2, 10, 0, 1.2])
    for _ in range(3):
        finish(scene(after=lambda px, k=k: (draw_lock(px), draw_box(px, bullets=k))))
# 5. Enter: bullets gather, a shimmer runs while the disk is unlocked
for i in range(4):
    finish(scene(after=lambda px, i=i: (draw_lock(px), draw_box(px, bullets=max(0, 8 - i * 3)))))
for i in range(16):
    finish(scene(after=lambda px, i=i: (draw_lock(px), draw_box(px, shimmer=(i * 5) % (BW + 6) - 3))))
# 6. Unlocked: lock opens, temple flashes, the light spreads over the screen, sparks burst from the roof
for k in range(12):
    ang = math.radians(200 + k * 12)
    extra_sparks.append([cx + (k - 6) * 2, BIG_TOP - 2 + (k % 3), 12 + (k * 7) % 6, math.cos(ang) * 1.6, 0.8 + ((k * 5) % 7) * 0.22])
for i in range(12):
    def a(px, i=i):
        draw_lock(px, opened=True, col=GOLD[4] if i < 4 else GOLD[3])
        if i < 3:
            draw_box(px, fill=GOLD[4] if i < 2 else GOLD[3])
        else:
            draw_progress(px, 0.0)
    k = (i + 1) / 12
    finish(scene(temple_flash=i < 3, after=a, light=(k ** 0.7, 1.3 * (1 - k) ** 1.2)))
# 7. Progress bar while the system starts
for i in range(30):
    p = 1 - (1 - i / 29) ** 2
    finish(scene(after=lambda px, p=p: (draw_lock(px, opened=True), draw_progress(px, p))))
# 8. Hand-off: wordmark, lock and bar fade, then the temple shrinks to its place on the wallpaper; the bar slides in
for i in range(6):
    finish(scene(wm=1 - (i + 1) / 6))
for i in range(12):
    e = 1 - (1 - (i + 1) / 12) ** 3
    pose[0] = TEMPLE_BIG + (1 - TEMPLE_BIG) * e
    pose[1] = BIG_TOP + (SMALL_TOP - BIG_TOP) * e
    finish(scene(wm=0, bar=min(9, i)))
for i in range(12):
    finish(scene(wm=0, bar=9))
frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=83, loop=0, optimize=True)
print("ok", len(frames), "bilder,", round(len(frames) / 12, 1), "s")
