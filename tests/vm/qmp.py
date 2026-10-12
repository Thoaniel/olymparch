"""Tiny QMP client for the VM tests (stdlib only).

  qmp.py SOCKET screendump OUT.png
  qmp.py SOCKET keys "text to type\n"      types with US qcodes
  qmp.py SOCKET press down down ret alt_r+2   named qcodes; + makes a chord
  qmp.py SOCKET click X Y W H             left click at pixel X,Y of a W x H screen (needs -device usb-tablet)
  qmp.py SOCKET quit
"""
import json
import socket
import sys
import time

QCODE = {" ": "spc", "\n": "ret", "-": "minus", "=": "equal", ".": "dot", ",": "comma", "/": "slash",
         ";": "semicolon", "'": "apostrophe", "[": "bracket_left", "]": "bracket_right", "\\": "backslash",
         "`": "grave_accent", "\t": "tab"}
SHIFTED = {"_": "minus", "+": "equal", ":": "semicolon", '"': "apostrophe", "?": "slash", ">": "dot", "<": "comma",
           "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
           "{": "bracket_left", "}": "bracket_right", "|": "backslash", "~": "grave_accent"}


class QMP:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(path)
        self.f = self.s.makefile("rw")
        json.loads(self.f.readline())  # greeting
        self.cmd("qmp_capabilities")

    def cmd(self, name, **args):
        self.f.write(json.dumps({"execute": name, "arguments": args} if args else {"execute": name}) + "\n")
        self.f.flush()
        while True:
            msg = json.loads(self.f.readline())
            if "return" in msg or "error" in msg:
                if "error" in msg:
                    raise RuntimeError(msg["error"])
                return msg["return"]

    def key(self, ch):
        if ch in SHIFTED or ch.isupper():
            keys = ["shift", SHIFTED.get(ch, ch.lower())]
        else:
            keys = [QCODE.get(ch, ch)]
        self.cmd("send-key", keys=[{"type": "qcode", "data": k} for k in keys])
        time.sleep(0.04)


if __name__ == "__main__":
    q = QMP(sys.argv[1])
    op = sys.argv[2]
    if op == "screendump":
        q.cmd("screendump", filename=sys.argv[3], format="ppm" if sys.argv[3].endswith(".ppm") else "png")
    elif op == "keys":
        for ch in sys.argv[3].encode().decode("unicode_escape"):
            q.key(ch)
    elif op == "press":
        for chord in sys.argv[3:]:
            q.cmd("send-key", keys=[{"type": "qcode", "data": k} for k in chord.split("+")])
            time.sleep(0.12)
    elif op == "cmd":   # qmp.py SOCKET cmd NAME '{"json": "arguments"}'
        print(json.dumps(q.cmd(sys.argv[3], **(json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}))))
    elif op == "click":
        x, y, w, h = (int(v) for v in sys.argv[3:7])
        q.cmd("input-send-event", events=[{"type": "abs", "data": {"axis": "x", "value": x * 32767 // (w - 1)}},
                                          {"type": "abs", "data": {"axis": "y", "value": y * 32767 // (h - 1)}}])
        time.sleep(0.3)
        for down in (True, False):
            q.cmd("input-send-event", events=[{"type": "btn", "data": {"down": down, "button": "left"}}])
            time.sleep(0.1)
    elif op == "quit":
        q.cmd("quit")
