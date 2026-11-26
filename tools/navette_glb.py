# Strumento in due passi: decimate.py (riduzione) e orient.py (raddrizzamento + ugelli), uniti qui.
"""Riduce i GLB delle navette: ~30.000 triangoli, texture 1024 JPEG, asse lungo su Z."""
import sys, io
import numpy as np, trimesh, fast_simplification
from PIL import Image
src, dst, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
sc = trimesh.load(src, force='scene')
geom = list(sc.geometry.values())[0]
v = np.asarray(geom.vertices, dtype=np.float64); f = np.asarray(geom.faces)
uv = np.asarray(geom.visual.uv)
red = target / len(f)
v2, f2, coll = fast_simplification.simplify(v, f, target_reduction=1 - red, return_collapses=True)
# mappa ogni vertice ridotto al vertice originale più vicino per le UV
_, idx = trimesh.proximity.ProximityQuery(trimesh.Trimesh(v, f, process=False)).vertex(v2)
uv2 = uv[idx]
img = geom.visual.material.baseColorTexture if hasattr(geom.visual.material, 'baseColorTexture') else geom.visual.material.image
img = img.convert('RGB').resize((1024, 1024), Image.LANCZOS)
mat = trimesh.visual.material.PBRMaterial(baseColorTexture=img, metallicFactor=0.3, roughnessFactor=0.55)
m = trimesh.Trimesh(v2, f2, visual=trimesh.visual.TextureVisuals(uv=uv2, material=mat), process=False)
m.export(dst)
print(dst, len(f), '->', len(f2))
"""Raddrizza il GLB: asse lungo su Z (motori verso -Z), larghezza su X, altezza su Y."""
import sys, numpy as np, trimesh
src, dst, flip = sys.argv[1], sys.argv[2], int(sys.argv[3])
sc = trimesh.load(src, force='scene')
m = list(sc.geometry.values())[0]
v = np.asarray(m.vertices).copy()
v -= v.mean(0)
# inclinazione nel piano (X vecchia, Y vecchia): retta di regressione x = a*y
a = np.polyfit(v[:, 1], v[:, 0], 1)[0]
th = np.arctan(a)
c, s = np.cos(th), np.sin(th)
x = v[:, 0] * c - v[:, 1] * s
y = v[:, 0] * s + v[:, 1] * c
z = v[:, 2]
# motori dove la sezione è più larga in Z
lo = np.abs(z[y < np.percentile(y, 25)]).max()
hi = np.abs(z[y > np.percentile(y, 75)]).max()
sgn = 1.0 if lo > hi else -1.0          # motori a y negativo -> z negativo
if len(sys.argv) > 4:
    sgn = float(sys.argv[4])                 # forzato (navette con le ali larghe sull'abitacolo)
new = np.stack([z * sgn, x * flip, y * sgn], 1)
new -= (new.min(0) + new.max(0)) / 2
new[:, 1] -= new[:, 1].min()           # appoggiato a y = 0
L = new[:, 2].max() - new[:, 2].min()
new /= L                                # lunghezza 1
m.vertices = new
m.fix_normals()
m.export(dst)
print(dst, 'incl %.1f gradi' % np.degrees(th), 'misure', (new.max(0) - new.min(0)).round(3))
# posizione degli ugelli: dietro ciascun motore (lato sinistro/destro della parte davanti)
import json, os
zmin = new[:, 2].min()
front = new[new[:, 2] < zmin + 0.45]
info = {}
for side, sel in (("L", front[:, 0] < 0), ("R", front[:, 0] > 0)):
    p = front[sel]
    # la fine del motore: dove la sezione si stringe (meno di metà della larghezza massima)
    zs = np.linspace(zmin, zmin + 0.6, 40)
    wmax = 0
    rear = zmin + 0.4
    for zz in zs:
        q = new[(new[:, 2] >= zz) & (new[:, 2] < zz + 0.03) & ((new[:, 0] < 0) if side == "L" else (new[:, 0] > 0))]
        if len(q) == 0:
            continue
        w = np.ptp(q[:, 1])
        wmax = max(wmax, w)
        if wmax > 0 and w < wmax * 0.45 and zz > zmin + 0.15:
            rear = zz
            break
    eng = new[(new[:, 2] < rear) & ((new[:, 0] < 0) if side == "L" else (new[:, 0] > 0))]
    info[side] = [float(np.median(eng[:, 0])), float((eng[:, 1].min() + eng[:, 1].max()) / 2), float(rear), float(np.ptp(eng[:, 1]) / 2)]
jf = os.path.join(os.path.dirname(dst), "ships.json")
d = json.load(open(jf)) if os.path.exists(jf) else {}
d[os.path.basename(dst)] = info
json.dump(d, open(jf, "w"), indent=1)
print(info)
