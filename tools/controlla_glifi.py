"""Controlla che ogni carattere delle stringhe del gioco esista nei font usati (Exo 2 e Orbitron):
niente quadratini al posto dei simboli. python3 tools/controlla_glifi.py"""
import glob, re, sys
from fontTools.ttLib import TTFont

body = set(TTFont("assets/fonts/Exo2-600.ttf").getBestCmap())
title = set(TTFont("assets/fonts/Orbitron-900.ttf").getBestCmap())
bad = {}
for f in glob.glob("scripts/*.gd"):
    for n, line in enumerate(open(f, encoding="utf-8"), 1):
        code = line.split("#", 1)[0] if not line.strip().startswith("##") else ""
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', code):
            for ch in s:
                if ord(ch) < 32 or ch in "\\":
                    continue
                if ord(ch) not in body:
                    bad.setdefault(ch, []).append("%s:%d" % (f, n))
for ch, where in bad.items():
    print("MANCA in Exo 2: %r U+%04X  %s" % (ch, ord(ch), ", ".join(where[:4])))
# i titoli (Orbitron): lettere accentate e segni usati nei pulsanti principali
for ch in "àèéìòùÀÈÉÌÒÙ'×-:!?.,":
    if ord(ch) not in title:
        print("MANCA in Orbitron: %r" % ch)
print("glifi controllati" if not bad else "ATTENZIONE: glifi mancanti")
sys.exit(1 if bad else 0)
