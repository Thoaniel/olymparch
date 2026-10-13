#!/usr/bin/env python3
"""A god's illustration (art/illustrations/<id>.svg) as a still background frame for its theme.

  python art/illustrations/render.py art/illustrations/hades.svg OUT/1080 1920 1080

writes OUT/1080/frame-00.png: the SVG drawn by rsvg-convert (librsvg) at that size, without alpha. A background with
one frame is a still; the shell smooths it when the screen is not exactly that size (docs/themes.md). The SVGs are
drawn by hand for Olymparch (no AI, nothing downloaded); see the comment at the top of each.
"""
import io
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image


def main():
    if len(sys.argv) != 5:
        sys.exit("usage: render.py SVG OUTDIR WIDTH HEIGHT")
    svg, out, w, h = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
    if not shutil.which("rsvg-convert"):
        sys.exit("render.py: rsvg-convert is missing (pacman -S librsvg)")
    png = subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h), str(svg)], check=True, capture_output=True).stdout
    im = Image.open(io.BytesIO(png)).convert("RGB")
    if im.size != (w, h):
        sys.exit(f"render.py: {svg} drew {im.size}, not {w}×{h}")
    out.mkdir(parents=True, exist_ok=True)
    tmp = out / ".frame-00.png"
    im.save(tmp, optimize=True)
    tmp.replace(out / "frame-00.png")
    print(out / "frame-00.png")


if __name__ == "__main__":
    main()
