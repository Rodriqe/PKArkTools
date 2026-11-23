#!/usr/bin/env python3
"""Comprueba los enlaces relativos, las anclas y las imágenes de los .md.

    python3 tool/check_links.py            # todos los .md del repositorio
    python3 tool/check_links.py docs/a.md  # solo esos archivos

Revisa enlaces Markdown `[texto](ruta#ancla)`, imágenes `![](ruta)` y
etiquetas HTML `<img src>` / `<a href>`. Los enlaces externos (http, https,
mailto) no se comprueban: el script no usa la red. Las anclas se calculan como
las genera GitHub para los títulos. Sale con código 1 si algo no existe.
"""
from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {'.git', '.ref', '.scratch', '.pub-cache', '.dart_tool', 'build', 'node_modules', 'ephemeral', 'Pods'}

MD_LINK = re.compile(r'!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)')
HTML_LINK = re.compile(r'<(?:img|a|source)\b[^>]*?\s(?:src|href)\s*=\s*"([^"]+)"', re.I)
HEADING = re.compile(r'^(#{1,6})\s+(.*?)\s*#*\s*$')
FENCE = re.compile(r'^\s*(```|~~~)')


def slug(text: str) -> str:
    """Ancla al estilo de GitHub: minúsculas, sin puntuación, espacios → guiones."""
    text = re.sub(r'<[^>]+>', '', text)                 # etiquetas HTML
    text = re.sub(r'!?\[([^\]]*)\]\([^)]*\)', r'\1', text)  # enlaces → su texto
    text = text.replace('`', '').strip().lower()
    out = []
    for ch in text:
        cat = unicodedata.category(ch)
        if ch in ' -':
            out.append('-' if ch == ' ' else ch)
        elif ch == '_' or cat[0] in ('L', 'N') or cat == 'Mn':
            out.append(ch)
    return ''.join(out)


def strip_code(lines: list[str]) -> list[tuple[int, str]]:
    """Líneas fuera de bloques de código, con el código en línea eliminado."""
    out, fenced = [], False
    for i, line in enumerate(lines, 1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if not fenced:
            out.append((i, re.sub(r'`[^`]*`', '', line)))
    return out


_anchor_cache: dict[Path, set[str]] = {}


def anchors(path: Path) -> set[str]:
    if path not in _anchor_cache:
        seen: dict[str, int] = {}
        result = set()
        for _, line in strip_code(path.read_text(encoding='utf-8').splitlines()):
            m = HEADING.match(line)
            if not m:
                continue
            base = slug(m.group(2))
            n = seen.get(base, 0)
            seen[base] = n + 1
            result.add(base if n == 0 else f'{base}-{n}')
        for m in re.finditer(r'<a\s+(?:name|id)="([^"]+)"', path.read_text(encoding='utf-8')):
            result.add(m.group(1))
        _anchor_cache[path] = result
    return _anchor_cache[path]


def check(md: Path) -> list[str]:
    errors = []
    for lineno, line in strip_code(md.read_text(encoding='utf-8').splitlines()):
        for target in MD_LINK.findall(line) + HTML_LINK.findall(line):
            if re.match(r'^[a-z][a-z0-9+.-]*:', target, re.I):   # http:, https:, mailto:…
                continue
            path_part, _, frag = target.partition('#')
            dest = md if not path_part else (md.parent / path_part).resolve()
            where = f'{md.relative_to(ROOT)}:{lineno}'
            if not dest.exists():
                errors.append(f'{where}: no existe «{target}»')
                continue
            if frag and dest.suffix.lower() == '.md' and frag not in anchors(dest):
                errors.append(f'{where}: ancla «#{frag}» no existe en {dest.relative_to(ROOT)}')
    return errors


def all_markdown() -> list[Path]:
    files = []
    for p in ROOT.rglob('*.md'):
        rel = p.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        files.append(p)
    return sorted(files)


def main(argv: list[str]) -> int:
    files = [Path(a).resolve() for a in argv] if argv else all_markdown()
    errors = [e for f in files for e in check(f)]
    for e in errors:
        print(e, file=sys.stderr)
    print(f'Enlaces: {len(files)} archivos revisados, {len(errors)} errores.')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
