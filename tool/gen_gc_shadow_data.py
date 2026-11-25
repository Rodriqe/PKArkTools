#!/usr/bin/env python3
"""Genera la tabla de Pokémon oscuros de Colosseum/XD de pkcore desde el oráculo PKHeX.

Uso (lo llama tool/gen_gc_shadow_data.sh):
    python3 tool/gen_gc_shadow_data.py <shadow_oracle.csv> \
        packages/pkcore/lib/src/data/generated/gc_shadow_data.dart

Cada fila de `shadow_oracle.csv` (comando `shadows` de tools/pkhex_oracle) es un
encuentro oscuro de PKHeX `Encounters3Colo.Shadow` / `Encounters3XD.Shadow` con
sus movimientos y semillas de origen del RNG de GameCube cuyo PID/IV pasa los
bloqueos del equipo del entrenador NPC y que PKHeX da por legales.
"""
import csv
import sys

SRC, OUT = sys.argv[1], sys.argv[2]


def main():
    rows = list(csv.DictReader(open(SRC, encoding='utf-8')))
    assert len(rows) > 150, len(rows)
    b = ['// GENERADO por tool/gen_gc_shadow_data.py — no editar a mano.\n',
         '// Fuente: PKHeX.Core (GPL-3.0), encuentros oscuros y bloqueos de equipo (LockFinder).\n',
         '// ignore_for_file: lines_longer_than_80_chars\n\n',
         '/// (juego, id oscuro, especie, nivel, lugar, medidor, Ball fija, amistad base, movimientos, semillas de origen).\n',
         'const List<(String, int, int, int, int, int, int, int, List<int>, List<int>)> kGcShadowEncounters = [\n']
    for r in rows:
        seeds = [s for s in r['seeds'].split(';') if s]
        assert seeds, r
        moves = ', '.join(str(int(m)) for m in r['moves'].split(';'))
        b.append(f"  ('{r['game']}', {r['index']}, {r['species']}, {r['level']}, {r['location']}, {r['gauge']}, "
                 f"{r['ball']}, {r['friendship']}, [{moves}], [{', '.join('0x' + s for s in seeds)}]),\n")
    b.append('];\n')
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(''.join(b))
    print(f'{len(rows)} encuentros oscuros → {OUT}')


if __name__ == '__main__':
    main()
