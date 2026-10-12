"""Lager bildene til én bakgrunn for ett tema (docs/themes.md, «Backgrounds»).

Bruk: render.py <theme.json> <scene> <ut-mappe> <bredde> <høyde> [--gif]
  ->  ut-mappe/frame-00.png … (palett-PNG, skannlinjer som tempelet); --gif lager også preview.gif (8 bilder/s)
      render.py <theme.json> --list   ->  scenene temaet har (id og antall bilder)

Scenene står i art/scenes/<tema-id>.py (SCENES = {id: (bilder, draw)}); tempelet er art/torch.py.
"""
import importlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel  # noqa: E402

theme = pixel.load_theme(sys.argv[1])
tid = theme.get("id", "")
if not re.fullmatch(r"[a-z]{1,20}", tid) or not (Path(__file__).resolve().parent / f"{tid}.py").is_file():
    sys.exit(f"render.py: ingen scener for temaet {tid!r}")
scenes = importlib.import_module(tid).SCENES
if sys.argv[2] == "--list":
    for k, (frames, _) in scenes.items():
        print(k, frames)
    sys.exit(0)
name = sys.argv[2]
if name not in scenes:
    sys.exit(f"render.py: {tid} har ingen scene {name!r} ({', '.join(scenes)})")
frames, draw = scenes[name]
out = Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)
OW, OH = int(sys.argv[4]), int(sys.argv[5])
small = []
for n, (img, pal) in enumerate(pixel.frames_of(draw, frames, theme)):
    pixel.upscale(img, OW, OH, pal).save(out / f"frame-{n:02d}.png", optimize=True)
    if "--gif" in sys.argv:
        small.append(img.resize((960, 540), 0))
if small:
    small[0].save(out / "preview.gif", save_all=True, append_images=small[1:], duration=125, loop=0)
print("ok", tid, name, frames, "bilder", (OW, OH))
