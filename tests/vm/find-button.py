"""Find the first action button («Undo») on a notification toast in a QEMU screendump (PPM, stdlib only).

  find-button.py FILE.ppm     prints: X Y WIDTH HEIGHT (button centre and screen size), or "none"
The first button is filled with the shell's gold (#d4a73a), the others with `raised` (#1c1c25); toasts sit top
right, 360 px wide. A button is the first row with a run of at least 20 px of either colour (the toast's 3 px
gold edge and the gold app name are too narrow to count).
"""
import sys

data = open(sys.argv[1], "rb").read()
parts, pos = [], 0
while len(parts) < 4:
    while data[pos:pos + 1].isspace():
        pos += 1
    end = pos
    while not data[end:end + 1].isspace():
        end += 1
    parts.append(data[pos:end])
    pos = end
pos += 1
w, h = int(parts[1]), int(parts[2])
px = data[pos:pos + w * h * 3]


def button(x, y):
    i = (y * w + x) * 3
    c = (px[i], px[i + 1], px[i + 2])
    return c == (0x1c, 0x1c, 0x25) or c == (0xd4, 0xa7, 0x3a)


def run_from(x, y):  # end of the run of button pixels starting at x
    while x + 1 < w and button(x + 1, y):
        x += 1
    return x


for y in range(30, min(h, 500)):
    x = max(0, w - 380)
    while x < w:
        if button(x, y):
            x1 = run_from(x, y)
            if x1 - x >= 20:
                y1 = y
                while y1 + 1 < h and button(x + 1, y1 + 1):
                    y1 += 1
                print((x + x1) // 2, (y + y1) // 2, w, h)
                sys.exit(0)
            x = x1 + 1
        else:
            x += 1
print("none")
