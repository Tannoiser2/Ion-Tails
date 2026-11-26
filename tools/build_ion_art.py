"""Grafica 2D di Ion Tails: carte spinta 1-5 per colore, carta danno, gettoni freno, plance.
python3 tools/build_ion_art.py  (dalla cartella del progetto)"""
import json, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

F_T = "assets/fonts/Orbitron-900.ttf"
F_B = "assets/fonts/Exo2-800.ttf"
COLS = {"red": "cf3a30", "blue": "2a9ac0", "yellow": "e0b020", "green": "5a9e2f", "black": "9a5fe0"}
SS = 2  # sovracampionamento

def rgb(h, a=255):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))

def font(p, s):
    return ImageFont.truetype(p, s * SS)

def grad(w, h, top, bot):
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=mix(top, bot, y / max(h - 1, 1)))
    return im

def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], r, fill=255)
    return m

def glow(layer, rad):
    g = layer.filter(ImageFilter.GaussianBlur(rad))
    out = Image.alpha_composite(g, layer)
    return out

def text_c(d, xy, s, f, fill, stroke=0, sfill=None, anchor="mm"):
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=sfill)

def card(v, key):
    W, H = 300 * SS, 461 * SS
    pc = rgb(COLS[key])
    bg = grad(W, H, mix(pc, (10, 16, 30, 255), 0.55), (8, 12, 22, 255))
    d = ImageDraw.Draw(bg)
    # griglia sottile
    for x in range(0, W, 24 * SS):
        d.line([(x, 0), (x, H)], fill=(255, 255, 255, 10), width=1)
    for y in range(0, H, 24 * SS):
        d.line([(0, y), (W, y)], fill=(255, 255, 255, 10), width=1)
    # motore: gondola verticale con anelli di presa e pennacchio di plasma proporzionale a v
    fx = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fx)
    cx = W // 2
    top, bot = int(H * 0.2), int(H * 0.56)
    nw = int(W * 0.2)
    flame = int(H * (0.07 + 0.065 * v))
    for i in range(14, 0, -1):
        t = i / 14
        ww = int(nw * (0.25 + 0.75 * t))
        col = mix((255, 255, 255, 255), pc, 1 - t)
        col = (col[0], col[1], col[2], int(90 + 165 * (1 - t)))
        fd.ellipse([cx - ww // 2, bot - 10 * SS, cx + ww // 2, bot + int(flame * (0.35 + 0.65 * t))], fill=col)
    fx = glow(fx.filter(ImageFilter.GaussianBlur(2 * SS)), 8 * SS)
    bg = Image.alpha_composite(bg, fx)
    d = ImageDraw.Draw(bg)
    steel = (170, 186, 204, 255)
    dark = (46, 58, 76, 255)
    d.rounded_rectangle([cx - nw // 2, top, cx + nw // 2, bot], radius=nw // 2, fill=dark, outline=steel, width=3 * SS)
    d.polygon([(cx - nw // 2 - 8 * SS, top + 20 * SS), (cx - nw // 2 - 26 * SS, bot - 30 * SS), (cx - nw // 2, bot - 30 * SS)], fill=mix(pc, dark, 0.3))
    d.polygon([(cx + nw // 2 + 8 * SS, top + 20 * SS), (cx + nw // 2 + 26 * SS, bot - 30 * SS), (cx + nw // 2, bot - 30 * SS)], fill=mix(pc, dark, 0.3))
    for k in range(4):
        y = top + 18 * SS + k * 16 * SS
        d.line([(cx - nw // 2 + 4 * SS, y), (cx + nw // 2 - 4 * SS, y)], fill=pc, width=3 * SS)
    d.ellipse([cx - nw // 2 + 6 * SS, top + 4 * SS, cx + nw // 2 - 6 * SS, top + 22 * SS], fill=(12, 16, 24, 255), outline=steel, width=2 * SS)
    # gallonature della spinta
    ch = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(ch)
    y0 = int(H * 0.88)
    for k in range(v):
        y = y0 - k * 15 * SS
        cd.line([(cx - 44 * SS, y), (cx, y - 12 * SS), (cx + 44 * SS, y)], fill=mix(pc, (255, 255, 255, 255), 0.35), width=5 * SS, joint="curve")
    bg = Image.alpha_composite(bg, glow(ch, 4 * SS))
    d = ImageDraw.Draw(bg)
    # numeri negli angoli
    fn = font(F_T, 62)
    for (x, y) in [(42 * SS, 48 * SS), (W - 42 * SS, 48 * SS)]:
        text_c(d, (x, y), str(v), fn, (255, 255, 255, 255), 6 * SS, mix(pc, (0, 0, 0, 255), 0.35))
    text_c(d, (cx, int(H * 0.94)), "SPINTA %d" % v, font(F_B, 17), (220, 232, 245, 230))
    # bordo luminoso
    br = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(br).rounded_rectangle([5 * SS, 5 * SS, W - 6 * SS, H - 6 * SS], 22 * SS, outline=mix(pc, (255, 255, 255, 255), 0.2), width=5 * SS)
    bg = Image.alpha_composite(bg, glow(br, 5 * SS))
    bg.putalpha(rounded_mask(W, H, 26 * SS))
    return bg.resize((W // SS, H // SS), Image.LANCZOS)

def dent_card():
    W, H = 300 * SS, 463 * SS
    bg = grad(W, H, (70, 14, 16, 255), (18, 8, 10, 255))
    d = ImageDraw.Draw(bg)
    # strisce di pericolo
    for band in [(0, 46 * SS), (H - 46 * SS, H)]:
        for x in range(-H, W + H, 36 * SS):
            d.polygon([(x, band[0]), (x + 18 * SS, band[0]), (x + 18 * SS - (band[1] - band[0]), band[1]), (x - (band[1] - band[0]), band[1])], fill=(230, 180, 30, 255))
        d.rectangle([0, band[0], W, band[1]], outline=(20, 10, 10, 255), width=3 * SS)
    # crepe
    random.seed(7)
    cr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cr)
    c0 = (W * 0.5, H * 0.45)
    for k in range(9):
        a = k / 9 * math.tau + random.uniform(-0.2, 0.2)
        x, y = c0
        for s in range(6):
            nx = x + math.cos(a) * random.uniform(20, 40) * SS
            ny = y + math.sin(a) * random.uniform(20, 40) * SS
            cd.line([(x, y), (nx, ny)], fill=(255, 120, 60, 255), width=3 * SS)
            x, y = nx, ny
            a += random.uniform(-0.5, 0.5)
    bg = Image.alpha_composite(bg, glow(cr, 4 * SS))
    d = ImageDraw.Draw(bg)
    text_c(d, (W // 2, int(H * 0.45)), "DANNO", font(F_T, 46), (255, 236, 220, 255), 5 * SS, (90, 10, 10, 255))
    d.rounded_rectangle([W * 0.12, H * 0.545, W * 0.88, H * 0.615], radius=10 * SS, fill=(20, 6, 8, 235))
    text_c(d, (W // 2, int(H * 0.58)), "occupa un posto in mano", font(F_B, 16), (255, 210, 200, 240))
    bg.putalpha(rounded_mask(W, H, 26 * SS))
    return bg.resize((W // SS, H // SS), Image.LANCZOS)

def brake(v):
    W, H = 240 * SS, 130 * SS
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(30 * SS, 6 * SS), (W - 30 * SS, 6 * SS), (W - 6 * SS, H // 2), (W - 30 * SS, H - 6 * SS), (30 * SS, H - 6 * SS), (6 * SS, H // 2)]
    d.polygon(pts, fill=(52, 62, 78, 255), outline=(190, 204, 220, 255))
    d.line(pts + [pts[0]], fill=(190, 204, 220, 255), width=4 * SS)
    inner = [(40 * SS, 18 * SS), (W - 40 * SS, 18 * SS), (W - 20 * SS, H // 2), (W - 40 * SS, H - 18 * SS), (40 * SS, H - 18 * SS), (20 * SS, H // 2)]
    d.polygon(inner, fill=(24, 30, 42, 255))
    text_c(d, (W * 0.36, H // 2), str(v), font(F_T, 58), (255, 190, 90, 255), 4 * SS, (80, 30, 0, 255))
    text_c(d, (W * 0.68, H // 2), "FRENO", font(F_B, 20), (210, 222, 236, 255))
    return im.resize((W // SS, H // SS), Image.LANCZOS)

def mat(key, slots):
    W, H = 438 * SS, 717 * SS
    pc = rgb(COLS[key])
    bg = grad(W, H, (30, 40, 56, 255), (14, 20, 32, 255))
    d = ImageDraw.Draw(bg)
    for x in range(0, W, 22 * SS):
        d.line([(x, 0), (x, H)], fill=(255, 255, 255, 9), width=1)
    for y in range(0, H, 22 * SS):
        d.line([(0, y), (W, y)], fill=(255, 255, 255, 9), width=1)
    R = lambda k: [slots[k][0] * W, slots[k][1] * H, slots[k][2] * W, slots[k][3] * H]
    L, Rr, B = R("L"), R("R"), R("B")
    # cavi d'energia dai motori all'abitacolo
    beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beam)
    pod_top = H * 0.53
    for r in (L, Rr):
        cx = (r[0] + r[2]) / 2
        bd.line([(cx, r[3]), (W / 2, pod_top)], fill=mix(pc, (255, 255, 255, 255), 0.3), width=4 * SS)
    bd.line([((L[0] + L[2]) / 2 + 14 * SS, L[3] + 14 * SS), ((Rr[0] + Rr[2]) / 2 - 14 * SS, Rr[3] + 14 * SS)], fill=(120, 230, 255, 200), width=3 * SS)
    bg = Image.alpha_composite(bg, glow(beam, 6 * SS))
    d = ImageDraw.Draw(bg)
    # abitacolo
    pw = W * 0.34
    d.rounded_rectangle([W / 2 - pw / 2, pod_top, W / 2 + pw / 2, H * 0.985], radius=int(pw / 2), fill=(40, 50, 66, 255), outline=pc, width=5 * SS)
    d.ellipse([W / 2 - pw * 0.32, pod_top + 18 * SS, W / 2 + pw * 0.32, pod_top + 18 * SS + pw * 0.5], fill=(20, 60, 80, 255), outline=(140, 230, 255, 255), width=3 * SS)
    # spazi delle carte e del freno
    for r, t in ((L, "MOTORE SX"), (Rr, "MOTORE DX")):
        d.rounded_rectangle(r, radius=18 * SS, fill=(10, 14, 22, 255), outline=pc, width=4 * SS)
        text_c(d, ((r[0] + r[2]) / 2, (r[1] + r[3]) / 2), t, font(F_B, 20), (150, 170, 192, 255))
    d.rounded_rectangle([B[0] - 6 * SS, B[1] - 6 * SS, B[2] + 6 * SS, B[3] + 6 * SS], radius=12 * SS, fill=(8, 10, 16, 255), outline=(190, 204, 220, 255), width=3 * SS)
    text_c(d, ((B[0] + B[2]) / 2, (B[1] + B[3]) / 2), "FRENO", font(F_B, 18), (150, 170, 192, 255))
    # nome del colore e sigla
    nm = {"red": "ROSSO", "blue": "BLU", "yellow": "GIALLO", "green": "VERDE", "black": "VIOLA"}[key]
    text_c(d, (W / 2, H * 0.965), nm, font(F_T, 15), mix(pc, (255, 255, 255, 255), 0.4))
    bg.putalpha(rounded_mask(W, H, 30 * SS))
    return bg.resize((W // SS, H // SS), Image.LANCZOS)

if __name__ == "__main__":
    js = json.load(open("assets/mats/mats.json"))
    red = js["red"]
    out = {}
    for key in COLS:
        for v in range(1, 6):
            im = card(v, key)
            name = "assets/cards/card_%d.webp" % v if key == "red" else "assets/cards/card_%s_%d.webp" % (key, v)
            im.save(name, quality=92)
        out[key] = red
        mat(key, red).save("assets/mats/%s.webp" % key, quality=92)
    json.dump(out, open("assets/mats/mats.json", "w"), indent=1)
    dent_card().save("assets/cards/card_dent.webp", quality=92)
    for v in range(1, 6):
        brake(v).save("assets/cards/brake_%d.webp" % v, quality=92)
    print("fatto")
