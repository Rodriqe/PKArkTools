#!/usr/bin/env python3
"""Genera packages/pkcore/lib/src/data/generated/evolution_data.dart desde la
tabla `evolutions.csv` del oráculo PKHeX (comando `dex`).

    tool/gen_dex_tables.sh   # compila el oráculo, vuelca las tablas y llama a este script

Cada evolución: especie, forma, especie destino, forma destino, método
(PKHeX `EvolutionType`), argumento (objeto, movimiento, tipo, especie…) y nivel,
del juego más reciente que tenga evoluciones para esa especie y forma.
"""
import csv
import sys
from pathlib import Path


def main(src: str, root: str) -> None:
    rows = []
    with open(Path(src) / 'evolutions.csv', encoding='utf-8') as f:
        for r in csv.reader(line for line in f if not line.startswith('#')):
            s, form, _game, dest, dform, method, arg, level = r
            # Pikachu con gorra o disfraz no evoluciona (PKHeX copia la forma al destino).
            if int(s) == 25 and int(form) != 0:
                continue
            rows.append([int(s), int(form), int(dest), int(dform), int(method), int(arg), int(level)])
    rows.sort()
    flat = ','.join(str(v) for r in rows for v in r)
    out = Path(root) / 'packages/pkcore/lib/src/data/generated/evolution_data.dart'
    out.write_text(
        '// GENERADO por tool/gen_evolution_data.py — no editar a mano.\n'
        '// Datos: PKHeX.Core (GPL-3.0), árbol de evoluciones del juego más reciente\n'
        '// que tenga evoluciones para cada especie y forma.\n'
        '// ignore_for_file: lines_longer_than_80_chars\n\n'
        '/// Evoluciones en grupos de 7: especie, forma, destino, forma destino,\n'
        '/// método (PKHeX `EvolutionType`), argumento y nivel.\n'
        f'const List<int> kEvolutionRows = <int>[{flat}];\n',
        encoding='utf-8')
    print(f'{len(rows)} evoluciones -> {out}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
