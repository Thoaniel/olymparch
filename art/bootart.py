"""Assets for the Olymparch boot: the Plymouth theme images for every pixel size, and the Limine wallpapers.

Usage: bootart.py <out-dir>
Writes s<S>-*.png for S in 4, 6, 8, 12 (one art pixel = S screen pixels; Plymouth picks S from the screen height,
like the desktop wallpaper does: S = round(height / 180)), and limine-s<S>.png.
"""
import math
import sys
from pathlib import Path

from PIL import Image

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
BG = (8, 8, 12)
HALO = [(30, 22, 10), (42, 29, 12), (60, 39, 12), (84, 52, 14)]
GOLD = [(90, 44, 8), (156, 94, 12), (214, 148, 22), (244, 198, 52), (255, 234, 118)]
LINE, BOXBG = (58, 54, 68), (13, 13, 18)
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
LOCK_C = ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
LOCK_O = ["..###..", ".#...#.", ".#.....", "#######", "###.###", "###.###", "#######"]


def ramp(colors, t, x, y):
    t = min(max(t, 0.0), 0.9999) * (len(colors) - 1)
    i, f = int(t), t - int(t)
    return colors[min(i + (f * 16 > BAYER[y % 4][x % 4] + 0.5), len(colors) - 1)]


def temple(tint=None):
    t = Image.new("RGBA", (34, 25), (0, 0, 0, 0))
    px = t.load()
    tcx, by = 17, 24

    def put(x, y, c):
        px[x, y] = (tint or c) + (255,)
    for i, (w, c) in enumerate(((34, GOLD[1]), (30, GOLD[2]), (26, GOLD[3]))):
        for x in range(tcx - w // 2, tcx + w // 2):
            put(x, by - i, c)
    for k in range(6):
        x = tcx - 11 + k * 4
        for y in range(by - 13, by - 2):
            put(x, y, GOLD[3]); put(x + 1, y, GOLD[1])
    for x in range(tcx - 14, tcx + 14):
        put(x, by - 14, GOLD[2]); put(x, by - 15, GOLD[4])
    for k in range(8):
        for x in range(tcx - 14 + k * 2, tcx + 14 - k * 2):
            edge = x in (tcx - 14 + k * 2, tcx + 13 - k * 2)
            put(x, by - 16 - k, GOLD[4] if edge else GOLD[1] if k > 1 else GOLD[2])
    return t


def wordmark(k=3):
    text = "OLYMPARCH"
    w, h = (len(text) * 8 - 1) * k, 11 * k
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for i, ch in enumerate(text):
        for gy, row in enumerate(GL[ch]):
            for gx, c in enumerate(row):
                if c == "#":
                    for dy in range(k):
                        for dx in range(k):
                            y = gy * k + dy
                            f = y / h
                            col = GOLD[4] if f < 0.09 else GOLD[3] if f < 0.45 else GOLD[2] if f < 0.82 else GOLD[1]
                            img.putpixel((i * 8 * k + gx * k + dx, y), col + (255,))
    return img


def halo_layers():
    """The torch halo around the big (2x) temple, split into 3 brightness layers that the script fades."""
    w, h = 300, 163                             # ends just above the wordmark
    hcx, hcy = w / 2, 120                       # 16 art px below the big temple's top
    layers = [Image.new("RGBA", (w, h), (0, 0, 0, 0)) for _ in range(3)]
    for y in range(h):
        for x in range(w):
            dy = y - hcy
            ry = 60 * (1.18 if dy < 0 else 0.92)
            g = max(0.0, 1 - math.hypot((x - hcx + 0.5) / 92, dy / ry))
            if g <= 0:
                continue
            v = min(1, (g ** 1.6) * 0.85 * 1.15)
            c = ramp([BG, *HALO], v, x, y)
            if c == BG:
                continue
            k = 0 if v > 0.55 else 1 if v > 0.28 else 2
            layers[k].putpixel((x, y), c + (255,))
    return layers


def spread():
    """The unlock light, a big warm dithered glow at art resolution (the script scales it to the screen)."""
    w, h = 320, 180
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            g = max(0.0, 1 - math.hypot((x - w / 2 + 0.5) / (w * 0.62), (y - h * 0.4) / (h * 0.62)))
            v = min(1, g ** 2.0 * 1.3)
            if v > 0.03:
                c = ramp([BG, (19, 15, 11), *HALO, GOLD[0]], v, x, y)
                if c != BG:
                    img.putpixel((x, y), c + (255,))
    return img


def pattern(rows, color):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#":
                img.putpixel((x, y), color + (255,))
    return img


def box(bw=64):
    img = Image.new("RGBA", (bw, 7), BOXBG + (255,))
    for x in range(bw):
        img.putpixel((x, 0), LINE + (255,)); img.putpixel((x, 6), LINE + (255,))
    for y in range(7):
        img.putpixel((0, y), LINE + (255,)); img.putpixel((bw - 1, y), LINE + (255,))
    for x, y in ((0, 0), (1, 0), (0, 1), (bw - 1, 6), (bw - 2, 6), (bw - 1, 5)):
        img.putpixel((x, y), GOLD[2] + (255,))
    return img


def progress(bw=64):
    frame = Image.new("RGBA", (bw, 5), BOXBG + (255,))
    for x in range(bw):
        frame.putpixel((x, 0), LINE + (255,)); frame.putpixel((x, 4), LINE + (255,))
    for y in range(5):
        frame.putpixel((0, y), LINE + (255,)); frame.putpixel((bw - 1, y), LINE + (255,))
    fill = Image.new("RGBA", (bw - 2, 3), (0, 0, 0, 0))
    for x in range(bw - 2):
        for y, c in enumerate((GOLD[4], GOLD[3], GOLD[2])):
            fill.putpixel((x, y), c + (255,))
    return frame, fill


def up(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


T, TF, WM = temple(), temple(GOLD[4]), wordmark(3)
HL = halo_layers()
SP = spread()
PB, PF = progress()
for S in (4, 6, 8, 12):
    for p in range(S, 2 * S + 1):               # every whole pixel size between the big and the wallpaper temple
        up(T, p).save(out / f"s{S}-temple-{p}.png", optimize=True)
    up(TF, 2 * S).save(out / f"s{S}-temple-flash.png", optimize=True)
    up(WM, S).save(out / f"s{S}-wordmark.png", optimize=True)
    for k, layer in enumerate(HL):
        up(layer, S).save(out / f"s{S}-halo-{k}.png", optimize=True)
    up(SP, S).save(out / f"s{S}-spread.png", optimize=True)
    up(pattern(LOCK_C, GOLD[3]), S).save(out / f"s{S}-lock.png", optimize=True)
    up(pattern(LOCK_O, GOLD[4]), S).save(out / f"s{S}-lock-open.png", optimize=True)
    up(pattern(LOCK_C, (224, 96, 94)), S).save(out / f"s{S}-lock-error.png", optimize=True)
    up(box(), S).save(out / f"s{S}-box.png", optimize=True)
    up(Image.new("RGBA", (64, 7), GOLD[4] + (255,)), S).save(out / f"s{S}-box-flash.png", optimize=True)
    up(PB, S).save(out / f"s{S}-progress-box.png", optimize=True)
    up(PF, S).save(out / f"s{S}-progress-fill.png", optimize=True)
    for k, c in enumerate((GOLD[4], GOLD[3], GOLD[1])):
        up(Image.new("RGBA", (1, 1), c + (255,)), S).save(out / f"s{S}-spark-{k}.png", optimize=True)
    up(Image.new("RGBA", (1, 1), GOLD[3] + (255,)), S).save(out / f"s{S}-bullet.png", optimize=True)
    up(Image.new("RGBA", (3, 5), GOLD[4] + (255,)), S).save(out / f"s{S}-shimmer.png", optimize=True)
    up(Image.new("RGBA", (220, 1), GOLD[4] + (255,)), S).save(out / f"s{S}-scanline.png", optimize=True)
    up(Image.new("RGBA", (220, 1), BG + (255,)), S).save(out / f"s{S}-cover.png", optimize=True)
    # Limine wallpaper: big temple above the screen centre, wordmark below; Limine draws its menu in the middle.
    lw, lh = 220, 140
    lim = Image.new("RGB", (lw, lh), BG)
    t2 = up(T, 2)
    lim.paste(t2, (lw // 2 - t2.width // 2, lh // 2 - 70), t2)
    lim.paste(WM, (lw // 2 - WM.width // 2, lh // 2 + 30), WM)
    up(lim, S).save(out / f"limine-s{S}.png", optimize=True)
# The Plymouth script, with the image loading written out for every pixel size (no file names built at runtime)
names = ["temple_flash:temple-flash", "wordmark", "spread", "lock", "lock_open:lock-open", "lock_error:lock-error",
         "box", "box_flash:box-flash", "progress_box:progress-box", "progress_fill:progress-fill", "bullet",
         "shimmer", "scanline", "cover"]
loader = []
for S in (4, 6, 8, 12):
    lines = [f'if (S == {S}) {{']
    for k, p in enumerate(range(S, 2 * S + 1)):
        lines.append(f'    A.temple[{k}] = Image("s{S}-temple-{p}.png");')
    for k in range(3):
        lines.append(f'    A.halo[{k}] = Image("s{S}-halo-{k}.png");')
        lines.append(f'    A.spark[{k}] = Image("s{S}-spark-{k}.png");')
    for n in names:
        key, _, file = n.partition(":")
        lines.append(f'    A.{key} = Image("s{S}-{file or key}.png");')
    lines.append("}")
    loader.append("\n".join(lines))
src = (Path(__file__).resolve().parent.parent / "default/plymouth/olymparch.script").read_text()
marker = next(l for l in src.splitlines() if l.startswith("// @ASSETS@"))
(out / "olymparch.script").write_text(src.replace(marker, "\n".join(loader)))
print("ok", out)
