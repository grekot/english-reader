# -*- coding: utf-8 -*-
"""Generuje ikonę aplikacji (książka/kartka z podświetlonym słowem + dymek).

Rysuje z 3x nadpróbkowaniem i skaluje w dół (LANCZOS) dla gładkich krawędzi.
Wyjście:
  assets/icon/icon_1024.png        - pełna ikona (zielone tło + grafika)
  assets/icon/icon_foreground.png  - sama grafika na przezroczystości (Android adaptive)
"""
import os
from PIL import Image, ImageDraw

SIZE = 1024
SS = 3
S = SIZE * SS

GREEN = (46, 110, 78)        # #2E6E4E primary
GREEN_DARK = (28, 74, 52)    # gradient dolny
BUBBLE = (24, 60, 42)        # ciemnozielony dymek
WHITE = (255, 255, 255)
LINE = (200, 214, 206)       # jasnoszare paski "tekstu"
AMBER = (244, 183, 64)       # podświetlone słowo
AMBER_DK = (214, 150, 40)


def rr(d, box, r, **kw):
    d.rounded_rectangle(box, radius=r, **kw)


def vertical_gradient(w, h, top, bottom):
    base = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        base.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return base.resize((w, h))


def draw_art(d, ox, oy, A):
    """Rysuje kartkę z tekstem, podświetlonym słowem i dymkiem w kwadracie A."""
    # Karta (biała kartka)
    card = [ox, oy, ox + A, oy + A]
    rr(d, card, int(A * 0.13), fill=WHITE)

    p = A * 0.135
    cw = A - 2 * p
    lx = ox + p
    lineH = A * 0.050
    gap = A * 0.105

    widths = [0.92, 0.74, 1.00, 0.66, 0.88, 0.50]
    hl_line = 2  # która linia ma podświetlone słowo
    n = len(widths)
    block_h = (n - 1) * gap + lineH
    y0 = oy + (A - block_h) / 2  # wyśrodkowanie pionowe linii

    hx0 = lx + cw * 0.32
    hx1 = lx + cw * 0.68
    for i, wf in enumerate(widths):
        y = y0 + i * gap
        rr(d, [lx, y, lx + cw * wf, y + lineH], int(lineH / 2), fill=LINE)
        if i == hl_line:
            rr(d, [hx0, y - lineH * 0.30, hx1, y + lineH * 1.30],
               int(lineH * 0.7), fill=AMBER)

    # Dymek z tłumaczeniem nad podświetlonym słowem
    y_hl = y0 + hl_line * gap
    cx = (hx0 + hx1) / 2
    bw = A * 0.42
    bh = A * 0.24
    by1 = y_hl - lineH * 0.7
    by0 = by1 - bh
    bx0 = cx - bw / 2
    bx1 = cx + bw / 2
    rr(d, [bx0, by0, bx1, by1], int(A * 0.055), fill=BUBBLE)
    # ogonek dymka
    tw = A * 0.055
    d.polygon([(cx - tw, by1 - 2), (cx + tw, by1 - 2), (cx, by1 + A * 0.055)],
              fill=BUBBLE)
    # treść dymka: dwa paski (przetłumaczone słowo)
    ipx = bw * 0.18
    iy = by0 + bh * 0.30
    ih = bh * 0.155
    rr(d, [bx0 + ipx, iy, bx1 - ipx * 1.5, iy + ih], int(ih / 2), fill=WHITE)
    rr(d, [bx0 + ipx, iy + ih * 2.1, bx0 + ipx + bw * 0.34, iy + ih * 3.1],
       int(ih / 2), fill=AMBER)


def build_full():
    img = Image.new('RGB', (S, S), GREEN)
    grad = vertical_gradient(S, S, GREEN, GREEN_DARK)
    # maska zaokrąglonego kwadratu (ikona z marginesem)
    mask = Image.new('L', (S, S), 0)
    md = ImageDraw.Draw(mask)
    m = int(S * 0.0)  # pełny kwadrat; platformy same przycinają
    rr(md, [m, m, S - m, S - m], int(S * 0.22), fill=255)
    bg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(bg)
    A = S * 0.62
    o = (S - A) / 2
    draw_art(d, o, o + S * 0.01, A)
    out = bg.resize((SIZE, SIZE), Image.LANCZOS)
    return out


def build_foreground():
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Android adaptive: bezpieczna strefa ~66%, więc grafika mniejsza i wycentrowana
    A = S * 0.50
    o = (S - A) / 2
    draw_art(d, o, o, A)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    outdir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)
    build_full().save(os.path.join(outdir, 'icon_1024.png'))
    build_foreground().save(os.path.join(outdir, 'icon_foreground.png'))
    print('OK ->', outdir)


if __name__ == '__main__':
    main()
