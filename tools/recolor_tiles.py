"""Ion Tails: ricolora le scansioni delle tessere di Snow Tails in un fondo di canyon desertico.
Neve -> arenaria rossastra, linee delle caselle -> linee al neon ciano, abeti -> rocce.
python3 tools/recolor_tiles.py <cartella originali> <cartella destinazione>"""
import sys, os, glob
import numpy as np
from PIL import Image, ImageFilter

def noise(h, w, seed):
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    for k, amp in [(8, 0.5), (24, 0.3), (70, 0.2)]:
        sm = rng.random((h // k + 2, w // k + 2))
        im = Image.fromarray((sm * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        out += np.asarray(im) / 255.0 * amp
    return out

def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0

SAND_D = hexc("6b3420")
SAND_M = hexc("a85a33")
SAND_L = hexc("d9955c")
NEON = hexc("55e6ff")
ROCK_D = hexc("2c2220")
ROCK_L = hexc("8a7466")

def recolor(path, out, seed):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(float) / 255.0
    rgb, al = a[..., :3], a[..., 3:]
    L = rgb.mean(-1)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / (mx + 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h, w = L.shape
    nz = noise(h, w, seed)
    # strati dell'arenaria: bande ondulate
    yy, xx = np.mgrid[0:h, 0:w]
    strata = 0.5 + 0.5 * np.sin((yy * 0.05 + xx * 0.012 + nz * 6.0))
    # sabbia: dalla luminosità della neve
    t = np.clip((L - 0.5) / 0.5, 0, 1)[..., None]
    sand = np.where(t < 0.5, SAND_D + (SAND_M - SAND_D) * (t * 2), SAND_M + (SAND_L - SAND_M) * (t * 2 - 1))
    sand = sand * (0.86 + 0.22 * nz[..., None]) * (0.94 + 0.08 * strata[..., None])
    # linee scure (poco sature): neon ciano, sfumato verso la sabbia
    k = np.clip((L - 0.22) / (0.52 - 0.22), 0, 1)[..., None]
    lowsat = (sat < 0.28)[..., None]
    lined = NEON * 0.95 + (sand - NEON * 0.95) * k
    # le linee delle caselle sono sottili: il nero delle macchie grandi (abeti, rocce, ombre
    # profonde) non diventa neon. Apertura morfologica: restano solo le macchie spesse.
    dark = (L < 0.5) | ((g > r + 0.03) & (sat > 0.12))
    dm = Image.fromarray((dark * 255).astype(np.uint8))
    blob = np.asarray(dm.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.MaxFilter(9))) > 0
    near_blob = np.asarray(Image.fromarray((blob * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    thin = lowsat & ~near_blob[..., None]
    out_rgb = np.where(thin, lined, sand)
    # verdi (abeti) e macchie scure -> roccia
    green = (((g > r + 0.03) & (g >= b - 0.05) & (sat > 0.12)) | (near_blob & (L < 0.62)))[..., None]
    rock = ROCK_D + (ROCK_L - ROCK_D) * np.clip(L * 1.6, 0, 1)[..., None]
    out_rgb = np.where(green, rock, out_rgb)
    # azzurri della neve in ombra (blu poco saturo e chiaro): sabbia più scura
    shade = ((b > r + 0.04) & (L > 0.45) & (sat < 0.4))[..., None]
    out_rgb = np.where(shade, sand * 0.78, out_rgb)
    # colori vivi (bandierine, cartelli rossi e gialli): restano
    vivid = ((sat > 0.45) & ((r > g + 0.15) | ((r > 0.6) & (g > 0.5) & (b < 0.35))))[..., None]
    out_rgb = np.where(vivid, rgb, out_rgb)
    res = np.concatenate([np.clip(out_rgb, 0, 1), al], -1)
    Image.fromarray((res * 255).astype(np.uint8), "RGBA").save(out, quality=90, method=4)

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    for i, p in enumerate(sorted(glob.glob(os.path.join(src, "*.webp")))):
        recolor(p, os.path.join(dst, os.path.basename(p)), i)
        print(os.path.basename(p))
