#!/usr/bin/env python3
"""Genera las tablas de cintas y marcas de pkcore a partir de PKHeX.Core (GPL-3.0).

Uso:
    python3 tool/gen_ribbon_data.py <ruta a PKHeX.Core> packages/pkcore/lib/src/data/generated/ribbon_data.dart

Lee las propiedades `Ribbon*` de PK3 … PA9 (bit y byte de cada cinta en la
estructura descifrada), los contadores (`RibbonCount*`), el byte de la cinta
mostrada (`AffixedRibbon`) y los nombres es/en de `text_Ribbons_*.txt`.
Los nombres son © Nintendo/Game Freak/Creatures.
"""
import os
import re
import sys

PK = sys.argv[1]
OUT = sys.argv[2]

SOURCES = {
    'pk3': ['PKM/PK3.cs'],
    'pk4': ['PKM/PK4.cs'],
    'pk5': ['PKM/PK5.cs'],
    'pk6': ['PKM/PK6.cs'],
    'pk7': ['PKM/PK7.cs'],
    'pb7': ['PKM/PB7.cs'],
    'pk8': ['PKM/Shared/G8PKM.cs'],
    'pb8': ['PKM/Shared/G8PKM.cs'],
    'pa8': ['PKM/PA8.cs'],
    'pk9': ['PKM/PK9.cs'],
    'pa9': ['PKM/PA9.cs'],
}

RE_RIB_DEF_BYTE = re.compile(r'private byte (RIB[0-9A-F])\s*\{\s*get => Data\[(0x[0-9A-Fa-f]+)\]')
RE_RIB_DEF_U32 = re.compile(r'private uint (RIB[0-9A-F])\s*\{\s*get => ReadUInt32LittleEndian\(Data\[(0x[0-9A-Fa-f]+)\.\.\]\)')
RE_BOOL_RIB = re.compile(r'public (?:override )?bool ((?:Ribbon|Has)[A-Za-z0-9]+)\s*\{\s*get => \((RIB[0-9A-F]) & \(1 << (\d+)\)\)')
RE_BOOL_FLAG = re.compile(r'public (?:override )?bool ((?:Ribbon|Has)[A-Za-z0-9]+)\s*\{\s*get => FlagUtil\.GetFlag\(Data, (0x[0-9A-Fa-f]+), (\d+)\)')
RE_COUNT_BYTE = re.compile(r'public (?:override )?byte (RibbonCount[A-Za-z0-9]+)\s*\{\s*get => Data\[(0x[0-9A-Fa-f]+)\]')
RE_COUNT_BITS = re.compile(r'public (?:override )?byte (RibbonCount[A-Za-z0-9]+)\s*\{\s*get => \(byte\)\(\((RIB[0-9A-F]) >> (\d+)\) & 7\)')
RE_AFFIXED = re.compile(r'public sbyte AffixedRibbon\s*\{\s*get => \(sbyte\)Data\[(0x[0-9A-Fa-f]+)\]')


def parse(fmt):
    text = ''.join(open(os.path.join(PK, p), encoding='utf-8').read() for p in SOURCES[fmt])
    ribs = {}
    for m in RE_RIB_DEF_BYTE.finditer(text):
        ribs[m.group(1)] = (int(m.group(2), 16), 1)
    for m in RE_RIB_DEF_U32.finditer(text):
        ribs[m.group(1)] = (int(m.group(2), 16), 4)
    entries = []  # (name, offset, bit, width)  width 1 = flag, 3 = contador de 3 bits, 8 = byte
    seen = set()
    for m in RE_BOOL_RIB.finditer(text):
        name, rib, bit = m.group(1), m.group(2), int(m.group(3))
        base, _ = ribs[rib]
        entries.append((name, base + bit // 8, bit % 8, 1))
    for m in RE_BOOL_FLAG.finditer(text):
        entries.append((m.group(1), int(m.group(2), 16), int(m.group(3)), 1))
    for m in RE_COUNT_BYTE.finditer(text):
        entries.append((m.group(1), int(m.group(2), 16), 0, 8))
    for m in RE_COUNT_BITS.finditer(text):
        rib, shift = m.group(2), int(m.group(3))
        base, _ = ribs[rib]
        # Contador de 3 bits en un u32 (PK3): se guarda como (byte base, bit absoluto).
        entries.append((m.group(1), base, shift, 3))
    out = []
    for e in entries:
        if e[0] in seen:
            continue
        seen.add(e[0])
        out.append(e)
    aff = RE_AFFIXED.search(text)
    return out, int(aff.group(1), 16) if aff else -1


def names(lang):
    path = os.path.join(PK, 'Resources', 'text', 'other', lang, f'text_Ribbons_{lang}.txt')
    raw = open(path, 'rb').read().decode('utf-8-sig')
    res = {}
    for line in raw.splitlines():
        if '\t' in line:
            k, v = line.split('\t', 1)
            res[k.strip()] = v.strip()
    return res


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def main():
    es, en = names('es'), names('en')
    lines = ['// GENERADO por tool/gen_ribbon_data.py desde PKHeX.Core (GPL-3.0). No editar a mano.',
             '// Nombres © Nintendo/Game Freak/Creatures.',
             '// ignore_for_file: lines_longer_than_80_chars', '']
    lines.append('/// Posición de cada cinta por formato: (nombre PKHeX, byte, bit, ancho).')
    lines.append('/// Ancho 1 = bandera; 3 = contador de 3 bits (PK3, el bit es absoluto en el u32); 8 = byte.')
    lines.append('const Map<String, List<(String, int, int, int)>> kRibbonLayouts = {')
    affixed = {}
    for fmt in SOURCES:
        entries, aff = parse(fmt)
        affixed[fmt] = aff
        lines.append(f"  '{fmt}': [")
        for (n, o, b, w) in entries:
            lines.append(f"    ({dart_str(n)}, 0x{o:02X}, {b}, {w}),")
        lines.append('  ],')
    lines.append('};')
    lines.append('')
    lines.append('/// Byte de la cinta mostrada (`AffixedRibbon`, -1 = ninguna) por formato.')
    lines.append('const Map<String, int> kRibbonAffixedOffset = {')
    for fmt, o in affixed.items():
        if o >= 0:
            lines.append(f"  '{fmt}': 0x{o:02X},")
    lines.append('};')
    lines.append('')
    lines.append('/// Orden de `RibbonIndex` de PKHeX (Gen 8+), para la cinta mostrada.')
    idx = open(os.path.join(PK, 'Ribbons', 'RibbonIndex.cs'), encoding='utf-8').read()
    body = idx[idx.index('enum RibbonIndex'):]
    body = body[body.index('{') + 1:body.index('MAX_COUNT')]
    order = [t.strip().rstrip(',') for t in body.split('\n') if t.strip().rstrip(',') and not t.strip().startswith('//')]
    lines.append('const List<String> kRibbonIndex = [')
    for n in order:
        lines.append(f"  'Ribbon{n}',")
    lines.append('];')
    lines.append('')
    lines.append('/// Nombres (es, en) de PKHeX `text_Ribbons_*`.')
    lines.append('const Map<String, (String, String)> kRibbonNames = {')
    for k, v in en.items():
        lines.append(f'  {dart_str(k)}: ({dart_str(es.get(k, v))}, {dart_str(v)}),')
    lines.append('};')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')


main()
