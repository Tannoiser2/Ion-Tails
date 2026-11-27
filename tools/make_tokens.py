#!/usr/bin/env python3
"""Token dei gadget nuovi nello stile di quelli disegnati: cornice metallica presa da un token
esistente, fondo blu notte, nome in corsivo e un'illustrazione disegnata a destra.
python3 tools/make_tokens.py"""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

GD = "assets/gadgets/"
FONT = "assets/fonts/Exo2-900.ttf"
W, H = 560, 96

def frame_and_mask():
    base = Image.open(GD + "sh.webp").convert("RGBA").resize((W, H))
    a = base.split()[3].point(lambda v: 255 if v > 128 else 0)
    # interno della cornice (lati obliqui come i token disegnati)
    inner = Image.new("L", (W, H), 0)
    ImageDraw.Draw(inner).polygon([(34, 13), (W - 34, 13), (W - 15, H // 2), (W - 34, H - 13), (34, H - 13), (15, H // 2)], fill=255)
    return base, a, inner

def bg(inner):
    g = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(g)
    for x in range(W):
        t = x / W
        c = (int(8 + 14 * t), int(16 + 26 * t), int(34 + 40 * t), 255)
        d.line([(x, 0), (x, H)], fill=c)
    # leggera luce in alto
    hl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hl).rectangle([0, 0, W, H // 3], fill=40)
    hl = hl.filter(ImageFilter.GaussianBlur(12))
    g = Image.composite(Image.new("RGBA", (W, H), (120, 170, 230, 255)), g, hl)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(g, (0, 0), inner)
    return out

def glow_layer(draw_fn, col, blur=6):
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(lay), col)
    g = lay.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(g, Image.alpha_composite(g, lay))

def ship(d, cx, cy, s, col):
    pts = [(cx + 60 * s, cy), (cx + 10 * s, cy - 9 * s), (cx - 20 * s, cy - 22 * s), (cx - 14 * s, cy - 7 * s),
           (cx - 40 * s, cy - 6 * s), (cx - 40 * s, cy + 6 * s), (cx - 14 * s, cy + 7 * s), (cx - 20 * s, cy + 22 * s),
           (cx + 10 * s, cy + 9 * s)]
    d.polygon(pts, fill=col)

def art(k):
    cx, cy = 455, 48
    if k == "em":
        def f(d, c):
            for r in (14, 26, 38):
                d.arc([cx - r, cy - r, cx + r, cy + r], 200, 520, fill=c, width=3)
            d.line([(cx - 8, cy - 22), (cx + 4, cy - 2), (cx - 4, cy + 2), (cx + 8, cy + 22)], fill=(255, 255, 255, 255), width=4)
        return [glow_layer(f, (90, 220, 255, 255))]
    if k == "sc":
        def f(d, c):
            ship(d, cx + 40, cy, 0.55, (120, 132, 155, 255))
            for i in range(40):
                x = cx + 10 - i * 5
                y = cy + math.sin(i * 0.6) * (4 + i * 0.35)
                r = 2 + (i % 3)
                d.ellipse([x - r, y - r, x + r, y + r], fill=(230, 170, 90, 255 - i * 4))
        return [glow_layer(f, None, 3)]
    if k == "si":
        def f(d, c):
            d.ellipse([cx + 30, cy - 14, cx + 58, cy + 14], fill=(80, 240, 190, 255))
            d.ellipse([cx - 70, cy - 10, cx - 50, cy + 10], fill=(60, 120, 110, 255))
            for i in range(3):
                pts = [(cx - 50 + t * 4, cy + math.sin(t * 0.5 + i * 2) * (6 + i * 3)) for t in range(21)]
                d.line(pts, fill=(120, 255, 210, 230), width=3)
        return [glow_layer(f, None, 5)]
    if k == "ec":
        def f(d, c):
            ship(d, cx - 30, cy + 8, 0.6, (120, 132, 155, 255))
            ship(d, cx + 10, cy - 8, 0.6, (120, 230, 255, 140))
            for y in range(int(cy - 24), int(cy + 8), 4):
                d.line([(cx - 30, y), (cx + 50, y)], fill=(160, 240, 255, 60), width=1)
        return [glow_layer(f, None, 4)]
    if k == "nb":
        def f(d, c):
            for (dx, dy) in [(0, 0), (26, -15), (26, 15), (-26, -15), (-26, 15), (52, 0)]:
                x, y = cx + dx - 10, cy + dy
                pts = [(x + 13 * math.cos(math.radians(a)), y + 13 * math.sin(math.radians(a))) for a in range(0, 360, 60)]
                d.polygon(pts, outline=(110, 255, 150, 255), width=3)
            for (dx, dy) in [(-40, -24), (40, 26), (8, 30)]:
                d.ellipse([cx + dx - 3, cy + dy - 3, cx + dx + 3, cy + dy + 3], fill=(230, 255, 230, 255))
        return [glow_layer(f, None, 5)]
    if k == "an":
        def f(d, c):
            d.arc([cx - 34, cy - 34, cx + 34, cy + 34], 0, 180, fill=(220, 60, 60, 255), width=16)
            d.rectangle([cx - 34, cy - 30, cx - 18, cy], fill=(220, 60, 60, 255))
            d.rectangle([cx + 18, cy - 30, cx + 34, cy], fill=(220, 60, 60, 255))
            d.rectangle([cx - 34, cy - 40, cx - 18, cy - 28], fill=(225, 230, 240, 255))
            d.rectangle([cx + 18, cy - 40, cx + 34, cy - 28], fill=(225, 230, 240, 255))
            for i in range(3):
                d.arc([cx - 20 - i * 8, cy - 70 - i * 6, cx + 20 + i * 8, cy - 40], 30, 150, fill=(150, 200, 255, 200), width=2)
        return [glow_layer(f, None, 3)]
    if k == "st":
        def f(d, c):
            d.ellipse([cx - 42, cy - 16, cx + 42, cy + 16], outline=(255, 205, 90, 255), width=4)
            d.ellipse([cx - 16, cy - 38, cx + 16, cy + 38], outline=(255, 205, 90, 255), width=4)
            d.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], outline=(255, 240, 180, 200), width=2)
            d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=(255, 255, 230, 255))
        return [glow_layer(f, None, 5)]
    if k == "sa":
        def f(d, c):
            ship(d, cx + 5, cy + 22, 0.45, (120, 132, 155, 255))
            pts = [(cx - 60 + t * 6, cy + 18 - math.sin(t / 20 * math.pi) * 46) for t in range(21)]
            d.line(pts, fill=(170, 140, 255, 255), width=5)
            ex, ey = pts[-1]
            d.polygon([(ex + 10, ey + 6), (ex - 8, ey - 6), (ex - 6, ey + 12)], fill=(170, 140, 255, 255))
            ship(d, cx - 20, cy - 26, 0.4, (120, 230, 255, 255))
        return [glow_layer(f, None, 5)]
    return []

def text_layer(name):
    size = 34 if len(name) <= 12 else (28 if len(name) <= 16 else 24)
    font = ImageFont.truetype(FONT, size)
    tl = Image.new("RGBA", (W * 2, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(tl)
    d.text((70, H // 2), name.upper(), font=font, fill=(236, 244, 255, 255), anchor="lm", stroke_width=2, stroke_fill=(10, 20, 40, 255))
    # corsivo: inclinazione orizzontale
    tl = tl.transform(tl.size, Image.AFFINE, (1, 0.22, -0.22 * H / 2, 0, 1, 0), resample=Image.BICUBIC)
    return tl.crop((0, 0, W, H))

def make(k, name):
    base, a, inner = frame_and_mask()
    frame = base.copy()
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(frame, (0, 0), a)
    out = Image.alpha_composite(out, bg(inner))
    for lay in art(k):
        m = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        m.paste(lay, (0, 0), ImageChops.multiply(lay.split()[3], inner))
        out = Image.alpha_composite(out, m)
    out = Image.alpha_composite(out, text_layer(name))
    # la cornice metallica sopra a tutto (solo la fascia esterna)
    ring = ImageChops.subtract(a, inner)
    top = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    top.paste(base, (0, 0), ring)
    out = Image.alpha_composite(out, top)
    out.save(GD + k + ".webp", quality=92)

NAMES = {"em": "Impulso EMP", "sc": "Scia di sabbia", "si": "Sifone ionico", "ec": "Esca olografica",
         "nb": "Nanobot", "an": "Ancora magnetica", "st": "Stabilizzatori", "sa": "Salto gravitazionale"}
for k, n in NAMES.items():
    make(k, n)
print("ok", len(NAMES))
