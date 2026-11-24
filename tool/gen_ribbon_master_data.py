#!/usr/bin/env python3
"""Genera la tabla de rutas de Ribbon Master de pkcore y su tabla de verificación.

Uso:
    python3 tool/gen_ribbon_master_data.py <ribbon_oracle.csv> <raíz del repo>

Entrada: la salida del oráculo PKHeX (`tools/pkhex_oracle`, comando `ribbons`).
Salidas:
  * packages/pkcore/lib/src/data/generated/ribbon_master_data.dart: por especie y
    forma, el origen (generación, versión, tipo de encuentro, evento, oscuro,
    nivel), el formato final y la cadena de evoluciones posible en cada contexto
    de juego (PKHeX `EvolutionHistory`). NO incluye las cintas: las calcula el
    motor de pkcore (`RibbonMaster`) con sus reglas.
  * packages/pkcore/test/data/ribbon_oracle.csv.gz: las cintas que PKHeX da por
    válidas para cada especie/forma, para `ribbon_master_pkhex_test.dart`.
"""
import csv
import gzip
import os
import sys

SRC, ROOT = sys.argv[1], sys.argv[2]

KIND = {
    'EncounterShadow3Colo': 'shadow', 'EncounterShadow3XD': 'shadow',
    'EncounterSlot7GO': 'go', 'EncounterSlot8GO': 'go',
}


def kind(name, event):
    if event == '1':
        return 'event'
    if name in KIND:
        return KIND[name]
    if name.startswith('EncounterEgg'):
        return 'egg'
    if name.startswith('EncounterSlot'):
        return 'wild'
    if name.startswith('EncounterTrade'):
        return 'trade'
    if name.startswith('EncounterStatic8N') or name.startswith('EncounterStatic8U') or name.startswith('EncounterTera') \
            or name.startswith('EncounterMight') or name.startswith('EncounterDist') or name.startswith('EncounterOutbreak'):
        return 'raid'
    if 'Gift' in name or 'Starter' in name:
        return 'gift'
    return 'static'


def main():
    rows = [r for r in csv.reader(l for l in open(SRC, encoding='utf-8') if not l.startswith('#'))]
    routes, oracle = [], []
    for r in rows:
        sp, form, final, gen, ver, enc, ev, shadow, lvl, chains, ribbons, mc, mb, flags = r
        if not final:
            continue
        routes.append(','.join([sp, form, final, gen, ver, kind(enc, ev), shadow, lvl, chains.rstrip(';'), flags]))
        oracle.append(','.join([sp, form, gen, ver, ribbons, mc, mb]))
    out = os.path.join(ROOT, 'packages/pkcore/lib/src/data/generated/ribbon_master_data.dart')
    with open(out, 'w', encoding='utf-8') as f:
        f.write('// GENERADO por tool/gen_ribbon_master_data.py desde el oráculo PKHeX (GPL-3.0). No editar a mano.\n')
        f.write('// ignore_for_file: lines_longer_than_80_chars\n\n')
        f.write('/// Una línea por especie y forma:\n')
        f.write('/// `especie,forma,formato final,generación de origen,versión de origen (PKHeX),tipo de encuentro,\n')
        f.write('/// oscuro (0/1),nivel mínimo,cadenas por contexto (Ctx=especie-forma/…;…),banderas (V sin voz en DBPR, M singular)`.\n')
        f.write("const String kRibbonRoutes = '''\n")
        f.write('\n'.join(routes))
        f.write("\n''';\n")
    test = os.path.join(ROOT, 'packages/pkcore/test/data/ribbon_oracle.csv.gz')
    with gzip.GzipFile(test, 'wb', mtime=0) as g:
        g.write(('# especie,forma,generacion de origen,version,cintas validas segun PKHeX (|),recuerdo concurso,recuerdo combate\n'
                 + '\n'.join(oracle) + '\n').encode('utf-8'))
    print(f'{len(routes)} rutas → {out}\n{len(oracle)} filas → {test}')


main()
