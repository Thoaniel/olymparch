"""Collect every test's screenshots into one HTML report (stdlib only).

  report.py OUT.html [TESTDIR ...]     default: every folder in tests/vm/out
Each test folder has steps.txt (file<TAB>description) and result.txt (PASS/FAIL + time).
"""
import base64
import html
import sys
from pathlib import Path

out = Path(sys.argv[1])
dirs = [Path(d) for d in sys.argv[2:]] or sorted(p for p in Path("tests/vm/out").iterdir() if p.is_dir())
parts = []
for d in dirs:
    res = (d / "result.txt").read_text().strip() if (d / "result.txt").exists() else "?"
    ok = res.startswith("PASS")
    rows = []
    for line in (d / "steps.txt").read_text().splitlines() if (d / "steps.txt").exists() else []:
        f, _, desc = line.partition("\t")
        if (d / f).exists():
            b64 = base64.b64encode((d / f).read_bytes()).decode()
            rows.append(f'<figure><img src="data:image/png;base64,{b64}" alt="{html.escape(desc)}">'
                        f'<figcaption><b>{html.escape(f.split("-", 1)[0])}</b> {html.escape(desc)}</figcaption></figure>')
    parts.append(f'<section><h2><span class="{"ok" if ok else "bad"}">{"✓" if ok else "✕"}</span> {html.escape(d.name)}'
                 f' <small>{html.escape(res)}</small></h2><div class="grid">{"".join(rows) or "<p>Ingen skjermbilder.</p>"}</div></section>')

out.write_text(f"""<title>Olymparch VM-tester</title>
<style>
:root {{ --bg:#060609; --line:#3a3644; --text:#e8e6df; --muted:#9a96a3; --gold:#d4a73a; --ok:#9cc98f; --bad:#e0605e; color-scheme:dark; }}
body {{ background:var(--bg); color:var(--text); font:14px/1.5 "JetBrains Mono", ui-monospace, monospace; margin:0; padding-inline:16px; padding-block:24px 48px; }}
main {{ max-width:1200px; margin:0 auto; display:grid; gap:32px; }}
h1 {{ color:var(--gold); font-size:14px; letter-spacing:.16em; margin:0; }}
h2 {{ font-size:15px; margin:0 0 10px; }} h2 small {{ color:var(--muted); font-weight:400; }}
.ok {{ color:var(--ok); }} .bad {{ color:var(--bad); }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(min(100%, 360px), 1fr)); gap:16px; }}
figure {{ margin:0; display:grid; gap:6px; }} img {{ width:100%; height:auto; border:1px solid var(--line); image-rendering:pixelated; }}
figcaption {{ color:var(--muted); font-size:12px; }} figcaption b {{ color:var(--gold); }}
</style>
<main><h1>OLYMPARCH · VM-TESTER</h1>{"".join(parts)}</main>""")
print("ok", out)
