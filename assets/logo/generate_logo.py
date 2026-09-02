#!/usr/bin/env python3
"""Generuje wspólne logo BorderlessMouse dla macOS (.icns) i Windows (.ico, .png).

Uruchom: python3 assets/logo/generate_logo.py   (wymaga Pillow)
"""
import math
import os
import struct
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.dirname(os.path.abspath(__file__))
SS = 4  # supersampling


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(size, margin_ratio):
    """Renderuje logo: gradientowy squircle + biały kursor z liniami ruchu."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    m = int(S * margin_ratio)
    box = (m, m, S - m, S - m)
    side = S - 2 * m
    radius = int(side * 0.225)

    # gradient diagonalny #3B82F6 -> #8B5CF6
    grad = Image.new("RGBA", (S, S))
    px = grad.load()
    c0, c1 = (59, 130, 246), (139, 92, 246)
    for y in range(S):
        for x in range(S):
            t = (x + y) / (2 * S)
            r, g, b = lerp(c0, c1, t)
            px[x, y] = (r, g, b, 255)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    # delikatne rozjaśnienie u góry (połysk)
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gloss)
    gd.ellipse((m - side * 0.2, m - side * 0.55, S - m + side * 0.2, m + side * 0.55), fill=(255, 255, 255, 28))
    grad = Image.alpha_composite(grad, gloss)
    img.paste(grad, (0, 0), mask)

    # cień kursora
    cx, cy = m + side * 0.56, m + side * 0.50
    scale = side * 0.50
    arrow = [(0.0, 0.0), (0.0, 0.80), (0.21, 0.62), (0.34, 0.92), (0.47, 0.86), (0.34, 0.57), (0.60, 0.57)]
    pts = [(cx - scale * 0.30 + x * scale, cy - scale * 0.46 + y * scale) for x, y in arrow]
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + side * 0.015, y + side * 0.03) for x, y in pts], fill=(20, 30, 80, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(side * 0.02))
    img = Image.alpha_composite(img, shadow)

    d = ImageDraw.Draw(img)
    d.polygon(pts, fill=(255, 255, 255, 255))
    # linie ruchu po lewej stronie kursora (jak SF Symbol cursorarrow.motionlines)
    lw = max(int(side * 0.045), 2)
    x0 = cx - scale * 0.30
    for i, (dy, length) in enumerate(((-0.08, 0.30), (0.12, 0.22), (0.32, 0.30))):
        y = cy - scale * 0.46 + scale * (0.15 + dy + 0.15)
        x1 = x0 - side * 0.10
        x2 = x1 - side * length * 0.6
        d.rounded_rectangle((x2, y - lw / 2, x1, y + lw / 2), radius=lw // 2, fill=(255, 255, 255, 235))

    return img.resize((size, size), Image.LANCZOS)


def write_ico(path, sizes):
    entries = []
    for s in sizes:
        buf = tempfile.SpooledTemporaryFile()
        render(s, 0.04).save(buf, "PNG")
        buf.seek(0)
        entries.append((s, buf.read()))
    header = struct.pack("<HHH", 0, 1, len(entries))
    offset = 6 + 16 * len(entries)
    dirs, blobs = b"", b""
    for s, blob in entries:
        dirs += struct.pack("<BBBBHHII", s if s < 256 else 0, s if s < 256 else 0, 0, 0, 1, 32, len(blob), offset + len(blobs))
        blobs += blob
    with open(path, "wb") as f:
        f.write(header + dirs + blobs)


def write_icns(path):
    iconset = os.path.join(tempfile.mkdtemp(), "AppIcon.iconset")
    os.makedirs(iconset)
    for base in (16, 32, 128, 256, 512):
        render(base, 0.10).save(os.path.join(iconset, f"icon_{base}x{base}.png"))
        render(base * 2, 0.10).save(os.path.join(iconset, f"icon_{base}x{base}@2x.png"))
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", path], check=True)


if __name__ == "__main__":
    render(1024, 0.10).save(os.path.join(OUT, "logo-1024.png"))
    render(256, 0.04).save(os.path.join(OUT, "logo-256.png"))
    # Windows
    win_assets = os.path.join(ROOT, "windows", "BorderlessMouse", "Assets")
    render(256, 0.04).save(os.path.join(win_assets, "icon.png"))
    render(512, 0.04).save(os.path.join(win_assets, "logo.png"))
    write_ico(os.path.join(win_assets, "icon.ico"), [16, 20, 24, 32, 40, 48, 64, 128, 256])
    # macOS
    write_icns(os.path.join(ROOT, "macos", "BorderlessMouse", "Resources", "AppIcon.icns"))
    print("logo ok")
