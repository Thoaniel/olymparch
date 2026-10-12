"""Felles pikselkunst for bakgrunnene (docs/themes.md): samme språk som tempelet i art/torch.py.

Alt tegnes på et lite lerret (320×180), skaleres opp uten utjevning (6× for 1080, 8× for 1440) og får de samme
skannlinjene som tempelet. Fargene kommer fra temaets palett; overganger er Bayer-dithret mellom noen få trinn, så
et bilde har sjelden mer enn hundre farger og lagres som en palett-PNG (små filer).

En scene er en funksjon draw(c, t) der c er et Canvas og t er 0..1 gjennom løkka. Bevegelse må gå sømløst rundt:
bruk sin/cos med et helt antall perioder per løkke (c.wave), eller ting som flytter seg et helt antall ganger
rundt (c.loop). Ro framfor fart: bakgrunnen står bak vinduer, og baren og varslene skal være lette å lese.
"""
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageDraw

W, H = 320, 180
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
TAU = 2 * math.pi


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, f):
    """f < 0: mørkere mot svart, f > 0: lysere mot hvitt"""
    return mix(c, (0, 0, 0), -f) if f < 0 else mix(c, (255, 255, 255), f)


def hsh(*a):
    """et fast tall 0..1 fra heltall (samme hver gang: bildene blir like ved hver bygging)"""
    x = 0x9E3779B9
    for v in a:
        x = (x ^ (int(v) & 0xFFFFFFFF)) * 0x85EBCA6B & 0xFFFFFFFF
        x ^= x >> 13
        x = x * 0xC2B2AE35 & 0xFFFFFFFF
        x ^= x >> 16
    return x / 0xFFFFFFFF


class Palette:
    """temaets farger som RGB, og trinnene scenene bruker"""

    def __init__(self, theme):
        p = theme["palette"]
        for k in ("bg", "surface", "raised", "line", "text", "muted", "accent", "accentHi", "danger"):
            if not re.fullmatch(r"#[0-9a-fA-F]{6}", p.get(k, "")):
                raise SystemExit(f"palette.{k} må være #RRGGBB")
        self.id = theme.get("id", "zeus")
        self.light = theme.get("light") is True or sum(rgb(p["bg"])) / 765 > 0.5
        self.bg, self.surface, self.raised, self.line = (rgb(p[k]) for k in ("bg", "surface", "raised", "line"))
        self.text, self.muted, self.acc, self.hi, self.danger = (rgb(p[k]) for k in ("text", "muted", "accent", "accentHi", "danger"))
        if self.light:
            self.top, self.bottom = mix(self.bg, self.surface, 0.3), self.bg
            # metallet: mørkt på det lyse, som tempelet i Apollon
            self.gold = [shade(self.acc, -0.55), shade(self.acc, -0.3), self.acc, mix(self.acc, self.hi, 0.5), shade(self.hi, 0.15)]
            self.halo = [mix(mix(self.bg, self.hi, t), (255, 214, 120), 0.25) for t in (0.06, 0.12, 0.2, 0.3)]
            self.scan = 0.97
        else:
            self.top, self.bottom = mix(self.bg, self.surface, 0.3), shade(self.bg, -0.2)
            self.gold = [shade(self.acc, -0.58), shade(self.acc, -0.3), self.acc, mix(self.acc, self.hi, 0.6), shade(self.hi, 0.45)]
            warm = shade(self.acc, -0.35)
            self.halo = [mix(self.bg, warm, t) for t in (0.13, 0.2, 0.31, 0.45)]
            self.scan = 0.75

    def ramp(self, a, b, n):
        return [mix(a, b, i / (n - 1)) for i in range(n)]

    def night(self, n=5):
        """himmelen: fra bakgrunnen øverst (der baren står) mot overflaten nederst"""
        return self.ramp(self.bottom, mix(self.surface, self.line, 0.35), n)

    def dim(self, c, t=0.5):
        """c dempet mot bakgrunnen (t = hvor mye av c som blir igjen)"""
        return mix(self.bg, c, t)


class Canvas:
    def __init__(self, pal, t, n, frames):
        self.p, self.t, self.n, self.frames = pal, t, n, frames
        self.img = Image.new("RGB", (W, H), pal.bottom)
        self.px = self.img.load()
        self.draw = ImageDraw.Draw(self.img)

    # ── tid
    def wave(self, k=1, phase=0.0):
        """sin med k hele perioder per løkke: -1..1"""
        return math.sin(TAU * (self.t * k + phase))

    def loop(self, k=1, phase=0.0):
        """0..1 som går k ganger rundt i løkka"""
        return (self.t * k + phase) % 1.0

    # ── piksler
    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < W and 0 <= y < H and c is not None:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[min(max(int(x), 0), W - 1), min(max(int(y), 0), H - 1)]

    def pick(self, colors, v, x, y):
        """v 0..1 langs colors, dithret (Bayer 4×4) mellom to naboer"""
        v = min(max(v, 0.0), 0.9999) * (len(colors) - 1)
        i, f = int(v), v - int(v)
        return colors[min(i + (f * 16 > BAYER[y % 4][x % 4] + 0.5), len(colors) - 1)]

    def gradient(self, colors, y0=0, y1=H, x0=0, x1=W):
        for y in range(max(0, y0), min(H, y1)):
            v = (y - y0) / max(1, y1 - y0 - 1)
            for x in range(max(0, x0), min(W, x1)):
                self.px[x, y] = self.pick(colors, v, x, y)

    def glow(self, cx, cy, rx, ry, colors, strength=1.0, power=1.6, top=None):
        """en dithret glød rundt (cx, cy) over det som er tegnet; colors[0] er det svakeste trinnet"""
        for y in range(max(0, int(cy - ry)), min(H, int(cy + ry) + 1)):
            if top is not None and y < top:
                continue
            for x in range(max(0, int(cx - rx)), min(W, int(cx + rx) + 1)):
                g = 1 - math.hypot((x - cx + 0.5) / rx, (y - cy + 0.5) / ry)
                if g <= 0:
                    continue
                v = (g ** power) * strength
                c = self.pick([None, *colors], v, x, y)
                if c is not None:
                    self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        self.draw.rectangle((x0, y0, x1, y1), fill=c)

    def line(self, pts, c, width=1):
        self.draw.line(pts, fill=c, width=width)

    def poly(self, pts, c):
        self.draw.polygon(pts, fill=c)

    def disc(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2 <= r * r:
                    self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx + 0.5) / rx) ** 2 + ((y - cy + 0.5) / ry) ** 2 <= 1:
                    self.put(x, y, c)

    def sprite(self, rows, x, y, colors, flip=False, scale=1):
        """rows: tekstlinjer; hvert tegn slås opp i colors (mangler = gjennomsiktig). x, y = øverste venstre hjørne"""
        if isinstance(rows, str):
            rows = [r for r in rows.strip("\n").split("\n")]
        w = max(len(r) for r in rows)
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                c = colors.get(ch)
                if c is None:
                    continue
                xx = (w - 1 - i) if flip else i
                for a in range(scale):
                    for b in range(scale):
                        self.put(x + xx * scale + a, y + j * scale + b, c)

    # ── landskap
    def ridge(self, base, amp, seed, c, rough=0.5, period=None, x0=0, x1=W):
        """en fjell- eller åsrygg (sum av sinuser) fylt ned til bunnen; gir høydene tilbake"""
        heights = []
        for x in range(x0, x1):
            h = 0.0
            a, f = amp, 1.0
            for o in range(4):
                h += a * math.sin(x / (period or 60) * f * 2.1 + seed * 7.3 + o * 1.9)
                a *= rough
                f *= 2.03
            yy = int(base - h)
            heights.append(yy)
            for y in range(max(0, yy), H):
                self.px[x, y] = c
        return heights

    def stars(self, count, seed, y0=0, y1=H, colors=None, twinkle=0.35):
        """faste stjerner; noen få blinker sakte (helt antall perioder)"""
        colors = colors or [self.p.dim(self.p.muted, 0.45), self.p.dim(self.p.text, 0.7), self.p.text]
        for i in range(count):
            x = int(hsh(seed, i, 1) * W)
            y = int(y0 + hsh(seed, i, 2) * (y1 - y0))
            lvl = hsh(seed, i, 3)
            k = 1 + int(hsh(seed, i, 4) * 3)
            tw = 0.5 + 0.5 * math.sin(TAU * (self.t * k + hsh(seed, i, 5)))
            v = lvl * (1 - twinkle) + tw * twinkle * lvl
            c = colors[min(len(colors) - 1, int(v * len(colors)))]
            self.put(x, y, c)
            if lvl > 0.93:  # de klareste får et kors
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    self.put(x + dx, y + dy, colors[0])

    def moon(self, cx, cy, r, c, shadow=None, glow=None):
        if glow:
            self.glow(cx, cy, r * 3.2, r * 3.2, glow, 0.8)
        self.disc(cx, cy, r, c)
        if shadow:  # noen kratere
            for a, b, s in ((-0.3, -0.2, 0.22), (0.25, 0.15, 0.28), (-0.1, 0.4, 0.16)):
                self.disc(cx + a * r, cy + b * r, max(1, s * r), shadow)

    def cloud(self, cx, cy, w, h, c, seed=0, edge=None):
        """en klump sky av noen ellipser; edge = en lysere kant oppå"""
        n = max(3, int(w / 10))
        for i in range(n):
            x = cx - w / 2 + (i + 0.5) * w / n
            rr = h * (0.55 + 0.45 * hsh(seed, i))
            if edge is not None:
                self.ellipse(x, cy - rr * 0.35 - 1, w / n * 0.9, rr * 0.8, edge)
        for i in range(n):
            x = cx - w / 2 + (i + 0.5) * w / n
            rr = h * (0.55 + 0.45 * hsh(seed, i))
            self.ellipse(x, cy - rr * 0.35, w / n * 0.9, rr * 0.8, c)
        self.ellipse(cx, cy + h * 0.15, w / 2, h * 0.35, c)

    def particles(self, count, seed, x0, x1, y0, y1, colors, rise=True, sway=2.0, life=1.0):
        """gnister, glør, blader: stiger (eller faller) fra y0 til y1 og går sømløst rundt; colors fra nytt til gammelt"""
        for i in range(count):
            ph = hsh(seed, i, 7)
            u = (self.t + ph) % 1.0
            if u > life:
                continue
            u /= life
            x = x0 + hsh(seed, i, 8) * (x1 - x0) + sway * math.sin(TAU * (u * 2 + hsh(seed, i, 9)))
            y = (y0 + (y1 - y0) * u) if rise else (y1 + (y0 - y1) * u)
            self.put(x, y, colors[min(len(colors) - 1, int(u * len(colors)))])


# ── lagring: palett-PNG med skannlinjer, som tempelet
def upscale(img, OW, OH, pal):
    S = max(2, round(OH / 180))
    P = max(2, S // 2)
    colors = img.getcolors(256)
    if colors is not None and len(colors) <= 127:
        cols = [c for _, c in colors]
        index = {c: i for i, c in enumerate(cols)}
        k = len(cols)
        small = Image.new("L", img.size)
        small.putdata([index[c] for c in img.getdata()])
        big = small.resize((W * S, H * S), Image.NEAREST).crop((0, 0, OW, OH))
        dark = big.point(lambda v: v + k)
        mask = Image.new("L", (OW, OH), 0)
        md = ImageDraw.Draw(mask)
        for y in range(0, OH, P):
            md.line((0, y, OW, y), fill=255)
        out = Image.frombytes("P", (OW, OH), Image.composite(dark, big, mask).tobytes())
        flat = []
        for c in cols:
            flat += c
        for c in cols:
            flat += [int(v * pal.scan) for v in c]
        out.putpalette(flat)
        return out
    big = img.resize((W * S, H * S), Image.NEAREST).crop((0, 0, OW, OH))
    d = big.load()
    for y in range(0, OH, P):
        for x in range(OW):
            r, g, b = d[x, y]
            d[x, y] = (int(r * pal.scan), int(g * pal.scan), int(b * pal.scan))
    return big


def load_theme(path):
    return json.loads(Path(path).read_text()) if path else {"id": "zeus", "palette": {
        "bg": "#0a0a0e", "surface": "#15151c", "raised": "#1c1c25", "line": "#3a3644", "text": "#e8e6df",
        "muted": "#9a96a3", "accent": "#d4a73a", "accentHi": "#f4d35e", "danger": "#e0605e"}}


def frames_of(draw, frames, theme):
    pal = Palette(theme)
    for n in range(frames):
        c = Canvas(pal, n / frames, n, frames)
        draw(c)
        yield c.img, pal
