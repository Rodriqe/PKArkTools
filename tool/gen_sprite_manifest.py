#!/usr/bin/env python3
"""Genera el índice de iconos (sprites) que la app descarga bajo demanda.

Uso:
    python3 tool/gen_sprite_manifest.py <clon de PKHeX en el commit fijado> \
        apps/pkarktools/lib/data/sprites/sprite_manifest.g.dart

Los iconos NO se empaquetan: la app los descarga de
https://raw.githubusercontent.com/kwsch/PKHeX/<commit>/... y los guarda en su
directorio de caché. Este script solo lista los nombres de archivo y sus
tamaños (para estimar la descarga completa y no pedir iconos que no existen) y
la tabla de objetos de Gen 2/3 → Gen 4 de PKHeX `ItemConverter`.
Los sprites son © Nintendo/Game Freak/The Pokémon Company.
"""
import os
import re
import subprocess
import sys

REPO = sys.argv[1]
OUT = sys.argv[2]

SETS = {
    'pokemon': 'PKHeX.Drawing.PokeSprite/Resources/img/Big Pokemon Sprites',
    'shiny': 'PKHeX.Drawing.PokeSprite/Resources/img/Big Shiny Sprites',
    'item': 'PKHeX.Drawing.PokeSprite/Resources/img/Big Items',
    'ball': 'PKHeX.Drawing.PokeSprite/Resources/img/ball',
    'ribbon': 'PKHeX.Drawing.Misc/Resources/img/ribbons',
    'type': 'PKHeX.Drawing.Misc/Resources/img/types/square',
}


def conv_table(name):
    src = open(os.path.join(REPO, 'PKHeX.Core', 'PKM', 'Util', 'Conversion', 'ItemConverter.cs'), encoding='utf-8').read()
    i = src.index(f'ReadOnlySpan<ushort> {name} =>')
    body = src[src.index('[', i) + 1:src.index('];', i)]
    body = re.sub(r'//[^\n]*', '', body)
    vals = [v.strip() for v in body.replace('\n', ',').split(',') if v.strip()]
    return [65535 if v == 'NaN' else (int(v, 16) if v.lower().startswith('0x') else int(v, 10)) for v in vals]


def main():
    commit = subprocess.check_output(['git', '-C', REPO, 'rev-parse', 'HEAD'], text=True).strip()
    out = [
        '// GENERADO por tool/gen_sprite_manifest.py. No editar a mano.',
        '// Índice de los iconos de PKHeX (GPL-3.0) que se descargan bajo demanda;',
        '// los sprites son © Nintendo/Game Freak/The Pokémon Company y no se distribuyen con la app.',
        '// ignore_for_file: lines_longer_than_80_chars',
        '',
        f"const String kSpriteCommit = '{commit}';",
        '',
        '/// Carpeta de cada grupo dentro del repositorio.',
        'const Map<String, String> kSpriteDirs = {',
    ]
    for k, d in SETS.items():
        out.append(f"  '{k}': '{d}',")
    out.append('};')
    out.append('')
    out.append('/// Archivos de cada grupo (sin «.png») y su tamaño en bytes, «nombre:tamaño» separados por comas.')
    out.append('const Map<String, String> kSpriteFiles = {')
    total = 0
    for k, d in SETS.items():
        files = sorted(f for f in os.listdir(os.path.join(REPO, d)) if f.endswith('.png'))
        entries = []
        for f in files:
            size = os.path.getsize(os.path.join(REPO, d, f))
            total += size
            entries.append(f'{f[:-4]}:{size}')
        out.append(f"  '{k}': '{','.join(entries)}',")
    out.append('};')
    out.append('')
    out.append(f'const int kSpriteTotalBytes = {total};')
    out.append('')
    out.append('/// PKHeX `ItemConverter.Item3to4`: objeto de Gen 3 → id moderno (65535 = no existe).')
    out.append('const List<int> kItem3to4 = [' + ', '.join(map(str, conv_table('Item3to4'))) + '];')
    out.append('')
    out.append('/// PKHeX `ItemConverter.Item2to4`: objeto de Gen 2 → id moderno (65535 = no existe).')
    out.append('const List<int> kItem2to4 = [' + ', '.join(map(str, conv_table('Item2to4'))) + '];')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print(commit, total)


main()
