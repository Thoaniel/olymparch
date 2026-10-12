#!/usr/bin/env python3
"""In the VM (tests/vm/mcp): a small MCP client over stdio that drives /usr/bin/olymparch-mcp for one step and
reports on the serial console (/dev/kmsg) as «MCP-STEP-OK …» or «MCP-STEP-NO …».

  mcp-guest.py read        read tools only: no card
  mcp-guest.py STEP        one call (STEPS below); reports CARD when the card is on screen, then the result
"""
import json
import subprocess
import sys
import threading
import time


def kmsg(line):
    with open("/dev/kmsg", "w") as f:
        f.write(f"<2>{line}\n")


class Client:
    def __init__(self):
        self.p = subprocess.Popen(["/usr/bin/olymparch-mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self.n = 0

    def req(self, method, params=None):
        self.n += 1
        self.p.stdin.write((json.dumps({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params or {}}) + "\n").encode())
        self.p.stdin.flush()
        while True:
            r = json.loads(self.p.stdout.readline())
            if r.get("id") == self.n:
                return r

    def init(self):
        r = self.req("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "vm-test", "title": "VM-test"}})
        self.p.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
        self.p.stdin.flush()
        return r

    def call(self, name, args):
        return self.req("tools/call", {"name": name, "arguments": args})


def text(r):
    return "".join(c.get("text", "") for c in r.get("result", {}).get("content", [])).replace("\n", " ")[:150]


def pending():
    out = subprocess.run(["qs", "ipc", "-p", "/usr/share/olymparch/shell", "call", "mcp", "pending"], capture_output=True, text=True).stdout
    try:
        return json.loads(out.strip() or "[]")
    except ValueError:
        return []


STEPS = {
    "once": ("settings_set", {"key": "appearance.gaps_in", "value": "16"}),      # approved: gaps get bigger
    "deny": ("settings_set", {"key": "appearance.rounding", "value": "12"}),     # denied: no rounding
    "timeout": ("workspace_focus", {"workspace": 2}),                            # nobody answers
    "always": ("notification_send", {"summary": "Hei fra VM-testen", "body": "Tillatt med «Alltid»"}),
    "again": ("notification_send", {"summary": "Andre varsel", "body": "Uten kort: «Alltid» gjelder"}),
    "revoked": ("notification_send", {"summary": "Tredje varsel", "body": "Kortet er tilbake"}),
    "game": ("settings_set", {"key": "appearance.gaps_in", "value": "4"}),       # in a game: denied, no card
    "sensitive": ("files_read", {"path": "~/.bashrc"}),                          # hidden: refused without a card
    "clipboard": ("clipboard_read", {}),                                         # sensitive: red card
}
c = Client()
c.init()
step = sys.argv[1]
if step == "read":
    ok = True
    for name, args in (("system_info", {}), ("settings_get", {"key": "appearance.gaps_in"}), ("windows_list", {}),
                       ("workspaces_list", {}), ("apps_list", {"query": "foot"}), ("backgrounds_list", {}),
                       ("files_list", {"path": "~"}), ("system_doctor", {})):
        r = c.call(name, args)
        good = "result" in r and not r["result"].get("isError")
        ok &= good
        print(f"{name}: {'ok' if good else 'FEIL'}  {text(r)[:90]}")
    print("kort på skjermen:", pending())
    kmsg(f"MCP-read-{'OK' if ok and not pending() else 'NO'}")
elif step in STEPS:
    (name, args), tag = STEPS[step], step
    box = {}
    t = threading.Thread(target=lambda: box.setdefault("r", c.call(name, args)), daemon=True)
    t0 = time.time()
    t.start()
    shown = False
    while t.is_alive() and time.time() - t0 < 70:
        if not shown and pending():
            shown = True
            kmsg(f"MCP-{tag}-CARD")
        time.sleep(0.2)
    t.join(5)
    r = box.get("r", {})
    res = r.get("result", {})
    state = "denied" if res.get("structuredContent", {}).get("denied") else ("error" if res.get("isError") else "ok")
    print(f"{name}: {state} etter {time.time() - t0:.1f} s · kort vist: {shown} · {text(r)}")
    kmsg(f"MCP-{tag}-DONE {state} card={int(shown)} t={int(time.time() - t0)} left={len(pending())}")
c.p.stdin.close()
c.p.wait(5)
