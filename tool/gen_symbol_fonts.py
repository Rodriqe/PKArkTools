#!/usr/bin/env python3
"""Genera las fuentes de respaldo de símbolos de la app (subconjuntos de Noto).

Manrope y Bricolage Grotesque no tienen ♂/♀, ★, ⚠, ⌘… La app declara
`fontFamilyFallback: ['NotoSansSymbols', 'NotoSansSymbols2']` en el tema para
que esos glifos salgan igual en todas las plataformas y en las capturas
offscreen (sin depender de las fuentes del sistema).

Uso (fonttools en un venv dentro de .scratch/):
    python3 -m venv .scratch/venv && .scratch/venv/bin/pip install fonttools
    .scratch/venv/bin/python tool/gen_symbol_fonts.py DIR

DIR contiene las fuentes originales de google/fonts (SIL OFL 1.1, sin
Reserved Font Name):
    ofl/notosanssymbols/NotoSansSymbols[wght].ttf   (variable, ♂/♀)
    ofl/notosanssymbols2/NotoSansSymbols2-Regular.ttf
Salida: apps/pkarktools/assets/fonts/NotoSansSymbols-Subset.ttf y
NotoSansSymbols2-Subset.ttf. La licencia está en OFL-NotoSansSymbols.txt.
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

# Bloques Unicode incluidos: flechas, técnicos (⌘ ⇧), formas geométricas,
# símbolos varios (♂ ♀ ★ ⚠), dingbats (✦ ✓) y flechas/símbolos misceláneos.
RANGES = [
    (0x2190, 0x21FF),
    (0x2300, 0x23FF),
    (0x25A0, 0x25FF),
    (0x2600, 0x26FF),
    (0x2700, 0x27BF),
    (0x2B00, 0x2BFF),
]

OUT = os.path.join(os.path.dirname(__file__), '..', 'apps', 'pkarktools', 'assets', 'fonts')


def build(src: str, dst: str) -> None:
    font = TTFont(src)
    cmap = font.getBestCmap()
    unicodes = [u for lo, hi in RANGES for u in range(lo, hi + 1) if u in cmap]
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.name_languages = ['*']
    opts.notdef_outline = True
    opts.hinting = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=unicodes)
    sub.subset(font)
    font.save(dst)
    print(f'{os.path.basename(dst)}: {len(unicodes)} glifos, {os.path.getsize(dst)} bytes')


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else '.scratch/noto'
    build(os.path.join(src, 'NotoSansSymbols[wght].ttf'), os.path.join(OUT, 'NotoSansSymbols-Subset.ttf'))
    build(os.path.join(src, 'NotoSansSymbols2-Regular.ttf'), os.path.join(OUT, 'NotoSansSymbols2-Subset.ttf'))


if __name__ == '__main__':
    main()
