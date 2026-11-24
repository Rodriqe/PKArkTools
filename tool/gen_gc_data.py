#!/usr/bin/env python3
"""Genera los datos de Pokémon Colosseum y XD de pkcore a partir de PKHeX.Core (GPL-3.0).

Uso:
    python3 tool/gen_gc_data.py <ruta a PKHeX.Core> \
        packages/pkcore/lib/src/data/generated/gc_data.dart

Produce `gc_data.dart` con:
  * kGcItems: nombres (es/en) de los objetos propios de Colosseum y XD (ids
    desde 500), de Resources/text/items/gen3/text_ItemsG3{Colosseum,XD}_*.txt.
  * kGcLocations: nombres (es/en) de los lugares de Colosseum/XD
    (Resources/text/locations/gen3/text_cxd_00000_*.txt).
  * kGcEncounters: encuentros de Legality/Encounters/Data/Gen3/Encounters3Colo.cs
    y Encounters3XD.cs: Pokémon oscuros (id oscuro y medidor de corazón),
    iniciales, regalos, intercambios y Poké Spots.
"""
import os
import re
import sys

PK, OUT = sys.argv[1], sys.argv[2]
TEXT = os.path.join(PK, 'Resources', 'text')
DATA = os.path.join(PK, 'Legality', 'Encounters', 'Data', 'Gen3')


def read_lines(path):
    with open(path, 'rb') as f:
        raw = f.read()
    if raw.startswith(b'\xff\xfe') or raw.startswith(b'\xfe\xff'):
        txt = raw.decode('utf-16')
    else:
        try:
            txt = raw.decode('utf-8-sig')
        except UnicodeDecodeError:  # algunos textos en español de PKHeX están en Windows-1252
            txt = raw.decode('cp1252')
    return [l.rstrip('\r') for l in txt.split('\n')]


def items(game, lang):
    lines = read_lines(os.path.join(TEXT, 'items', 'gen3', f'text_ItemsG3{game}_{lang}.txt'))
    while lines and not lines[-1]:
        lines.pop()
    return lines


def locations(lang):
    lines = read_lines(os.path.join(TEXT, 'locations', 'gen3', f'text_cxd_00000_{lang}.txt'))
    while lines and not lines[-1]:
        lines.pop()
    return lines


# Tipos: 0 oscuro, 1 inicial, 2 regalo, 3 intercambio, 4 Poké Spot.
SHADOW, STARTER, GIFT, TRADE, POKESPOT = 0, 1, 2, 3, 4


def strip_comments(src):
    return '\n'.join(l.split('//')[0] for l in src.split('\n'))


def encounters():
    out = []  # (game, kind, species, levelMin, levelMax, location, shadowId, gauge, ball)
    colo = strip_comments(open(os.path.join(DATA, 'Encounters3Colo.cs'), encoding='utf-8').read())
    xd = strip_comments(open(os.path.join(DATA, 'Encounters3XD.cs'), encoding='utf-8').read())

    def block(src, name):
        m = re.search(r'\b' + name + r'\s*=\s*\[(.*?)\n\s*\];', src, re.S)
        return m.group(1) if m else ''

    shadow_re = re.compile(r'new\((\d+),\s*(\d+),\s*\w+\)\s*\{([^}]*)\}')

    def field(body, name):
        m = re.search(name + r'\s*=\s*(\w+)', body)
        return m.group(1) if m else None

    for game, src in (('colo', colo), ('xd', xd)):
        for blk in ('Shadow', 'EReader'):
            for m in shadow_re.finditer(block(src, blk)):
                sid, gauge, body = int(m.group(1)), int(m.group(2)), m.group(3)
                lvl = int(field(body, 'Level'))
                ball = 4 if field(body, 'FixedBall') == 'Ball' or 'Ball.Poke' in body else 0
                out.append((game, SHADOW, int(field(body, 'Species')), lvl, lvl, int(field(body, 'Location')), sid, gauge, ball))
    # Colosseum: Espeon/Umbreon iniciales (lugar 254, Poké Ball) y Plusle de Duking (254).
    for m in re.finditer(r'new\((\d+),\s*(\d+)\)\s*\{\s*Moves', block(colo, 'Starters')):
        lv = int(m.group(2))
        out.append(('colo', STARTER, int(m.group(1)), lv, lv, 254, 0, 0, 4))
    for m in re.finditer(r'new\((\d+),\s*(\d+),[^)]*\)\s*\{([^}]*)\}', block(colo, 'Gifts')):
        lv = int(m.group(2))
        out.append(('colo', GIFT, int(m.group(1)), lv, lv, int(field(m.group(3), 'Location')), 0, 0, 4))
    # XD: regalos (Eevee, iniciales de Johto), intercambios y Poké Spots.
    for m in re.finditer(r'new\((\d+),\s*(\d+)\)\s*\{([^}]*)\}', block(xd, 'Gifts')):
        lv = int(m.group(2))
        out.append(('xd', GIFT, int(m.group(1)), lv, lv, int(field(m.group(3), 'Location')), 0, 0, 4))
    for m in re.finditer(r'new\((\d+),\s*(\d+),[^)]*\)\s*\{([^}]*)\}', block(xd, 'Trades')):
        lv = int(m.group(2))
        out.append(('xd', TRADE, int(m.group(1)), lv, lv, int(field(m.group(3), 'Location')), 0, 0, 0))
    for m in re.finditer(r'new\((\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\)', block(xd, 'Slots')):
        loc = int(m.group(1))
        for i in range(3):
            out.append(('xd', POKESPOT, int(m.group(2 + 2 * i)), 10, int(m.group(3 + 2 * i)), loc, 0, 0, 0))
    return out


def dart_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def dart_list(name, values):
    body = ''.join(f'  {dart_str(v)},\n' for v in values)
    return f'const List<String> {name} = <String>[\n{body}];\n\n'


def main():
    enc = encounters()
    assert len(enc) > 150, len(enc)
    b = ['// GENERADO por tool/gen_gc_data.py — no editar a mano.\n',
         '// Fuente: PKHeX.Core (GPL-3.0). Nombres © Nintendo/Game Freak/Creatures.\n',
         '// ignore_for_file: lines_longer_than_80_chars\n\n']
    for game, key in (('Colosseum', 'Colo'), ('XD', 'Xd')):
        for lang, suf in (('es', 'Es'), ('en', 'En')):
            b.append(dart_list(f'kGcItems{key}{suf}', items(game, lang)))
    for lang, suf in (('es', 'Es'), ('en', 'En')):
        b.append(dart_list(f'kGcLocations{suf}', locations(lang)))
    b.append('/// (juego, tipo, especie, nivel mín., nivel máx., lugar, id oscuro, medidor, Ball fija).\n')
    b.append('/// Tipo: 0 oscuro, 1 inicial, 2 regalo, 3 intercambio, 4 Poké Spot.\n')
    b.append('const List<(String, int, int, int, int, int, int, int, int)> kGcEncounters = [\n')
    for e in enc:
        b.append(f"  ('{e[0]}', {', '.join(str(x) for x in e[1:])}),\n")
    b.append('];\n')
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(''.join(b))
    print(f'{len(enc)} encuentros → {OUT}')


if __name__ == '__main__':
    main()
